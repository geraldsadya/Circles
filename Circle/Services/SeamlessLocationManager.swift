//
//  SeamlessLocationManager.swift
//  Circle
//
//  Automatic location sharing with contacts (Find My style)
//

import Foundation
import CoreLocation
import CloudKit
import Combine

@MainActor
class SeamlessLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = SeamlessLocationManager()
    
    @Published var friendsLocations: [String: FriendLocation] = [:]
    @Published var isSharing = false
    @Published var lastUpdate: Date?
    
    private let locationManager = CLLocationManager()
    private let container = CKContainer(identifier: "iCloud.com.circle.app")
    private var updateTimer: Timer?
    private var myLocationRecord: CKRecord?
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    deinit {
        stopSharing()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    // MARK: - Auto Start (like Find My)
    func autoStart() {
        print("🚀 Auto-starting location sharing...")
        
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startSharing()
        case .denied, .restricted:
            print("⚠️ Location permission denied")
        @unknown default:
            print("⚠️ Unknown authorization status")
        }
    }
    
    // MARK: - Start Sharing
    private func startSharing() {
        print("📍 Starting automatic location sharing...")
        
        guard !isSharing else { return }
        
        locationManager.startUpdatingLocation()
        isSharing = true
        
        // Start periodic updates (every 15 seconds)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncLocations()
            }
        }
        
        // Immediate first sync
        Task {
            await syncLocations()
        }
        
        print("✅ Location sharing started")
    }
    
    // MARK: - Stop Sharing
    func stopSharing() {
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
        isSharing = false
    }
    
    // MARK: - Sync Locations
    private func syncLocations() async {
        // Upload my location
        await uploadMyLocation()
        
        // Download friends' locations
        await downloadFriendsLocations()
    }
    
    // MARK: - Upload My Location
    private func uploadMyLocation() async {
        guard let location = locationManager.location else {
            print("⚠️ No current location")
            return
        }
        
        guard let userID = SeamlessAuthManager.shared.currentUserID else {
            print("⚠️ Not signed in")
            return
        }
        
        print("📤 Uploading location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        do {
            let privateDB = container.privateCloudDatabase
            
            // Get or create location record
            let recordID = CKRecord.ID(recordName: "Location_\(userID)")
            
            let record: CKRecord
            if let existingRecord = myLocationRecord {
                record = existingRecord
            } else {
                // Try to fetch existing, or create new
                do {
                    record = try await privateDB.record(for: recordID)
                    myLocationRecord = record
                } catch {
                    record = CKRecord(recordType: "UserLocation", recordID: recordID)
                    myLocationRecord = record
                }
            }
            
            // Update location
            record["latitude"] = location.coordinate.latitude
            record["longitude"] = location.coordinate.longitude
            record["timestamp"] = Date()
            record["accuracy"] = location.horizontalAccuracy
            record["displayName"] = SeamlessAuthManager.shared.displayName ?? "Unknown"
            
            // Save to CloudKit
            let savedRecord = try await privateDB.save(record)
            myLocationRecord = savedRecord
            lastUpdate = Date()
            
            print("✅ Location uploaded successfully")
            
        } catch {
            print("❌ Failed to upload location: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Download Friends' Locations
    private func downloadFriendsLocations() async {
        let friends = ContactDiscoveryManager.shared.discoveredFriends
        
        guard !friends.isEmpty else {
            print("ℹ️ No friends to fetch locations for")
            return
        }
        
        print("📥 Downloading \(friends.count) friends' locations...")
        
        var locations: [String: FriendLocation] = [:]
        
        for friend in friends {
            do {
                let recordID = CKRecord.ID(recordName: "Location_\(friend.userID)")
                let record = try await container.privateCloudDatabase.record(for: recordID)
                
                if let lat = record["latitude"] as? Double,
                   let lon = record["longitude"] as? Double,
                   let timestamp = record["timestamp"] as? Date {
                    
                    // Only show if updated in last 5 minutes
                    if Date().timeIntervalSince(timestamp) < 300 {
                        let location = FriendLocation(
                            userID: friend.userID,
                            displayName: friend.contactName,
                            latitude: lat,
                            longitude: lon,
                            timestamp: timestamp
                        )
                        
                        locations[friend.userID] = location
                        print("✅ Got location for \(friend.contactName)")
                    } else {
                        print("⏰ \(friend.contactName)'s location is stale")
                    }
                }
            } catch {
                print("⚠️ Couldn't get location for \(friend.contactName): \(error.localizedDescription)")
            }
        }
        
        friendsLocations = locations
        print("✅ Updated \(locations.count) friend locations")
    }
    
    // MARK: - CLLocationManagerDelegate
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        Task { @MainActor in
            await uploadMyLocation()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 Authorization changed: \(status.rawValue)")
        
        Task { @MainActor in
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.startSharing()
            }
        }
    }
}

// MARK: - Friend Location Model
struct FriendLocation: Identifiable {
    let id = UUID()
    let userID: String
    let displayName: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 300 // 5 minutes
    }
}

