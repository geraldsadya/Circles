//
//  GeofenceManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class GeofenceManager: ObservableObject {
    static let shared = GeofenceManager()
    
    @Published var activeGeofences: [String: GeofenceData] = [:]
    @Published var geofenceEvents: [GeofenceEvent] = []
    
    private let locationManager = LocationManager.shared
    private var geofenceTimers: [String: Timer] = [:]
    private var geofenceCooldowns: [String: Date] = [:]
    
    init() {
        setupNotifications()
    }
    
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
    }
    
    // MARK: - Geofence Creation
    func createGeofence(
        name: String,
        coordinate: CLLocationCoordinate2D,
        radius: Double = Verify.geofenceRadius,
        minDuration: Double = Verify.minDwellGym
    ) -> String {
        let identifier = "\(name)_\(UUID().uuidString)"
        
        let geofenceData = GeofenceData(
            id: identifier,
            name: name,
            coordinate: coordinate,
            radius: radius,
            minDuration: minDuration,
            createdAt: Date(),
            isActive: true
        )
        
        activeGeofences[identifier] = geofenceData
        
        // Create Core Location region
        locationManager.createGeofence(at: coordinate, radius: radius, identifier: identifier)
        
        return identifier
    }
    
    func removeGeofence(identifier: String) {
        activeGeofences.removeValue(forKey: identifier)
        geofenceTimers[identifier]?.invalidate()
        geofenceTimers.removeValue(forKey: identifier)
        geofenceCooldowns.removeValue(forKey: identifier)
        
        locationManager.removeGeofence(identifier: identifier)
    }
    
    // MARK: - Geofence Events
    @objc private func handleGeofenceEntered(_ notification: Notification) {
        guard let region = notification.userInfo?["region"] as? CLCircularRegion else { return }
        
        let identifier = region.identifier
        guard let geofenceData = activeGeofences[identifier] else { return }
        
        // Check cooldown period
        if let lastCredit = geofenceCooldowns[identifier] {
            let hoursSinceLastCredit = Date().timeIntervalSince(lastCredit) / 3600
            if hoursSinceLastCredit < Verify.geofenceCooldownHours {
                print("Geofence \(identifier) is in cooldown period")
                return
            }
        }
        
        // Start timer for minimum duration
        let timer = Timer.scheduledTimer(withTimeInterval: geofenceData.minDuration * 60, repeats: false) { [weak self] _ in
            self?.handleGeofenceDurationMet(identifier: identifier)
        }
        
        geofenceTimers[identifier] = timer
        
        // Log entry event
        let event = GeofenceEvent(
            id: UUID(),
            geofenceID: identifier,
            type: .entered,
            timestamp: Date(),
            location: locationManager.currentLocation
        )
        
        geofenceEvents.append(event)
        
        print("Entered geofence: \(geofenceData.name)")
    }
    
    @objc private func handleGeofenceExited(_ notification: Notification) {
        guard let region = notification.userInfo?["region"] as? CLCircularRegion else { return }
        
        let identifier = region.identifier
        guard let geofenceData = activeGeofences[identifier] else { return }
        
        // Cancel timer if still running
        geofenceTimers[identifier]?.invalidate()
        geofenceTimers.removeValue(forKey: identifier)
        
        // Log exit event
        let event = GeofenceEvent(
            id: UUID(),
            geofenceID: identifier,
            type: .exited,
            timestamp: Date(),
            location: locationManager.currentLocation
        )
        
        geofenceEvents.append(event)
        
        print("Exited geofence: \(geofenceData.name)")
    }
    
    private func handleGeofenceDurationMet(identifier: String) {
        guard let geofenceData = activeGeofences[identifier] else { return }
        
        // Verify we're still in the geofence
        guard let currentLocation = locationManager.currentLocation else { return }
        
        let distance = currentLocation.distance(from: CLLocation(
            latitude: geofenceData.coordinate.latitude,
            longitude: geofenceData.coordinate.longitude
        ))
        
        guard distance <= geofenceData.radius else {
            print("No longer in geofence \(identifier) - duration requirement not met")
            return
        }
        
        // Check location accuracy
        guard currentLocation.horizontalAccuracy <= Verify.accThreshold else {
            print("Location accuracy insufficient for geofence \(identifier)")
            return
        }
        
        // Success! Geofence challenge completed
        geofenceCooldowns[identifier] = Date()
        
        let event = GeofenceEvent(
            id: UUID(),
            geofenceID: identifier,
            type: .completed,
            timestamp: Date(),
            location: currentLocation
        )
        
        geofenceEvents.append(event)
        
        // Notify challenge verification
        NotificationCenter.default.post(
            name: .geofenceChallengeCompleted,
            object: nil,
            userInfo: [
                "geofenceID": identifier,
                "geofenceData": geofenceData,
                "location": currentLocation
            ]
        )
        
        print("Geofence challenge completed: \(geofenceData.name)")
    }
    
    // MARK: - Challenge Integration
    func createChallengeGeofence(for challenge: Challenge) -> String? {
        guard challenge.verificationMethod == VerificationMethod.location.rawValue,
              let paramsData = challenge.verificationParams,
              let params = try? JSONDecoder().decode(LocationChallengeParams.self, from: paramsData) else {
            return nil
        }
        
        return createGeofence(
            name: challenge.title,
            coordinate: params.targetLocation,
            radius: params.radiusMeters,
            minDuration: params.minDurationMinutes
        )
    }
    
    func removeChallengeGeofence(for challenge: Challenge) {
        // Find geofence by challenge title
        for (identifier, geofenceData) in activeGeofences {
            if geofenceData.name == challenge.title {
                removeGeofence(identifier: identifier)
                break
            }
        }
    }
    
    // MARK: - Analytics
    func getGeofenceStats(for identifier: String) -> GeofenceStats? {
        guard let geofenceData = activeGeofences[identifier] else { return nil }
        
        let events = geofenceEvents.filter { $0.geofenceID == identifier }
        let completedEvents = events.filter { $0.type == .completed }
        
        return GeofenceStats(
            geofenceID: identifier,
            name: geofenceData.name,
            totalVisits: completedEvents.count,
            lastVisit: completedEvents.last?.timestamp,
            averageDuration: calculateAverageDuration(for: events),
            isInCooldown: isInCooldown(identifier: identifier)
        )
    }
    
    private func calculateAverageDuration(for events: [GeofenceEvent]) -> Double {
        var durations: [Double] = []
        
        for i in 0..<events.count {
            if events[i].type == .entered {
                // Find corresponding exit or completion
                for j in (i+1)..<events.count {
                    if events[j].type == .exited || events[j].type == .completed {
                        let duration = events[j].timestamp.timeIntervalSince(events[i].timestamp)
                        durations.append(duration / 60.0) // Convert to minutes
                        break
                    }
                }
            }
        }
        
        return durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
    }
    
    private func isInCooldown(identifier: String) -> Bool {
        guard let lastCredit = geofenceCooldowns[identifier] else { return false }
        let hoursSinceLastCredit = Date().timeIntervalSince(lastCredit) / 3600
        return hoursSinceLastCredit < Verify.geofenceCooldownHours
    }
    
    // MARK: - Cleanup
    func cleanupOldEvents() {
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        geofenceEvents.removeAll { $0.timestamp < cutoffDate }
    }
}

// MARK: - Supporting Types
struct GeofenceData {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let minDuration: Double
    let createdAt: Date
    let isActive: Bool
}

struct GeofenceEvent {
    let id: UUID
    let geofenceID: String
    let type: GeofenceEventType
    let timestamp: Date
    let location: CLLocation?
}

enum GeofenceEventType {
    case entered
    case exited
    case completed
}

struct GeofenceStats {
    let geofenceID: String
    let name: String
    let totalVisits: Int
    let lastVisit: Date?
    let averageDuration: Double
    let isInCooldown: Bool
}

// MARK: - Notifications
extension Notification.Name {
    static let geofenceChallengeCompleted = Notification.Name("geofenceChallengeCompleted")
}
