//
//  ChallengeEngine.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import BackgroundTasks
import Combine

@MainActor
class ChallengeEngine: ObservableObject {
    static let shared = ChallengeEngine()
    
    @Published var activeChallenges: [Challenge] = []
    @Published var scheduledChallenges: [Challenge] = []
    @Published var completedChallenges: [Challenge] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let verificationEngine = ChallengeVerificationEngine()
    private let geofenceManager = GeofenceManager.shared
    private let antiCheatEngine = AntiCheatEngine.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var challengeTimers: [UUID: Timer] = [:]
    private var evaluationTimer: Timer?
    
    private init() {
        setupNotifications()
        loadChallenges()
        startEvaluationTimer()
        scheduleBackgroundTasks()
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGeofenceChallengeCompleted),
            name: .geofenceChallengeCompleted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHangoutStarted),
            name: .hangoutStarted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHangoutEnded),
            name: .hangoutEnded,
            object: nil
        )
    }
    
    private func startEvaluationTimer() {
        // Evaluate challenges every 5 minutes
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.evaluateAllActiveChallenges()
            }
        }
    }
    
    private func stopAllTimers() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        
        challengeTimers.values.forEach { $0.invalidate() }
        challengeTimers.removeAll()
    }
    
    // MARK: - Challenge Loading
    private func loadChallenges() {
        isLoading = true
        errorMessage = nil
        
        let request: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Challenge.startDate, ascending: true)]
        
        do {
            activeChallenges = try persistenceController.container.viewContext.fetch(request)
            categorizeChallenges()
            isLoading = false
        } catch {
            errorMessage = "Failed to load challenges: \(error.localizedDescription)"
            isLoading = false
            print("Error loading challenges: \(error)")
        }
    }
    
    private func categorizeChallenges() {
        let now = Date()
        
        scheduledChallenges = activeChallenges.filter { challenge in
            challenge.startDate > now
        }
        
        completedChallenges = activeChallenges.filter { challenge in
            if let endDate = challenge.endDate {
                return endDate <= now
            }
            return false
        }
        
        activeChallenges = activeChallenges.filter { challenge in
            challenge.startDate <= now && (challenge.endDate == nil || challenge.endDate! > now)
        }
    }
    
    // MARK: - Challenge Creation
    func createChallenge(
        from template: ChallengeTemplate,
        circle: Circle,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> Challenge {
        let context = persistenceController.container.viewContext
        
        let challenge = Challenge(context: context)
        challenge.id = UUID()
        challenge.title = template.title
        challenge.description = template.description
        challenge.category = template.category
        challenge.frequency = template.frequency
        challenge.targetValue = template.targetValue
        challenge.targetUnit = template.targetUnit
        challenge.verificationMethod = template.verificationMethod
        challenge.verificationParams = template.verificationParams
        challenge.startDate = startDate ?? Date()
        challenge.endDate = endDate
        challenge.isActive = true
        challenge.pointsReward = Int32(Verify.challengeCompletePoints)
        challenge.pointsPenalty = Int32(abs(Verify.challengeMissPoints))
        challenge.createdBy = getCurrentUser()
        challenge.circle = circle
        challenge.template = template
        
        // Set up geofence if it's a location challenge
        if challenge.verificationMethod == VerificationMethod.location.rawValue {
            setupGeofenceForChallenge(challenge)
        }
        
        // Set up challenge timer
        setupChallengeTimer(challenge)
        
        try context.save()
        
        await MainActor.run {
            loadChallenges()
        }
        
        return challenge
    }
    
    // MARK: - Challenge Management
    func activateChallenge(_ challenge: Challenge) {
        challenge.isActive = true
        challenge.startDate = Date()
        
        setupGeofenceForChallenge(challenge)
        setupChallengeTimer(challenge)
        
        saveContext()
        loadChallenges()
    }
    
    func deactivateChallenge(_ challenge: Challenge) {
        challenge.isActive = false
        challenge.endDate = Date()
        
        removeGeofenceForChallenge(challenge)
        challengeTimers[challenge.id]?.invalidate()
        challengeTimers.removeValue(forKey: challenge.id)
        
        saveContext()
        loadChallenges()
    }
    
    func deleteChallenge(_ challenge: Challenge) {
        removeGeofenceForChallenge(challenge)
        challengeTimers[challenge.id]?.invalidate()
        challengeTimers.removeValue(forKey: challenge.id)
        
        let context = persistenceController.container.viewContext
        context.delete(challenge)
        
        saveContext()
        loadChallenges()
    }
    
    // MARK: - Challenge Evaluation
    func evaluateAllActiveChallenges() async {
        for challenge in activeChallenges {
            await evaluateChallenge(challenge)
        }
    }
    
    func evaluateChallenge(_ challenge: Challenge) async {
        guard let user = getCurrentUser() else { return }
        
        // Check if challenge is within evaluation window
        guard isWithinEvaluationWindow(challenge) else { return }
        
        // Check if already evaluated today
        if hasBeenEvaluatedToday(challenge, user: user) {
            return
        }
        
        // Anti-cheat check
        let integrityResult = antiCheatEngine.verifyChallengeIntegrity(challenge, user: user)
        guard integrityResult.isVerified else {
            print("Challenge integrity check failed: \(integrityResult.notes ?? "Unknown reason")")
            return
        }
        
        // Verify challenge
        let proof = verificationEngine.verifyChallenge(challenge, for: user)
        
        // Save proof
        let context = persistenceController.container.viewContext
        context.insert(proof)
        
        // Award points
        await awardPoints(for: proof, challenge: challenge, user: user)
        
        // Save context
        do {
            try context.save()
            print("Challenge evaluated: \(challenge.title ?? "Unknown") - \(proof.isVerified ? "PASSED" : "FAILED")")
        } catch {
            print("Error saving challenge evaluation: \(error)")
        }
    }
    
    // MARK: - Geofence Integration
    private func setupGeofenceForChallenge(_ challenge: Challenge) {
        guard challenge.verificationMethod == VerificationMethod.location.rawValue,
              let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(LocationChallengeParams.self, from: paramsData) else {
            return
        }
        
        let identifier = "challenge_\(challenge.id.uuidString)"
        geofenceManager.createGeofence(
            name: challenge.title ?? "Challenge Location",
            coordinate: params.targetLocation,
            radius: params.radiusMeters,
            minDuration: params.minDurationMinutes
        )
    }
    
    private func removeGeofenceForChallenge(_ challenge: Challenge) {
        let identifier = "challenge_\(challenge.id.uuidString)"
        geofenceManager.removeGeofence(identifier: identifier)
    }
    
    // MARK: - Timer Management
    private func setupChallengeTimer(_ challenge: Challenge) {
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.evaluateChallenge(challenge)
            }
        }
        
        challengeTimers[challenge.id] = timer
    }
    
    // MARK: - Points System
    private func awardPoints(for proof: Proof, challenge: Challenge, user: User) async {
        let pointsLedger = PointsLedger(context: persistenceController.container.viewContext)
        pointsLedger.id = UUID()
        pointsLedger.user = user
        pointsLedger.points = proof.pointsAwarded
        pointsLedger.reason = proof.isVerified ? "challenge_complete" : "challenge_miss"
        pointsLedger.timestamp = Date()
        pointsLedger.challenge = challenge
        
        // Update user points
        user.totalPoints += proof.pointsAwarded
        user.weeklyPoints += proof.pointsAwarded
        
        // Check for group challenge bonus
        if proof.isVerified {
            await checkGroupChallengeBonus(challenge: challenge, user: user)
        }
    }
    
    private func checkGroupChallengeBonus(challenge: Challenge, user: User) async {
        guard let circle = challenge.circle else { return }
        
        // Count how many members completed the same challenge today
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(
            format: "challenge == %@ AND timestamp >= %@ AND timestamp < %@ AND isVerified == YES",
            challenge, today as NSDate, tomorrow as NSDate
        )
        
        do {
            let proofs = try persistenceController.container.viewContext.fetch(request)
            let uniqueUsers = Set(proofs.compactMap { $0.user })
            
            // If 2 or more members completed the challenge, award group bonus
            if uniqueUsers.count >= 2 {
                let bonusPoints = Int32(Verify.groupChallengeBonus)
                
                let bonusLedger = PointsLedger(context: persistenceController.container.viewContext)
                bonusLedger.id = UUID()
                bonusLedger.user = user
                bonusLedger.points = bonusPoints
                bonusLedger.reason = "group_challenge_bonus"
                bonusLedger.timestamp = Date()
                bonusLedger.challenge = challenge
                
                user.totalPoints += bonusPoints
                user.weeklyPoints += bonusPoints
                
                print("Group challenge bonus awarded: \(bonusPoints) points")
            }
        } catch {
            print("Error checking group challenge bonus: \(error)")
        }
    }
    
    // MARK: - Background Tasks
    private func scheduleBackgroundTasks() {
        let request = BGAppRefreshTaskRequest(identifier: "com.circle.challenge-evaluation")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }
    
    func handleBackgroundAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await evaluateAllActiveChallenges()
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleGeofenceChallengeCompleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let geofenceID = userInfo["geofenceID"] as? String,
              let geofenceData = userInfo["geofenceData"] as? GeofenceData else {
            return
        }
        
        // Find the challenge associated with this geofence
        let challengeID = geofenceID.replacingOccurrences(of: "challenge_", with: "")
        guard let uuid = UUID(uuidString: challengeID),
              let challenge = activeChallenges.first(where: { $0.id == uuid }) else {
            return
        }
        
        // Evaluate the challenge
        Task {
            await evaluateChallenge(challenge)
        }
    }
    
    @objc private func handleHangoutStarted(_ notification: Notification) {
        // Handle hangout started - could trigger social challenges
        print("Hangout started - checking for social challenges")
    }
    
    @objc private func handleHangoutEnded(_ notification: Notification) {
        // Handle hangout ended - evaluate social challenges
        print("Hangout ended - evaluating social challenges")
    }
    
    // MARK: - Helper Methods
    private func getCurrentUser() -> User? {
        // This would be implemented to get the current authenticated user
        // For now, return nil
        return nil
    }
    
    private func isWithinEvaluationWindow(_ challenge: Challenge) -> Bool {
        let now = Date()
        
        // Check if challenge has started
        guard challenge.startDate <= now else { return false }
        
        // Check if challenge has ended
        if let endDate = challenge.endDate {
            guard endDate > now else { return false }
        }
        
        // Check frequency
        switch challenge.frequency {
        case ChallengeFrequency.daily.rawValue:
            return true // Can be evaluated any time during the day
        case ChallengeFrequency.weekly.rawValue:
            return true // Can be evaluated any time during the week
        default:
            return true
        }
    }
    
    private func hasBeenEvaluatedToday(_ challenge: Challenge, user: User) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(
            format: "challenge == %@ AND user == %@ AND timestamp >= %@ AND timestamp < %@",
            challenge, user, today as NSDate, tomorrow as NSDate
        )
        
        do {
            let proofs = try persistenceController.container.viewContext.fetch(request)
            return !proofs.isEmpty
        } catch {
            print("Error checking if challenge was evaluated today: \(error)")
            return false
        }
    }
    
    private func saveContext() {
        do {
            try persistenceController.container.viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // MARK: - Analytics
    func getChallengeStats(for user: User) -> ChallengeStats {
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        
        do {
            let proofs = try persistenceController.container.viewContext.fetch(request)
            let completedCount = proofs.filter { $0.isVerified }.count
            let totalCount = proofs.count
            let successRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
            
            return ChallengeStats(
                totalChallenges: totalCount,
                completedChallenges: completedCount,
                successRate: successRate,
                totalPoints: proofs.reduce(0) { $0 + $1.pointsAwarded }
            )
        } catch {
            print("Error getting challenge stats: \(error)")
            return ChallengeStats(
                totalChallenges: 0,
                completedChallenges: 0,
                successRate: 0.0,
                totalPoints: 0
            )
        }
    }
}

// MARK: - Supporting Types
struct ChallengeStats {
    let totalChallenges: Int
    let completedChallenges: Int
    let successRate: Double
    let totalPoints: Int32
}

// MARK: - Core Data Extensions
extension Challenge {
    static func fetchRequest() -> NSFetchRequest<Challenge> {
        return NSFetchRequest<Challenge>(entityName: "Challenge")
    }
    
    var categoryEnum: ChallengeCategory? {
        return ChallengeCategory(rawValue: category ?? "")
    }
    
    var frequencyEnum: ChallengeFrequency? {
        return ChallengeFrequency(rawValue: frequency ?? "")
    }
    
    var verificationMethodEnum: VerificationMethod? {
        return VerificationMethod(rawValue: verificationMethod ?? "")
    }
    
    func getVerificationParams<T: Codable>(as type: T.Type) -> T? {
        guard let data = verificationParams else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
