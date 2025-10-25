//
//  MotionChallengeVerifier.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreMotion
import CoreData
import Combine

@MainActor
class MotionChallengeVerifier: ObservableObject {
    static let shared = MotionChallengeVerifier()
    
    @Published var isVerifying = false
    @Published var verificationProgress: Double = 0.0
    @Published var currentStepCount: Int = 0
    @Published var currentDistance: Double = 0.0
    @Published var currentActivity: String = "Unknown"
    
    private let pedometer = CMPedometer()
    private let motionActivityManager = CMMotionActivityManager()
    private let persistenceController = PersistenceController.shared
    
    private var verificationTimers: [UUID: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoringMotion = false
    
    private init() {
        setupMotionMonitoring()
    }
    
    deinit {
        stopAllVerifications()
        stopMotionMonitoring()
    }
    
    // MARK: - Setup
    private func setupMotionMonitoring() {
        // Check if motion services are available
        guard CMPedometer.isStepCountingAvailable() else {
            print("Step counting not available on this device")
            return
        }
        
        // Start motion activity monitoring
        if CMMotionActivityManager.isActivityAvailable() {
            motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
                Task { @MainActor in
                    self?.updateCurrentActivity(activity)
                }
            }
        }
    }
    
    private func stopMotionMonitoring() {
        motionActivityManager.stopActivityUpdates()
    }
    
    // MARK: - Motion Challenge Verification
    func verifyMotionChallenge(_ challenge: Challenge, for user: User) async -> VerificationResult {
        guard challenge.verificationMethod == VerificationMethod.motion.rawValue,
              let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(MotionChallengeParams.self, from: paramsData) else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Invalid motion challenge parameters"
            )
        }
        
        isVerifying = true
        verificationProgress = 0.0
        
        // Check time window if specified
        if let timeWindow = params.timeWindow {
            guard isWithinTimeWindow(timeWindow) else {
                return VerificationResult(
                    isVerified: false,
                    confidenceScore: 0.0,
                    verificationTimestamp: Date(),
                    sensorData: nil,
                    notes: "Outside specified time window"
                )
            }
        }
        
        // Get motion data for today
        let motionData = await getMotionDataForDate(Date(), params: params)
        
        // Calculate verification result
        let isVerified = motionData.stepCount >= params.minSteps
        let confidenceScore = calculateConfidenceScore(
            stepCount: motionData.stepCount,
            targetSteps: params.minSteps,
            distance: motionData.distance,
            activityType: motionData.activityType
        )
        
        isVerifying = false
        
        return VerificationResult(
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            verificationTimestamp: Date(),
            sensorData: MotionData(
                stepCount: motionData.stepCount,
                distance: motionData.distance,
                activityType: motionData.activityType,
                timestamp: Date()
            ),
            notes: isVerified ? "Motion challenge completed successfully" : "Insufficient step count"
        )
    }
    
    // MARK: - Motion Data Collection
    private func getMotionDataForDate(_ date: Date, params: MotionChallengeParams) async -> MotionDataResult {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Filter by time window if specified
        var startTime = startOfDay
        var endTime = endOfDay
        
        if let timeWindow = params.timeWindow {
            switch timeWindow {
            case "morning":
                startTime = startOfDay
                endTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? endOfDay
            case "evening":
                startTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? startOfDay
                endTime = endOfDay
            default:
                break
            }
        }
        
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: startTime, to: endTime) { data, error in
                if let error = error {
                    print("Error querying pedometer data: \(error.localizedDescription)")
                    continuation.resume(returning: MotionDataResult(
                        stepCount: 0,
                        distance: 0.0,
                        activityType: "unknown",
                        error: error
                    ))
                    return
                }
                
                let stepCount = data?.numberOfSteps.intValue ?? 0
                let distance = data?.distance?.doubleValue ?? 0.0
                let activityType = self.determineActivityType(from: data)
                
                continuation.resume(returning: MotionDataResult(
                    stepCount: stepCount,
                    distance: distance,
                    activityType: activityType,
                    error: nil
                ))
            }
        }
    }
    
    private func determineActivityType(from data: CMPedometerData?) -> String {
        // This is a simplified activity type determination
        // In a real implementation, you might use CMMotionActivityManager data
        
        guard let data = data else { return "unknown" }
        
        let stepCount = data.numberOfSteps.intValue
        let distance = data.distance?.doubleValue ?? 0.0
        
        // Simple heuristic based on step count and distance
        if stepCount > 10000 {
            return "running"
        } else if stepCount > 5000 {
            return "walking"
        } else {
            return "stationary"
        }
    }
    
    // MARK: - Real-time Monitoring
    func startRealTimeMonitoring(for challenge: Challenge) {
        guard challenge.verificationMethod == VerificationMethod.motion.rawValue,
              let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(MotionChallengeParams.self, from: paramsData) else {
            return
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            Task { @MainActor in
                await self?.updateMotionProgress(challenge: challenge, params: params)
            }
        }
        
        verificationTimers[challenge.id] = timer
        isMonitoringMotion = true
    }
    
    func stopRealTimeMonitoring(for challenge: Challenge) {
        verificationTimers[challenge.id]?.invalidate()
        verificationTimers.removeValue(forKey: challenge.id)
        
        if verificationTimers.isEmpty {
            isMonitoringMotion = false
        }
    }
    
    private func updateMotionProgress(challenge: Challenge, params: MotionChallengeParams) async {
        let motionData = await getMotionDataForDate(Date(), params: params)
        
        currentStepCount = motionData.stepCount
        currentDistance = motionData.distance
        currentActivity = motionData.activityType
        
        // Update progress
        verificationProgress = min(Double(motionData.stepCount) / Double(params.minSteps), 1.0)
        
        // Check if challenge is completed
        if motionData.stepCount >= params.minSteps {
            await completeMotionChallenge(challenge: challenge, motionData: motionData)
            stopRealTimeMonitoring(for: challenge)
        }
    }
    
    private func completeMotionChallenge(challenge: Challenge, motionData: MotionDataResult) async {
        NotificationCenter.default.post(
            name: .motionChallengeCompleted,
            object: nil,
            userInfo: [
                "challenge": challenge,
                "motionData": motionData
            ]
        )
    }
    
    // MARK: - Activity Updates
    private func updateCurrentActivity(_ activity: CMMotionActivity?) {
        guard let activity = activity else { return }
        
        if activity.walking {
            currentActivity = "walking"
        } else if activity.running {
            currentActivity = "running"
        } else if activity.automotive {
            currentActivity = "driving"
        } else if activity.cycling {
            currentActivity = "cycling"
        } else if activity.stationary {
            currentActivity = "stationary"
        } else {
            currentActivity = "unknown"
        }
    }
    
    // MARK: - Time Window Validation
    private func isWithinTimeWindow(_ timeWindow: String) -> Bool {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        switch timeWindow {
        case "morning":
            return currentHour < 8
        case "evening":
            return currentHour >= 18
        case "all_day":
            return true
        default:
            return true
        }
    }
    
    // MARK: - Confidence Score Calculation
    private func calculateConfidenceScore(
        stepCount: Int,
        targetSteps: Int,
        distance: Double,
        activityType: String
    ) -> Double {
        var score: Double = 0.0
        
        // Step count factor (0.0 - 1.0)
        let stepFactor = min(Double(stepCount) / Double(targetSteps), 1.0)
        score += stepFactor * 0.7 // 70% weight
        
        // Activity type factor (0.0 - 1.0)
        let activityFactor: Double
        switch activityType {
        case "running":
            activityFactor = 1.0
        case "walking":
            activityFactor = 0.8
        case "cycling":
            activityFactor = 0.6
        case "stationary":
            activityFactor = 0.2
        default:
            activityFactor = 0.5
        }
        score += activityFactor * 0.2 // 20% weight
        
        // Distance factor (0.0 - 1.0)
        let expectedDistance = Double(targetSteps) * 0.7 // Rough estimate: 0.7m per step
        let distanceFactor = min(distance / expectedDistance, 1.0)
        score += distanceFactor * 0.1 // 10% weight
        
        return min(score, 1.0)
    }
    
    // MARK: - Timer Management
    private func stopAllVerifications() {
        verificationTimers.values.forEach { $0.invalidate() }
        verificationTimers.removeAll()
        isMonitoringMotion = false
    }
    
    // MARK: - Validation
    func validateMotionChallenge(_ challenge: Challenge) -> ValidationResult {
        guard challenge.verificationMethod == VerificationMethod.motion.rawValue else {
            return ValidationResult(
                isValid: false,
                errors: ["Challenge is not a motion challenge"]
            )
        }
        
        guard let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(MotionChallengeParams.self, from: paramsData) else {
            return ValidationResult(
                isValid: false,
                errors: ["Invalid motion challenge parameters"]
            )
        }
        
        var errors: [String] = []
        
        // Validate step count
        if params.minSteps <= 0 {
            errors.append("Minimum steps must be greater than 0")
        }
        
        if params.minSteps > 100000 {
            errors.append("Minimum steps cannot exceed 100,000")
        }
        
        // Validate distance if provided
        if let minDistance = params.minDistance {
            if minDistance <= 0 {
                errors.append("Minimum distance must be greater than 0")
            }
            
            if minDistance > 100000 { // 100km
                errors.append("Minimum distance cannot exceed 100km")
            }
        }
        
        // Validate activity type
        if let activityType = params.activityType {
            let validTypes = ["walking", "running", "cycling", "all"]
            if !validTypes.contains(activityType) {
                errors.append("Invalid activity type")
            }
        }
        
        // Validate time window
        if let timeWindow = params.timeWindow {
            let validWindows = ["morning", "evening", "all_day"]
            if !validWindows.contains(timeWindow) {
                errors.append("Invalid time window")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Analytics
    func getMotionChallengeStats(for user: User) -> MotionChallengeStats {
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(
            format: "user == %@ AND verificationMethod == %@",
            user, VerificationMethod.motion.rawValue
        )
        
        do {
            let proofs = try persistenceController.container.viewContext.fetch(request)
            let completedCount = proofs.filter { $0.isVerified }.count
            let totalCount = proofs.count
            let successRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
            
            // Calculate average step count
            let stepCounts = proofs.compactMap { proof in
                proof.getVerificationParams(as: MotionData.self)?.stepCount
            }
            let averageStepCount = stepCounts.isEmpty ? 0 : stepCounts.reduce(0, +) / stepCounts.count
            
            return MotionChallengeStats(
                totalChallenges: totalCount,
                completedChallenges: completedCount,
                successRate: successRate,
                averageStepCount: averageStepCount,
                averageConfidenceScore: proofs.compactMap { $0.confidenceScore }.reduce(0, +) / Double(proofs.count)
            )
        } catch {
            print("Error getting motion challenge stats: \(error)")
            return MotionChallengeStats(
                totalChallenges: 0,
                completedChallenges: 0,
                successRate: 0.0,
                averageStepCount: 0,
                averageConfidenceScore: 0.0
            )
        }
    }
    
    // MARK: - Device Capabilities
    func checkMotionCapabilities() -> MotionCapabilities {
        return MotionCapabilities(
            isStepCountingAvailable: CMPedometer.isStepCountingAvailable(),
            isDistanceAvailable: CMPedometer.isDistanceAvailable(),
            isPaceAvailable: CMPedometer.isPaceAvailable(),
            isCadenceAvailable: CMPedometer.isCadenceAvailable(),
            isActivityAvailable: CMMotionActivityManager.isActivityAvailable()
        )
    }
}

// MARK: - Supporting Types
struct MotionDataResult {
    let stepCount: Int
    let distance: Double
    let activityType: String
    let error: Error?
}

struct MotionChallengeStats {
    let totalChallenges: Int
    let completedChallenges: Int
    let successRate: Double
    let averageStepCount: Int
    let averageConfidenceScore: Double
}

struct MotionCapabilities {
    let isStepCountingAvailable: Bool
    let isDistanceAvailable: Bool
    let isPaceAvailable: Bool
    let isCadenceAvailable: Bool
    let isActivityAvailable: Bool
}

// MARK: - Notifications
extension Notification.Name {
    static let motionChallengeCompleted = Notification.Name("motionChallengeCompleted")
}
