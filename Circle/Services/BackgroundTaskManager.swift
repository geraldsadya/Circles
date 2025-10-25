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
    
    @Published var isBackgroundTaskRunning = false
    @Published var lastBackgroundTaskTime: Date?
    @Published var backgroundTaskStatus: BackgroundTaskStatus = .idle
    
    private let persistenceController = PersistenceController.shared
    private let challengeEngine = ChallengeEngine.shared
    private let locationManager = LocationManager.shared
    private let motionManager = MotionManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Background task identifiers
    private let challengeEvaluationTaskID = "com.circle.challenge-evaluation"
    private let hangoutDetectionTaskID = "com.circle.hangout-detection"
    private let dataSyncTaskID = "com.circle.data-sync"
    private let weeklyRollupTaskID = "com.circle.weekly-rollup"
    
    // Task state
    private var activeBackgroundTasks: Set<String> = []
    private var taskCompletionHandlers: [String: (Bool) -> Void] = [:]
    
    init() {
        setupBackgroundTasks()
        setupNotifications()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupBackgroundTasks() {
        // Register background task handlers
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: challengeEvaluationTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleChallengeEvaluationTask(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: hangoutDetectionTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleHangoutDetectionTask(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dataSyncTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleDataSyncTask(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: weeklyRollupTaskID,
            using: nil
        ) { [weak self] task in
            self?.handleWeeklyRollupTask(task: task as! BGProcessingTask)
        }
    }
    
    private func setupNotifications() {
        // App lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppEnteredBackground()
            }
            .store(in: &cancellables)
        
        // Low power mode notifications
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.handlePowerStateChange()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Background Task Scheduling
    func scheduleBackgroundTasks() {
        scheduleChallengeEvaluationTask()
        scheduleHangoutDetectionTask()
        scheduleDataSyncTask()
        scheduleWeeklyRollupTask()
    }
    
    private func scheduleChallengeEvaluationTask() {
        let request = BGAppRefreshTaskRequest(identifier: challengeEvaluationTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled challenge evaluation background task")
        } catch {
            print("❌ Failed to schedule challenge evaluation task: \(error)")
        }
    }
    
    private func scheduleHangoutDetectionTask() {
        let request = BGAppRefreshTaskRequest(identifier: hangoutDetectionTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled hangout detection background task")
        } catch {
            print("❌ Failed to schedule hangout detection task: \(error)")
        }
    }
    
    private func scheduleDataSyncTask() {
        let request = BGAppRefreshTaskRequest(identifier: dataSyncTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled data sync background task")
        } catch {
            print("❌ Failed to schedule data sync task: \(error)")
        }
    }
    
    private func scheduleWeeklyRollupTask() {
        let request = BGProcessingTaskRequest(identifier: weeklyRollupTaskID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled weekly rollup background task")
        } catch {
            print("❌ Failed to schedule weekly rollup task: \(error)")
        }
    }
    
    // MARK: - Background Task Handlers
    private func handleChallengeEvaluationTask(task: BGAppRefreshTask) {
        print("🔄 Starting challenge evaluation background task")
        
        isBackgroundTaskRunning = true
        backgroundTaskStatus = .challengeEvaluation
        activeBackgroundTasks.insert(challengeEvaluationTaskID)
        
        task.expirationHandler = {
            print("⏰ Challenge evaluation task expired")
            task.setTaskCompleted(success: false)
            self.isBackgroundTaskRunning = false
            self.backgroundTaskStatus = .idle
            self.activeBackgroundTasks.remove(challengeEvaluationTaskID)
        }
        
        Task {
            do {
                // Evaluate all active challenges
                await challengeEngine.evaluateAllActiveChallenges()
                
                // Update motion-based challenges
                await updateMotionChallenges()
                
                // Save context
                persistenceController.save()
                
                print("✅ Challenge evaluation completed successfully")
                task.setTaskCompleted(success: true)
                
            } catch {
                print("❌ Challenge evaluation failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            // Clean up
            isBackgroundTaskRunning = false
            backgroundTaskStatus = .idle
            activeBackgroundTasks.remove(challengeEvaluationTaskID)
            lastBackgroundTaskTime = Date()
            
            // Schedule next task
            scheduleChallengeEvaluationTask()
        }
    }
    
    private func handleHangoutDetectionTask(task: BGAppRefreshTask) {
        print("🔄 Starting hangout detection background task")
        
        isBackgroundTaskRunning = true
        backgroundTaskStatus = .hangoutDetection
        activeBackgroundTasks.insert(hangoutDetectionTaskID)
        
        task.expirationHandler = {
            print("⏰ Hangout detection task expired")
            task.setTaskCompleted(success: false)
            self.isBackgroundTaskRunning = false
            self.backgroundTaskStatus = .idle
            self.activeBackgroundTasks.remove(hangoutDetectionTaskID)
        }
        
        Task {
            do {
                // Update location and detect hangouts
                await locationManager.detectHangoutCandidates()
                
                // Process any pending hangout sessions
                await processPendingHangoutSessions()
                
                print("✅ Hangout detection completed successfully")
                task.setTaskCompleted(success: true)
                
            } catch {
                print("❌ Hangout detection failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            // Clean up
            isBackgroundTaskRunning = false
            backgroundTaskStatus = .idle
            activeBackgroundTasks.remove(hangoutDetectionTaskID)
            lastBackgroundTaskTime = Date()
            
            // Schedule next task
            scheduleHangoutDetectionTask()
        }
    }
    
    private func handleDataSyncTask(task: BGAppRefreshTask) {
        print("🔄 Starting data sync background task")
        
        isBackgroundTaskRunning = true
        backgroundTaskStatus = .dataSync
        activeBackgroundTasks.insert(dataSyncTaskID)
        
        task.expirationHandler = {
            print("⏰ Data sync task expired")
            task.setTaskCompleted(success: false)
            self.isBackgroundTaskRunning = false
            self.backgroundTaskStatus = .idle
            self.activeBackgroundTasks.remove(dataSyncTaskID)
        }
        
        Task {
            do {
                // Sync with CloudKit
                await persistenceController.syncWithCloudKit()
                
                // Update motion data
                await motionManager.updateTodaysSteps()
                
                // Clean up old data
                await cleanupOldData()
                
                print("✅ Data sync completed successfully")
                task.setTaskCompleted(success: true)
                
            } catch {
                print("❌ Data sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            // Clean up
            isBackgroundTaskRunning = false
            backgroundTaskStatus = .idle
            activeBackgroundTasks.remove(dataSyncTaskID)
            lastBackgroundTaskTime = Date()
            
            // Schedule next task
            scheduleDataSyncTask()
        }
    }
    
    private func handleWeeklyRollupTask(task: BGProcessingTask) {
        print("🔄 Starting weekly rollup background task")
        
        isBackgroundTaskRunning = true
        backgroundTaskStatus = .weeklyRollup
        activeBackgroundTasks.insert(weeklyRollupTaskID)
        
        task.expirationHandler = {
            print("⏰ Weekly rollup task expired")
            task.setTaskCompleted(success: false)
            self.isBackgroundTaskRunning = false
            self.backgroundTaskStatus = .idle
            self.activeBackgroundTasks.remove(weeklyRollupTaskID)
        }
        
        Task {
            do {
                // Generate weekly leaderboards
                await generateWeeklyLeaderboards()
                
                // Create weekly summaries
                await createWeeklySummaries()
                
                // Archive old data
                await archiveOldData()
                
                print("✅ Weekly rollup completed successfully")
                task.setTaskCompleted(success: true)
                
            } catch {
                print("❌ Weekly rollup failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            // Clean up
            isBackgroundTaskRunning = false
            backgroundTaskStatus = .idle
            activeBackgroundTasks.remove(weeklyRollupTaskID)
            lastBackgroundTaskTime = Date()
            
            // Schedule next task
            scheduleWeeklyRollupTask()
        }
    }
    
    // MARK: - Task Implementation
    private func updateMotionChallenges() async {
        // Update motion-based challenges with latest data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        request.predicate = NSPredicate(format: "verificationMethod == %@", "motion")
        
        do {
            let motionChallenges = try context.fetch(request)
            for challenge in motionChallenges {
                // Update challenge with latest motion data
                // This would integrate with the motion verification system
            }
        } catch {
            print("Error updating motion challenges: \(error)")
        }
    }
    
    private func processPendingHangoutSessions() async {
        // Process any hangout sessions that need to be ended or updated
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<HangoutSession> = HangoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let activeSessions = try context.fetch(request)
            for session in activeSessions {
                // Check if session should be ended
                let timeSinceStart = Date().timeIntervalSince(session.startTime)
                if timeSinceStart > 3600 { // 1 hour max
                    await locationManager.endHangoutSession(session)
                }
            }
        } catch {
            print("Error processing hangout sessions: \(error)")
        }
    }
    
    private func cleanupOldData() async {
        // Clean up old analytics events, logs, etc.
        let context = persistenceController.container.viewContext
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        // Clean up old analytics events
        let analyticsRequest: NSFetchRequest<AnalyticsEventEntity> = AnalyticsEventEntity.fetchRequest()
        analyticsRequest.predicate = NSPredicate(format: "timestamp < %@", thirtyDaysAgo as NSDate)
        
        do {
            let oldEvents = try context.fetch(analyticsRequest)
            for event in oldEvents {
                context.delete(event)
            }
            try context.save()
            print("Cleaned up \(oldEvents.count) old analytics events")
        } catch {
            print("Error cleaning up old data: \(error)")
        }
    }
    
    private func generateWeeklyLeaderboards() async {
        // Generate weekly leaderboards for all circles
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        
        do {
            let circles = try context.fetch(request)
            for circle in circles {
                // Generate leaderboard for this circle
                // This would integrate with the LeaderboardManager
            }
        } catch {
            print("Error generating weekly leaderboards: \(error)")
        }
    }
    
    private func createWeeklySummaries() async {
        // Create weekly summaries for all users
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try context.fetch(request)
            for user in users {
                // Create weekly summary for this user
                // This would integrate with the WrappedExportManager
            }
        } catch {
            print("Error creating weekly summaries: \(error)")
        }
    }
    
    private func archiveOldData() async {
        // Archive data older than 3 months
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        
        // Archive old hangout sessions
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<HangoutSession> = HangoutSession.fetchRequest()
        request.predicate = NSPredicate(format: "startTime < %@", threeMonthsAgo as NSDate)
        
        do {
            let oldSessions = try context.fetch(request)
            for session in oldSessions {
                // Archive the session (move to archive table or mark as archived)
                session.isActive = false
            }
            try context.save()
            print("Archived \(oldSessions.count) old hangout sessions")
        } catch {
            print("Error archiving old data: \(error)")
        }
    }
    
    // MARK: - Power Management
    private func handlePowerStateChange() {
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerMode {
            print("🔋 Low power mode enabled - reducing background task frequency")
            // Reduce background task frequency
            // Skip non-essential tasks
        } else {
            print("🔋 Low power mode disabled - resuming normal background tasks")
            // Resume normal background task frequency
        }
    }
    
    // MARK: - App Lifecycle Handlers
    private func handleAppBecomeActive() {
        // Cancel any pending background tasks
        BGTaskScheduler.shared.cancelAllTaskRequests()
        
        // Reschedule tasks for normal operation
        scheduleBackgroundTasks()
    }
    
    private func handleAppEnteredBackground() {
        // Ensure background tasks are scheduled
        scheduleBackgroundTasks()
    }
    
    // MARK: - Public Methods
    func getBackgroundTaskStatus() -> String {
        switch backgroundTaskStatus {
        case .idle:
            return "Idle"
        case .challengeEvaluation:
            return "Evaluating Challenges"
        case .hangoutDetection:
            return "Detecting Hangouts"
        case .dataSync:
            return "Syncing Data"
        case .weeklyRollup:
            return "Weekly Rollup"
        }
    }
    
    func getActiveTaskCount() -> Int {
        return activeBackgroundTasks.count
    }
    
    func isTaskActive(_ taskID: String) -> Bool {
        return activeBackgroundTasks.contains(taskID)
    }
}

// MARK: - Supporting Types
enum BackgroundTaskStatus {
    case idle
    case challengeEvaluation
    case hangoutDetection
    case dataSync
    case weeklyRollup
}

// MARK: - Extensions
extension PersistenceController {
    func syncWithCloudKit() async {
        // This would handle CloudKit synchronization
        // For now, just save the context
        save()
    }
}

extension MotionManager {
    func updateTodaysSteps() async {
        // This would update today's step count
        // The actual implementation is in MotionManager
    }
}