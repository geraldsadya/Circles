# 🧱 **Technical Handoff for "Circle" (iOS MVP)**

*Ready-to-implement technical specification for Circle iOS app*

---

## 📊 1. **Data Models & Schema**

### Core Data Entities

```swift
// MARK: - Core Data Models

@objc(User)
public class User: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var appleUserID: String
    @NSManaged public var displayName: String
    @NSManaged public var profileEmoji: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var lastActiveAt: Date
    @NSManaged public var totalPoints: Int32
    @NSManaged public var weeklyPoints: Int32
    @NSManaged public var circles: Set<Circle>
    @NSManaged public var challenges: Set<Challenge>
    @NSManaged public var proofs: Set<Proof>
    @NSManaged public var hangoutSessions: Set<HangoutSession>
}

@objc(Circle)
public class Circle: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var inviteCode: String
    @NSManaged public var createdAt: Date
    @NSManaged public var isActive: Bool
    @NSManaged public var members: Set<User>
    @NSManaged public var challenges: Set<Challenge>
    @NSManaged public var leaderboardEntries: Set<LeaderboardEntry>
}

@objc(Challenge)
public class Challenge: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var description: String?
    @NSManaged public var category: String // "fitness", "screen_time", "sleep", "social", "custom"
    @NSManaged public var frequency: String // "daily", "weekly", "custom"
    @NSManaged public var targetValue: Double
    @NSManaged public var targetUnit: String // "minutes", "hours", "count", "time"
    @NSManaged public var verificationMethod: String // "location", "motion", "health", "screen_time", "camera"
    @NSManaged public var verificationParams: Data // JSON parameters
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var pointsReward: Int32
    @NSManaged public var pointsPenalty: Int32
    @NSManaged public var createdBy: User
    @NSManaged public var circle: Circle
    @NSManaged public var proofs: Set<Proof>
}

@objc(Proof)
public class Proof: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var challenge: Challenge
    @NSManaged public var user: User
    @NSManaged public var timestamp: Date
    @NSManaged public var isVerified: Bool
    @NSManaged public var verificationData: Data? // JSON with sensor data
    @NSManaged public var verificationMethod: String
    @NSManaged public var pointsAwarded: Int32
    @NSManaged public var notes: String?
}

@objc(HangoutSession)
public class HangoutSession: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var duration: Double // in minutes
    @NSManaged public var location: Data? // CLLocation JSON
    @NSManaged public var participants: Set<User>
    @NSManaged public var pointsAwarded: Int32
    @NSManaged public var isActive: Bool
}

@objc(LeaderboardEntry)
public class LeaderboardEntry: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var user: User
    @NSManaged public var circle: Circle
    @NSManaged public var weekStartDate: Date
    @NSManaged public var weekEndDate: Date
    @NSManaged public var weeklyPoints: Int32
    @NSManaged public var rank: Int32
    @NSManaged public var challengesCompleted: Int32
    @NSManaged public var hangoutMinutes: Double
}

@objc(WrappedStats)
public class WrappedStats: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var user: User
    @NSManaged public var year: Int32
    @NSManaged public var totalChallengesCompleted: Int32
    @NSManaged public var totalHangoutHours: Double
    @NSManaged public var topFriend: User?
    @NSManaged public var topLocation: String?
    @NSManaged public var longestStreak: Int32
    @NSManaged public var mostCommonActivity: String?
    @NSManaged public var generatedAt: Date
}

@objc(Membership)
public class Membership: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var role: String // "owner", "admin", "member"
    @NSManaged public var joinedAt: Date
    @NSManaged public var user: User
    @NSManaged public var circle: Circle
}

@objc(HangoutParticipant)
public class HangoutParticipant: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var joinedAt: Date
    @NSManaged public var leftAt: Date?
    @NSManaged public var durationSec: Int32
    @NSManaged public var user: User
    @NSManaged public var session: HangoutSession
}

@objc(ConsentLog)
public class ConsentLog: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var kind: String // "location_always", "motion", "health", "screen_time", etc.
    @NSManaged public var granted: Bool
    @NSManaged public var timestamp: Date
    @NSManaged public var user: User
}

@objc(Device)
public class Device: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var model: String
    @NSManaged public var osVersion: String
    @NSManaged public var lastSeenAt: Date
    @NSManaged public var user: User
}

@objc(ChallengeTemplate)
public class ChallengeTemplate: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var description: String?
    @NSManaged public var category: String
    @NSManaged public var frequency: String
    @NSManaged public var targetValue: Double
    @NSManaged public var targetUnit: String
    @NSManaged public var verificationMethod: String
    @NSManaged public var verificationParams: Data
    @NSManaged public var isPreset: Bool
    @NSManaged public var localizedTitle: String?
}
```

### JSON Structures for API/Debugging

```json
// Challenge Verification Parameters
{
  "location_challenge": {
    "target_location": {
      "latitude": 37.7749,
      "longitude": -122.4194,
      "radius_meters": 50,
      "name": "Gym"
    },
    "min_duration_minutes": 20
  },
  "motion_challenge": {
    "min_steps": 5000,
    "activity_type": "running",
    "time_window": "morning" // before 8 AM
  },
  "screen_time_challenge": {
    "max_hours": 2,
    "categories": ["social", "entertainment"]
  },
  "sleep_challenge": {
    "bedtime_before": "23:00",
    "wakeup_after": "07:00"
  }
}

// Proof Verification Data
{
  "proof_id": "uuid",
  "verification_method": "location",
  "sensor_data": {
    "location": {
      "latitude": 37.7749,
      "longitude": -122.4194,
      "accuracy": 5.0,
      "timestamp": "2024-01-15T10:30:00Z"
    },
    "duration_at_location": 25.5
  },
  "verification_result": {
    "is_verified": true,
    "confidence_score": 0.95,
    "verification_timestamp": "2024-01-15T10:55:00Z"
  }
}
```

---

## 🔧 2. **Framework Mapping**

| Feature | Apple Framework | Key Classes | Usage |
|---------|----------------|-------------|-------|
| **Location Tracking** | Core Location | `CLLocationManager`, `CLLocation` | Hangout detection, gym verification |
| **Proximity Detection** | Core Bluetooth (Optional) | `CBPeripheralManager`, `CBCentralManager` | Foreground-only friend proximity refinement |
| **Motion Verification** | Core Motion | `CMMotionManager`, `CMPedometer` | Steps, workouts, activity detection |
| **Screen Time** | DeviceActivity (Optional) | `DeviceActivityMonitor`, `DeviceActivityReport` | Daily usage tracking (requires entitlement) |
| **Health Data** | HealthKit | `HKHealthStore`, `HKWorkoutType` | Sleep, fitness, heart rate |
| **Live Camera** | AVFoundation | `AVCaptureSession`, `AVCapturePhotoOutput` | Proof check-ins |
| **Background Tasks** | BackgroundTasks | `BGTaskScheduler`, `BGAppRefreshTask` | Periodic verification |
| **Notifications** | UserNotifications | `UNUserNotificationCenter` | Challenge reminders |
| **Data Sync** | CloudKit | `CKContainer`, `CKRecord` | Multi-device sync |
| **Local Storage** | Core Data | `NSPersistentContainer` | On-device data |
| **Authentication** | AuthenticationServices | `ASAuthorizationAppleIDProvider` | Sign in with Apple |

---

## ⚡ 3. **Verification Logic**

### Verification Constants (iOS-Optimized)

```swift
enum Verify {
    // Hangout detection thresholds
    static let hangoutProximity = 10.0        // m (target)
    static let candidateBuffer = 15.0         // m (GPS buffer)
    static let hangoutPromote = 60.0          // s continuous candidate
    static let hangoutStale = 180.0           // s no updates
    static let hangoutMergeGap = 120.0        // s merge sessions
    
    // Location verification
    static let geofenceRadius = 75.0          // m default
    static let minDwellGym = 20.0             // min
    static let accThreshold = 50.0            // m required for credit
    static let locationAccuracyIdle = kCLLocationAccuracyHundredMeters
    static let locationAccuracyActive = kCLLocationAccuracyNearestTenMeters
    
    // Points and limits
    static let hangoutPtsPer5 = 5             // pts per 5 min
    static let dailyHangoutCapPts = 60        // max daily hangout points
    static let geofenceCooldownHours = 3.0    // hours between gym credits
    
    // Anti-cheat thresholds
    static let motionLocationMismatchMinutes = 10.0 // flag if GPS stationary but motion active
    static let clockTamperThreshold = 300.0   // s system uptime vs wall clock
    static let cameraLivenessFrames = 3        // frames for liveness check
}
```

### Challenge Evaluation with Anti-Cheat

```swift
class ChallengeVerificationEngine {
    
    func verifyChallenge(_ challenge: Challenge, for user: User) -> Proof {
        let proof = Proof(context: context)
        proof.challenge = challenge
        proof.user = user
        proof.timestamp = Date()
        
        // Anti-cheat: Check for clock tampering
        guard !isClockTampered() else {
            proof.isVerified = false
            proof.notes = "Clock tampering detected"
            return proof
        }
        
        switch challenge.verificationMethod {
        case "location":
            proof.isVerified = verifyLocationChallenge(challenge, user: user)
        case "motion":
            proof.isVerified = verifyMotionChallenge(challenge, user: user)
        case "screen_time":
            proof.isVerified = verifyScreenTimeChallenge(challenge, user: user)
        case "health":
            proof.isVerified = verifyHealthChallenge(challenge, user: user)
        case "camera":
            proof.isVerified = verifyCameraChallenge(challenge, user: user)
        default:
            proof.isVerified = false
        }
        
        proof.pointsAwarded = proof.isVerified ? challenge.pointsReward : -challenge.pointsPenalty
        return proof
    }
    
    private func isClockTampered() -> Bool {
        let systemUptime = ProcessInfo.processInfo.systemUptime
        let wallClockTime = Date().timeIntervalSince1970
        
        // Check if system uptime vs wall clock is suspiciously different
        let expectedUptime = wallClockTime - appLaunchTime
        let uptimeDifference = abs(systemUptime - expectedUptime)
        
        return uptimeDifference > Verify.clockTamperThreshold
    }
    
    private func verifyLocationChallenge(_ challenge: Challenge, user: User) -> Bool {
        let params = parseLocationParams(challenge.verificationParams)
        let userLocation = LocationManager.shared.currentLocation
        
        guard let targetLocation = params.targetLocation,
              let userLocation = userLocation else { return false }
        
        // Check location accuracy
        guard userLocation.horizontalAccuracy <= Verify.accThreshold else { return false }
        
        let distance = userLocation.distance(from: targetLocation)
        let durationAtLocation = LocationManager.shared.durationAtLocation(targetLocation)
        
        // Anti-cheat: Check for motion/location mismatch
        if isMotionLocationMismatch() {
            // Require camera verification for suspicious activity
            return false
        }
        
        // Check cooldown period for geofence challenges
        if let lastCredit = getLastGeofenceCredit(targetLocation) {
            let hoursSinceLastCredit = Date().timeIntervalSince(lastCredit) / 3600
            guard hoursSinceLastCredit >= Verify.geofenceCooldownHours else { return false }
        }
        
        return distance <= params.radiusMeters && 
               durationAtLocation >= params.minDurationMinutes
    }
    
    private func verifyMotionChallenge(_ challenge: Challenge, user: User) -> Bool {
        let params = parseMotionParams(challenge.verificationParams)
        let pedometerData = MotionManager.shared.getStepsForDate(Date())
        
        if let timeWindow = params.timeWindow {
            let currentHour = Calendar.current.component(.hour, from: Date())
            switch timeWindow {
            case "morning":
                guard currentHour < 8 else { return false }
            case "evening":
                guard currentHour >= 18 else { return false }
            default: break
            }
        }
        
        return pedometerData.stepCount >= params.minSteps
    }
    
    private func verifyScreenTimeChallenge(_ challenge: Challenge, user: User) -> Bool {
        // Check if DeviceActivity entitlement is available
        guard DeviceActivityManager.isEntitlementAvailable else {
            // Fallback to manual camera check-ins
            return false
        }
        
        let params = parseScreenTimeParams(challenge.verificationParams)
        let screenTimeData = DeviceActivityManager.shared.getDailyUsage()
        
        return screenTimeData.totalHours <= params.maxHours
    }
    
    private func verifyCameraChallenge(_ challenge: Challenge, user: User) -> Bool {
        // Implement liveness detection
        let capturedFrames = CameraManager.shared.captureLivenessFrames(count: Verify.cameraLivenessFrames)
        
        // Hash frames for verification (no storage)
        let frameHashes = capturedFrames.map { frame in
            frame.sha256Hash()
        }
        
        // Verify liveness (simplified - in production, use ML)
        return frameHashes.count == Verify.cameraLivenessFrames
    }
    
    private func isMotionLocationMismatch() -> Bool {
        let isStationary = LocationManager.shared.isStationary
        let isMoving = MotionManager.shared.isActivelyMoving
        
        // If GPS says stationary but motion says moving for extended period
        return isStationary && isMoving && 
               MotionManager.shared.motionDuration > Verify.motionLocationMismatchMinutes
    }
}
```

### Background Execution Strategy (iOS Reality)

```swift
class BackgroundTaskManager {
    
    func setupLocationDrivenBackground() {
        // Use Significant Location Change (SLC) for cheap wake-ups
        let locationManager = CLLocationManager()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Enable deferred updates for power efficiency
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // meters
        
        // Only escalate accuracy during candidate hangout windows
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(escalateLocationAccuracy),
            name: .hangoutCandidateDetected,
            object: nil
        )
    }
    
    @objc private func escalateLocationAccuracy() {
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10
        
        // Drop back to low accuracy after 5 minutes
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
            self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            self.locationManager.distanceFilter = 100
        }
    }
    
    func scheduleBackgroundTasks() {
        // Only use BGProcessing for heavy rollups (weekly snapshots)
        let weeklyRollupRequest = BGProcessingTaskRequest(identifier: "com.circle.weekly-rollup")
        weeklyRollupRequest.requiresNetworkConnectivity = true
        weeklyRollupRequest.requiresExternalPower = false
        
        try? BGTaskScheduler.shared.submit(weeklyRollupRequest)
        
        // BGAppRefresh is opportunistic - don't rely on fixed intervals
        let refreshRequest = BGAppRefreshTaskRequest(identifier: "com.circle.opportunistic-refresh")
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        try? BGTaskScheduler.shared.submit(refreshRequest)
    }
    
    func handleBackgroundAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Only do lightweight work in background refresh
        switch task.identifier {
        case "com.circle.opportunistic-refresh":
            processPendingProofs { success in
                task.setTaskCompleted(success: success)
            }
        case "com.circle.weekly-rollup":
            generateWeeklyLeaderboards { success in
                task.setTaskCompleted(success: success)
            }
        default:
            task.setTaskCompleted(success: false)
        }
    }
}
```

---

## 💾 4. **Sync and Storage**

### Core Data Model Diagram

```
User (1) ←→ (N) Circle
User (1) ←→ (N) Challenge [createdBy]
User (1) ←→ (N) Proof
User (1) ←→ (N) HangoutSession
User (1) ←→ (N) LeaderboardEntry
User (1) ←→ (1) WrappedStats

Circle (1) ←→ (N) Challenge
Circle (1) ←→ (N) LeaderboardEntry

Challenge (1) ←→ (N) Proof
```

### CloudKit Container Design with Notifications

```swift
// CloudKit Record Types
struct CloudKitRecordTypes {
    static let user = "User"
    static let circle = "Circle"
    static let challenge = "Challenge"
    static let proof = "Proof"
    static let hangoutSession = "HangoutSession"
    static let leaderboardEntry = "LeaderboardEntry"
    static let membership = "Membership"
    static let hangoutParticipant = "HangoutParticipant"
}

// Record Zones
struct CloudKitZones {
    static let privateZone = CKRecordZone(zoneName: "CirclePrivate")
    static let sharedZone = CKRecordZone(zoneName: "CircleShared")
}

// CloudKit Subscriptions for Real-time Updates
class CloudKitSubscriptionManager {
    
    func setupSubscriptions() {
        // Subscribe to shared record changes
        let challengeSubscription = CKQuerySubscription(
            recordType: CloudKitRecordTypes.challenge,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let proofSubscription = CKQuerySubscription(
            recordType: CloudKitRecordTypes.proof,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let hangoutSubscription = CKQuerySubscription(
            recordType: CloudKitRecordTypes.hangoutSession,
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        // Configure notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Circle activity detected"
        notificationInfo.shouldBadge = true
        notificationInfo.soundName = "default"
        
        challengeSubscription.notificationInfo = notificationInfo
        proofSubscription.notificationInfo = notificationInfo
        hangoutSubscription.notificationInfo = notificationInfo
        
        // Save subscriptions
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [
            challengeSubscription, proofSubscription, hangoutSubscription
        ])
        
        CKContainer.default().sharedCloudDatabase.add(operation)
    }
    
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        switch notification.notificationType {
        case .query:
            if let queryNotification = notification as? CKQueryNotification {
                handleQueryNotification(queryNotification)
            }
        default:
            break
        }
    }
    
    private func handleQueryNotification(_ notification: CKQueryNotification) {
        // Process the notification and update local data
        switch notification.recordType {
        case CloudKitRecordTypes.challenge:
            fetchUpdatedChallenge(recordID: notification.recordID)
        case CloudKitRecordTypes.proof:
            fetchUpdatedProof(recordID: notification.recordID)
        case CloudKitRecordTypes.hangoutSession:
            fetchUpdatedHangoutSession(recordID: notification.recordID)
        default:
            break
        }
    }
}

// Sharing Configuration
class CloudKitSharingManager {
    func shareCircle(_ circle: Circle, with users: [User]) {
        let share = CKShare(rootRecord: circle.ckRecord)
        share[CKShare.SystemFieldKey.title] = circle.name
        
        // Add participants
        for user in users {
            let participant = CKShare.Participant()
            participant.userIdentity = CKUserIdentity(lookupInfo: CKUserIdentity.LookupInfo(emailAddress: user.email))
            participant.permission = .readWrite
            share.addParticipant(participant)
        }
        
        let operation = CKModifyRecordsOperation(recordsToSave: [circle.ckRecord, share])
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { result in
            // Handle sharing result
        }
        
        CKContainer.default().privateCloudDatabase.add(operation)
    }
}
```

### Offline Caching Rules

```swift
class DataSyncManager {
    
    func syncStrategy() {
        // Critical data (always cached)
        cacheUsers()
        cacheActiveChallenges()
        cacheRecentProofs()
        
        // Background sync (when connected)
        syncLeaderboards()
        syncHangoutSessions()
        syncWrappedStats()
    }
    
    func handleOfflineMode() {
        // Store pending proofs locally
        // Queue sync operations
        // Show offline indicators
    }
}
```

---

## 🔐 5. **Permissions Matrix**

| Permission | Framework | When Requested | NSUsageDescription |
|------------|-----------|----------------|-------------------|
| **Location Always** | Core Location | After demonstrating value | "Circle needs your location to detect 5-minute hangouts with friends you've added and verify gym visits." |
| **Location When In Use** | Core Location | Onboarding | "Circle uses your location to verify that you visited your saved gym location for at least 20 minutes." |
| **Motion & Fitness** | Core Motion | Onboarding | "Circle tracks your steps and workouts to verify runs and walks you choose to track." |
| **Health Data** | HealthKit | Optional setup | "Circle can verify sleep-before-11-pm goals you explicitly enable using your Health app data." |
| **Screen Time** | DeviceActivity | Optional setup | "Circle verifies screen time challenges using your device usage data (requires Apple entitlement)." |
| **Camera** | AVFoundation | First forfeit | "Circle uses your camera for live proof check-ins and forfeit challenges." |
| **Bluetooth** | Core Bluetooth | Optional (foreground only) | "Circle uses Bluetooth to refine proximity detection when both friends have the app open." |
| **Notifications** | UserNotifications | Onboarding | "Circle sends reminders for active challenges and hangout notifications." |
| **Background App Refresh** | BackgroundTasks | Settings | "Circle verifies challenges and detects hangouts in the background." |

### Apple-Friendly Permission Request Flow

```swift
class PermissionManager {
    
    func requestPermissionsProgressive() async -> PermissionStatus {
        // Step 1: Request When-In-Use location first
        let whenInUseGranted = await requestLocationWhenInUse()
        
        if !whenInUseGranted {
            return .locationDenied
        }
        
        // Step 2: Request motion permission
        let motionGranted = await requestMotionPermission()
        
        // Step 3: Request notifications
        let notificationsGranted = await requestNotificationPermission()
        
        // Step 4: Show value, then request Always location
        if whenInUseGranted {
            await demonstrateLocationValue()
            let alwaysGranted = await requestLocationAlways()
            
            if alwaysGranted {
                return .fullAccess
            } else {
                return .degradedMode // Manual check-ins only
            }
        }
        
        return .partialAccess
    }
    
    private func requestLocationWhenInUse() async -> Bool {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        
        return manager.authorizationStatus == .authorizedWhenInUse
    }
    
    private func requestLocationAlways() async -> Bool {
        let manager = CLLocationManager()
        manager.requestAlwaysAuthorization()
        
        return manager.authorizationStatus == .authorizedAlways
    }
    
    private func demonstrateLocationValue() async {
        // Show immediate benefit: detect nearby friends
        let nearbyFriends = await detectNearbyFriends()
        if !nearbyFriends.isEmpty {
            showNotification("Found \(nearbyFriends.count) friends nearby!")
        }
    }
    
    private func requestMotionPermission() async -> Bool {
        return CMPedometer.isStepCountingAvailable()
    }
    
    private func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        return granted ?? false
    }
    
    // Handle permission denials gracefully
    func handlePermissionDenial(_ permission: PermissionType) {
        switch permission {
        case .location:
            showDegradedModeExplanation()
            enableManualCheckIns()
        case .motion:
            showManualStepEntry()
        case .notifications:
            showInAppReminders()
        case .camera:
            showAlternativeForfeits()
        }
    }
    
    private func showDegradedModeExplanation() {
        // Explain that hangout detection won't work, but manual check-ins will
        let alert = UIAlertController(
            title: "Manual Mode",
            message: "Without location access, you'll need to manually check in for challenges. You can still participate in all other features!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        // Present alert
    }
}

enum PermissionStatus {
    case fullAccess
    case partialAccess
    case degradedMode
    case locationDenied
}

enum PermissionType {
    case location
    case motion
    case notifications
    case camera
}
```

---

## 🏗️ 6. **App Architecture**

### View Hierarchy (SwiftUI + MVVM)

```
CircleApp
├── OnboardingView
│   ├── WelcomeView
│   ├── PermissionsView
│   └── CircleSetupView
├── MainTabView
│   ├── HomeView
│   │   ├── ActiveChallengesView
│   │   ├── RecentProofsView
│   │   └── QuickActionsView
│   ├── CirclesView
│   │   ├── MyCirclesView
│   │   ├── CreateCircleView
│   │   └── JoinCircleView
│   ├── LeaderboardView
│   │   ├── WeeklyRankingView
│   │   ├── AllTimeStatsView
│   │   └── FriendComparisonView
│   ├── ChallengesView
│   │   ├── CreateChallengeView
│   │   ├── ChallengeDetailView
│   │   └── ChallengeHistoryView
│   └── ProfileView
│       ├── UserStatsView
│       ├── SettingsView
│       └── WrappedView
└── CameraView (Modal)
    ├── LiveCameraView
    ├── ProofCaptureView
    └── ForfeitView
```

### Module Boundaries

```swift
// MARK: - Core Modules

class LocationManager: ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var isTrackingHangouts: Bool = false
    
    func startHangoutTracking() { }
    func stopHangoutTracking() { }
    func verifyLocationChallenge(_ challenge: Challenge) -> Bool { }
}

class ChallengeEngine: ObservableObject {
    @Published var activeChallenges: [Challenge] = []
    @Published var recentProofs: [Proof] = []
    
    func createChallenge(_ challenge: Challenge) { }
    func verifyChallenge(_ challenge: Challenge) -> Proof { }
    func getChallengeProgress(_ challenge: Challenge) -> Double { }
}

class ProofCamera: ObservableObject {
    @Published var isCapturing: Bool = false
    @Published var capturedImage: UIImage?
    
    func startLiveCapture() { }
    func captureProof() { }
    func processForfeit() { }
}

class PointsEngine: ObservableObject {
    @Published var userPoints: Int = 0
    @Published var weeklyPoints: Int = 0
    
    func awardPoints(_ amount: Int, for action: String) { }
    func calculateWeeklyRanking() -> [LeaderboardEntry] { }
    func resetWeeklyPoints() { }
}

class HangoutDetector: ObservableObject {
    @Published var activeHangouts: [HangoutSession] = []
    @Published var nearbyFriends: [User] = []
    
    func startProximityDetection() { }
    func detectHangoutSession() -> HangoutSession? { }
    func endHangoutSession(_ session: HangoutSession) { }
}
```

### Notification & Background Refresh Flow

```swift
class NotificationManager {
    
    func scheduleChallengeReminders() {
        for challenge in activeChallenges {
            let content = UNMutableNotificationContent()
            content.title = "Challenge Reminder"
            content.body = "Don't forget: \(challenge.title)"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
            let request = UNNotificationRequest(identifier: challenge.id.uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func handleBackgroundRefresh() {
        // Verify active challenges
        // Detect new hangouts
        // Update leaderboards
        // Sync with CloudKit
    }
}
```

---

## ⚙️ 7. **Build Setup**

### Minimum Requirements

```swift
// iOS Deployment Target
// Minimum: iOS 16.0
// Target: iOS 17.0+

// Required Capabilities
// - Background Modes: Background App Refresh, Background Processing
// - HealthKit
// - Core Location (Always)
// - Bluetooth LE
// - Camera
// - Push Notifications
```

### Environment Configuration

```swift
// Build Configuration
struct BuildConfiguration {
    static let isDebug: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    static let cloudKitContainer: String = {
        #if DEBUG
        return "iCloud.com.circle.debug"
        #else
        return "iCloud.com.circle.production"
        #endif
    }()
    
    static let apiBaseURL: String = {
        #if DEBUG
        return "https://api-dev.circle.app"
        #else
        return "https://api.circle.app"
        #endif
    }()
}
```

### Test Harness Checklist

```swift
// Testing Infrastructure
class TestHarness {
    
    // ✅ Unit Tests
    func testChallengeVerification() { }
    func testPointsCalculation() { }
    func testHangoutDetection() { }
    func testAntiCheatHeuristics() { }
    func testClockTamperDetection() { }
    
    // ✅ Integration Tests
    func testLocationVerification() { }
    func testMotionTracking() { }
    func testCloudKitSync() { }
    func testScreenTimeFallback() { }
    func testBLEForegroundOnly() { }
    
    // ✅ UI Tests
    func testOnboardingFlow() { }
    func testChallengeCreation() { }
    func testCameraCapture() { }
    func testPermissionDenialHandling() { }
    func testDegradedModeUI() { }
    
    // ✅ Performance Tests
    func testBackgroundTaskPerformance() { }
    func testLocationUpdateFrequency() { }
    func testBatteryUsage() { }
    func testLowPowerModeBehavior() { }
    
    // ✅ Field Tests (Critical for iOS)
    func testUrbanCanyonAccuracy() {
        // Test GPS accuracy in downtown areas
        // Verify hangout detection works with poor GPS
    }
    
    func testTimeChangeScenarios() {
        // Test manual clock changes
        // Test timezone switches
        // Verify system uptime vs wall clock
    }
    
    func testOfflineScenarios() {
        // Test airplane mode behavior
        // Test no-service areas
        // Verify offline data persistence
    }
    
    func testTwoDeviceEdgeCases() {
        // Test friends walking apart then back together
        // Test merge/split scenarios within 2 minutes
        // Verify hangout session continuity
    }
    
    func testPermissionEdgeCases() {
        // Test partial permission grants
        // Test permission revocation during use
        // Test degraded mode functionality
    }
    
    func testAppReviewScenarios() {
        // Test with minimal permissions
        // Test with denied permissions
        // Verify graceful degradation
        // Test privacy compliance
    }
}
```

### Required Info.plist Entries (App Review Ready)

```xml
<!-- Info.plist -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Circle needs your location to detect 5-minute hangouts with friends you've added and verify gym visits.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Circle uses your location to verify that you visited your saved gym location for at least 20 minutes.</string>

<key>NSLocationTemporaryUsageDescriptionDictionary</key>
<dict>
    <key>PreciseLocation</key>
    <string>Verify a nearby hangout more accurately for the next 15 minutes.</string>
</dict>

<key>NSMotionUsageDescription</key>
<string>Circle tracks your steps and workouts to verify runs and walks you choose to track.</string>

<key>NSCameraUsageDescription</key>
<string>Circle uses your camera for live proof check-ins and forfeit challenges.</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Circle uses Bluetooth to refine proximity detection when both friends have the app open.</string>

<key>NSHealthShareUsageDescription</key>
<string>Circle can verify sleep-before-11-pm goals you explicitly enable using your Health app data.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Circle can update your Health app with verified fitness activities.</string>

<key>UIBackgroundModes</key>
<array>
    <string>background-app-refresh</string>
    <string>background-processing</string>
    <string>location</string>
</array>

<key>NSHealthKitUsageDescription</key>
<string>Circle integrates with HealthKit to verify fitness and sleep challenges.</string>

<!-- Screen Time API (Optional - requires entitlement) -->
<key>NSDeviceActivityUsageDescription</key>
<string>Circle verifies screen time challenges using your device usage data.</string>
```

---

## 🚀 **Implementation Priority (iOS Reality)**

### Phase 1 (MVP - 4 weeks)
1. Core Data models + CloudKit setup with subscriptions
2. Basic authentication (Sign in with Apple)
3. Location tracking with Significant Location Change
4. Simple challenge creation and verification
5. Basic leaderboard
6. Progressive permission flow
7. Anti-cheat heuristics (clock tampering, motion/location mismatch)

### Phase 2 (Core Features - 6 weeks)
1. Motion tracking and verification
2. Camera proof system with liveness detection
3. Points engine and forfeits
4. CloudKit push notifications
5. Background task optimization (BGProcessing only)
6. Screen Time fallback system
7. Degraded mode handling

### Phase 3 (Polish - 4 weeks)
1. Screen Time API integration (if entitlement granted)
2. HealthKit integration
3. Circle Wrapped feature
4. Performance optimization
5. Field testing (urban canyon, time changes, offline)
6. App Review preparation
7. App Store submission

### Phase 4 (Future - Optional)
1. BLE proximity refinement (foreground only)
2. UWB + MultipeerConnectivity for sub-10m detection
3. Advanced ML for camera liveness
4. Sponsored challenges integration

---

**Ready to start coding! 🎯**

This technical handoff provides everything your development team needs to begin implementation immediately. Each section includes concrete code examples, data structures, and implementation guidelines.
