//
//  ForfeitEngine.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class ForfeitEngine: ObservableObject {
    static let shared = ForfeitEngine()
    
    @Published var activeForfeits: [Forfeit] = []
    @Published var forfeitTemplates: [ForfeitTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let pointsEngine = PointsEngine.shared
    private let cameraManager = CameraManager.shared
    
    // Forfeit scheduling
    private var forfeitTimer: Timer?
    private let forfeitTime = "20:00" // 8:00 PM
    private let forfeitDay = 1 // Monday (0 = Sunday)
    
    // Forfeit limits
    private let maxForfeitsPerWeek = 3
    private let forfeitCompletionPoints = 5
    private let forfeitMissPenalty = -10
    
    private init() {
        loadForfeitTemplates()
        setupForfeitScheduling()
        setupNotifications()
    }
    
    deinit {
        forfeitTimer?.invalidate()
    }
    
    // MARK: - Setup
    private func setupForfeitScheduling() {
        // Schedule forfeit assignment for Sunday at 8:00 PM
        scheduleNextForfeitAssignment()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWeeklyReset),
            name: .weeklyPointsReset,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLeaderboardUpdated),
            name: .leaderboardUpdated,
            object: nil
        )
    }
    
    // MARK: - Forfeit Templates
    private func loadForfeitTemplates() {
        isLoading = true
        errorMessage = nil
        
        let request: NSFetchRequest<ForfeitTemplate> = ForfeitTemplate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ForfeitTemplate.title, ascending: true)]
        
        do {
            forfeitTemplates = try persistenceController.container.viewContext.fetch(request)
            
            // Create default templates if none exist
            if forfeitTemplates.isEmpty {
                createDefaultForfeitTemplates()
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load forfeit templates: \(error.localizedDescription)"
            isLoading = false
            print("Error loading forfeit templates: \(error)")
        }
    }
    
    private func createDefaultForfeitTemplates() {
        let context = persistenceController.container.viewContext
        
        // Camera-based forfeits
        let selfieTemplate = ForfeitTemplate(context: context)
        selfieTemplate.id = UUID()
        selfieTemplate.title = "Random Selfie"
        selfieTemplate.description = "Take a selfie with the first thing you see"
        selfieTemplate.type = ForfeitType.camera.rawValue
        selfieTemplate.difficulty = ForfeitDifficulty.easy.rawValue
        selfieTemplate.estimatedDuration = 30
        selfieTemplate.isActive = true
        
        let lunchTemplate = ForfeitTemplate(context: context)
        lunchTemplate.id = UUID()
        lunchTemplate.title = "Show Your Lunch"
        lunchTemplate.description = "Take a photo of your current meal"
        lunchTemplate.type = ForfeitType.camera.rawValue
        lunchTemplate.difficulty = ForfeitDifficulty.easy.rawValue
        lunchTemplate.estimatedDuration = 30
        lunchTemplate.isActive = true
        
        let surroundingsTemplate = ForfeitTemplate(context: context)
        surroundingsTemplate.id = UUID()
        surroundingsTemplate.title = "Your Surroundings"
        surroundingsTemplate.description = "Show us where you are right now"
        surroundingsTemplate.type = ForfeitType.camera.rawValue
        surroundingsTemplate.difficulty = ForfeitDifficulty.easy.rawValue
        surroundingsTemplate.estimatedDuration = 30
        surroundingsTemplate.isActive = true
        
        // Action-based forfeits
        let danceTemplate = ForfeitTemplate(context: context)
        danceTemplate.id = UUID()
        danceTemplate.title = "Dance Move"
        danceTemplate.description = "Do your best dance move for 10 seconds"
        danceTemplate.type = ForfeitType.action.rawValue
        danceTemplate.difficulty = ForfeitDifficulty.medium.rawValue
        danceTemplate.estimatedDuration = 60
        danceTemplate.isActive = true
        
        let jokeTemplate = ForfeitTemplate(context: context)
        jokeTemplate.id = UUID()
        jokeTemplate.title = "Tell a Joke"
        jokeTemplate.description = "Tell us your best joke"
        jokeTemplate.type = ForfeitType.action.rawValue
        jokeTemplate.difficulty = ForfeitDifficulty.easy.rawValue
        jokeTemplate.estimatedDuration = 60
        jokeTemplate.isActive = true
        
        // Challenge-based forfeits
        let pushupTemplate = ForfeitTemplate(context: context)
        pushupTemplate.id = UUID()
        pushupTemplate.title = "10 Push-ups"
        pushupTemplate.description = "Do 10 push-ups right now"
        pushupTemplate.type = ForfeitType.challenge.rawValue
        pushupTemplate.difficulty = ForfeitDifficulty.hard.rawValue
        pushupTemplate.estimatedDuration = 120
        pushupTemplate.isActive = true
        
        let plankTemplate = ForfeitTemplate(context: context)
        plankTemplate.id = UUID()
        plankTemplate.title = "30-Second Plank"
        plankTemplate.description = "Hold a plank for 30 seconds"
        plankTemplate.type = ForfeitType.challenge.rawValue
        plankTemplate.difficulty = ForfeitDifficulty.medium.rawValue
        plankTemplate.estimatedDuration = 90
        plankTemplate.isActive = true
        
        // Save context
        do {
            try context.save()
            loadForfeitTemplates() // Reload to get the new templates
        } catch {
            errorMessage = "Failed to create default forfeit templates: \(error.localizedDescription)"
            print("Error creating default forfeit templates: \(error)")
        }
    }
    
    // MARK: - Forfeit Assignment
    private func scheduleNextForfeitAssignment() {
        let calendar = Calendar.current
        let now = Date()
        
        // Find next Sunday
        var nextSunday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: 1), // Sunday
            matchingPolicy: .nextTime
        ) ?? now
        
        // Set to 8:00 PM
        nextSunday = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: nextSunday) ?? nextSunday
        
        let timeInterval = nextSunday.timeIntervalSince(now)
        
        forfeitTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.assignWeeklyForfeits()
                self?.scheduleNextForfeitAssignment() // Schedule next assignment
            }
        }
        
        print("Next forfeit assignment scheduled for: \(nextSunday)")
    }
    
    private func assignWeeklyForfeits() async {
        print("Assigning weekly forfeits")
        
        // Get all circles
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        
        do {
            let circles = try persistenceController.container.viewContext.fetch(request)
            
            for circle in circles {
                await assignForfeitsForCircle(circle)
            }
            
            // Reload active forfeits
            loadActiveForfeits()
            
            // Notify other systems
            NotificationCenter.default.post(name: .forfeitsAssigned, object: nil)
            
            print("Weekly forfeits assigned successfully")
            
        } catch {
            errorMessage = "Failed to assign forfeits: \(error.localizedDescription)"
            print("Error assigning forfeits: \(error)")
        }
    }
    
    private func assignForfeitsForCircle(_ circle: Circle) async {
        guard let members = circle.members?.allObjects as? [User] else { return }
        
        // Get current week's leaderboard
        let weekStart = getCurrentWeekStart()
        let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "circle == %@ AND weekStart == %@",
            circle, weekStart as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LeaderboardEntry.rank, ascending: true)]
        
        do {
            let entries = try persistenceController.container.viewContext.fetch(request)
            
            // Get bottom 3 users (or all users if less than 3)
            let bottomUsers = Array(entries.suffix(min(3, entries.count)))
            
            for entry in bottomUsers {
                guard let user = entry.user else { continue }
                
                // Check if user already has forfeits this week
                let existingForfeits = getForfeitsForUser(user, weekStart: weekStart)
                if existingForfeits.count >= maxForfeitsPerWeek {
                    continue
                }
                
                // Assign random forfeit
                await assignRandomForfeit(to: user, circle: circle)
            }
            
        } catch {
            print("Error assigning forfeits for circle: \(error)")
        }
    }
    
    private func assignRandomForfeit(to user: User, circle: Circle) async {
        // Get active templates
        let activeTemplates = forfeitTemplates.filter { $0.isActive }
        guard !activeTemplates.isEmpty else { return }
        
        // Select random template
        let randomTemplate = activeTemplates.randomElement()!
        
        // Create forfeit
        let forfeit = Forfeit(context: persistenceController.container.viewContext)
        forfeit.id = UUID()
        forfeit.user = user
        forfeit.circle = circle
        forfeit.template = randomTemplate
        forfeit.title = randomTemplate.title
        forfeit.description = randomTemplate.description
        forfeit.type = randomTemplate.type
        forfeit.difficulty = randomTemplate.difficulty
        forfeit.estimatedDuration = randomTemplate.estimatedDuration
        forfeit.assignedAt = Date()
        forfeit.dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        forfeit.isCompleted = false
        forfeit.isActive = true
        forfeit.pointsReward = Int32(forfeitCompletionPoints)
        forfeit.pointsPenalty = Int32(forfeitMissPenalty)
        
        // Save context
        do {
            try persistenceController.container.viewContext.save()
            
            // Send notification to user
            await sendForfeitNotification(forfeit)
            
            print("Forfeit assigned: \(forfeit.title ?? "Unknown") to \(user.name ?? "Unknown")")
            
        } catch {
            print("Error assigning forfeit: \(error)")
        }
    }
    
    // MARK: - Forfeit Completion
    func completeForfeit(_ forfeit: Forfeit, proof: Proof? = nil) async throws {
        guard !forfeit.isCompleted else {
            throw ForfeitError.alreadyCompleted
        }
        
        forfeit.isCompleted = true
        forfeit.completedAt = Date()
        forfeit.proof = proof
        
        // Award points
        try await pointsEngine.awardForfeitPoints(
            forfeit.pointsReward,
            user: forfeit.user!,
            forfeit: forfeit
        )
        
        // Save context
        try persistenceController.container.viewContext.save()
        
        // Update active forfeits
        loadActiveForfeits()
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .forfeitCompleted,
            object: nil,
            userInfo: ["forfeit": forfeit]
        )
        
        print("Forfeit completed: \(forfeit.title ?? "Unknown")")
    }
    
    func missForfeit(_ forfeit: Forfeit) async throws {
        guard !forfeit.isCompleted else {
            throw ForfeitError.alreadyCompleted
        }
        
        forfeit.isCompleted = false
        forfeit.completedAt = Date()
        
        // Apply penalty
        try await pointsEngine.awardForfeitPoints(
            forfeit.pointsPenalty,
            user: forfeit.user!,
            forfeit: forfeit
        )
        
        // Save context
        try persistenceController.container.viewContext.save()
        
        // Update active forfeits
        loadActiveForfeits()
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .forfeitMissed,
            object: nil,
            userInfo: ["forfeit": forfeit]
        )
        
        print("Forfeit missed: \(forfeit.title ?? "Unknown")")
    }
    
    // MARK: - Camera Integration
    func startCameraForfeit(_ forfeit: Forfeit) async throws -> CameraSession {
        guard forfeit.type == ForfeitType.camera.rawValue else {
            throw ForfeitError.invalidForfeitType
        }
        
        // Start camera session
        let session = try await cameraManager.startSession(
            for: .forfeit,
            duration: TimeInterval(forfeit.estimatedDuration)
        )
        
        return session
    }
    
    func completeCameraForfeit(_ forfeit: Forfeit, session: CameraSession) async throws {
        // Verify camera session
        let verification = try await cameraManager.verifySession(session)
        
        if verification.isVerified {
            // Create proof
            let proof = Proof(context: persistenceController.container.viewContext)
            proof.id = UUID()
            proof.user = forfeit.user
            proof.challenge = nil
            proof.forfeit = forfeit
            proof.timestamp = Date()
            proof.isVerified = true
            proof.confidenceScore = verification.confidenceScore
            proof.verificationMethod = VerificationMethod.camera.rawValue
            proof.sensorData = try JSONEncoder().encode(verification.sensorData)
            proof.notes = "Camera forfeit completed"
            
            // Complete forfeit
            try await completeForfeit(forfeit, proof: proof)
        } else {
            throw ForfeitError.verificationFailed
        }
    }
    
    // MARK: - Forfeit Management
    func loadActiveForfeits() {
        let request: NSFetchRequest<Forfeit> = Forfeit.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Forfeit.assignedAt, ascending: true)]
        
        do {
            activeForfeits = try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error loading active forfeits: \(error)")
        }
    }
    
    func getForfeitsForUser(_ user: User, weekStart: Date) -> [Forfeit] {
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        
        let request: NSFetchRequest<Forfeit> = Forfeit.fetchRequest()
        request.predicate = NSPredicate(
            format: "user == %@ AND assignedAt >= %@ AND assignedAt < %@",
            user, weekStart as NSDate, weekEnd as NSDate
        )
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error getting forfeits for user: \(error)")
            return []
        }
    }
    
    func getForfeitsForCircle(_ circle: Circle) -> [Forfeit] {
        let request: NSFetchRequest<Forfeit> = Forfeit.fetchRequest()
        request.predicate = NSPredicate(format: "circle == %@ AND isActive == YES", circle)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Forfeit.assignedAt, ascending: true)]
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error getting forfeits for circle: \(error)")
            return []
        }
    }
    
    // MARK: - Notifications
    private func sendForfeitNotification(_ forfeit: Forfeit) async {
        // This would integrate with UserNotifications framework
        // For now, we'll just log it
        print("Forfeit notification sent: \(forfeit.title ?? "Unknown")")
    }
    
    // MARK: - Notification Handlers
    @objc private func handleWeeklyReset(_ notification: Notification) {
        // Clear active forfeits
        activeForfeits.removeAll()
    }
    
    @objc private func handleLeaderboardUpdated(_ notification: Notification) {
        // Forfeits are assigned based on leaderboard, so no action needed here
        // The assignment happens on schedule
    }
    
    // MARK: - Helper Methods
    private func getCurrentWeekStart() -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }
    
    // MARK: - Analytics
    func getForfeitStats(for user: User) -> ForfeitStats {
        let request: NSFetchRequest<Forfeit> = Forfeit.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        
        do {
            let forfeits = try persistenceController.container.viewContext.fetch(request)
            
            let completedCount = forfeits.filter { $0.isCompleted }.count
            let missedCount = forfeits.filter { !$0.isCompleted && $0.completedAt != nil }.count
            let totalCount = forfeits.count
            
            let completionRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
            
            return ForfeitStats(
                totalForfeits: totalCount,
                completedForfeits: completedCount,
                missedForfeits: missedCount,
                completionRate: completionRate,
                totalPointsEarned: forfeits.filter { $0.isCompleted }.reduce(0) { $0 + $1.pointsReward }
            )
            
        } catch {
            print("Error getting forfeit stats: \(error)")
            return ForfeitStats(
                totalForfeits: 0,
                completedForfeits: 0,
                missedForfeits: 0,
                completionRate: 0.0,
                totalPointsEarned: 0
            )
        }
    }
}

// MARK: - Supporting Types
enum ForfeitType: String, CaseIterable {
    case camera = "camera"
    case action = "action"
    case challenge = "challenge"
    
    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .action: return "Action"
        case .challenge: return "Challenge"
        }
    }
    
    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .action: return "figure.dance"
        case .challenge: return "dumbbell.fill"
        }
    }
}

enum ForfeitDifficulty: String, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
}

struct ForfeitStats {
    let totalForfeits: Int
    let completedForfeits: Int
    let missedForfeits: Int
    let completionRate: Double
    let totalPointsEarned: Int32
}

enum ForfeitError: LocalizedError {
    case alreadyCompleted
    case invalidForfeitType
    case verificationFailed
    case userNotFound
    case templateNotFound
    
    var errorDescription: String? {
        switch self {
        case .alreadyCompleted:
            return "Forfeit has already been completed"
        case .invalidForfeitType:
            return "Invalid forfeit type for this operation"
        case .verificationFailed:
            return "Forfeit verification failed"
        case .userNotFound:
            return "User not found"
        case .templateNotFound:
            return "Forfeit template not found"
        }
    }
}

// MARK: - Core Data Extensions
extension Forfeit {
    static func fetchRequest() -> NSFetchRequest<Forfeit> {
        return NSFetchRequest<Forfeit>(entityName: "Forfeit")
    }
    
    var typeEnum: ForfeitType? {
        return ForfeitType(rawValue: type ?? "")
    }
    
    var difficultyEnum: ForfeitDifficulty? {
        return ForfeitDifficulty(rawValue: difficulty ?? "")
    }
}

extension ForfeitTemplate {
    static func fetchRequest() -> NSFetchRequest<ForfeitTemplate> {
        return NSFetchRequest<ForfeitTemplate>(entityName: "ForfeitTemplate")
    }
    
    var typeEnum: ForfeitType? {
        return ForfeitType(rawValue: type ?? "")
    }
    
    var difficultyEnum: ForfeitDifficulty? {
        return ForfeitDifficulty(rawValue: difficulty ?? "")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let forfeitsAssigned = Notification.Name("forfeitsAssigned")
    static let forfeitCompleted = Notification.Name("forfeitCompleted")
    static let forfeitMissed = Notification.Name("forfeitMissed")
}
