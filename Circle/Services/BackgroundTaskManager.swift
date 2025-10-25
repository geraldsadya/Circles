//
//  BackgroundTaskManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import BackgroundTasks
import CoreData
import Combine

@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    @Published var isProcessing = false
    @Published var lastProcessedDate: Date?
    @Published var processingStats: BackgroundProcessingStats?
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let challengeEngine = ChallengeEngine.shared
    private let leaderboardManager = LeaderboardManager.shared
    private let forfeitEngine = ForfeitEngine.shared
    private let pointsEngine = PointsEngine.shared
    private let hangoutEngine = HangoutEngine.shared
    
    // Background task identifiers
    private let backgroundRefreshIdentifier = "com.circle.background-refresh"
    private let backgroundProcessingIdentifier = "com.circle.background-processing"
    private let weeklyRollupIdentifier = "com.circle.weekly-rollup"
    private let dataCompactionIdentifier = "com.circle.data-compaction"
    
    // Processing state
    private var isLowPowerMode = false
    private var isCellularConnection = false
    private var processingQueue: [BackgroundTask] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBackgroundTasks()
        setupNotifications()
        registerBackgroundTasks()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupBackgroundTasks() {
        // Register background task handlers
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundRefreshIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundProcessingIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleBackgroundProcessing(task: task as! BGProcessingTask)
            }
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: weeklyRollupIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleWeeklyRollup(task: task as! BGProcessingTask)
            }
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dataCompactionIdentifier,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                await self?.handleDataCompaction(task: task as! BGProcessingTask)
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePointsAwarded),
            name: .pointsAwarded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHangoutEnded),
            name: .hangoutEnded,
            object: nil
        )
    }
    
    private func registerBackgroundTasks() {
        // Register background tasks in Info.plist
        // This is done in the Info.plist file with BGTaskSchedulerPermittedIdentifiers
        print("Background tasks registered")
    }
    
    // MARK: - Background Refresh Handler
    func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        print("Background refresh started")
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        isProcessing = true
        
        do {
            // Perform light background tasks
            await performLightBackgroundTasks()
            
            // Schedule next background refresh
            scheduleBackgroundRefresh()
            
            task.setTaskCompleted(success: true)
            lastProcessedDate = Date()
            
            print("Background refresh completed successfully")
            
        } catch {
            print("Background refresh failed: \(error)")
            task.setTaskCompleted(success: false)
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    // MARK: - Background Processing Handler
    func handleBackgroundProcessing(task: BGProcessingTask) async {
        print("Background processing started")
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        isProcessing = true
        
        do {
            // Perform heavy background tasks
            await performHeavyBackgroundTasks()
            
            // Schedule next background processing
            scheduleBackgroundProcessing()
            
            task.setTaskCompleted(success: true)
            lastProcessedDate = Date()
            
            print("Background processing completed successfully")
            
        } catch {
            print("Background processing failed: \(error)")
            task.setTaskCompleted(success: false)
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    // MARK: - Weekly Rollup Handler
    func handleWeeklyRollup(task: BGProcessingTask) async {
        print("Weekly rollup started")
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        isProcessing = true
        
        do {
            // Perform weekly rollup tasks
            await performWeeklyRollup()
            
            // Schedule next weekly rollup
            scheduleWeeklyRollup()
            
            task.setTaskCompleted(success: true)
            lastProcessedDate = Date()
            
            print("Weekly rollup completed successfully")
            
        } catch {
            print("Weekly rollup failed: \(error)")
            task.setTaskCompleted(success: false)
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    // MARK: - Data Compaction Handler
    func handleDataCompaction(task: BGProcessingTask) async {
        print("Data compaction started")
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        isProcessing = true
        
        do {
            // Perform data compaction
            await performDataCompaction()
            
            // Schedule next data compaction
            scheduleDataCompaction()
            
            task.setTaskCompleted(success: true)
            lastProcessedDate = Date()
            
            print("Data compaction completed successfully")
            
        } catch {
            print("Data compaction failed: \(error)")
            task.setTaskCompleted(success: false)
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    // MARK: - Light Background Tasks
    private func performLightBackgroundTasks() async {
        // Check for new challenges
        await challengeEngine.evaluateAllActiveChallenges()
        
        // Update hangout detection
        await hangoutEngine.mergeNearbyHangouts()
        
        // Clean up old data
        await cleanupOldData()
        
        // Update processing stats
        updateProcessingStats(taskType: .light)
    }
    
    // MARK: - Heavy Background Tasks
    private func performHeavyBackgroundTasks() async {
        // Update leaderboards
        await updateAllLeaderboards()
        
        // Process forfeits
        await processForfeits()
        
        // Update points calculations
        await updatePointsCalculations()
        
        // Update processing stats
        updateProcessingStats(taskType: .heavy)
    }
    
    // MARK: - Weekly Rollup Tasks
    private func performWeeklyRollup() async {
        // Create weekly leaderboard snapshots
        await leaderboardManager.createWeeklySnapshot()
        
        // Reset weekly points
        await pointsEngine.performWeeklyReset()
        
        // Assign weekly forfeits
        await forfeitEngine.assignWeeklyForfeits()
        
        // Generate weekly analytics
        await generateWeeklyAnalytics()
        
        // Update processing stats
        updateProcessingStats(taskType: .weeklyRollup)
    }
    
    // MARK: - Data Compaction Tasks
    private func performDataCompaction() async {
        // Compact old proofs
        await compactOldProofs()
        
        // Compact old hangout sessions
        await compactOldHangoutSessions()
        
        // Compact old points ledger
        await compactOldPointsLedger()
        
        // Compact old leaderboard entries
        await compactOldLeaderboardEntries()
        
        // Update processing stats
        updateProcessingStats(taskType: .dataCompaction)
    }
    
    // MARK: - Task Scheduling
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled")
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: backgroundProcessingIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background processing scheduled")
        } catch {
            print("Failed to schedule background processing: \(error)")
        }
    }
    
    func scheduleWeeklyRollup() {
        let calendar = Calendar.current
        let now = Date()
        
        // Find next Sunday at 11:55 PM
        var nextSunday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: 1), // Sunday
            matchingPolicy: .nextTime
        ) ?? now
        
        nextSunday = calendar.date(bySettingHour: 23, minute: 55, second: 0, of: nextSunday) ?? nextSunday
        
        let request = BGProcessingTaskRequest(identifier: weeklyRollupIdentifier)
        request.earliestBeginDate = nextSunday
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Weekly rollup scheduled for: \(nextSunday)")
        } catch {
            print("Failed to schedule weekly rollup: \(error)")
        }
    }
    
    func scheduleDataCompaction() {
        let request = BGProcessingTaskRequest(identifier: dataCompactionIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60) // 1 week
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Data compaction scheduled")
        } catch {
            print("Failed to schedule data compaction: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func updateAllLeaderboards() async {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        
        do {
            let circles = try persistenceController.container.viewContext.fetch(request)
            
            for circle in circles {
                await leaderboardManager.updateLeaderboard(for: circle)
            }
            
        } catch {
            print("Error updating leaderboards: \(error)")
        }
    }
    
    private func processForfeits() async {
        // Process active forfeits
        await forfeitEngine.processActiveForfeits()
    }
    
    private func updatePointsCalculations() async {
        // Update points calculations for all users
        let request: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try persistenceController.container.viewContext.fetch(request)
            
            for user in users {
                await pointsEngine.calculateDailyPoints(for: user)
            }
            
        } catch {
            print("Error updating points calculations: \(error)")
        }
    }
    
    private func generateWeeklyAnalytics() async {
        // Generate weekly analytics for all circles
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        
        do {
            let circles = try persistenceController.container.viewContext.fetch(request)
            
            for circle in circles {
                await generateCircleAnalytics(circle)
            }
            
        } catch {
            print("Error generating weekly analytics: \(error)")
        }
    }
    
    private func generateCircleAnalytics(_ circle: Circle) async {
        // Generate analytics for a specific circle
        let stats = leaderboardManager.getLeaderboardStats(for: circle)
        
        // Store analytics in Core Data
        let analytics = CircleAnalytics(context: persistenceController.container.viewContext)
        analytics.id = UUID()
        analytics.circle = circle
        analytics.weekStart = stats.weekStart
        analytics.totalParticipants = Int32(stats.totalParticipants)
        analytics.totalPoints = stats.totalPoints
        analytics.averagePoints = stats.averagePoints
        analytics.createdAt = Date()
        
        try? persistenceController.container.viewContext.save()
    }
    
    private func compactOldProofs() async {
        let cutoffDate = Date().addingTimeInterval(-90 * 24 * 60 * 60) // 90 days ago
        
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        
        do {
            let oldProofs = try persistenceController.container.viewContext.fetch(request)
            
            for proof in oldProofs {
                persistenceController.container.viewContext.delete(proof)
            }
            
            try persistenceController.container.viewContext.save()
            print("Compacted \(oldProofs.count) old proofs")
            
        } catch {
            print("Error compacting old proofs: \(error)")
        }
    }
    
    private func compactOldHangoutSessions() async {
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        
        let request: NSFetchRequest<HangoutSession> = HangoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "startTime < %@", cutoffDate as NSDate)
        
        do {
            let oldSessions = try persistenceController.container.viewContext.fetch(request)
            
            for session in oldSessions {
                persistenceController.container.viewContext.delete(session)
            }
            
            try persistenceController.container.viewContext.save()
            print("Compacted \(oldSessions.count) old hangout sessions")
            
        } catch {
            print("Error compacting old hangout sessions: \(error)")
        }
    }
    
    private func compactOldPointsLedger() async {
        let cutoffDate = Date().addingTimeInterval(-365 * 24 * 60 * 60) // 1 year ago
        
        let request: NSFetchRequest<PointsLedger> = PointsLedger.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        
        do {
            let oldEntries = try persistenceController.container.viewContext.fetch(request)
            
            for entry in oldEntries {
                persistenceController.container.viewContext.delete(entry)
            }
            
            try persistenceController.container.viewContext.save()
            print("Compacted \(oldEntries.count) old points ledger entries")
            
        } catch {
            print("Error compacting old points ledger: \(error)")
        }
    }
    
    private func compactOldLeaderboardEntries() async {
        let cutoffDate = Date().addingTimeInterval(-52 * 7 * 24 * 60 * 60) // 52 weeks ago
        
        let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart < %@", cutoffDate as NSDate)
        
        do {
            let oldEntries = try persistenceController.container.viewContext.fetch(request)
            
            for entry in oldEntries {
                persistenceController.container.viewContext.delete(entry)
            }
            
            try persistenceController.container.viewContext.save()
            print("Compacted \(oldEntries.count) old leaderboard entries")
            
        } catch {
            print("Error compacting old leaderboard entries: \(error)")
        }
    }
    
    private func cleanupOldData() async {
        // Clean up old data
        await hangoutEngine.cleanupOldHangouts()
        await antiCheatEngine.cleanupOldActivities()
        await proofHooksManager.cleanupOldProofs()
    }
    
    private func updateProcessingStats(taskType: BackgroundTaskType) {
        let stats = BackgroundProcessingStats(
            taskType: taskType,
            processedAt: Date(),
            isLowPowerMode: isLowPowerMode,
            isCellularConnection: isCellularConnection,
            processingDuration: 0.0 // This would be calculated
        )
        
        processingStats = stats
    }
    
    // MARK: - Notification Handlers
    @objc private func handleLowPowerModeChanged(_ notification: Notification) {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerMode {
            // Reduce background task frequency
            print("Low power mode enabled - reducing background task frequency")
        } else {
            // Restore normal background task frequency
            print("Low power mode disabled - restoring normal background task frequency")
        }
    }
    
    @objc private func handlePointsAwarded(_ notification: Notification) {
        // Schedule background processing if significant points were awarded
        guard let userInfo = notification.userInfo,
              let points = userInfo["points"] as? Int32,
              abs(points) > 10 else { return }
        
        scheduleBackgroundProcessing()
    }
    
    @objc private func handleHangoutEnded(_ notification: Notification) {
        // Schedule background processing for hangout updates
        scheduleBackgroundProcessing()
    }
    
    // MARK: - Manual Processing
    func processNow() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        do {
            await performLightBackgroundTasks()
            await performHeavyBackgroundTasks()
            
            lastProcessedDate = Date()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    // MARK: - Analytics
    func getBackgroundProcessingStats() -> BackgroundProcessingStats? {
        return processingStats
    }
    
    func getProcessingHistory() -> [BackgroundProcessingStats] {
        // This would return historical processing stats
        // For now, return current stats if available
        if let stats = processingStats {
            return [stats]
        }
        return []
    }
}

// MARK: - Supporting Types
enum BackgroundTaskType: String, CaseIterable {
    case light = "light"
    case heavy = "heavy"
    case weeklyRollup = "weekly_rollup"
    case dataCompaction = "data_compaction"
    
    var displayName: String {
        switch self {
        case .light: return "Light Processing"
        case .heavy: return "Heavy Processing"
        case .weeklyRollup: return "Weekly Rollup"
        case .dataCompaction: return "Data Compaction"
        }
    }
}

struct BackgroundTask {
    let id: UUID
    let type: BackgroundTaskType
    let priority: Int
    let createdAt: Date
    let data: [String: Any]
}

struct BackgroundProcessingStats {
    let taskType: BackgroundTaskType
    let processedAt: Date
    let isLowPowerMode: Bool
    let isCellularConnection: Bool
    let processingDuration: TimeInterval
}

// MARK: - Core Data Extensions
extension CircleAnalytics {
    static func fetchRequest() -> NSFetchRequest<CircleAnalytics> {
        return NSFetchRequest<CircleAnalytics>(entityName: "CircleAnalytics")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let backgroundProcessingCompleted = Notification.Name("backgroundProcessingCompleted")
    static let weeklyRollupCompleted = Notification.Name("weeklyRollupCompleted")
    static let dataCompactionCompleted = Notification.Name("dataCompactionCompleted")
}
