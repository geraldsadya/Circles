import SwiftUI
import MapKit
import CoreLocation
import Combine
import HealthKit

// MARK: - Service Imports
// In a real Xcode project, these would be imported from the Services folder
// For now, we need to make sure the service classes are accessible

// Import HealthKitManager and MotionManager from Services
// These are defined in Circle/Services/HealthKitManager.swift and Circle/Services/MotionManager.swift

// MARK: - Seamless Auth Manager (stub for compilation)
@MainActor
class SeamlessAuthManager: ObservableObject {
    static let shared = SeamlessAuthManager()
    @Published var isReady = true
    @Published var currentUserID: String? = "default-user"
    @Published var displayName: String? = "User"
    @Published var isSignedIn = true
    
    private init() {}
    
    func checkiCloudStatus() {
        print("🔐 Checking iCloud status...")
        isReady = true
        isSignedIn = true
    }
}

class ContactDiscoveryManager: ObservableObject {
    static let shared = ContactDiscoveryManager()
    @Published var discoveredFriends: [DiscoveredFriend] = []
    @Published var isDiscovering = false
    
    private init() {}
    
    func discoverFriendsFromContacts() async throws {
        print("🔍 Discovering friends from contacts...")
    }
}

struct DiscoveredFriend: Identifiable {
    let id = UUID()
    let userID: String
    let contactName: String
}

@MainActor
class SeamlessLocationManager: NSObject, ObservableObject {
    static let shared = SeamlessLocationManager()
    @Published var friendsLocations: [String: FriendLocation] = [:]
    @Published var isSharing = false
    @Published var lastUpdate: Date?
    
    private override init() {
        super.init()
    }
    
    func autoStart() {
        print("📍 Auto-starting location sharing...")
        isSharing = true
    }
}

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
}

struct SeamlessOnboardingView: View {
    @StateObject private var authManager = SeamlessAuthManager.shared
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("⭕️")
                    .font(.system(size: 100))
                
                Text("Circle")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Social life, verified")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Button("Get Started") {
                    UserDefaults.standard.set(true, forKey: "onboarding_complete")
                    authManager.isReady = true
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

class FriendManager: ObservableObject {
    static let shared = FriendManager()
    @Published var friends: [UserProfile] = []
    private init() {}
}

struct UserProfile {
    let recordName: String
    let displayName: String
    let profileEmoji: String
    let latitude: Double?
    let longitude: Double?
    
    var location: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Models
struct User: Identifiable, Hashable, Equatable {
    let id = UUID()
    let name: String
    let location: CLLocationCoordinate2D?
    let profileEmoji: String?
    
    init(name: String, location: CLLocationCoordinate2D?, profileEmoji: String? = nil) {
        self.name = name
        self.location = location
        self.profileEmoji = profileEmoji ?? "👤"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

struct HangoutSession: Identifiable, Hashable, Equatable {
    let id = UUID()
    let participants: [User]
    let startTime: Date
    let endTime: Date?
    let location: CLLocationCoordinate2D?
    let duration: TimeInterval
    let isActive: Bool
    
    init(participants: [User], startTime: Date, endTime: Date? = nil, location: CLLocationCoordinate2D? = nil, isActive: Bool = false) {
        self.participants = participants
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.isActive = isActive
        self.duration = endTime?.timeIntervalSince(startTime) ?? 0
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startTime)
    }
    
    static func == (lhs: HangoutSession, rhs: HangoutSession) -> Bool {
        return lhs.id == rhs.id && lhs.startTime == rhs.startTime
    }
}

struct Challenge: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let participants: [String]
    let points: Int
    let verificationMethod: String
    let isActive: Bool
}

// MARK: - Health Types (for UI compatibility)
struct HealthInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let icon: String
}

enum InsightType {
    case achievement
    case motivation
    case warning
    case tip
}

// MARK: - Service Integration
// Note: In a real project, these would be imported from the Services folder
// For now, we'll use the actual service classes that were created

// The real HealthKitManager is in Circle/Services/HealthKitManager.swift
// The real MotionManager is in Circle/Services/MotionManager.swift
// These provide actual HealthKit integration and step counting

// MARK: - Service Integration
// Using the real service classes from Circle/Services/
// These provide actual HealthKit integration and real data

// Real HealthKitManager is in Circle/Services/HealthKitManager.swift
// Real MotionManager is in Circle/Services/MotionManager.swift
// Real StartupPermissionsManager is in Circle/Services/StartupPermissionsManager.swift

// Note: In a real Xcode project, these would be properly imported
// For now, we'll use placeholder classes that match the real interface

// MARK: - Service Placeholders (for compilation)
// These are temporary placeholders until proper imports are set up
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    @Published var isAuthorized: Bool = false
    @Published var todaysSteps: Int = 0
    @Published var todaysDistance: Double = 0.0
    @Published var todaysSleepHours: Double = 0.0
    @Published var weeklySteps: Int = 0
    @Published var monthlySteps: Int = 0
    @Published var errorMessage: String?
    
    private let healthStore = HKHealthStore()
    
    private init() {
        checkHealthKitAvailability()
    }
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            return
        }
        
        print("✅ HealthKit is available on this device")
        
        // Check current authorization status
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let status = healthStore.authorizationStatus(for: stepType)
        
        print("📊 HealthKit authorization status: \(status.rawValue)")
        
        // Check if we're in simulator
        #if targetEnvironment(simulator)
        print("📱 Running in simulator - HealthKit entitlements may not work properly")
        DispatchQueue.main.async {
            self.isAuthorized = false
            // Don't show error message in simulator - just use placeholder data
            self.errorMessage = nil
        }
        #else
        DispatchQueue.main.async {
            self.isAuthorized = (status == .sharingAuthorized)
            print("🔐 HealthKit authorized: \(self.isAuthorized)")
            
            // Auto-request authorization if not authorized
            if !self.isAuthorized {
                Task {
                    await self.requestHealthKitAuthorization()
                }
            }
        }
        #endif
    }
    
    func requestHealthKitAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available for authorization")
            return
        }
        
        // Check if we're in simulator
        #if targetEnvironment(simulator)
        print("📱 Simulator detected - HealthKit entitlements don't work properly")
        return
        #endif
        
        print("🔐 Requesting HealthKit authorization...")
        
        let healthDataTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)
            
            print("✅ HealthKit authorization completed")
            
            DispatchQueue.main.async {
                self.isAuthorized = true
                self.errorMessage = nil
            }
            
            // Refresh data after authorization
            await refreshHealthData()
            
        } catch {
            print("❌ HealthKit authorization failed: \(error.localizedDescription)")
            // Don't show error messages to user
        }
    }
    
    func refreshHealthData() async {
        guard isAuthorized else { 
            print("❌ Cannot refresh health data - not authorized")
            return 
        }
        
        print("🔄 Refreshing health data...")
        
        let today = Date()
        
        // First, let's check if there's any data available at all
        await checkDataAvailability()
        
        // Fetch today's steps
        let steps = await getStepsForDate(today)
        print("👟 Steps fetched: \(steps)")
        
        // Fetch today's distance
        let distance = await getDistanceForDate(today)
        print("🏃 Distance fetched: \(distance)")
        
        // Fetch today's sleep
        let sleepHours = await getSleepHoursForDate(today)
        print("😴 Sleep hours fetched: \(sleepHours)")
        
        DispatchQueue.main.async {
            self.todaysSteps = steps
            self.todaysDistance = distance
            self.todaysSleepHours = sleepHours
            print("✅ Health data updated in UI")
            
            // If we got 0 data, it might be because there's no data in HealthKit
            if steps == 0 && sleepHours == 0 && distance == 0 {
                print("⚠️ No HealthKit data found - this is normal for new devices or simulators")
                print("💡 To test with real data: Add some steps and sleep data to the Health app")
                self.errorMessage = "No health data found. Make sure you have step and sleep data in the Health app."
            } else {
                print("✅ Real HealthKit data loaded successfully!")
                print("📊 Steps: \(steps), Sleep: \(sleepHours)h, Distance: \(distance)m")
            }
        }
    }
    
    private func checkDataAvailability() async {
        print("🔍 Checking HealthKit data availability...")
        
        // Check if there are any step samples at all
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepQuery = HKSampleQuery(sampleType: stepType, predicate: nil, limit: 1, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("❌ Error checking step data: \(error.localizedDescription)")
            } else if let samples = samples, !samples.isEmpty {
                print("✅ Found \(samples.count) step samples in HealthKit")
            } else {
                print("⚠️ No step samples found in HealthKit")
            }
        }
        
        healthStore.execute(stepQuery)
        
        // Check if there are any sleep samples at all
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepQuery = HKSampleQuery(sampleType: sleepType, predicate: nil, limit: 1, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("❌ Error checking sleep data: \(error.localizedDescription)")
            } else if let samples = samples, !samples.isEmpty {
                print("✅ Found \(samples.count) sleep samples in HealthKit")
            } else {
                print("⚠️ No sleep samples found in HealthKit")
            }
        }
        
        healthStore.execute(sleepQuery)
    }
    
    private func getStepsForDate(_ date: Date) async -> Int {
        guard isAuthorized else { 
            print("❌ Cannot fetch steps - not authorized")
            return 0 
        }
        
        print("👟 Fetching steps for date: \(date)")
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        print("📅 Query range: \(startOfDay) to \(endOfDay)")
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("❌ Error fetching steps: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                print("👟 Steps result: \(steps)")
                continuation.resume(returning: Int(steps))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getDistanceForDate(_ date: Date) async -> Double {
        guard isAuthorized else { return 0.0 }
        
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Error fetching distance: \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let distance = result?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0.0
                continuation.resume(returning: distance)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getSleepHoursForDate(_ date: Date) async -> Double {
        guard isAuthorized else { return 0.0 }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Error fetching sleep data: \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                
                var totalSleepHours: Double = 0.0
                
                if let sleepSamples = samples as? [HKCategorySample] {
                    for sample in sleepSamples {
                        if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                            let duration = sample.endDate.timeIntervalSince(sample.startDate)
                            totalSleepHours += duration / 3600.0 // Convert to hours
                        }
                    }
                }
                
                continuation.resume(returning: totalSleepHours)
            }
            
            healthStore.execute(query)
        }
    }
    
    func getHealthInsights() -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Step goal achievement
        let stepGoal = 10000
        if todaysSteps >= stepGoal {
            insights.append(HealthInsight(
                type: .achievement,
                title: "Step Goal Achieved! 🎉",
                description: "You've reached your daily step goal of \(stepGoal) steps",
                icon: "figure.walk"
            ))
        } else {
            let remaining = stepGoal - todaysSteps
            insights.append(HealthInsight(
                type: .motivation,
                title: "Keep Going! 💪",
                description: "Just \(remaining) more steps to reach your daily goal",
                icon: "figure.walk"
            ))
        }
        
        // Sleep quality
        if todaysSleepHours >= 7.0 {
            insights.append(HealthInsight(
                type: .achievement,
                title: "Great Sleep! 😴",
                description: "You got \(String(format: "%.1f", todaysSleepHours)) hours of sleep",
                icon: "bed.double"
            ))
        } else if todaysSleepHours < 6.0 {
            insights.append(HealthInsight(
                type: .warning,
                title: "Need More Sleep ⚠️",
                description: "Only \(String(format: "%.1f", todaysSleepHours)) hours of sleep. Aim for 7-9 hours",
                icon: "bed.double"
            ))
        }
        
        return insights
    }
}

class MotionManager: ObservableObject {
    static let shared = MotionManager()
    
    @Published var todaysSteps: Int = 0
    
    private init() {}
}

class StartupPermissionsManager: ObservableObject {
    static let shared = StartupPermissionsManager()
    
    @Published var permissionsStatus: [PermissionType: PermissionStatus] = [:]
    @Published var isShowingPermissionsFlow = false
    @Published var currentPermissionStep = 0
    
    enum PermissionType: String, CaseIterable {
        case healthKit = "Health App"
        case location = "Location"
        case notifications = "Notifications"
        case contacts = "Contacts"
        case camera = "Camera"
        case motion = "Motion & Fitness"
        
        var description: String {
            switch self {
            case .healthKit: return "Access your health data to track steps, sleep, and fitness goals"
            case .location: return "Find friends nearby and verify location-based challenges"
            case .notifications: return "Get reminders about challenges and hangout invitations"
            case .contacts: return "Find friends who use Circle and invite them to circles"
            case .camera: return "Take photos for challenges and photo stories"
            case .motion: return "Track your activity and verify motion-based challenges"
            }
        }
        
        var icon: String {
            switch self {
            case .healthKit: return "heart.fill"
            case .location: return "location.fill"
            case .notifications: return "bell.fill"
            case .contacts: return "person.2.fill"
            case .camera: return "camera.fill"
            case .motion: return "figure.walk"
            }
        }
    }
    
    enum PermissionStatus {
        case notRequested
        case denied
        case authorized
        case restricted
    }
    
    private init() {}
    
    func handleAppStartup() {
        // Check if this is the first launch
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        
        if !hasLaunchedBefore {
            // First launch - show permissions flow
            isShowingPermissionsFlow = true
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }
    
    func requestPermission(_ type: PermissionType) async {
        switch type {
        case .healthKit:
            await HealthKitManager.shared.requestHealthKitAuthorization()
        case .location:
            // Location permission would be handled by LocationManager
            break
        case .notifications:
            // Notification permission would be handled by NotificationManager
            break
        case .contacts:
            // Contacts permission would be handled by ContactsManager
            break
        case .camera:
            // Camera permission would be handled by CameraManager
            break
        case .motion:
            // Motion permission is always available
            permissionsStatus[.motion] = .authorized
        }
        
        // Refresh status after requesting
        checkAllPermissions()
    }
    
    private func checkAllPermissions() {
        // Check HealthKit permission
        let healthKitStatus = HealthKitManager.shared.isAuthorized ? PermissionStatus.authorized : PermissionStatus.notRequested
        permissionsStatus[.healthKit] = healthKitStatus
        
        // Other permissions would be checked here
        permissionsStatus[.location] = .notRequested
        permissionsStatus[.notifications] = .notRequested
        permissionsStatus[.contacts] = .notRequested
        permissionsStatus[.camera] = .notRequested
        permissionsStatus[.motion] = .authorized
    }
    
    func nextPermissionStep() {
        currentPermissionStep += 1
        if currentPermissionStep >= PermissionType.allCases.count {
            isShowingPermissionsFlow = false
        }
    }
    
    func skipPermissionsFlow() {
        isShowingPermissionsFlow = false
    }
    
    func getCurrentPermission() -> PermissionType? {
        let permissions = PermissionType.allCases
        guard currentPermissionStep < permissions.count else { return nil }
        return permissions[currentPermissionStep]
    }
    
    func getPermissionStatus(_ type: PermissionType) -> PermissionStatus {
        return permissionsStatus[type] ?? .notRequested
    }
}

// MARK: - Services
// LocationManager is now implemented in Circle/Services/LocationManager.swift
// This is a local wrapper for UI purposes
    
class LocalLocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates(handler: @escaping (CLLocation) -> Void) {
        locationUpdateHandler = handler
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationUpdateHandler = nil
    }
}

extension LocalLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        locationUpdateHandler?(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
    }
}

class HangoutEngine: ObservableObject {
    static let shared = HangoutEngine()
    
    private init() {}
    
    func getActiveHangouts() -> [HangoutSession] {
        // Return mock active hangouts - friends currently hanging out
        return [
            HangoutSession(
                participants: [
                    User(name: "Sarah", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), profileEmoji: "👩‍💼"),
                    User(name: "Mike", location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294), profileEmoji: "👨‍💻")
                ],
                startTime: Date().addingTimeInterval(-300), // 5 minutes ago
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                isActive: true
            ),
            HangoutSession(
                participants: [
                    User(name: "Emma", location: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.4194), profileEmoji: "👩‍🎓"),
                    User(name: "Alex", location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4094), profileEmoji: "👨‍🍳")
                ],
                startTime: Date().addingTimeInterval(-600), // 10 minutes ago
                location: CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4190),
                isActive: true
            )
        ]
    }
    
    func getWeeklyHangouts() -> [HangoutSession] {
        // Return mock weekly hangouts - friends who hung out this week
        return [
            // You hung out with Sarah yesterday
            HangoutSession(
                participants: [
                    User(name: "You", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), profileEmoji: "👤"),
                    User(name: "Sarah", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), profileEmoji: "👩‍💼")
                ],
                startTime: Date().addingTimeInterval(-86400), // Yesterday
                endTime: Date().addingTimeInterval(-86400 + 3600), // 1 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ),
            // Sarah and Josh hung out together
            HangoutSession(
                participants: [
                    User(name: "Sarah", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), profileEmoji: "👩‍💼"),
                    User(name: "Josh", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.3994), profileEmoji: "👨‍🎨")
                ],
                startTime: Date().addingTimeInterval(-172800), // 2 days ago
                endTime: Date().addingTimeInterval(-172800 + 7200), // 2 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7755, longitude: -122.4200)
            ),
            // Mike and Lisa hung out together
            HangoutSession(
                participants: [
                    User(name: "Mike", location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294), profileEmoji: "👨‍💻"),
                    User(name: "Lisa", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4394), profileEmoji: "👩‍⚕️")
                ],
                startTime: Date().addingTimeInterval(-259200), // 3 days ago
                endTime: Date().addingTimeInterval(-259200 + 5400), // 1.5 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7740, longitude: -122.4190)
            ),
            // You hung out with Emma and Alex
            HangoutSession(
                participants: [
                    User(name: "You", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), profileEmoji: "👤"),
                    User(name: "Emma", location: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.4194), profileEmoji: "👩‍🎓"),
                    User(name: "Alex", location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4094), profileEmoji: "👨‍🍳")
                ],
                startTime: Date().addingTimeInterval(-345600), // 4 days ago
                endTime: Date().addingTimeInterval(-345600 + 7200), // 2 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4190)
            )
        ]
    }
    
    func getTotalHangoutTime(with friend: User) -> TimeInterval {
        // Placeholder implementation
        return 7200 // 2 hours
    }
}

// MARK: - Components
struct CircleMemberAnnotation: View {
    let member: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                Text(member.profileEmoji ?? "👤")
                    .font(.system(size: 20))
            }
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.2), value: member.name)
    }
}

struct StatsOverlayCard: View {
    let activeHangouts: [HangoutSession]
    let weeklyHangouts: [HangoutSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Active hangouts
            if !activeHangouts.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("Currently with \(activeHangouts.first?.participants.count ?? 0) friends")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            // Weekly summary
            let totalHours = weeklyHangouts.reduce(0) { $0 + $1.duration } / 3600
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("\(String(format: "%.1f", totalHours)) hours this week")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // Top hangout buddy
            if let topFriend = getTopHangoutBuddy() {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.orange)
                    Text("Most time with \(topFriend.name)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func getTopHangoutBuddy() -> User? {
        // Simple implementation - return first participant from first hangout
        return weeklyHangouts.first?.participants.first
    }
}

struct CustomMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let circleMembers: [User]
    let activeHangouts: [HangoutSession]
    let weeklyHangouts: [HangoutSession]
    let onFriendTap: (User) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: true)
        
        // Remove existing annotations and overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add friend annotations
        for member in circleMembers {
            if let location = member.location {
                let annotation = FriendAnnotation(member: member)
                annotation.coordinate = location
                mapView.addAnnotation(annotation)
            }
        }
        
        // Add connection lines as proper map overlays
        addConnectionLines(to: mapView)
    }
    
    private func addConnectionLines(to mapView: MKMapView) {
        // Connect YOU to all your friends (since they're all your friends) - ALL GREEN
        if let you = circleMembers.first(where: { $0.name == "You" }),
           let yourLocation = you.location {
            for friend in circleMembers {
                if friend.name != "You", let friendLocation = friend.location {
                    let coordinates = [yourLocation, friendLocation]
                    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    polyline.title = "friend" // Mark as friend connection
                    mapView.addOverlay(polyline)
                }
            }
        }
        
        // Add active hangout lines (solid green) - only for non-You connections
        for hangout in activeHangouts {
            if hangout.participants.count >= 2 {
                for i in 0..<hangout.participants.count-1 {
                    let member1 = hangout.participants[i]
                    let member2 = hangout.participants[i+1]
                    
                    // Skip if either participant is "You" (already connected above)
                    if member1.name == "You" || member2.name == "You" {
                        continue
                    }
                    
                    if let loc1 = member1.location, let loc2 = member2.location {
                        let coordinates = [loc1, loc2]
                        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                        polyline.title = "active" // Mark as active for styling
                        mapView.addOverlay(polyline)
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView
        
        init(_ parent: CustomMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let friendAnnotation = annotation as? FriendAnnotation {
                let identifier = "FriendAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                    annotationView?.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                } else {
                    annotationView?.annotation = annotation
                }
                
                // Clear existing subviews
                annotationView?.subviews.forEach { $0.removeFromSuperview() }
                
                // Create custom annotation view using UIKit
                let customView = FriendAnnotationView(member: friendAnnotation.member) {
                    self.parent.onFriendTap(friendAnnotation.member)
                }
                
                annotationView?.addSubview(customView)
                customView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    customView.centerXAnchor.constraint(equalTo: annotationView!.centerXAnchor),
                    customView.centerYAnchor.constraint(equalTo: annotationView!.centerYAnchor),
                    customView.widthAnchor.constraint(equalToConstant: 40),
                    customView.heightAnchor.constraint(equalToConstant: 40)
                ])
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // ALL LINES ARE GREEN - friends and active hangouts
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                renderer.lineDashPattern = nil
                
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

class FriendAnnotation: NSObject, MKAnnotation {
    let member: User
    var coordinate: CLLocationCoordinate2D
    
    init(member: User) {
        self.member = member
        self.coordinate = member.location ?? CLLocationCoordinate2D()
        super.init()
    }
}

class FriendAnnotationView: UIView {
    let member: User
    let onTap: () -> Void
    
    init(member: User, onTap: @escaping () -> Void) {
        self.member = member
        self.onTap = onTap
        super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Create circular background
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.systemBlue
        backgroundView.layer.cornerRadius = 20
        backgroundView.layer.borderWidth = 2
        backgroundView.layer.borderColor = UIColor.white.cgColor
        
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.widthAnchor.constraint(equalToConstant: 40),
            backgroundView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Create emoji label
        let emojiLabel = UILabel()
        emojiLabel.text = member.profileEmoji ?? "👤"
        emojiLabel.font = UIFont.systemFont(ofSize: 20)
        emojiLabel.textAlignment = .center
        
        addSubview(emojiLabel)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    @objc private func handleTap() {
        print("🎯 FriendAnnotationView tapped for: \(member.name)")
        onTap()
    }
}


struct FriendDetailSheet: View {
    let friend: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 12) {
                        Text(friend.profileEmoji ?? "👤")
                            .font(.system(size: 60))
                        
                        Text(friend.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(getLocationString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Updated 1 minute ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    // Action Buttons Section
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // Contact Button
                            Button(action: {
                                // Contact action
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.title2)
                                    }
                                    
                                    Text("Contact")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            // Directions Button
                            Button(action: {
                                // Directions action
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                            .foregroundColor(.white)
                                            .font(.title2)
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Text("Directions")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        
                                        Text("2.3 km")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Hangout Stats Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hangout History")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            LastHangoutRow(friend: friend)
                            Divider()
                            StatRow(title: "Total Time Together", value: getTotalHangoutTime())
                            Divider()
                            StatRow(title: "Mutual Connections", value: "\(getMutualConnections()) friends")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Management Options Section
                    VStack(spacing: 0) {
                        ManagementRow(title: "Stop Sharing My Location", icon: "location.slash", color: .red)
                        Divider()
                        ManagementRow(title: "Remove \(friend.name)", icon: "trash", color: .red)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getLocationString() -> String {
        if let location = friend.location {
            // Mock location names based on coordinates
            if location.latitude > 37.78 {
                return "San Francisco, CA"
            } else if location.latitude > 37.76 {
                return "Oakland, CA"
            } else {
                return "Berkeley, CA"
            }
        }
        return "Location unavailable"
    }
    
    private func getTotalHangoutTime() -> String {
        let hangouts = HangoutEngine.shared.getWeeklyHangouts()
        let friendHangouts = hangouts.filter { hangout in
            hangout.participants.contains { $0.id == friend.id }
        }
        
        let totalMinutes = friendHangouts.reduce(0) { total, hangout in
            total + Int(hangout.duration / 60) // Convert seconds to minutes
        }
        
        if totalMinutes < 60 {
            return "\(totalMinutes) minutes"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours) hours"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }
    
    private func getMutualConnections() -> Int {
        // Mock data - in real app, this would calculate actual mutual friends
        return Int.random(in: 3...8)
    }
}

struct LastHangoutRow: View {
    let friend: User
    
    init(friend: User) {
        self.friend = friend
    }
    
    var body: some View {
        let hangoutInfo = getLastHangoutInfo()
        
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Hangout")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(hangoutInfo.timeAgo)
                .font(.headline)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                Text(hangoutInfo.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(hangoutInfo.duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func getLastHangoutInfo() -> (timeAgo: String, location: String, duration: String) {
        let hangouts = HangoutEngine.shared.getWeeklyHangouts()
        let friendHangouts = hangouts.filter { hangout in
            hangout.participants.contains { $0.id == friend.id }
        }
        
        if let lastHangout = friendHangouts.max(by: { 
            let endTime1 = $0.endTime ?? $0.startTime
            let endTime2 = $1.endTime ?? $1.startTime
            return endTime1 < endTime2
        }) {
            let endTime = lastHangout.endTime ?? lastHangout.startTime
            let timeAgo = Date().timeIntervalSince(endTime)
            
            let timeAgoString: String
            if timeAgo < 3600 { // Less than 1 hour
                timeAgoString = "\(Int(timeAgo / 60)) minutes ago"
            } else if timeAgo < 86400 { // Less than 1 day
                timeAgoString = "\(Int(timeAgo / 3600)) hours ago"
            } else {
                timeAgoString = "\(Int(timeAgo / 86400)) days ago"
            }
            
            let locationString: String
            if let location = lastHangout.location {
                if location.latitude > 37.78 {
                    locationString = "Golden Gate Park"
                } else if location.latitude > 37.76 {
                    locationString = "Downtown Oakland"
                } else {
                    locationString = "UC Berkeley Campus"
                }
            } else {
                locationString = "Unknown location"
            }
            
            let durationMinutes = Int(lastHangout.duration / 60)
            let durationString: String
            if durationMinutes < 60 {
                durationString = "\(durationMinutes) minutes"
            } else {
                let hours = durationMinutes / 60
                let minutes = durationMinutes % 60
                if minutes == 0 {
                    durationString = "\(hours) hours"
                } else {
                    durationString = "\(hours)h \(minutes)m"
                }
            }
            
            return (timeAgoString, locationString, durationString)
        }
        
        return ("Never", "Unknown location", "0 minutes")
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ManagementRow: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(color == .red ? .red : .primary)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle tap action
        }
    }
}

struct NoLocationPermissionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Location Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Circle needs location access to show your friends on the map and detect hangouts. You can still use challenges and other features.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}


struct ContentView: View {
    @StateObject private var seamlessAuth = SeamlessAuthManager.shared
    @State private var selectedTab = 1 // Start with Circles tab (now index 1)
    @State private var dragOffset: CGFloat = 0
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_complete")
    
    var body: some View {
        Group {
            // Seamless onboarding (one-time only)
            if !hasCompletedOnboarding {
                SeamlessOnboardingView()
                    .onAppear {
                        // Check if actually needs onboarding
                        if seamlessAuth.isReady {
                            hasCompletedOnboarding = true
                        }
                    }
            } else if !seamlessAuth.isReady {
                // Loading state
                ZStack {
                    Color.blue.opacity(0.1).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Connecting to iCloud...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .onAppear {
                    seamlessAuth.checkiCloudStatus()
                }
            } else {
                // Main app interface
        ZStack {
            // Content area with swipe gesture
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    HomeView()
                        .frame(width: geometry.size.width)
                    
                    CirclesView()
                        .frame(width: geometry.size.width)
            
            ChallengesView()
                        .frame(width: geometry.size.width)
                }
                .offset(x: -CGFloat(selectedTab) * geometry.size.width + dragOffset)
                .animation(.interactiveSpring(), value: selectedTab)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                                    if value.translation.width < -threshold && selectedTab < 2 {
                                selectedTab += 1
                            } else if value.translation.width > threshold && selectedTab > 0 {
                                selectedTab -= 1
                            }
                            dragOffset = 0
                        }
                )
            }
            
            // Custom Tab Bar - Pill shape like Find My (overlay at bottom)
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    TabBarButton(icon: "house", selectedIcon: "house.fill", label: "Home", isSelected: selectedTab == 0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 0
                        }
                    }
                    
                            TabBarButton(icon: "circle.fill", selectedIcon: "circle.fill", label: "Circles", isSelected: selectedTab == 1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 1
                        }
                    }
                    
                            TabBarButton(icon: "target", selectedIcon: "target", label: "Circles", isSelected: selectedTab == 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 2
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }
            }
        }
        }
        .onAppear {
            // Handle app startup - seamless auth
            seamlessAuth.checkiCloudStatus()
        }
    }
}

struct HomeView: View {
    // Use the real HealthKitManager from Services
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var motionManager = MotionManager.shared
    @State private var healthInsights: [HealthInsight] = []
    @State private var isHealthKitAuthorized = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Clean Header
                    VStack(spacing: 16) {
                        // Health Stats - Native style with real data
                        HStack(spacing: 16) {
                            HealthStatCard(
                                title: "Steps",
                                value: "\(healthKitManager.todaysSteps)",
                                icon: "figure.walk",
                                color: .green
                            )
                            
                            HealthStatCard(
                                title: "Sleep",
                                value: String(format: "%.1fh", healthKitManager.todaysSleepHours),
                                icon: "bed.double",
                                color: .purple
                            )
                            
                            HealthStatCard(
                                title: "Hangouts",
                                value: "2",
                                icon: "person.2.fill",
                                color: .blue
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Health Insights - Only show if authorized
                    if healthKitManager.isAuthorized && !healthInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Health Insights")
                                .font(.headline)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(healthInsights) { insight in
                                        HealthInsightCard(insight: insight)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // Active Challenges
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                        Text("Active Challenges")
                            .font(.headline)
                            
                            Spacer()
                            
                            Button("View All") {
                                // Navigate to challenges
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(mockChallenges) { challenge in
                                    ChallengeCard(challenge: challenge)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadHealthData()
            }
        }
    }
    
    private func loadHealthData() {
        // Always refresh health data to get latest from Health app
        Task {
            await healthKitManager.refreshHealthData()
        }
        
        // Load health insights from the real HealthKitManager
        healthInsights = healthKitManager.getHealthInsights()
    }
    
    private var mockChallenges: [Challenge] {
        [
            Challenge(title: "Daily Steps", description: "Walk 10,000 steps", participants: ["You", "Sarah"], points: 50, verificationMethod: "motion", isActive: true),
            Challenge(title: "Gym Session", description: "Work out together", participants: ["You", "Mike"], points: 30, verificationMethod: "location", isActive: true)
        ]
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

struct HealthStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
                Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HealthInsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: insight.icon)
                    .foregroundColor(insightColor)
                
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(insight.description)
                .font(.caption)
                    .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(width: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var insightColor: Color {
        switch insight.type {
        case .achievement: return .green
        case .motivation: return .blue
        case .warning: return .orange
        case .tip: return .purple
        }
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: challengeIcon)
                    .foregroundColor(.blue)
                
                Text(challenge.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            
            Spacer()
            
                Text("\(challenge.points) pts")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            Text(challenge.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("\(challenge.participants.count) participants")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Progress indicator
            Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .frame(width: 180)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var challengeIcon: String {
        switch challenge.verificationMethod {
        case "motion": return "figure.walk"
        case "location": return "location"
        case "camera": return "camera"
        default: return "target"
        }
    }
}

// Placeholder views for other tabs
struct CirclesView: View {
    @StateObject private var locationManager = LocalLocationManager()
    @StateObject private var hangoutEngine = HangoutEngine.shared
    @StateObject private var seamlessAuth = SeamlessAuthManager.shared
    @StateObject private var contactDiscovery = ContactDiscoveryManager.shared
    @StateObject private var seamlessLocation = SeamlessLocationManager.shared
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedFriend: User?
    @State private var circleMembers: [User] = []
    @State private var activeHangouts: [HangoutSession] = []
    @State private var weeklyHangouts: [HangoutSession] = []
    @State private var useRealFriends = true // Toggle between real and mock data
    
    var body: some View {
        NavigationView {
            Group {
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    // No location permission fallback
                    NoLocationPermissionView()
                } else {
                    // Main map view - ALWAYS show map with friends
                    ZStack {
                        // Custom MapKit Map View with proper overlays
                        CustomMapView(
                            region: $region,
                            circleMembers: circleMembers,
                            activeHangouts: activeHangouts,
                            weeklyHangouts: weeklyHangouts,
                            onFriendTap: { friend in
                                print("🎯 onFriendTap called for: \(friend.name)")
                                selectedFriend = friend
                            }
                        )
                        .ignoresSafeArea(.all, edges: .all)
                        .onAppear {
                            setupLocationTracking()
                            // Delay loading circle data until we have location
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                loadCircleData()
                            }
                            
                            // Refresh circle data every 10 seconds
                            Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                                loadCircleData()
                            }
                        }
                        
                        // Stats Overlay (screen overlay)
            VStack {
                            HStack {
                                Spacer()
                                StatsOverlayCard(
                                    activeHangouts: activeHangouts,
                                    weeklyHangouts: weeklyHangouts
                                )
                                .padding(.trailing, 16)
                            }
                            .padding(.top, 60) // Move below Dynamic Island
                            
                            Spacer()
                        }
                    }
                    .ignoresSafeArea(.all, edges: .all)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(item: $selectedFriend) { friend in
                FriendDetailSheet(friend: friend)
                    .onAppear {
                        print("🎯 Sheet presenting for: \(friend.name)")
                    }
            }
        }
        .onAppear {
            // Auto-start location sharing (seamless)
            if !seamlessLocation.isSharing {
                seamlessLocation.autoStart()
            }
            
            // Discover friends from contacts (one-time)
            if contactDiscovery.discoveredFriends.isEmpty {
                Task {
                    try? await contactDiscovery.discoverFriendsFromContacts()
                }
            }
        }
    }
    
    private func setupLocationTracking() {
        locationManager.requestLocationPermission()
        locationManager.startLocationUpdates { location in
            region.center = location.coordinate
        }
    }
    
    private func loadCircleData() {
        // Check if we have real friends to display
        if useRealFriends && !seamlessLocation.friendsLocations.isEmpty {
            loadRealFriends()
        } else {
            loadMockFriends()
        }
        
        // Load hangout data
        activeHangouts = hangoutEngine.getActiveHangouts()
        weeklyHangouts = hangoutEngine.getWeeklyHangouts()
        
        print("👥 Active hangouts: \(activeHangouts.count), Weekly hangouts: \(weeklyHangouts.count)")
    }
    
    private func loadRealFriends() {
        print("📱 Loading REAL friends from contacts")
        
        var members: [User] = []
        
        // Add yourself
        if let location = locationManager.currentLocation?.coordinate {
            let displayName = seamlessAuth.displayName ?? "You"
            members.append(User(
                name: displayName,
                location: location,
                profileEmoji: "👤"
            ))
            print("✅ Added you: \(location.latitude), \(location.longitude)")
        }
        
        // Add discovered friends with their locations
        for (userID, friendLocation) in seamlessLocation.friendsLocations {
            members.append(User(
                name: friendLocation.displayName,
                location: friendLocation.coordinate,
                profileEmoji: "👥"
            ))
            print("✅ Added friend: \(friendLocation.displayName) at \(friendLocation.latitude), \(friendLocation.longitude)")
        }
        
        circleMembers = members
        print("📍 Loaded \(circleMembers.count) people from contacts (including you)")
    }
    
    private func loadMockFriends() {
        print("🧪 Loading MOCK friends for testing")
        
        // Get user's current location or use default
        let userLat = locationManager.currentLocation?.coordinate.latitude ?? 37.7749
        let userLon = locationManager.currentLocation?.coordinate.longitude ?? -122.4194
        
        print("🗺️ Loading circle data at location: \(userLat), \(userLon)")
        
        // Create mock friends relative to user's location (within ~5km radius)
        let offset = 0.01 // Roughly 1km offset
        
        circleMembers = [
            User(name: "You", location: CLLocationCoordinate2D(latitude: userLat, longitude: userLon), profileEmoji: "👤"),
            User(name: "Sarah", location: CLLocationCoordinate2D(latitude: userLat + offset, longitude: userLon - offset), profileEmoji: "👩‍💼"),
            User(name: "Mike", location: CLLocationCoordinate2D(latitude: userLat - offset, longitude: userLon + offset), profileEmoji: "👨‍💻"),
            User(name: "Josh", location: CLLocationCoordinate2D(latitude: userLat, longitude: userLon - (offset * 2)), profileEmoji: "👨‍🎨"),
            User(name: "Emma", location: CLLocationCoordinate2D(latitude: userLat + (offset * 2), longitude: userLon), profileEmoji: "👩‍🎓"),
            User(name: "Alex", location: CLLocationCoordinate2D(latitude: userLat - (offset * 1.5), longitude: userLon - offset), profileEmoji: "👨‍🍳"),
            User(name: "Lisa", location: CLLocationCoordinate2D(latitude: userLat + offset, longitude: userLon + (offset * 1.5)), profileEmoji: "👩‍⚕️")
        ]
        
        print("📍 Created \(circleMembers.count) MOCK circle members around user location")
    }
}

struct LeaderboardView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Leaderboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Weekly rankings will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Leaderboard")
        }
    }
}

struct ChallengesView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Challenges")
                    .font(.title2)
                    .fontWeight(.medium)
                    .padding(.top, 16)
                
                Text("View and create challenges with friends")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Plus button action - could open challenge creation
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct ChallengeRow: View {
    let challenge: Challenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Challenge icon
                Image(systemName: challengeIcon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(challenge.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text("\(challenge.participants.count) participants")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(challenge.points) pts")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Progress indicator
            VStack {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Tap for leaderboard")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var challengeIcon: String {
        switch challenge.verificationMethod {
        case "motion":
            return "figure.walk"
        case "location":
            return "location"
        case "camera":
            return "camera"
        default:
            return "target"
        }
    }
}

struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @State private var leaderboardData: [LeaderboardEntry] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Challenge info card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: challengeIcon)
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(challenge.title)
                                .font(.title2)
                    .fontWeight(.bold)
                            
                            Text(challenge.description)
                                .font(.body)
                    .foregroundColor(.secondary)
            }
                        
                        Spacer()
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Participants")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(challenge.participants.count)")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(challenge.points)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                
                // Leaderboard
                VStack(alignment: .leading, spacing: 12) {
                    Text("Leaderboard")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if leaderboardData.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No data yet")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(leaderboardData) { entry in
                            LeaderboardRow(entry: entry)
                        }
                        .listStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadLeaderboardData()
        }
    }
    
    private var challengeIcon: String {
        switch challenge.verificationMethod {
        case "motion":
            return "figure.walk"
        case "location":
            return "location"
        case "camera":
            return "camera"
        default:
            return "target"
        }
    }
    
    private func loadLeaderboardData() {
        // Mock leaderboard data
        leaderboardData = [
            LeaderboardEntry(
                participant: "Sarah",
                score: 85,
                rank: 1,
                progress: 0.85,
                isCurrentUser: false
            ),
            LeaderboardEntry(
                participant: "You",
                score: 72,
                rank: 2,
                progress: 0.72,
                isCurrentUser: true
            ),
            LeaderboardEntry(
                participant: "Mike",
                score: 68,
                rank: 3,
                progress: 0.68,
                isCurrentUser: false
            ),
            LeaderboardEntry(
                participant: "Emma",
                score: 45,
                rank: 4,
                progress: 0.45,
                isCurrentUser: false
            )
        ]
    }
}

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let participant: String
    let score: Int
    let rank: Int
    let progress: Double
    let isCurrentUser: Bool
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(entry.rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(entry.rank <= 3 ? .orange : .secondary)
                .frame(width: 30)
            
            // Participant name
            Text(entry.participant)
                .font(.body)
                .fontWeight(entry.isCurrentUser ? .semibold : .regular)
                .foregroundColor(entry.isCurrentUser ? .blue : .primary)
            
            Spacer()
            
            // Progress bar
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.score)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                ProgressView(value: entry.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: entry.isCurrentUser ? .blue : .orange))
                    .frame(width: 80)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions Flow View
struct PermissionsFlowView: View {
    @StateObject private var permissionsManager = StartupPermissionsManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text("Welcome to Circle")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Let's set up your permissions to get started")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Current Permission Card
                if let currentPermission = permissionsManager.getCurrentPermission() {
                    PermissionCard(
                        permission: currentPermission,
                        status: permissionsManager.getPermissionStatus(currentPermission),
                        onAllow: {
                            Task {
                                await permissionsManager.requestPermission(currentPermission)
                                permissionsManager.nextPermissionStep()
                            }
                        },
                        onSkip: {
                            permissionsManager.nextPermissionStep()
                        }
                    )
                }
                
                // Progress Indicator
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<StartupPermissionsManager.PermissionType.allCases.count, id: \.self) { index in
                            Circle()
                                .fill(index <= permissionsManager.currentPermissionStep ? Color.blue : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text("Step \(permissionsManager.currentPermissionStep + 1) of \(StartupPermissionsManager.PermissionType.allCases.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Skip All Button
                Button("Skip All Permissions") {
                    permissionsManager.skipPermissionsFlow()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct PermissionCard: View {
    let permission: StartupPermissionsManager.PermissionType
    let status: StartupPermissionsManager.PermissionStatus
    let onAllow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Permission Icon
            Image(systemName: permission.icon)
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            // Permission Title
            Text(permission.rawValue)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Permission Description
            Text(permission.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Status Indicator
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(statusColor.opacity(0.1))
            )
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Allow") {
                    onAllow()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(status == .authorized)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
    
    private var statusIcon: String {
        switch status {
        case .notRequested: return "questionmark.circle"
        case .denied: return "xmark.circle"
        case .authorized: return "checkmark.circle.fill"
        case .restricted: return "exclamationmark.triangle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .notRequested: return .orange
        case .denied: return .red
        case .authorized: return .green
        case .restricted: return .orange
        }
    }
    
    private var statusText: String {
        switch status {
        case .notRequested: return "Not Requested"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .restricted: return "Restricted"
        }
    }
}

// MARK: - Story System Components

// Premium Story Circle Component
struct StoryCircleView: View {
    @StateObject private var storyManager = PhotoStoriesManager.shared
    @State private var showingStories = false
    
    var body: some View {
        Button(action: {
            showingStories = true
        }) {
            ZStack {
                // Black circle background
                Circle()
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                
                       // White number for people with unviewed stories
                       if storyManager.unviewedPeopleCount > 0 {
                           Text("\(storyManager.unviewedPeopleCount)")
                               .font(.system(size: 16, weight: .semibold))
                               .foregroundColor(.white)
                       }
            }
        }
        .sheet(isPresented: $showingStories) {
            StoryViewer()
        }
        .onAppear {
            storyManager.loadStories()
        }
    }
}

// Story Viewer with Proper Instagram/Snapchat Mechanics
struct StoryViewer: View {
    @StateObject private var storyManager = PhotoStoriesManager.shared
    @State private var currentPersonIndex = 0
    @State private var currentStoryIndex = 0
    @Environment(\.dismiss) private var dismiss
    
    private var storiesByCreator: [(String, [PhotoStory])] {
        let grouped = storyManager.getStoriesByCreator()
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    
    private var currentPerson: String {
        guard currentPersonIndex < storiesByCreator.count else { return "" }
        return storiesByCreator[currentPersonIndex].0
    }
    
    private var currentPersonStories: [PhotoStory] {
        guard currentPersonIndex < storiesByCreator.count else { return [] }
        return storiesByCreator[currentPersonIndex].1
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            if storiesByCreator.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No Stories Yet")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Create your first story by tagging friends")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            } else {
                // Current story content
                if currentStoryIndex < currentPersonStories.count {
                    StoryContentView(
                        story: currentPersonStories[currentStoryIndex],
                        creator: currentPerson,
                        currentPersonIndex: $currentPersonIndex,
                        currentStoryIndex: $currentStoryIndex,
                        totalPeople: storiesByCreator.count,
                        totalStoriesForCurrentPerson: currentPersonStories.count,
                        onDismiss: { dismiss() }
                    )
                }
            }
        }
        .onAppear {
            storyManager.loadStories()
        }
    }
}

// Individual Story Content with Proper Progress Bars
struct StoryContentView: View {
    let story: PhotoStory
    let creator: String
    @Binding var currentPersonIndex: Int
    @Binding var currentStoryIndex: Int
    let totalPeople: Int
    let totalStoriesForCurrentPerson: Int
    let onDismiss: () -> Void
    @State private var progress: Double = 0
    @State private var timer: Timer?
    @StateObject private var storyManager = PhotoStoriesManager.shared
    
    var body: some View {
        ZStack {
            // Story image
            AsyncImage(url: story.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .ignoresSafeArea()
            }
            
            // Story overlay
            VStack {
                // Top bar with progress bars for current person
                HStack(spacing: 4) {
                    ForEach(0..<totalStoriesForCurrentPerson, id: \.self) { index in
                        Rectangle()
                            .fill(index < currentStoryIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 2)
                            .overlay(
                                // Progress animation ONLY for current story
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(height: 2)
                                    .scaleEffect(x: index == currentStoryIndex ? progress : 0, anchor: .leading)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom info - simplified (name only)
                VStack(alignment: .leading, spacing: 8) {
                    Text(story.title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onTapGesture { location in
            handleTap(at: location)
        }
               .onAppear {
                   // Mark story as viewed when it starts
                   storyManager.markStoryAsViewed(story.id)
                   startProgressTimer()
               }
        .onDisappear {
            stopProgressTimer()
        }
    }
    
    private func handleTap(at location: CGPoint) {
        let screenWidth = UIScreen.main.bounds.width
        let tapX = location.x
        
        // Stop current timer
        stopProgressTimer()
        
        if tapX < screenWidth / 2 {
            // Tap left - previous story (DON'T mark as viewed)
            if currentStoryIndex > 0 {
                currentStoryIndex -= 1
                progress = 0 // Reset progress immediately
                DispatchQueue.main.async {
                    self.startProgressTimer() // Restart timer for new story
                }
            } else if currentPersonIndex > 0 {
                // Move to previous person's last story
                currentPersonIndex -= 1
                currentStoryIndex = totalStoriesForCurrentPerson - 1
                progress = 0 // Reset progress immediately
                DispatchQueue.main.async {
                    self.startProgressTimer() // Restart timer for new story
                }
            }
        } else {
            // Tap right - next story
            if currentStoryIndex < totalStoriesForCurrentPerson - 1 {
                // Next story in same person's sequence
                currentStoryIndex += 1
                progress = 0
                startProgressTimer() // Restart timer for new story
            } else {
                // Finished all stories for this person
                if currentPersonIndex < totalPeople - 1 {
                    // Move to next person's first story
                    currentPersonIndex += 1
                    currentStoryIndex = 0
                    progress = 0
                    startProgressTimer() // Restart timer for new story
                } else {
                    // Finished all stories - close and return to home
                    onDismiss()
                }
            }
        }
    }
    
           private func startProgressTimer() {
               timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                   progress += 0.02
                   if progress >= 1.0 {
                       // Move to next story
                       if currentStoryIndex < totalStoriesForCurrentPerson - 1 {
                    // Next story in same person's sequence
                    currentStoryIndex += 1
                } else {
                    // Finished all stories for this person
                    if currentPersonIndex < totalPeople - 1 {
                        // Move to next person's first story
                        currentPersonIndex += 1
                        currentStoryIndex = 0
                    } else {
                        // Finished all stories - close and return to home
                        onDismiss()
                    }
                }
                progress = 0
            }
        }
    }
    
    private func stopProgressTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// Photo Story Model
struct PhotoStory: Identifiable {
    let id: String
    let imageURL: URL?
    let title: String
    let taggedFriends: [String] // Friend IDs
    let creator: String
    let timestamp: Date
    let isViewed: Bool
    
    init(id: String = UUID().uuidString, imageURL: URL? = nil, title: String, taggedFriends: [String], creator: String, timestamp: Date = Date(), isViewed: Bool = false) {
        self.id = id
        self.imageURL = imageURL
        self.title = title
        self.taggedFriends = taggedFriends
        self.creator = creator
        self.timestamp = timestamp
        self.isViewed = isViewed
    }
}

// Photo Stories Manager
class PhotoStoriesManager: ObservableObject {
    static let shared = PhotoStoriesManager()
    
    @Published var stories: [PhotoStory] = []
    @Published var unviewedPeopleCount: Int = 0
    
    private init() {}
    
    func loadStories() {
        // Only load stories if we don't have any yet (first time)
        guard stories.isEmpty else { return }
        
        // Mock data with Josh (2 stories) and Emma (5 stories)
        stories = [
            // Josh's stories (2 stories)
            PhotoStory(
                imageURL: Bundle.main.url(forResource: "josh1", withExtension: "jpg", subdirectory: "StoryImages"),
                title: "Josh",
                taggedFriends: ["friend1", "friend2"],
                creator: "josh",
                timestamp: Date().addingTimeInterval(-3600) // 1 hour ago
            ),
            PhotoStory(
                imageURL: Bundle.main.url(forResource: "josh2", withExtension: "jpg", subdirectory: "StoryImages"),
                title: "Josh",
                taggedFriends: ["friend1", "friend2"],
                creator: "josh",
                timestamp: Date().addingTimeInterval(-7200) // 2 hours ago
            ),
            
            // Emma's stories (5 stories)
            PhotoStory(
                imageURL: Bundle.main.url(forResource: "emma1", withExtension: "jpg", subdirectory: "StoryImages"),
                title: "Emma",
                taggedFriends: ["friend1", "friend3"],
                creator: "emma",
                timestamp: Date().addingTimeInterval(-1800) // 30 minutes ago
            ),
            PhotoStory(
                imageURL: Bundle.main.url(forResource: "emma2", withExtension: "jpg", subdirectory: "StoryImages"),
                title: "Emma",
                taggedFriends: ["friend1", "friend3"],
                creator: "emma",
                timestamp: Date().addingTimeInterval(-5400) // 1.5 hours ago
            ),
            PhotoStory(
                imageURL: Bundle.main.url(forResource: "emma3", withExtension: "jpg", subdirectory: "StoryImages"),
                title: "Emma",
                taggedFriends: ["friend1", "friend3"],
                creator: "emma",
                timestamp: Date().addingTimeInterval(-9000) // 2.5 hours ago
            ),
            PhotoStory(
                imageURL: Bundle.main.url(forResource: "emma4", withExtension: "jpg", subdirectory: "StoryImages"),
                title: "Emma",
                taggedFriends: ["friend1", "friend3"],
                creator: "emma",
                timestamp: Date().addingTimeInterval(-12600) // 3.5 hours ago
            ),
            PhotoStory(
                imageURL: Bundle.main.url(forResource: "emma5", withExtension: "jpg", subdirectory: "StoryImages"),
                title: "Emma",
                taggedFriends: ["friend1", "friend3"],
                creator: "emma",
                timestamp: Date().addingTimeInterval(-16200) // 4.5 hours ago
            )
               ]
               
               updateUnviewedPeopleCount()
           }
    
    func markStoryAsViewed(_ storyId: String) {
        if let index = stories.firstIndex(where: { $0.id == storyId }) {
            // Only mark if not already viewed
            guard !stories[index].isViewed else { return }
            
            print("📝 Marking story as viewed: \(storyId)")
            objectWillChange.send()
            stories[index] = PhotoStory(
                id: stories[index].id,
                imageURL: stories[index].imageURL,
                title: stories[index].title,
                taggedFriends: stories[index].taggedFriends,
                creator: stories[index].creator,
                timestamp: stories[index].timestamp,
                isViewed: true
            )
            updateUnviewedPeopleCount()
            print("📊 Updated unviewed people count: \(unviewedPeopleCount)")
        }
    }
    
    func markAllPersonStoriesAsViewed(creator: String) {
        objectWillChange.send()
        for index in stories.indices where stories[index].creator == creator {
            stories[index] = PhotoStory(
                id: stories[index].id,
                imageURL: stories[index].imageURL,
                title: stories[index].title,
                taggedFriends: stories[index].taggedFriends,
                creator: stories[index].creator,
                timestamp: stories[index].timestamp,
                isViewed: true
            )
        }
        updateUnviewedPeopleCount()
    }
    
    private func updateUnviewedPeopleCount() {
        // Count unique people whose stories haven't ALL been viewed
        var peopleWithUnviewedStories = Set<String>()
        
        for creator in Set(stories.map { $0.creator }) {
            let creatorStories = stories.filter { $0.creator == creator }
            let hasUnviewedStories = creatorStories.contains { !$0.isViewed }
            if hasUnviewedStories {
                peopleWithUnviewedStories.insert(creator)
            }
            print("👤 Creator: \(creator), Stories: \(creatorStories.count), Unviewed: \(creatorStories.filter { !$0.isViewed }.count), Has Unviewed: \(hasUnviewedStories)")
        }
        
        unviewedPeopleCount = peopleWithUnviewedStories.count
        print("🔢 Total unviewed people count: \(unviewedPeopleCount)")
    }
    
    // Get stories grouped by creator
    func getStoriesByCreator() -> [String: [PhotoStory]] {
        return Dictionary(grouping: stories) { $0.creator }
    }
    
    // Check if all stories from a creator have been viewed
    func areAllStoriesViewed(for creator: String) -> Bool {
        let creatorStories = stories.filter { $0.creator == creator }
        return creatorStories.allSatisfy { $0.isViewed }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}