//
//  MotionManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreMotion
import CoreLocation
import Combine
import CoreData

@MainActor
class MotionManager: ObservableObject {
    static let shared = MotionManager()
    
    @Published var isActivelyMoving: Bool = false
    @Published var motionDuration: Double = 0.0
    @Published var currentActivity: CMMotionActivity?
    @Published var todaysSteps: Int = 0
    @Published var todaysDistance: Double = 0.0
    @Published var isStepCountingAvailable: Bool = false
    
    private let motionActivityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Motion tracking state
    private var motionStartTime: Date?
    private var lastActivityUpdate: Date = Date()
    private var activityTimer: Timer?
    private var stepCountingTimer: Timer?
    
    // Activity classification
    private var recentActivities: [CMMotionActivity] = []
    private var activityConfidence: Double = 0.0
    
    init() {
        checkAvailability()
        setupNotifications()
        startMotionTracking()
    }
    
    deinit {
        stopMotionTracking()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func checkAvailability() {
        isStepCountingAvailable = CMPedometer.isStepCountingAvailable()
        
        if !CMMotionActivityManager.isActivityAvailable() {
            print("⚠️ Motion activity not available on this device")
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
    }
    
    // MARK: - Motion Tracking
    func startMotionTracking() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        // Start activity updates
        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            self?.handleMotionActivityUpdate(activity)
        }
        
        // Start step counting if available
        if isStepCountingAvailable {
            startStepCounting()
        }
        
        // Start activity monitoring timer
        activityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateMotionState()
        }
    }
    
    func stopMotionTracking() {
        motionActivityManager.stopActivityUpdates()
        stopStepCounting()
        activityTimer?.invalidate()
        activityTimer = nil
    }
    
    private func handleMotionActivityUpdate(_ activity: CMMotionActivity?) {
        guard let activity = activity else { return }
        
        DispatchQueue.main.async {
            self.currentActivity = activity
            self.lastActivityUpdate = Date()
            
            // Update motion state
            self.isActivelyMoving = activity.walking || activity.running || activity.cycling || activity.automotive
            
            // Track motion duration
            if self.isActivelyMoving && self.motionStartTime == nil {
                self.motionStartTime = Date()
            } else if !self.isActivelyMoving && self.motionStartTime != nil {
                self.motionDuration += Date().timeIntervalSince(self.motionStartTime!)
                self.motionStartTime = nil
            }
            
            // Store recent activity for analysis
            self.recentActivities.append(activity)
            if self.recentActivities.count > 10 {
                self.recentActivities.removeFirst()
            }
            
            // Calculate activity confidence
            self.calculateActivityConfidence()
            
            // Post notification
            NotificationCenter.default.post(
                name: .motionActivityUpdated,
                object: nil,
                userInfo: ["activity": activity]
            )
        }
    }
    
    private func updateMotionState() {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastActivityUpdate)
        
        // If no activity update in 2 minutes, assume stationary
        if timeSinceLastUpdate > 120 {
            isActivelyMoving = false
            if motionStartTime != nil {
                motionDuration += Date().timeIntervalSince(motionStartTime!)
                motionStartTime = nil
            }
        }
    }
    
    private func calculateActivityConfidence() {
        guard !recentActivities.isEmpty else {
            activityConfidence = 0.0
            return
        }
        
        let recentWalking = recentActivities.filter { $0.walking }.count
        let recentRunning = recentActivities.filter { $0.running }.count
        let recentStationary = recentActivities.filter { $0.stationary }.count
        
        let totalActivities = recentActivities.count
        let activeActivities = recentWalking + recentRunning
        
        activityConfidence = Double(activeActivities) / Double(totalActivities)
    }
    
    // MARK: - Step Counting
    private func startStepCounting() {
        guard isStepCountingAvailable else { return }
        
        // Get today's steps
        updateTodaysSteps()
        
        // Start periodic step updates
        stepCountingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateTodaysSteps()
        }
    }
    
    private func stopStepCounting() {
        stepCountingTimer?.invalidate()
        stepCountingTimer = nil
    }
    
    private func updateTodaysSteps() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] data, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error getting step data: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else { return }
                
                self?.todaysSteps = data.numberOfSteps.intValue
                self?.todaysDistance = data.distance?.doubleValue ?? 0.0
                
                // Post notification
                NotificationCenter.default.post(
                    name: .stepCountUpdated,
                    object: nil,
                    userInfo: [
                        "steps": data.numberOfSteps.intValue,
                        "distance": data.distance?.doubleValue ?? 0.0
                    ]
                )
            }
        }
    }
    
    // MARK: - Public Methods
    func getStepsForDate(_ date: Date) -> (stepCount: Int, distance: Double) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        var stepCount = 0
        var distance = 0.0
        
        let semaphore = DispatchSemaphore(value: 0)
        
        pedometer.queryPedometerData(from: startOfDay, to: endOfDay) { data, error in
            if let data = data {
                stepCount = data.numberOfSteps.intValue
                distance = data.distance?.doubleValue ?? 0.0
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return (stepCount, distance)
    }
    
    func getStepsForDateRange(from startDate: Date, to endDate: Date) -> [(Date, Int, Double)] {
        var results: [(Date, Int, Double)] = []
        let calendar = Calendar.current
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dayResult = getStepsForDate(currentDate)
            results.append((currentDate, dayResult.stepCount, dayResult.distance))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return results
    }
    
    func getWeeklySteps() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        let weekResults = getStepsForDateRange(from: weekAgo, to: now)
        return weekResults.reduce(0) { $0 + $1.1 }
    }
    
    func getMonthlySteps() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        
        let monthResults = getStepsForDateRange(from: monthAgo, to: now)
        return monthResults.reduce(0) { $0 + $1.1 }
    }
    
    // MARK: - Activity Analysis
    func getActivitySummary(for date: Date) -> ActivitySummary {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // This would analyze motion activities for the day - activity classification
        // For now, return a basic summary
        return ActivitySummary(
            date: date,
            totalSteps: getStepsForDate(date).stepCount,
            totalDistance: getStepsForDate(date).distance,
            walkingTime: 0,
            runningTime: 0,
            cyclingTime: 0,
            stationaryTime: 0,
            confidence: activityConfidence
        )
    }
    
    func isUserActive() -> Bool {
        return isActivelyMoving && activityConfidence > 0.5
    }
    
    func getCurrentActivityType() -> ActivityType {
        guard let activity = currentActivity else { return .unknown }
        
        if activity.running {
            return .running
        } else if activity.walking {
            return .walking
        } else if activity.cycling {
            return .cycling
        } else if activity.automotive {
            return .driving
        } else if activity.stationary {
            return .stationary
        } else {
            return .unknown
        }
    }
    
    // MARK: - Challenge Integration
    func verifyStepChallenge(targetSteps: Int, for date: Date) -> Bool {
        let actualSteps = getStepsForDate(date).stepCount
        return actualSteps >= targetSteps
    }
    
    func verifyActivityChallenge(activityType: ActivityType, minDuration: TimeInterval, for date: Date) -> Bool {
        // This would analyze the day's activities to see if the user
        // performed the required activity for the minimum duration
        // For now, return a placeholder
        return false
    }
    
    // MARK: - App Lifecycle Handlers
    private func handleAppBecameActive() {
        // Resume motion tracking
        startMotionTracking()
    }
    
    private func handleAppEnteredBackground() {
        // Continue motion tracking in background
        // Core Motion continues to work in background
    }
}

// MARK: - Supporting Types
struct ActivitySummary {
    let date: Date
    let totalSteps: Int
    let totalDistance: Double
    let walkingTime: TimeInterval
    let runningTime: TimeInterval
    let cyclingTime: TimeInterval
    let stationaryTime: TimeInterval
    let confidence: Double
}

enum ActivityType: String, CaseIterable {
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

// MARK: - Notifications
extension Notification.Name {
    static let motionActivityUpdated = Notification.Name("motionActivityUpdated")
    static let stepCountUpdated = Notification.Name("stepCountUpdated")
}
