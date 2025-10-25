//
//  LocationChallengeVerifier.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import CoreData
import Combine

@MainActor
class LocationChallengeVerifier: ObservableObject {
    static let shared = LocationChallengeVerifier()
    
    @Published var isVerifying = false
    @Published var verificationProgress: Double = 0.0
    @Published var currentVerification: LocationVerification?
    
    private let locationManager = LocationManager.shared
    private let geofenceManager = GeofenceManager.shared
    private let persistenceController = PersistenceController.shared
    
    private var verificationTimers: [UUID: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        stopAllVerifications()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGeofenceEntered),
            name: .geofenceEntered,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGeofenceExited),
            name: .geofenceExited,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationUpdate),
            name: .locationUpdated,
            object: nil
        )
    }
    
    // MARK: - Location Challenge Verification
    func verifyLocationChallenge(_ challenge: Challenge, for user: User) async -> VerificationResult {
        guard challenge.verificationMethod == VerificationMethod.location.rawValue,
              let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(LocationChallengeParams.self, from: paramsData) else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "Invalid location challenge parameters"
            )
        }
        
        isVerifying = true
        verificationProgress = 0.0
        
        // Create verification record
        let verification = LocationVerification(
            id: UUID(),
            challengeID: challenge.id,
            userID: user.id,
            targetLocation: params.targetLocation,
            radiusMeters: params.radiusMeters,
            minDurationMinutes: params.minDurationMinutes,
            startTime: Date(),
            endTime: nil,
            isCompleted: false,
            confidenceScore: 0.0
        )
        
        currentVerification = verification
        
        // Start verification process
        let result = await performLocationVerification(verification: verification, params: params)
        
        isVerifying = false
        currentVerification = nil
        
        return result
    }
    
    private func performLocationVerification(
        verification: LocationVerification,
        params: LocationChallengeParams
    ) async -> VerificationResult {
        // Check current location
        guard let currentLocation = locationManager.currentLocation else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: nil,
                notes: "No location data available"
            )
        }
        
        let targetLocation = CLLocation(
            latitude: params.targetLocation.latitude,
            longitude: params.targetLocation.longitude
        )
        
        let distance = currentLocation.distance(from: targetLocation)
        
        // Check if we're within the geofence
        if distance <= params.radiusMeters {
            // Start duration tracking
            return await trackDurationAtLocation(
                verification: verification,
                params: params,
                currentLocation: currentLocation
            )
        } else {
            return VerificationResult(
                isVerified: false,
                confidenceScore: 0.0,
                verificationTimestamp: Date(),
                sensorData: LocationData(
                    latitude: currentLocation.coordinate.latitude,
                    longitude: currentLocation.coordinate.longitude,
                    accuracy: currentLocation.horizontalAccuracy,
                    timestamp: currentLocation.timestamp,
                    durationAtLocation: 0.0
                ),
                notes: "Not within geofence radius"
            )
        }
    }
    
    private func trackDurationAtLocation(
        verification: LocationVerification,
        params: LocationChallengeParams,
        currentLocation: CLLocation
    ) async -> VerificationResult {
        let startTime = Date()
        var duration: TimeInterval = 0
        var lastLocation = currentLocation
        var isStillInGeofence = true
        
        // Create timer to track duration
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { return }
                
                duration = Date().timeIntervalSince(startTime)
                verificationProgress = min(duration / (params.minDurationMinutes * 60), 1.0)
                
                // Check if still in geofence
                if let currentLoc = self.locationManager.currentLocation {
                    let distance = currentLoc.distance(from: CLLocation(
                        latitude: params.targetLocation.latitude,
                        longitude: params.targetLocation.longitude
                    ))
                    
                    if distance > params.radiusMeters {
                        isStillInGeofence = false
                        timer.invalidate()
                    }
                    
                    lastLocation = currentLoc
                }
                
                // Check if minimum duration reached
                if duration >= params.minDurationMinutes * 60 {
                    timer.invalidate()
                }
            }
        }
        
        verificationTimers[verification.id] = timer
        
        // Wait for verification to complete or fail
        while timer.isValid && isStillInGeofence {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        timer.invalidate()
        verificationTimers.removeValue(forKey: verification.id)
        
        // Determine result
        let isVerified = duration >= params.minDurationMinutes * 60 && isStillInGeofence
        let confidenceScore = calculateConfidenceScore(
            duration: duration,
            minDuration: params.minDurationMinutes,
            locationAccuracy: lastLocation.horizontalAccuracy,
            isInGeofence: isStillInGeofence
        )
        
        return VerificationResult(
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            verificationTimestamp: Date(),
            sensorData: LocationData(
                latitude: lastLocation.coordinate.latitude,
                longitude: lastLocation.coordinate.longitude,
                accuracy: lastLocation.horizontalAccuracy,
                timestamp: lastLocation.timestamp,
                durationAtLocation: duration / 60.0 // Convert to minutes
            ),
            notes: isVerified ? "Location challenge completed successfully" : "Insufficient duration at location"
        )
    }
    
    // MARK: - Geofence-based Verification
    func startGeofenceVerification(for challenge: Challenge) {
        guard challenge.verificationMethod == VerificationMethod.location.rawValue,
              let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(LocationChallengeParams.self, from: paramsData) else {
            return
        }
        
        // Create geofence for this challenge
        let identifier = "challenge_\(challenge.id.uuidString)"
        geofenceManager.createGeofence(
            name: challenge.title ?? "Challenge Location",
            coordinate: params.targetLocation,
            radius: params.radiusMeters,
            minDuration: params.minDurationMinutes
        )
        
        // Start monitoring
        startMonitoringGeofence(identifier: identifier, challenge: challenge)
    }
    
    private func startMonitoringGeofence(identifier: String, challenge: Challenge) {
        // This will be handled by the geofence manager notifications
        // The actual verification will happen in handleGeofenceChallengeCompleted
    }
    
    // MARK: - Notification Handlers
    @objc private func handleGeofenceEntered(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let region = userInfo["region"] as? CLCircularRegion else {
            return
        }
        
        let identifier = region.identifier
        
        // Check if this is a challenge geofence
        if identifier.hasPrefix("challenge_") {
            let challengeID = identifier.replacingOccurrences(of: "challenge_", with: "")
            guard let uuid = UUID(uuidString: challengeID) else { return }
            
            // Start verification timer
            startVerificationTimer(for: uuid, region: region)
        }
    }
    
    @objc private func handleGeofenceExited(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let region = userInfo["region"] as? CLCircularRegion else {
            return
        }
        
        let identifier = region.identifier
        
        // Check if this is a challenge geofence
        if identifier.hasPrefix("challenge_") {
            let challengeID = identifier.replacingOccurrences(of: "challenge_", with: "")
            guard let uuid = UUID(uuidString: challengeID) else { return }
            
            // Stop verification timer
            stopVerificationTimer(for: uuid)
        }
    }
    
    @objc private func handleLocationUpdate(_ notification: Notification) {
        // Update current verification progress if active
        if let verification = currentVerification {
            updateVerificationProgress(verification)
        }
    }
    
    // MARK: - Timer Management
    private func startVerificationTimer(for challengeID: UUID, region: CLCircularRegion) {
        // Find the challenge
        let request: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", challengeID as CVarArg)
        
        do {
            let challenges = try persistenceController.container.viewContext.fetch(request)
            guard let challenge = challenges.first else { return }
            
            // Start timer for minimum duration
            let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    await self?.checkVerificationProgress(challenge: challenge, region: region)
                }
            }
            
            verificationTimers[challengeID] = timer
            
        } catch {
            print("Error starting verification timer: \(error)")
        }
    }
    
    private func stopVerificationTimer(for challengeID: UUID) {
        verificationTimers[challengeID]?.invalidate()
        verificationTimers.removeValue(forKey: challengeID)
    }
    
    private func stopAllVerifications() {
        verificationTimers.values.forEach { $0.invalidate() }
        verificationTimers.removeAll()
    }
    
    private func checkVerificationProgress(challenge: Challenge, region: CLCircularRegion) async {
        guard let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(LocationChallengeParams.self, from: paramsData) else {
            return
        }
        
        // Check if still in geofence
        guard let currentLocation = locationManager.currentLocation else { return }
        
        let targetLocation = CLLocation(
            latitude: params.targetLocation.latitude,
            longitude: params.targetLocation.longitude
        )
        
        let distance = currentLocation.distance(from: targetLocation)
        
        if distance <= params.radiusMeters {
            // Check if minimum duration has been reached
            let duration = locationManager.durationAtLocation(targetLocation)
            
            if duration >= params.minDurationMinutes {
                // Challenge completed!
                await completeLocationChallenge(challenge: challenge, location: currentLocation)
                stopVerificationTimer(for: challenge.id)
            }
        } else {
            // Left geofence - stop timer
            stopVerificationTimer(for: challenge.id)
        }
    }
    
    private func completeLocationChallenge(challenge: Challenge, location: CLLocation) async {
        // This will be handled by the ChallengeEngine
        // We just need to notify that the challenge is complete
        
        NotificationCenter.default.post(
            name: .locationChallengeCompleted,
            object: nil,
            userInfo: [
                "challenge": challenge,
                "location": location
            ]
        )
    }
    
    // MARK: - Progress Updates
    private func updateVerificationProgress(_ verification: LocationVerification) {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        let targetLocation = CLLocation(
            latitude: verification.targetLocation.latitude,
            longitude: verification.targetLocation.longitude
        )
        
        let distance = currentLocation.distance(from: targetLocation)
        let duration = Date().timeIntervalSince(verification.startTime) / 60.0 // minutes
        
        if distance <= verification.radiusMeters {
            verificationProgress = min(duration / verification.minDurationMinutes, 1.0)
        } else {
            verificationProgress = 0.0
        }
    }
    
    // MARK: - Confidence Score Calculation
    private func calculateConfidenceScore(
        duration: TimeInterval,
        minDuration: Double,
        locationAccuracy: Double,
        isInGeofence: Bool
    ) -> Double {
        var score: Double = 0.0
        
        // Duration factor (0.0 - 1.0)
        let durationFactor = min(duration / (minDuration * 60), 1.0)
        score += durationFactor * 0.6 // 60% weight
        
        // Location accuracy factor (0.0 - 1.0)
        let accuracyFactor = max(0, 1.0 - (locationAccuracy / Verify.accThreshold))
        score += accuracyFactor * 0.3 // 30% weight
        
        // Geofence factor (0.0 or 1.0)
        let geofenceFactor = isInGeofence ? 1.0 : 0.0
        score += geofenceFactor * 0.1 // 10% weight
        
        return min(score, 1.0)
    }
    
    // MARK: - Validation
    func validateLocationChallenge(_ challenge: Challenge) -> ValidationResult {
        guard challenge.verificationMethod == VerificationMethod.location.rawValue else {
            return ValidationResult(
                isValid: false,
                errors: ["Challenge is not a location challenge"]
            )
        }
        
        guard let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(LocationChallengeParams.self, from: paramsData) else {
            return ValidationResult(
                isValid: false,
                errors: ["Invalid location challenge parameters"]
            )
        }
        
        var errors: [String] = []
        
        // Validate radius
        if params.radiusMeters <= 0 {
            errors.append("Geofence radius must be greater than 0")
        }
        
        if params.radiusMeters > 1000 {
            errors.append("Geofence radius cannot exceed 1000 meters")
        }
        
        // Validate duration
        if params.minDurationMinutes <= 0 {
            errors.append("Minimum duration must be greater than 0")
        }
        
        if params.minDurationMinutes > 480 { // 8 hours
            errors.append("Minimum duration cannot exceed 8 hours")
        }
        
        // Validate location
        let latitude = params.targetLocation.latitude
        let longitude = params.targetLocation.longitude
        
        if abs(latitude) > 90 {
            errors.append("Invalid latitude")
        }
        
        if abs(longitude) > 180 {
            errors.append("Invalid longitude")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Analytics
    func getLocationChallengeStats(for user: User) -> LocationChallengeStats {
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(
            format: "user == %@ AND verificationMethod == %@",
            user, VerificationMethod.location.rawValue
        )
        
        do {
            let proofs = try persistenceController.container.viewContext.fetch(request)
            let completedCount = proofs.filter { $0.isVerified }.count
            let totalCount = proofs.count
            let successRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
            
            return LocationChallengeStats(
                totalChallenges: totalCount,
                completedChallenges: completedCount,
                successRate: successRate,
                averageConfidenceScore: proofs.compactMap { $0.confidenceScore }.reduce(0, +) / Double(proofs.count)
            )
        } catch {
            print("Error getting location challenge stats: \(error)")
            return LocationChallengeStats(
                totalChallenges: 0,
                completedChallenges: 0,
                successRate: 0.0,
                averageConfidenceScore: 0.0
            )
        }
    }
}

// MARK: - Supporting Types
struct LocationVerification {
    let id: UUID
    let challengeID: UUID
    let userID: UUID
    let targetLocation: CLLocationCoordinate2D
    let radiusMeters: Double
    let minDurationMinutes: Double
    let startTime: Date
    var endTime: Date?
    var isCompleted: Bool
    var confidenceScore: Double
}

struct LocationChallengeStats {
    let totalChallenges: Int
    let completedChallenges: Int
    let successRate: Double
    let averageConfidenceScore: Double
}

// MARK: - Notifications
extension Notification.Name {
    static let locationUpdated = Notification.Name("locationUpdated")
    static let locationChallengeCompleted = Notification.Name("locationChallengeCompleted")
}
