//
//  MotionActivityClassifier.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreMotion
import CoreData
import Combine

@MainActor
class MotionActivityClassifier: ObservableObject {
    static let shared = MotionActivityClassifier()
    
    @Published var currentActivity: MotionActivity = .unknown
    @Published var activityConfidence: Double = 0.0
    @Published var isActivelyMoving: Bool = false
    @Published var motionDuration: TimeInterval = 0.0
    @Published var activityHistory: [MotionActivityRecord] = []
    
    private let motionActivityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let persistenceController = PersistenceController.shared
    
    private var activityTimer: Timer?
    private var motionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false
    
    // Activity classification thresholds
    private let stepThresholdForWalking = 100
    private let stepThresholdForRunning = 200
    private let confidenceThreshold = 0.7
    private let minActivityDuration: TimeInterval = 60 // 1 minute
    
    private init() {
        setupActivityMonitoring()
    }
    
    deinit {
        stopActivityMonitoring()
    }
    
    // MARK: - Setup
    private func setupActivityMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity monitoring not available on this device")
            return
        }
        
        startActivityMonitoring()
    }
    
    func startActivityMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start motion activity updates
        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            Task { @MainActor in
                self?.processMotionActivity(activity)
            }
        }
        
        // Start activity timer for duration tracking
        activityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActivityDuration()
            }
        }
        
        print("Motion activity monitoring started")
    }
    
    func stopActivityMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        motionActivityManager.stopActivityUpdates()
        activityTimer?.invalidate()
        activityTimer = nil
        
        // Reset state
        currentActivity = .unknown
        activityConfidence = 0.0
        isActivelyMoving = false
        motionDuration = 0.0
        motionStartTime = nil
        
        print("Motion activity monitoring stopped")
    }
    
    // MARK: - Activity Processing
    private func processMotionActivity(_ activity: CMMotionActivity?) {
        guard let activity = activity else { return }
        
        let previousActivity = currentActivity
        let newActivity = classifyActivity(activity)
        let confidence = calculateActivityConfidence(activity)
        
        // Update current activity
        currentActivity = newActivity
        activityConfidence = confidence
        
        // Determine if actively moving
        isActivelyMoving = isActivityMoving(newActivity)
        
        // Handle activity transitions
        if newActivity != previousActivity {
            handleActivityTransition(from: previousActivity, to: newActivity)
        }
        
        // Update motion duration
        updateMotionDuration(for: newActivity)
        
        // Record activity
        recordActivity(newActivity, confidence: confidence, timestamp: activity.startDate)
    }
    
    private func classifyActivity(_ activity: CMMotionActivity) -> MotionActivity {
        // Use Core Motion's confidence levels and activity types
        if activity.running && activity.confidence >= confidenceThreshold {
            return .running
        } else if activity.walking && activity.confidence >= confidenceThreshold {
            return .walking
        } else if activity.cycling && activity.confidence >= confidenceThreshold {
            return .cycling
        } else if activity.automotive && activity.confidence >= confidenceThreshold {
            return .driving
        } else if activity.stationary && activity.confidence >= confidenceThreshold {
            return .stationary
        } else {
            // Low confidence or unknown activity
            return classifyByStepCount()
        }
    }
    
    private func classifyByStepCount() -> MotionActivity {
        // Fallback classification based on recent step count
        let recentSteps = getRecentStepCount()
        
        if recentSteps > stepThresholdForRunning {
            return .running
        } else if recentSteps > stepThresholdForWalking {
            return .walking
        } else {
            return .stationary
        }
    }
    
    private func getRecentStepCount() -> Int {
        // Get step count for the last 5 minutes
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: fiveMinutesAgo, to: Date()) { data, error in
                if let error = error {
                    print("Error getting recent step count: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                
                let stepCount = data?.numberOfSteps.intValue ?? 0
                continuation.resume(returning: stepCount)
            }
        }
    }
    
    private func calculateActivityConfidence(_ activity: CMMotionActivity) -> Double {
        // Use Core Motion's confidence level as base
        var confidence = activity.confidence
        
        // Adjust confidence based on activity type
        if activity.running || activity.walking {
            confidence *= 1.1 // Boost confidence for common activities
        } else if activity.cycling || activity.automotive {
            confidence *= 0.9 // Slightly reduce confidence for less common activities
        }
        
        return min(confidence, 1.0)
    }
    
    private func isActivityMoving(_ activity: MotionActivity) -> Bool {
        switch activity {
        case .walking, .running, .cycling:
            return true
        case .driving, .stationary, .unknown:
            return false
        }
    }
    
    // MARK: - Activity Transitions
    private func handleActivityTransition(from previousActivity: MotionActivity, to newActivity: MotionActivity) {
        print("Activity transition: \(previousActivity) -> \(newActivity)")
        
        // End previous activity if it was moving
        if isActivityMoving(previousActivity) {
            endMotionActivity(previousActivity)
        }
        
        // Start new activity if it's moving
        if isActivityMoving(newActivity) {
            startMotionActivity(newActivity)
        }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .motionActivityChanged,
            object: nil,
            userInfo: [
                "previousActivity": previousActivity,
                "newActivity": newActivity,
                "confidence": activityConfidence
            ]
        )
    }
    
    private func startMotionActivity(_ activity: MotionActivity) {
        motionStartTime = Date()
        print("Started motion activity: \(activity)")
    }
    
    private func endMotionActivity(_ activity: MotionActivity) {
        if let startTime = motionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("Ended motion activity: \(activity) - Duration: \(duration) seconds")
            
            // Record the completed activity
            recordCompletedActivity(activity, duration: duration)
        }
        
        motionStartTime = nil
    }
    
    // MARK: - Duration Tracking
    private func updateActivityDuration() {
        if let startTime = motionStartTime {
            motionDuration = Date().timeIntervalSince(startTime)
        } else {
            motionDuration = 0.0
        }
    }
    
    // MARK: - Activity Recording
    private func recordActivity(_ activity: MotionActivity, confidence: Double, timestamp: Date) {
        let record = MotionActivityRecord(
            id: UUID(),
            activity: activity,
            confidence: confidence,
            timestamp: timestamp,
            duration: 0.0
        )
        
        activityHistory.append(record)
        
        // Keep only last 100 records
        if activityHistory.count > 100 {
            activityHistory.removeFirst()
        }
    }
    
    private func recordCompletedActivity(_ activity: MotionActivity, duration: TimeInterval) {
        // Find the most recent record for this activity and update its duration
        if let lastIndex = activityHistory.lastIndex(where: { $0.activity == activity && $0.duration == 0.0 }) {
            activityHistory[lastIndex] = MotionActivityRecord(
                id: activityHistory[lastIndex].id,
                activity: activity,
                confidence: activityHistory[lastIndex].confidence,
                timestamp: activityHistory[lastIndex].timestamp,
                duration: duration
            )
        }
        
        // Save to Core Data if duration is significant
        if duration >= minActivityDuration {
            saveActivityToCoreData(activity, duration: duration)
        }
    }
    
    private func saveActivityToCoreData(_ activity: MotionActivity, duration: TimeInterval) {
        let context = persistenceController.container.viewContext
        
        // This would create a MotionActivityRecord entity in Core Data
        // For now, we'll just log it
        print("Saving activity to Core Data: \(activity) - Duration: \(duration)")
    }
    
    // MARK: - Activity Analysis
    func getActivityStats(for timeInterval: TimeInterval = 3600) -> ActivityStats {
        let cutoffTime = Date().addingTimeInterval(-timeInterval)
        let recentActivities = activityHistory.filter { $0.timestamp >= cutoffTime }
        
        let totalDuration = recentActivities.reduce(0) { $0 + $1.duration }
        let activityCounts = Dictionary(grouping: recentActivities, by: { $0.activity })
            .mapValues { $0.count }
        
        let averageConfidence = recentActivities.isEmpty ? 0.0 : 
            recentActivities.reduce(0) { $0 + $1.confidence } / Double(recentActivities.count)
        
        return ActivityStats(
            totalDuration: totalDuration,
            activityCounts: activityCounts,
            averageConfidence: averageConfidence,
            mostCommonActivity: activityCounts.max(by: { $0.value < $1.value })?.key ?? .unknown,
            timeInterval: timeInterval
        )
    }
    
    func getMotionPatterns() -> MotionPatterns {
        let last24Hours = activityHistory.filter { 
            $0.timestamp.timeIntervalSinceNow > -86400 
        }
        
        let walkingActivities = last24Hours.filter { $0.activity == .walking }
        let runningActivities = last24Hours.filter { $0.activity == .running }
        let cyclingActivities = last24Hours.filter { $0.activity == .cycling }
        
        return MotionPatterns(
            totalWalkingTime: walkingActivities.reduce(0) { $0 + $1.duration },
            totalRunningTime: runningActivities.reduce(0) { $0 + $1.duration },
            totalCyclingTime: cyclingActivities.reduce(0) { $0 + $1.duration },
            walkingSessions: walkingActivities.count,
            runningSessions: runningActivities.count,
            cyclingSessions: cyclingActivities.count,
            averageSessionDuration: last24Hours.isEmpty ? 0.0 : 
                last24Hours.reduce(0) { $0 + $1.duration } / Double(last24Hours.count)
        )
    }
    
    // MARK: - Anti-cheat Integration
    func detectSuspiciousMotion() -> SuspiciousMotionDetection? {
        // Check for impossible motion patterns
        let recentActivities = activityHistory.suffix(10)
        
        // Check for rapid activity changes
        let activityChanges = recentActivities.enumerated().reduce(0) { count, item in
            if item.offset > 0 && item.element.activity != recentActivities[item.offset - 1].activity {
                return count + 1
            }
            return count
        }
        
        if activityChanges > 5 {
            return SuspiciousMotionDetection(
                type: .rapidActivityChanges,
                severity: .medium,
                description: "Too many rapid activity changes detected",
                details: ["activity_changes": activityChanges]
            )
        }
        
        // Check for impossible step counts
        let recentSteps = getRecentStepCount()
        if recentSteps > 50000 { // More than 50k steps in 5 minutes
            return SuspiciousMotionDetection(
                type: .impossibleStepCount,
                severity: .high,
                description: "Impossibly high step count detected",
                details: ["step_count": recentSteps]
            )
        }
        
        // Check for motion/location mismatch
        if isActivelyMoving && motionDuration > Verify.motionLocationMismatchMinutes * 60 {
            return SuspiciousMotionDetection(
                type: .motionLocationMismatch,
                severity: .medium,
                description: "Motion detected but location appears stationary",
                details: ["motion_duration": motionDuration]
            )
        }
        
        return nil
    }
    
    // MARK: - Validation
    func validateMotionData() -> ValidationResult {
        var errors: [String] = []
        
        // Check if motion services are available
        if !CMMotionActivityManager.isActivityAvailable() {
            errors.append("Motion activity monitoring not available")
        }
        
        if !CMPedometer.isStepCountingAvailable() {
            errors.append("Step counting not available")
        }
        
        // Check for recent activity data
        let recentActivities = activityHistory.filter { 
            $0.timestamp.timeIntervalSinceNow > -300 // Last 5 minutes
        }
        
        if recentActivities.isEmpty {
            errors.append("No recent motion activity data")
        }
        
        // Check confidence levels
        let lowConfidenceActivities = recentActivities.filter { $0.confidence < 0.5 }
        if lowConfidenceActivities.count > recentActivities.count / 2 {
            errors.append("Low confidence in motion activity detection")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Cleanup
    func cleanupOldData() {
        let cutoffTime = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        activityHistory.removeAll { $0.timestamp < cutoffTime }
    }
}

// MARK: - Supporting Types
enum MotionActivity: String, CaseIterable {
    case walking = "walking"
    case running = "running"
    case cycling = "cycling"
    case driving = "driving"
    case stationary = "stationary"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .driving: return "Driving"
        case .stationary: return "Stationary"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .driving: return "car"
        case .stationary: return "pause.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct MotionActivityRecord {
    let id: UUID
    let activity: MotionActivity
    let confidence: Double
    let timestamp: Date
    let duration: TimeInterval
}

struct ActivityStats {
    let totalDuration: TimeInterval
    let activityCounts: [MotionActivity: Int]
    let averageConfidence: Double
    let mostCommonActivity: MotionActivity
    let timeInterval: TimeInterval
}

struct MotionPatterns {
    let totalWalkingTime: TimeInterval
    let totalRunningTime: TimeInterval
    let totalCyclingTime: TimeInterval
    let walkingSessions: Int
    let runningSessions: Int
    let cyclingSessions: Int
    let averageSessionDuration: TimeInterval
}

enum SuspiciousMotionType {
    case rapidActivityChanges
    case impossibleStepCount
    case motionLocationMismatch
    case lowConfidencePattern
}

enum SuspiciousMotionSeverity {
    case low
    case medium
    case high
    case critical
}

struct SuspiciousMotionDetection {
    let type: SuspiciousMotionType
    let severity: SuspiciousMotionSeverity
    let description: String
    let details: [String: Any]
}

// MARK: - Notifications
extension Notification.Name {
    static let motionActivityChanged = Notification.Name("motionActivityChanged")
}
