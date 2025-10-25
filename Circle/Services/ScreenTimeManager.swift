//
//  ScreenTimeManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import DeviceActivity
import FamilyControls
import CoreData
import Combine

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()
    
    @Published var isScreenTimeAvailable = false
    @Published var isStrictModeEnabled = false
    @Published var focusSessions: [FocusSession] = []
    @Published var dailyScreenTime: TimeInterval = 0
    @Published var weeklyScreenTime: TimeInterval = 0
    @Published var randomProofRequests: [RandomProofRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let cameraManager = CameraManager.shared
    private let notificationManager = NotificationManager.shared
    
    // Screen Time components
    private var deviceActivityCenter = DeviceActivityCenter()
    private var authorizationCenter = AuthorizationCenter.shared
    private var activityMonitor: DeviceActivityMonitor?
    
    // Focus session management
    private var focusSessionTimer: Timer?
    private var randomProofTimer: Timer?
    private var currentFocusSession: FocusSession?
    
    // Configuration
    private let maxDailyScreenTime: TimeInterval = 8 * 3600 // 8 hours
    private let focusSessionDuration: TimeInterval = 2 * 3600 // 2 hours
    private let randomProofInterval: TimeInterval = 4 * 3600 // 4 hours
    private let maxRandomProofsPerDay = 3
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkScreenTimeAvailability()
        setupNotifications()
        loadFocusSessions()
    }
    
    deinit {
        focusSessionTimer?.invalidate()
        randomProofTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func checkScreenTimeAvailability() {
        // Check if DeviceActivity is available
        isScreenTimeAvailable = DeviceActivityCenter.isSupported
        
        if isScreenTimeAvailable {
            // Check authorization status
            Task {
                await checkAuthorizationStatus()
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDayChanged),
            name: .NSCalendarDayChanged,
            object: nil
        )
    }
    
    // MARK: - Authorization
    private func checkAuthorizationStatus() async {
        do {
            let status = try await authorizationCenter.requestAuthorization(for: .individual)
            
            await MainActor.run {
                isStrictModeEnabled = status == .approved
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to check authorization status: \(error.localizedDescription)"
                isStrictModeEnabled = false
            }
            print("Error checking authorization status: \(error)")
        }
    }
    
    func requestScreenTimePermission() async {
        guard isScreenTimeAvailable else {
            errorMessage = "Screen Time is not available on this device"
            return
        }
        
        do {
            let status = try await authorizationCenter.requestAuthorization(for: .individual)
            
            await MainActor.run {
                isStrictModeEnabled = status == .approved
            }
            
            if isStrictModeEnabled {
                await setupStrictMode()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to request Screen Time permission: \(error.localizedDescription)"
                isStrictModeEnabled = false
            }
            print("Error requesting Screen Time permission: \(error)")
        }
    }
    
    // MARK: - Strict Mode Setup
    private func setupStrictMode() async {
        // Create device activity schedule
        await createDeviceActivitySchedule()
        
        // Start monitoring
        await startDeviceActivityMonitoring()
        
        // Schedule random proof requests
        scheduleRandomProofRequests()
    }
    
    private func createDeviceActivitySchedule() async {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        let activityName = DeviceActivityName("CircleScreenTime")
        
        do {
            try await deviceActivityCenter.startMonitoring(activityName, during: schedule)
            print("Device activity monitoring started")
        } catch {
            print("Error starting device activity monitoring: \(error)")
        }
    }
    
    private func startDeviceActivityMonitoring() async {
        let activityName = DeviceActivityName("CircleScreenTime")
        
        activityMonitor = DeviceActivityMonitor(activityName) { [weak self] event in
            Task { @MainActor in
                await self?.handleDeviceActivityEvent(event)
            }
        }
    }
    
    private func handleDeviceActivityEvent(_ event: DeviceActivityEvent) {
        switch event {
        case .didStart:
            print("Device activity started")
        case .didEnd:
            print("Device activity ended")
        case .didUpdate:
            print("Device activity updated")
        @unknown default:
            print("Unknown device activity event")
        }
    }
    
    // MARK: - Focus Sessions
    func startFocusSession(duration: TimeInterval = 2 * 3600) async {
        guard !isFocusSessionActive() else { return }
        
        let session = FocusSession(
            id: UUID(),
            startTime: Date(),
            duration: duration,
            isActive: true,
            completedProofs: [],
            totalScreenTime: 0
        )
        
        currentFocusSession = session
        focusSessions.append(session)
        
        // Start focus session timer
        startFocusSessionTimer(session)
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .focusSessionStarted,
            object: nil,
            userInfo: ["session": session]
        )
        
        print("Focus session started: \(session.id)")
    }
    
    func endFocusSession() async {
        guard let session = currentFocusSession else { return }
        
        session.endTime = Date()
        session.isActive = false
        
        // Calculate total screen time during session
        session.totalScreenTime = await calculateScreenTimeDuringSession(session)
        
        // Check if session was successful
        let isSuccessful = session.completedProofs.count >= 2 && session.totalScreenTime <= session.duration
        
        if isSuccessful {
            await awardFocusSessionPoints(session)
        }
        
        currentFocusSession = nil
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .focusSessionEnded,
            object: nil,
            userInfo: ["session": session, "isSuccessful": isSuccessful]
        )
        
        print("Focus session ended: \(session.id) - Success: \(isSuccessful)")
    }
    
    private func startFocusSessionTimer(_ session: FocusSession) {
        focusSessionTimer = Timer.scheduledTimer(withTimeInterval: session.duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.endFocusSession()
            }
        }
    }
    
    private func calculateScreenTimeDuringSession(_ session: FocusSession) async -> TimeInterval {
        // This would integrate with DeviceActivity to get actual screen time
        // For now, return a simulated value
        return Double.random(in: 0...session.duration)
    }
    
    private func awardFocusSessionPoints(_ session: FocusSession) async {
        // Award points for successful focus session
        // This would integrate with the PointsEngine
        print("Awarding points for successful focus session: \(session.id)")
    }
    
    // MARK: - Random Proof Requests
    private func scheduleRandomProofRequests() {
        randomProofTimer = Timer.scheduledTimer(withTimeInterval: randomProofInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.requestRandomProof()
            }
        }
    }
    
    private func requestRandomProof() async {
        // Check if we've reached the daily limit
        let today = Calendar.current.startOfDay(for: Date())
        let todayRequests = randomProofRequests.filter { $0.requestedAt >= today }
        
        guard todayRequests.count < maxRandomProofsPerDay else {
            print("Daily random proof limit reached")
            return
        }
        
        // Create random proof request
        let request = RandomProofRequest(
            id: UUID(),
            requestedAt: Date(),
            isCompleted: false,
            proofType: .screenTimeVerification,
            prompt: generateRandomPrompt()
        )
        
        randomProofRequests.append(request)
        
        // Send notification
        await notificationManager.scheduleCustomReminder(
            title: "Screen Time Check",
            body: request.prompt,
            date: Date().addingTimeInterval(300), // 5 minutes from now
            user: getCurrentUser() ?? User(),
            category: "SCREEN_TIME_CATEGORY"
        )
        
        print("Random proof requested: \(request.id)")
    }
    
    private func generateRandomPrompt() -> String {
        let prompts = [
            "Take a quick selfie to verify you're actively using your phone",
            "Show us what you're currently doing on your phone",
            "Take a photo of your current screen",
            "Verify you're using your phone responsibly right now",
            "Show us your current activity"
        ]
        
        return prompts.randomElement() ?? "Take a quick verification photo"
    }
    
    func completeRandomProof(_ request: RandomProofRequest) async throws {
        guard let index = randomProofRequests.firstIndex(where: { $0.id == request.id }) else {
            throw ScreenTimeError.requestNotFound
        }
        
        // Start camera proof
        let session = try await cameraManager.startSession(
            for: .antiCheat,
            duration: 10.0
        )
        
        // Verify the proof
        let verification = try await cameraManager.verifySession(session)
        
        if verification.isVerified {
            randomProofRequests[index].isCompleted = true
            randomProofRequests[index].completedAt = Date()
            
            // Award points
            await awardRandomProofPoints(request)
            
            print("Random proof completed: \(request.id)")
        } else {
            throw ScreenTimeError.verificationFailed
        }
    }
    
    private func awardRandomProofPoints(_ request: RandomProofRequest) async {
        // Award points for completing random proof
        // This would integrate with the PointsEngine
        print("Awarding points for random proof: \(request.id)")
    }
    
    // MARK: - Screen Time Tracking
    func getDailyScreenTime() async -> TimeInterval {
        guard isStrictModeEnabled else {
            // Fallback to estimated screen time
            return await getEstimatedScreenTime()
        }
        
        // Get actual screen time from DeviceActivity
        return await getActualScreenTime()
    }
    
    private func getActualScreenTime() async -> TimeInterval {
        // This would integrate with DeviceActivity to get actual screen time
        // For now, return a simulated value
        return Double.random(in: 0...maxDailyScreenTime)
    }
    
    private func getEstimatedScreenTime() async -> TimeInterval {
        // Estimate screen time based on app usage
        // This would integrate with app usage tracking
        return Double.random(in: 0...maxDailyScreenTime)
    }
    
    func getWeeklyScreenTime() async -> TimeInterval {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = Date()
        
        // Calculate weekly screen time
        var totalTime: TimeInterval = 0
        
        for day in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: day, to: weekStart) ?? Date()
            totalTime += await getScreenTimeForDate(date)
        }
        
        return totalTime
    }
    
    private func getScreenTimeForDate(_ date: Date) async -> TimeInterval {
        // Get screen time for a specific date
        return Double.random(in: 0...maxDailyScreenTime)
    }
    
    // MARK: - Screen Time Challenges
    func createScreenTimeChallenge(targetHours: Double, user: User) async throws -> Challenge {
        let context = persistenceController.container.viewContext
        
        let challenge = Challenge(context: context)
        challenge.id = UUID()
        challenge.title = "Screen Time Limit"
        challenge.description = "Keep screen time under \(targetHours) hours today"
        challenge.category = ChallengeCategory.screenTime.rawValue
        challenge.frequency = ChallengeFrequency.daily.rawValue
        challenge.targetValue = targetHours
        challenge.targetUnit = "hours"
        challenge.verificationMethod = VerificationMethod.screenTime.rawValue
        challenge.isActive = true
        challenge.pointsReward = Int32(Verify.challengeCompletePoints)
        challenge.pointsPenalty = Int32(abs(Verify.challengeMissPoints))
        challenge.createdBy = user
        challenge.startDate = Date()
        challenge.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        // Create verification parameters
        let params = ScreenTimeChallengeParams(
            maxHours: targetHours,
            categories: ["social", "entertainment", "games"]
        )
        challenge.verificationParams = try JSONEncoder().encode(params)
        
        try context.save()
        
        return challenge
    }
    
    func verifyScreenTimeChallenge(_ challenge: Challenge, user: User) async -> Proof {
        let context = persistenceController.container.viewContext
        
        let proof = Proof(context: context)
        proof.id = UUID()
        proof.user = user
        proof.challenge = challenge
        proof.timestamp = Date()
        proof.verificationMethod = VerificationMethod.screenTime.rawValue
        
        // Get current screen time
        let currentScreenTime = await getDailyScreenTime()
        let targetScreenTime = challenge.targetValue * 3600 // Convert hours to seconds
        
        // Verify challenge
        proof.isVerified = currentScreenTime <= targetScreenTime
        proof.confidenceScore = proof.isVerified ? 0.9 : 0.1
        proof.pointsAwarded = proof.isVerified ? challenge.pointsReward : -challenge.pointsPenalty
        
        // Add sensor data
        let sensorData = ScreenTimeData(
            totalScreenTime: currentScreenTime,
            targetScreenTime: targetScreenTime,
            isStrictMode: isStrictModeEnabled,
            timestamp: Date()
        )
        proof.sensorData = try? JSONEncoder().encode(sensorData)
        
        proof.notes = proof.isVerified ? "Screen time challenge completed" : "Screen time limit exceeded"
        
        try? context.save()
        
        return proof
    }
    
    // MARK: - Helper Methods
    private func isFocusSessionActive() -> Bool {
        return currentFocusSession?.isActive ?? false
    }
    
    private func getCurrentUser() -> User? {
        // This would be implemented to get the current authenticated user
        return nil
    }
    
    private func loadFocusSessions() {
        let request: NSFetchRequest<FocusSession> = FocusSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startTime, ascending: false)]
        request.fetchLimit = 50
        
        do {
            focusSessions = try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error loading focus sessions: \(error)")
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // App became active - check for random proof requests
        Task {
            await checkPendingRandomProofs()
        }
    }
    
    @objc private func handleAppWillResignActive(_ notification: Notification) {
        // App will resign active - pause focus session if active
        if isFocusSessionActive() {
            // Pause focus session
            print("Focus session paused due to app becoming inactive")
        }
    }
    
    @objc private func handleDayChanged(_ notification: Notification) {
        // New day - reset daily counters
        Task {
            await resetDailyCounters()
        }
    }
    
    private func checkPendingRandomProofs() async {
        let pendingRequests = randomProofRequests.filter { !$0.isCompleted }
        
        for request in pendingRequests {
            // Check if request is overdue
            let timeSinceRequest = Date().timeIntervalSince(request.requestedAt)
            if timeSinceRequest > 3600 { // 1 hour
                // Mark as missed
                if let index = randomProofRequests.firstIndex(where: { $0.id == request.id }) {
                    randomProofRequests[index].isCompleted = false
                    randomProofRequests[index].completedAt = Date()
                }
            }
        }
    }
    
    private func resetDailyCounters() async {
        // Reset daily screen time
        dailyScreenTime = 0
        
        // Reset random proof requests
        randomProofRequests.removeAll()
        
        // Reset focus sessions
        focusSessions.removeAll()
        
        print("Daily counters reset")
    }
    
    // MARK: - Analytics
    func getScreenTimeStats() -> ScreenTimeStats {
        let totalFocusSessions = focusSessions.count
        let successfulFocusSessions = focusSessions.filter { $0.isActive == false && $0.completedProofs.count >= 2 }.count
        let successRate = totalFocusSessions > 0 ? Double(successfulFocusSessions) / Double(totalFocusSessions) : 0.0
        
        let totalRandomProofs = randomProofRequests.count
        let completedRandomProofs = randomProofRequests.filter { $0.isCompleted }.count
        let completionRate = totalRandomProofs > 0 ? Double(completedRandomProofs) / Double(totalRandomProofs) : 0.0
        
        return ScreenTimeStats(
            dailyScreenTime: dailyScreenTime,
            weeklyScreenTime: weeklyScreenTime,
            totalFocusSessions: totalFocusSessions,
            successfulFocusSessions: successfulFocusSessions,
            focusSessionSuccessRate: successRate,
            totalRandomProofs: totalRandomProofs,
            completedRandomProofs: completedRandomProofs,
            randomProofCompletionRate: completionRate,
            isStrictModeEnabled: isStrictModeEnabled,
            isScreenTimeAvailable: isScreenTimeAvailable
        )
    }
}

// MARK: - Supporting Types
class FocusSession: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var duration: TimeInterval
    @NSManaged public var isActive: Bool
    @NSManaged public var completedProofs: Set<Proof>
    @NSManaged public var totalScreenTime: TimeInterval
}

struct RandomProofRequest {
    let id: UUID
    let requestedAt: Date
    var isCompleted: Bool
    let proofType: ProofType
    let prompt: String
    var completedAt: Date?
}

enum ProofType: String, CaseIterable {
    case screenTimeVerification = "screen_time_verification"
    case focusSessionVerification = "focus_session_verification"
    case randomCheck = "random_check"
}

struct ScreenTimeData: Codable {
    let totalScreenTime: TimeInterval
    let targetScreenTime: TimeInterval
    let isStrictMode: Bool
    let timestamp: Date
}

struct ScreenTimeStats {
    let dailyScreenTime: TimeInterval
    let weeklyScreenTime: TimeInterval
    let totalFocusSessions: Int
    let successfulFocusSessions: Int
    let focusSessionSuccessRate: Double
    let totalRandomProofs: Int
    let completedRandomProofs: Int
    let randomProofCompletionRate: Double
    let isStrictModeEnabled: Bool
    let isScreenTimeAvailable: Bool
}

enum ScreenTimeError: LocalizedError {
    case requestNotFound
    case verificationFailed
    case authorizationDenied
    case deviceNotSupported
    
    var errorDescription: String? {
        switch self {
        case .requestNotFound:
            return "Random proof request not found"
        case .verificationFailed:
            return "Proof verification failed"
        case .authorizationDenied:
            return "Screen Time authorization denied"
        case .deviceNotSupported:
            return "Screen Time not supported on this device"
        }
    }
}

// MARK: - Core Data Extensions
extension FocusSession {
    static func fetchRequest() -> NSFetchRequest<FocusSession> {
        return NSFetchRequest<FocusSession>(entityName: "FocusSession")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let focusSessionStarted = Notification.Name("focusSessionStarted")
    static let focusSessionEnded = Notification.Name("focusSessionEnded")
    static let randomProofRequested = Notification.Name("randomProofRequested")
    static let randomProofCompleted = Notification.Name("randomProofCompleted")
}
