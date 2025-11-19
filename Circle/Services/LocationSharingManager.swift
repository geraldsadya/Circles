//
//  LocationSharingManager.swift
//  Circle
//
//  Real-time location sharing via CloudKit
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationSharingManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationSharingManager()
    
    @Published var isSharing = false
    @Published var friendsLocations: [String: CLLocationCoordinate2D] = [:]
    @Published var lastUpdate: Date?
    
    private let locationManager = CLLocationManager()
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    deinit {
        stopSharing()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    // MARK: - Start Sharing
    func startSharing() {
        print("📍 Starting location sharing")
        
        guard !isSharing else {
            print("ℹ️ Location sharing already active")
            return
        }
        
        // Request permissions
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            isSharing = true
            startPeriodicUpdates()
            print("✅ Location sharing started")
        case .denied, .restricted:
            print("⚠️ Location permission denied or restricted")
        @unknown default:
            print("⚠️ Unknown authorization status")
        }
    }
    
    // MARK: - Stop Sharing
    func stopSharing() {
        print("🛑 Stopping location sharing")
        
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
        isSharing = false
    }
    
    // MARK: - Periodic Updates
    private func startPeriodicUpdates() {
        // Upload location every 15 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.uploadCurrentLocation()
                await self?.fetchFriendsLocations()
            }
        }
        
        // Immediate first update
        Task {
            await uploadCurrentLocation()
            await fetchFriendsLocations()
        }
    }
    
    // MARK: - Upload Location
    private func uploadCurrentLocation() async {
        guard let location = locationManager.location else {
            print("⚠️ No current location available")
            return
        }
        
        guard let userProfile = UserProfileManager.shared.currentUserProfile else {
            print("⚠️ No user profile to update location")
            return
        }
        
        do {
            try await UserProfileManager.shared.updateLocation(location.coordinate)
            lastUpdate = Date()
            print("📍 Location uploaded: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } catch {
            print("❌ Failed to upload location: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fetch Friends Locations
    func fetchFriendsLocations() async {
        let friends = FriendManager.shared.friends
        
        guard !friends.isEmpty else {
            print("ℹ️ No friends to fetch locations for")
            return
        }
        
        print("📍 Fetching locations for \(friends.count) friends")
        
        var locations: [String: CLLocationCoordinate2D] = [:]
        
        for friend in friends {
            if let location = friend.location {
                // Only show friends who updated in last 5 minutes
                if let lastUpdate = friend.lastLocationUpdate,
                   Date().timeIntervalSince(lastUpdate) < 300 {
                    locations[friend.recordName] = location
                    print("✅ Friend \(friend.displayName) location: \(location.latitude), \(location.longitude)")
                } else {
                    print("⏰ Friend \(friend.displayName) location is stale")
                }
            } else {
                print("⚠️ Friend \(friend.displayName) has no location")
            }
        }
        
        friendsLocations = locations
        print("📍 Updated \(locations.count) friend locations")
    }
    
    // MARK: - CLLocationManagerDelegate
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        Task { @MainActor in
            await uploadCurrentLocation()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 Location authorization changed: \(status.rawValue)")
        
        Task { @MainActor in
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.startSharing()
            }
        }
    }
    
    nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("⏸️ Location updates paused")
    }
    
    nonisolated func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("▶️ Location updates resumed")
    }
}

