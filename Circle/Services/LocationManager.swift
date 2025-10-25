//
//  LocationManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import Combine
import CoreData

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTrackingHangouts: Bool = false
    @Published var isStationary: Bool = false
    @Published var nearbyFriends: [User] = []
    @Published var activeHangoutSessions: [HangoutSession] = []
    
    private let locationManager = CLLocationManager()
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Hangout detection state
    private var hangoutCandidates: [String: HangoutCandidate] = [:]
    private var hangoutTimers: [String: Timer] = [:]
    private var locationUpdateTimer: Timer?
    private var lastLocationUpdate: Date = Date()
    
    // Background location tracking
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var isInBackground: Bool = false
    
    override init() {
        super.init()
        setupLocationManager()
        setupNotifications()
        setupBackgroundLocationTracking()
    }
    
    deinit {
        stopAllTracking()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
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
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundLocationTracking() {
        // Use Significant Location Change for battery efficiency
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Start location updates when needed
        if authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
    
    // MARK: - Permission Management
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Show rationale for always location
            requestAlwaysLocationPermission()
        case .authorizedAlways:
            startLocationUpdates()
        default:
            break
        }
    }
    
    private func requestAlwaysLocationPermission() {
        // This would show a custom UI explaining why always location is needed
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Location Tracking
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            return
        }
        
        locationManager.startUpdatingLocation()
        startHangoutDetection()
        
        // Start location update timer for monitoring
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkLocationUpdateHealth()
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        stopHangoutDetection()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func checkLocationUpdateHealth() {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastLocationUpdate)
        
        // If no location update in 5 minutes, something might be wrong
        if timeSinceLastUpdate > 300 {
            print("⚠️ No location update in \(timeSinceLastUpdate) seconds")
            
            // Try to restart location services
            if authorizationStatus == .authorizedAlways {
                locationManager.stopUpdatingLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.locationManager.startUpdatingLocation()
                }
            }
        }
    }
    
    // MARK: - Hangout Detection
    func startHangoutDetection() {
        guard !isTrackingHangouts else { return }
        
        isTrackingHangouts = true
        loadNearbyFriends()
        
        // Start hangout detection timer
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.detectHangoutCandidates()
        }
    }
    
    func stopHangoutDetection() {
        isTrackingHangouts = false
        
        // End all active hangout sessions
        for session in activeHangoutSessions {
            endHangoutSession(session)
        }
        
        // Clear candidates
        hangoutCandidates.removeAll()
        hangoutTimers.values.forEach { $0.invalidate() }
        hangoutTimers.removeAll()
    }
    
    private func loadNearbyFriends() {
        // Load friends from Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try context.fetch(request)
            nearbyFriends = users.filter { $0.id != getCurrentUser()?.id }
        } catch {
            print("Error loading nearby friends: \(error)")
        }
    }
    
    private func detectHangoutCandidates() {
        guard let currentLocation = currentLocation else { return }
        
        for friend in nearbyFriends {
            // In a real implementation, you'd get friend locations from CloudKit
            // For now, we'll simulate proximity detection
            let friendLocation = getSimulatedFriendLocation(for: friend)
            let distance = currentLocation.distance(from: friendLocation)
            
            if distance <= Verify.hangoutProximity {
                handleFriendProximity(friend: friend, distance: distance)
            } else {
                handleFriendDistance(friend: friend, distance: distance)
            }
        }
    }
    
    private func handleFriendProximity(friend: User, distance: CLLocationDistance) {
        let friendID = friend.id.uuidString
        
        if let candidate = hangoutCandidates[friendID] {
            // Update existing candidate
            candidate.updateProximity(distance: distance, timestamp: Date())
            
            // Check if we should promote to active hangout
            if candidate.shouldPromoteToActive() {
                promoteCandidateToHangout(candidate)
            }
        } else {
            // Create new candidate
            let candidate = HangoutCandidate(
                friend: friend,
                startTime: Date(),
                lastProximityTime: Date(),
                minDistance: distance
            )
            hangoutCandidates[friendID] = candidate
        }
    }
    
    private func handleFriendDistance(friend: User, distance: CLLocationDistance) {
        let friendID = friend.id.uuidString
        
        if let candidate = hangoutCandidates[friendID] {
            // Check if we should end the candidate
            if candidate.shouldEndCandidate() {
                hangoutCandidates.removeValue(forKey: friendID)
                hangoutTimers[friendID]?.invalidate()
                hangoutTimers.removeValue(forKey: friendID)
            }
        }
    }
    
    private func promoteCandidateToHangout(_ candidate: HangoutCandidate) {
        let hangoutSession = HangoutSession(context: persistenceController.container.viewContext)
        hangoutSession.id = UUID()
        hangoutSession.startTime = candidate.startTime
        hangoutSession.isActive = true
        hangoutSession.participants = NSSet(objects: getCurrentUser()!, candidate.friend)
        
        // Save to Core Data
        do {
            try persistenceController.container.viewContext.save()
            activeHangoutSessions.append(hangoutSession)
            
            // Notify other services
            NotificationCenter.default.post(
                name: .hangoutStarted,
                object: nil,
                userInfo: ["hangoutSession": hangoutSession]
            )
            
            print("🎉 Hangout started with \(candidate.friend.displayName)")
        } catch {
            print("Error creating hangout session: \(error)")
        }
    }
    
    func endHangoutSession(_ session: HangoutSession) {
        session.endTime = Date()
        session.isActive = false
        session.duration = session.endTime!.timeIntervalSince(session.startTime) / 60 // minutes
        
        // Award points
        let pointsPerMinute = Verify.hangoutPtsPer5 / 5 // 1 point per minute
        let totalPoints = Int32(session.duration * pointsPerMinute)
        session.pointsAwarded = min(totalPoints, Verify.dailyHangoutCapPts)
        
        // Save to Core Data
        do {
            try persistenceController.container.viewContext.save()
            
            // Remove from active sessions
            activeHangoutSessions.removeAll { $0.id == session.id }
            
            // Notify other services
            NotificationCenter.default.post(
                name: .hangoutEnded,
                object: nil,
                userInfo: ["hangoutSession": session]
            )
            
            print("🏁 Hangout ended with duration: \(session.duration) minutes")
        } catch {
            print("Error ending hangout session: \(error)")
        }
    }
    
    // MARK: - Geofence Management
    func createGeofence(at coordinate: CLLocationCoordinate2D, radius: Double, identifier: String) {
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
    }
    
    func removeGeofence(identifier: String) {
        let regions = locationManager.monitoredRegions
        for region in regions {
            if region.identifier == identifier {
                locationManager.stopMonitoring(for: region)
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    func durationAtLocation(_ location: CLLocation) -> Double {
        // This would track how long the user has been at a specific location
        // Implementation would involve storing location history and calculating duration
        return 0.0
    }
    
    private func getCurrentUser() -> User? {
        // This would get the current authenticated user
        // For now, return nil
        return nil
    }
    
    private func getSimulatedFriendLocation(for friend: User) -> CLLocation {
        // In a real implementation, this would get the friend's actual location from CloudKit
        // For now, simulate a nearby location
        let baseLocation = currentLocation ?? CLLocation(latitude: 37.7749, longitude: -122.4194)
        let randomOffset = Double.random(in: -0.001...0.001)
        
        return CLLocation(
            latitude: baseLocation.coordinate.latitude + randomOffset,
            longitude: baseLocation.coordinate.longitude + randomOffset
        )
    }
    
    private func stopAllTracking() {
        stopLocationUpdates()
        stopHangoutDetection()
        
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - App Lifecycle Handlers
    private func handleAppBecameActive() {
        isInBackground = false
        
        // Resume location updates if needed
        if authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
    
    private func handleAppEnteredBackground() {
        isInBackground = true
        
        // Start background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LocationTracking") {
            self.endBackgroundTask()
        }
        
        // Continue location updates in background
        if authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    private func handleAppWillTerminate() {
        stopAllTracking()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.lastLocationUpdate = Date()
            
            // Check if user is stationary
            self.isStationary = location.speed < 1.0 // Less than 1 m/s
            
            // Post location update notification
            NotificationCenter.default.post(
                name: .locationUpdated,
                object: nil,
                userInfo: ["location": location]
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startLocationUpdates()
            case .denied, .restricted:
                self.stopLocationUpdates()
            default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            NotificationCenter.default.post(
                name: .geofenceEntered,
                object: nil,
                userInfo: ["region": circularRegion]
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            NotificationCenter.default.post(
                name: .geofenceExited,
                object: nil,
                userInfo: ["region": circularRegion]
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        
        // Handle specific errors
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                stopLocationUpdates()
            case .locationUnknown:
                // Retry location update
                break
            default:
                break
            }
        }
    }
}

// MARK: - Supporting Types
class HangoutCandidate {
    let friend: User
    let startTime: Date
    var lastProximityTime: Date
    var minDistance: CLLocationDistance
    
    init(friend: User, startTime: Date, lastProximityTime: Date, minDistance: CLLocationDistance) {
        self.friend = friend
        self.startTime = startTime
        self.lastProximityTime = lastProximityTime
        self.minDistance = minDistance
    }
    
    func updateProximity(distance: CLLocationDistance, timestamp: Date) {
        lastProximityTime = timestamp
        minDistance = min(minDistance, distance)
    }
    
    func shouldPromoteToActive() -> Bool {
        let timeInProximity = lastProximityTime.timeIntervalSince(startTime)
        return timeInProximity >= Verify.hangoutPromote && minDistance <= Verify.hangoutProximity
    }
    
    func shouldEndCandidate() -> Bool {
        let timeSinceLastProximity = Date().timeIntervalSince(lastProximityTime)
        return timeSinceLastProximity > Verify.hangoutStale
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let locationUpdated = Notification.Name("locationUpdated")
    static let hangoutStarted = Notification.Name("hangoutStarted")
    static let hangoutEnded = Notification.Name("hangoutEnded")
    static let geofenceEntered = Notification.Name("geofenceEntered")
    static let geofenceExited = Notification.Name("geofenceExited")
}
