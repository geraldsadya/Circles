//
//  AntiCheatEngine.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import CoreMotion
import Security
import Combine

@MainActor
class AntiCheatEngine: ObservableObject {
    static let shared = AntiCheatEngine()
    
    @Published var suspiciousActivities: [SuspiciousActivity] = []
    @Published var isMonitoring = false
    @Published var integrityScore: Double = 1.0
    
    private let locationManager = LocationManager.shared
    private let motionManager = MotionManager.shared
    private let cameraManager = CameraManager.shared
    private let persistenceController = PersistenceController.shared
    
    // Monitoring state
    private var monitoringTimer: Timer?
    private var systemUptimeAtLaunch: TimeInterval = 0
    private var lastClockCheck: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // Suspicion thresholds
    private var motionLocationMismatchCount = 0
    private var clockTamperCount = 0
    private var rapidLocationChanges = 0
    private var impossibleMovementCount = 0
    private var dataInconsistencyCount = 0
    
    // Integrity tracking
    private var recentIntegrityChecks: [IntegrityCheck] = []
    private var baselineIntegrityScore: Double = 1.0
    
    init() {
        systemUptimeAtLaunch = ProcessInfo.processInfo.systemUptime
        setupNotificationObservers()
        startMonitoring()
    }
    
    deinit {
        cancellables.removeAll()
        stopMonitoring()
    }
    
    // MARK: - Setup
    private func setupNotificationObservers() {
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.performIntegrityCheck()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pauseMonitoring()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Perform initial integrity check
        performIntegrityCheck()
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performAntiCheatChecks()
        }
        
        // Log monitoring start
        AnalyticsManager.shared.logEvent(.permissionGranted, properties: [
            "permission": "anti_cheat_monitoring"
        ])
        
        print("Anti-cheat monitoring started")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Log monitoring stop
        AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
            "permission": "anti_cheat_monitoring"
        ])
        
        print("Anti-cheat monitoring stopped")
    }
    
    private func pauseMonitoring() {
        // Pause timers but keep monitoring active
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Anti-Cheat Checks
    private func performAntiCheatChecks() {
        checkClockTampering()
        checkMotionLocationMismatch()
        checkRapidLocationChanges()
        checkImpossibleMovement()
        checkDataInconsistency()
        checkSuspiciousPatterns()
        updateIntegrityScore()
    }
    
    // MARK: - Clock Tampering Detection
    private func checkClockTampering() {
        let systemUptime = ProcessInfo.processInfo.systemUptime
        let wallClockTime = Date().timeIntervalSince1970
        
        // Calculate expected uptime based on wall clock
        let expectedUptime = wallClockTime - systemUptimeAtLaunch
        let uptimeDifference = abs(systemUptime - expectedUptime)
        
        if uptimeDifference > Verify.clockTamperThreshold {
            clockTamperCount += 1
            
            let activity = SuspiciousActivity(
                id: UUID(),
                type: .clockTampering,
                severity: .high,
                timestamp: Date(),
                description: "System uptime vs wall clock mismatch detected",
                details: [
                    "uptime_difference": uptimeDifference,
                    "system_uptime": systemUptime,
                    "wall_clock": wallClockTime,
                    "expected_uptime": expectedUptime,
                    "tamper_count": clockTamperCount
                ]
            )
            
            recordSuspiciousActivity(activity)
            
            // Require camera verification for clock tampering
            requireCameraVerification(reason: "Clock tampering detected")
            
            // Log clock tampering
            AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
                "permission": "clock_tampering",
                "severity": "high",
                "uptime_difference": uptimeDifference
            ])
        }
    }
    
    // MARK: - Motion/Location Mismatch Detection
    private func checkMotionLocationMismatch() {
        let isStationary = locationManager.isStationary
        let isMoving = motionManager.isActivelyMoving
        let motionDuration = motionManager.motionDuration
        
        // If GPS says stationary but motion says moving for extended period
        if isStationary && isMoving && motionDuration > Verify.motionLocationMismatchMinutes {
            motionLocationMismatchCount += 1
            
            let activity = SuspiciousActivity(
                id: UUID(),
                type: .motionLocationMismatch,
                severity: .medium,
                timestamp: Date(),
                description: "GPS stationary but motion active for extended period",
                details: [
                    "motion_duration": motionDuration,
                    "is_stationary": isStationary,
                    "is_moving": isMoving,
                    "mismatch_count": motionLocationMismatchCount
                ]
            )
            
            recordSuspiciousActivity(activity)
            
            // Require camera verification for motion/location mismatch
            requireCameraVerification(reason: "Motion/location mismatch detected")
            
            // Log motion/location mismatch
            AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
                "permission": "motion_location_mismatch",
                "severity": "medium",
                "motion_duration": motionDuration
            ])
        }
    }
    
    // MARK: - Rapid Location Changes Detection
    private func checkRapidLocationChanges() {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        // Check if location changed too rapidly (impossible movement)
        if let lastLocation = locationManager.locationHistory.last {
            let distance = currentLocation.distance(from: lastLocation)
            let timeDifference = currentLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
            
            // Calculate speed (m/s)
            let speed = distance / timeDifference
            
            // If speed > 50 m/s (180 km/h), it's suspicious
            if speed > 50.0 {
                rapidLocationChanges += 1
                
                let activity = SuspiciousActivity(
                    id: UUID(),
                    type: .rapidLocationChange,
                    severity: .high,
                    timestamp: Date(),
                    description: "Impossibly rapid location change detected",
                    details: [
                        "speed_ms": speed,
                        "distance": distance,
                        "time_difference": timeDifference,
                        "rapid_changes_count": rapidLocationChanges
                    ]
                )
                
                recordSuspiciousActivity(activity)
                
                // Require camera verification for rapid location changes
                requireCameraVerification(reason: "Rapid location change detected")
                
                // Log rapid location change
                AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
                    "permission": "rapid_location_change",
                    "severity": "high",
                    "speed_ms": speed
                ])
            }
        }
    }
    
    // MARK: - Impossible Movement Detection
    private func checkImpossibleMovement() {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        // Check for impossible movement patterns
        let locationHistory = locationManager.locationHistory
        guard locationHistory.count >= 3 else { return }
        
        let recentLocations = Array(locationHistory.suffix(3))
        var impossibleMovements = 0
        
        for i in 1..<recentLocations.count {
            let prev = recentLocations[i-1]
            let curr = recentLocations[i]
            
            let distance = curr.distance(from: prev)
            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            
            if timeDiff > 0 {
                let speed = distance / timeDiff
                
                // Check for impossible speeds (>200 m/s = 720 km/h)
                if speed > 200.0 {
                    impossibleMovements += 1
                }
            }
        }
        
        if impossibleMovements > 0 {
            impossibleMovementCount += 1
            
            let activity = SuspiciousActivity(
                id: UUID(),
                type: .impossibleMovement,
                severity: .high,
                timestamp: Date(),
                description: "Impossible movement pattern detected",
                details: [
                    "impossible_movements": impossibleMovements,
                    "impossible_movement_count": impossibleMovementCount
                ]
            )
            
            recordSuspiciousActivity(activity)
            
            // Require camera verification for impossible movement
            requireCameraVerification(reason: "Impossible movement detected")
            
            // Log impossible movement
            AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
                "permission": "impossible_movement",
                "severity": "high",
                "impossible_movements": impossibleMovements
            ])
        }
    }
    
    // MARK: - Data Inconsistency Detection
    private func checkDataInconsistency() {
        // Check for data inconsistencies between different sensors
        let locationAccuracy = locationManager.currentLocation?.horizontalAccuracy ?? 0
        let isStationary = locationManager.isStationary
        let isMoving = motionManager.isActivelyMoving
        
        // If location accuracy is very poor but motion says moving
        if locationAccuracy > 100 && isMoving {
            dataInconsistencyCount += 1
            
            let activity = SuspiciousActivity(
                id: UUID(),
                type: .dataInconsistency,
                severity: .medium,
                timestamp: Date(),
                description: "Data inconsistency between location accuracy and motion",
                details: [
                    "location_accuracy": locationAccuracy,
                    "is_stationary": isStationary,
                    "is_moving": isMoving,
                    "inconsistency_count": dataInconsistencyCount
                ]
            )
            
            recordSuspiciousActivity(activity)
            
            // Log data inconsistency
            AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
                "permission": "data_inconsistency",
                "severity": "medium",
                "location_accuracy": locationAccuracy
            ])
        }
    }
    
    // MARK: - Suspicious Patterns Detection
    private func checkSuspiciousPatterns() {
        // Check for patterns that might indicate cheating
        let recentActivities = suspiciousActivities.filter { 
            $0.timestamp.timeIntervalSinceNow > -3600 // Last hour
        }
        
        // If too many suspicious activities in short time
        if recentActivities.count > 5 {
            let activity = SuspiciousActivity(
                id: UUID(),
                type: .suspiciousPattern,
                severity: .high,
                timestamp: Date(),
                description: "Multiple suspicious activities detected in short time",
                details: [
                    "recent_activities_count": recentActivities.count,
                    "time_window": "1 hour"
                ]
            )
            
            recordSuspiciousActivity(activity)
            
            // Require camera verification for suspicious patterns
            requireCameraVerification(reason: "Suspicious activity pattern detected")
            
            // Log suspicious pattern
            AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
                "permission": "suspicious_pattern",
                "severity": "high",
                "recent_activities_count": recentActivities.count
            ])
        }
    }
    
    // MARK: - Integrity Score Management
    private func updateIntegrityScore() {
        let recentActivities = suspiciousActivities.filter { 
            $0.timestamp.timeIntervalSinceNow > -3600 // Last hour
        }
        
        let highSeverityCount = recentActivities.filter { $0.severity == .high }.count
        let mediumSeverityCount = recentActivities.filter { $0.severity == .medium }.count
        let lowSeverityCount = recentActivities.filter { $0.severity == .low }.count
        
        // Calculate integrity score (0.0 - 1.0)
        var score = 1.0
        score -= Double(highSeverityCount) * 0.3
        score -= Double(mediumSeverityCount) * 0.15
        score -= Double(lowSeverityCount) * 0.05
        
        integrityScore = max(0.0, min(1.0, score))
        
        // Record integrity check
        let integrityCheck = IntegrityCheck(
            id: UUID(),
            timestamp: Date(),
            score: integrityScore,
            highSeverityCount: highSeverityCount,
            mediumSeverityCount: mediumSeverityCount,
            lowSeverityCount: lowSeverityCount
        )
        
        recentIntegrityChecks.append(integrityCheck)
        
        // Keep only last 24 hours of checks
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        recentIntegrityChecks.removeAll { $0.timestamp < cutoffDate }
    }
    
    private func performIntegrityCheck() {
        // Perform a comprehensive integrity check
        let check = IntegrityCheck(
            id: UUID(),
            timestamp: Date(),
            score: integrityScore,
            highSeverityCount: suspiciousActivities.filter { $0.severity == .high }.count,
            mediumSeverityCount: suspiciousActivities.filter { $0.severity == .medium }.count,
            lowSeverityCount: suspiciousActivities.filter { $0.severity == .low }.count
        )
        
        recentIntegrityChecks.append(check)
        
        // Log integrity check
        AnalyticsManager.shared.logEvent(.permissionGranted, properties: [
            "permission": "integrity_check",
            "score": integrityScore
        ])
    }
    
    // MARK: - Camera Verification Requirement
    private func requireCameraVerification(reason: String) {
        NotificationCenter.default.post(
            name: .cameraVerificationRequired,
            object: nil,
            userInfo: [
                "reason": reason,
                "timestamp": Date(),
                "integrity_score": integrityScore
            ]
        )
        
        print("Camera verification required: \(reason)")
    }
    
    // MARK: - Activity Recording
    private func recordSuspiciousActivity(_ activity: SuspiciousActivity) {
        suspiciousActivities.append(activity)
        
        // Keep only last 100 activities
        if suspiciousActivities.count > 100 {
            suspiciousActivities.removeFirst()
        }
        
        // Save to Core Data
        saveSuspiciousActivity(activity)
        
        // Log to system
        print("Suspicious activity recorded: \(activity.type) - \(activity.description)")
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .suspiciousActivityDetected,
            object: nil,
            userInfo: ["activity": activity]
        )
    }
    
    private func saveSuspiciousActivity(_ activity: SuspiciousActivity) {
        let context = persistenceController.container.viewContext
        
        let entity = SuspiciousActivityEntity(context: context)
        entity.id = activity.id
        entity.type = activity.type.rawValue
        entity.severity = activity.severity.rawValue
        entity.timestamp = activity.timestamp
        entity.description = activity.description
        entity.details = activity.details as NSDictionary
        entity.createdAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Error saving suspicious activity: \(error)")
        }
    }
    
    // MARK: - Challenge Verification Integration
    func verifyChallengeIntegrity(_ challenge: Challenge, user: User) -> VerificationResult {
        // Check if user has recent suspicious activities
        let recentSuspiciousActivities = suspiciousActivities.filter {
            $0.timestamp.timeIntervalSinceNow > -3600 // Last hour
        }
        
        if recentSuspiciousActivities.count > 2 {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Recent suspicious activity detected - camera verification required"
            )
        }
        
        // Check integrity score
        if integrityScore < 0.5 {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Low integrity score - camera verification required"
            )
        }
        
        // Check for specific challenge-related cheating
        switch challenge.verificationMethod {
        case VerificationMethod.location.rawValue:
            return verifyLocationChallengeIntegrity(challenge)
        case VerificationMethod.motion.rawValue:
            return verifyMotionChallengeIntegrity(challenge)
        case VerificationMethod.camera.rawValue:
            return verifyCameraChallengeIntegrity(challenge)
        default:
            return VerificationResult(
                isVerified: true,
                confidenceScore: integrityScore,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "No specific anti-cheat checks for this verification method"
            )
        }
    }
    
    private func verifyLocationChallengeIntegrity(_ challenge: Challenge) -> VerificationResult {
        // Check if location accuracy is sufficient
        guard let currentLocation = locationManager.currentLocation else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "No location data available"
            )
        }
        
        if currentLocation.horizontalAccuracy > Verify.accThreshold {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Location accuracy insufficient for verification"
            )
        }
        
        // Check for motion/location mismatch
        if isMotionLocationMismatch() {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Motion/location mismatch detected - camera verification required"
            )
        }
        
        return VerificationResult(
            isVerified: true,
            confidenceScore: integrityScore * 0.9,
            verificationTimestamp: Date(),
            sensorData: nil,
            notes: "Location challenge integrity verified"
        )
    }
    
    private func verifyMotionChallengeIntegrity(_ challenge: Challenge) -> VerificationResult {
        // Check if motion data is consistent
        let motionData = motionManager.getStepsForDate(Date())
        
        // Check for impossible step counts
        if motionData.stepCount > 50000 { // More than 50k steps in a day
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Impossibly high step count detected"
            )
        }
        
        return VerificationResult(
            isVerified: true,
            confidenceScore: integrityScore * 0.85,
            verificationTimestamp: Date(),
            sensorData: nil,
            notes: "Motion challenge integrity verified"
        )
    }
    
    private func verifyCameraChallengeIntegrity(_ challenge: Challenge) -> VerificationResult {
        // Camera challenges are inherently more secure
        // Check for liveness detection
        let livenessScore = cameraManager.getLivenessScore()
        
        if livenessScore < 0.7 {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Liveness detection failed"
            )
        }
        
        return VerificationResult(
            isVerified: true,
            confidenceScore: integrityScore * livenessScore,
            verificationTimestamp: Date(),
            sensorData: nil,
            notes: "Camera challenge integrity verified"
        )
    }
    
    // MARK: - Helper Methods
    private func isMotionLocationMismatch() -> Bool {
        let isStationary = locationManager.isStationary
        let isMoving = motionManager.isActivelyMoving
        let motionDuration = motionManager.motionDuration
        
        return isStationary && isMoving && motionDuration > Verify.motionLocationMismatchMinutes
    }
    
    // MARK: - Analytics
    func getAntiCheatStats() -> AntiCheatStats {
        let totalActivities = suspiciousActivities.count
        let highSeverityActivities = suspiciousActivities.filter { $0.severity == .high }.count
        let mediumSeverityActivities = suspiciousActivities.filter { $0.severity == .medium }.count
        let lowSeverityActivities = suspiciousActivities.filter { $0.severity == .low }.count
        
        return AntiCheatStats(
            totalSuspiciousActivities: totalActivities,
            highSeverityCount: highSeverityActivities,
            mediumSeverityCount: mediumSeverityActivities,
            lowSeverityCount: lowSeverityActivities,
            motionLocationMismatches: motionLocationMismatchCount,
            clockTamperAttempts: clockTamperCount,
            rapidLocationChanges: rapidLocationChanges,
            impossibleMovements: impossibleMovementCount,
            dataInconsistencies: dataInconsistencyCount,
            integrityScore: integrityScore,
            isMonitoring: isMonitoring
        )
    }
    
    // MARK: - Cleanup
    func cleanupOldActivities() {
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        suspiciousActivities.removeAll { $0.timestamp < cutoffDate }
    }
}

// MARK: - Supporting Types
struct SuspiciousActivity {
    let id: UUID
    let type: SuspiciousActivityType
    let severity: SuspiciousActivitySeverity
    let timestamp: Date
    let description: String
    let details: [String: Any]
}

enum SuspiciousActivityType: String, CaseIterable {
    case clockTampering = "clock_tampering"
    case motionLocationMismatch = "motion_location_mismatch"
    case rapidLocationChange = "rapid_location_change"
    case suspiciousPattern = "suspicious_pattern"
    case impossibleMovement = "impossible_movement"
    case dataInconsistency = "data_inconsistency"
}

enum SuspiciousActivitySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct IntegrityCheck {
    let id: UUID
    let timestamp: Date
    let score: Double
    let highSeverityCount: Int
    let mediumSeverityCount: Int
    let lowSeverityCount: Int
}

struct AntiCheatStats {
    let totalSuspiciousActivities: Int
    let highSeverityCount: Int
    let mediumSeverityCount: Int
    let lowSeverityCount: Int
    let motionLocationMismatches: Int
    let clockTamperAttempts: Int
    let rapidLocationChanges: Int
    let impossibleMovements: Int
    let dataInconsistencies: Int
    let integrityScore: Double
    let isMonitoring: Bool
}

// MARK: - Extensions
extension MotionManager {
    var isActivelyMoving: Bool {
        // This would be implemented in the actual MotionManager
        return false
    }
    
    var motionDuration: Double {
        // This would be implemented in the actual MotionManager
        return 0.0
    }
    
    func getStepsForDate(_ date: Date) -> MotionDataResult {
        // This would be implemented in the actual MotionManager
        return MotionDataResult(stepCount: 0, distance: 0.0, activityType: "unknown", error: nil)
    }
}

extension CameraManager {
    func getLivenessScore() -> Double {
        // This would be implemented in the actual CameraManager
        return 0.8
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let suspiciousActivityDetected = Notification.Name("suspiciousActivityDetected")
    static let cameraVerificationRequired = Notification.Name("cameraVerificationRequired")
}
