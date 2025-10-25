//
//  ChallengeVerificationEngine.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import CoreMotion
import HealthKit
import AVFoundation

class ChallengeVerificationEngine: ObservableObject {
    private let locationManager = LocationManager.shared
    private let motionManager = MotionManager.shared
    private let healthManager = HealthManager.shared
    private let cameraManager = CameraManager.shared
    
    func verifyChallenge(_ challenge: Challenge, for user: User) -> Proof {
        let proof = Proof(context: PersistenceController.shared.container.viewContext)
        proof.id = UUID()
        proof.challenge = challenge
        proof.user = user
        proof.timestamp = Date()
        proof.verificationMethod = challenge.verificationMethod
        
        // Anti-cheat: Check for clock tampering
        guard !isClockTampered() else {
            proof.isVerified = false
            proof.notes = "Clock tampering detected"
            proof.confidenceScore = 0.0
            proof.pointsAwarded = -challenge.pointsPenalty
            return proof
        }
        
        var verificationResult: VerificationResult
        
        switch challenge.verificationMethod {
        case VerificationMethod.location.rawValue:
            verificationResult = verifyLocationChallenge(challenge, user: user)
        case VerificationMethod.motion.rawValue:
            verificationResult = verifyMotionChallenge(challenge, user: user)
        case VerificationMethod.health.rawValue:
            verificationResult = verifyHealthChallenge(challenge, user: user)
        case VerificationMethod.screenTime.rawValue:
            verificationResult = verifyScreenTimeChallenge(challenge, user: user)
        case VerificationMethod.camera.rawValue:
            verificationResult = verifyCameraChallenge(challenge, user: user)
        default:
            verificationResult = VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Unknown verification method"
            )
        }
        
        proof.isVerified = verificationResult.isVerified
        proof.confidenceScore = verificationResult.confidenceScore
        proof.notes = verificationResult.notes
        
        // Store verification data
        if let sensorData = verificationResult.sensorData {
            proof.verificationData = try? JSONEncoder().encode(sensorData)
        }
        
        proof.pointsAwarded = verificationResult.isVerified ? challenge.pointsReward : -challenge.pointsPenalty
        
        return proof
    }
    
    // MARK: - Anti-Cheat Detection
    private func isClockTampered() -> Bool {
        let systemUptime = ProcessInfo.processInfo.systemUptime
        let wallClockTime = Date().timeIntervalSince1970
        
        // Check if system uptime vs wall clock is suspiciously different
        let expectedUptime = wallClockTime - appLaunchTime
        let uptimeDifference = abs(systemUptime - expectedUptime)
        
        return uptimeDifference > Verify.clockTamperThreshold
    }
    
    private var appLaunchTime: TimeInterval = Date().timeIntervalSince1970
    
    // MARK: - Location Verification
    private func verifyLocationChallenge(_ challenge: Challenge, user: User) -> VerificationResult {
        guard let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(LocationChallengeParams.self, from: paramsData) else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Invalid location challenge parameters"
            )
        }
        
        guard let userLocation = locationManager.currentLocation else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "No location data available"
            )
        }
        
        // Check location accuracy
        guard userLocation.horizontalAccuracy <= Verify.accThreshold else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: LocationData(
                    latitude: userLocation.coordinate.latitude,
                    longitude: userLocation.coordinate.longitude,
                    accuracy: userLocation.horizontalAccuracy,
                    timestamp: userLocation.timestamp,
                    durationAtLocation: nil
                ),
                notes: "Location accuracy insufficient"
            )
        }
        
        let targetLocation = CLLocation(
            latitude: params.targetLocation.latitude,
            longitude: params.targetLocation.longitude
        )
        
        let distance = userLocation.distance(from: targetLocation)
        let durationAtLocation = locationManager.durationAtLocation(targetLocation)
        
        // Anti-cheat: Check for motion/location mismatch
        if isMotionLocationMismatch() {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: LocationData(
                    latitude: userLocation.coordinate.latitude,
                    longitude: userLocation.coordinate.longitude,
                    accuracy: userLocation.horizontalAccuracy,
                    timestamp: userLocation.timestamp,
                    durationAtLocation: durationAtLocation
                ),
                notes: "Motion/location mismatch detected - camera verification required"
            )
        }
        
        // Check cooldown period for geofence challenges
        if let lastCredit = getLastGeofenceCredit(targetLocation) {
            let hoursSinceLastCredit = Date().timeIntervalSince(lastCredit) / 3600
            guard hoursSinceLastCredit >= Verify.geofenceCooldownHours else {
                return VerificationResult(
                    isVerified: false,
                    confidenceScore: 0.0,
                    verificationTimestamp: Date(),
                    sensorData: LocationData(
                        latitude: userLocation.coordinate.latitude,
                        longitude: userLocation.coordinate.longitude,
                        accuracy: userLocation.horizontalAccuracy,
                        timestamp: userLocation.timestamp,
                        durationAtLocation: durationAtLocation
                    ),
                    notes: "Geofence cooldown period active"
                )
            }
        }
        
        let isVerified = distance <= params.radiusMeters && durationAtLocation >= params.minDurationMinutes
        let confidenceScore = isVerified ? 0.95 : 0.0
        
        return VerificationResult(
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            verificationTimestamp: Date(),
            sensorData: LocationData(
                latitude: userLocation.coordinate.latitude,
                longitude: userLocation.coordinate.longitude,
                accuracy: userLocation.horizontalAccuracy,
                timestamp: userLocation.timestamp,
                durationAtLocation: durationAtLocation
            ),
            notes: isVerified ? "Location challenge completed successfully" : "Location challenge not met"
        )
    }
    
    // MARK: - Motion Verification
    private func verifyMotionChallenge(_ challenge: Challenge, user: User) -> VerificationResult {
        guard let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(MotionChallengeParams.self, from: paramsData) else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Invalid motion challenge parameters"
            )
        }
        
        let pedometerData = motionManager.getStepsForDate(Date())
        
        // Check time window if specified
        if let timeWindow = params.timeWindow {
            let currentHour = Calendar.current.component(.hour, from: Date())
            switch timeWindow {
            case "morning":
                guard currentHour < 8 else {
                    return VerificationResult(
                        isVerified: false,
                        confidenceScore: 0.0,
                        verificationTimestamp: Date(),
                        sensorData: MotionData(
                            stepCount: pedometerData.stepCount,
                            distance: pedometerData.distance,
                            activityType: params.activityType,
                            timestamp: Date()
                        ),
                        notes: "Outside morning time window"
                    )
                }
            case "evening":
                guard currentHour >= 18 else {
                    return VerificationResult(
                        isVerified: false,
                        confidenceScore: 0.0,
                        verificationTimestamp: Date(),
                        sensorData: MotionData(
                            stepCount: pedometerData.stepCount,
                            distance: pedometerData.distance,
                            activityType: params.activityType,
                            timestamp: Date()
                        ),
                        notes: "Outside evening time window"
                    )
                }
            default:
                break
            }
        }
        
        let isVerified = pedometerData.stepCount >= params.minSteps
        let confidenceScore = isVerified ? 0.9 : 0.0
        
        return VerificationResult(
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            verificationTimestamp: Date(),
            sensorData: MotionData(
                stepCount: pedometerData.stepCount,
                distance: pedometerData.distance,
                activityType: params.activityType,
                timestamp: Date()
            ),
            notes: isVerified ? "Motion challenge completed successfully" : "Step count insufficient"
        )
    }
    
    // MARK: - Health Verification
    private func verifyHealthChallenge(_ challenge: Challenge, user: User) -> VerificationResult {
        // This will be implemented when we add HealthKit integration
        return VerificationResult(
            isVerified: false,
            confidenceScore: 0.0,
            verificationTimestamp: Date(),
            sensorData: nil,
            notes: "Health verification not yet implemented"
        )
    }
    
    // MARK: - Screen Time Verification
    private func verifyScreenTimeChallenge(_ challenge: Challenge, user: User) -> VerificationResult {
        // Check if DeviceActivity entitlement is available
        guard DeviceActivityManager.isEntitlementAvailable else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Screen Time API not available - use fallback method"
            )
        }
        
        guard let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(ScreenTimeChallengeParams.self, from: paramsData) else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Invalid screen time challenge parameters"
            )
        }
        
        let screenTimeData = DeviceActivityManager.shared.getDailyUsage()
        let isVerified = screenTimeData.totalHours <= params.maxHours
        let confidenceScore = isVerified ? 0.85 : 0.0
        
        return VerificationResult(
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            verificationTimestamp: Date(),
            sensorData: nil,
            notes: isVerified ? "Screen time challenge completed successfully" : "Screen time limit exceeded"
        )
    }
    
    // MARK: - Camera Verification
    private func verifyCameraChallenge(_ challenge: Challenge, user: User) -> VerificationResult {
        guard let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(CameraChallengeParams.self, from: paramsData) else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Invalid camera challenge parameters"
            )
        }
        
        // Implement liveness detection
        let capturedFrames = cameraManager.captureLivenessFrames(count: Verify.cameraLivenessFrames)
        
        // Hash frames for verification (no storage)
        let frameHashes = capturedFrames.map { frame in
            frame.sha256Hash()
        }
        
        // Verify liveness (simplified - in production, use ML)
        let isVerified = frameHashes.count == Verify.cameraLivenessFrames
        let confidenceScore = isVerified ? 0.8 : 0.0
        
        return VerificationResult(
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            verificationTimestamp: Date(),
            sensorData: CameraData(
                frameHashes: frameHashes,
                livenessScore: isVerified ? 0.8 : 0.0,
                duration: Double(params.durationSeconds),
                timestamp: Date()
            ),
            notes: isVerified ? "Camera challenge completed successfully" : "Camera verification failed"
        )
    }
    
    // MARK: - Helper Methods
    private func isMotionLocationMismatch() -> Bool {
        let isStationary = locationManager.isStationary
        let isMoving = motionManager.isActivelyMoving
        
        // If GPS says stationary but motion says moving for extended period
        return isStationary && isMoving && 
               motionManager.motionDuration > Verify.motionLocationMismatchMinutes
    }
    
    private func getLastGeofenceCredit(_ location: CLLocation) -> Date? {
        // This will query Core Data for the last geofence credit at this location
        // Implementation will be added when we have the full data model
        return nil
    }
}

// MARK: - Manager Classes (Now using actual implementations)
// LocationManager and MotionManager are now implemented in separate files
// HealthManager, CameraManager, and DeviceActivityManager remain as placeholders
// until Phase 2 implementation

class HealthManager {
    static let shared = HealthManager()
}

class CameraManager {
    static let shared = CameraManager()
    
    func captureLivenessFrames(count: Int) -> [UIImage] {
        // Implementation will be added in Phase 2
        return []
    }
}

class DeviceActivityManager {
    static var isEntitlementAvailable: Bool {
        // Check if DeviceActivity entitlement is available
        return false
    }
    
    static let shared = DeviceActivityManager()
    
    func getDailyUsage() -> (totalHours: Double) {
        // Implementation will be added in Phase 2
        return (0.0)
    }
}

// MARK: - Extensions
extension UIImage {
    func sha256Hash() -> String {
        // Implementation will be added
        return "placeholder_hash"
    }
}
