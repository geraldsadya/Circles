//
//  CloudKitSubscriptionManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CloudKit
import CoreData
import Combine

@MainActor
class CloudKitSubscriptionManager: ObservableObject {
    static let shared = CloudKitSubscriptionManager()
    
    @Published var isSubscribed = false
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var lastSyncDate: Date?
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let cloudKitManager = CloudKitManager.shared
    private let notificationManager = NotificationManager.shared
    
    // CloudKit containers
    private let privateContainer: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // Subscription identifiers
    private let challengeSubscriptionID = "challenge-updates"
    private let forfeitSubscriptionID = "forfeit-updates"
    private let hangoutSubscriptionID = "hangout-updates"
    private let leaderboardSubscriptionID = "leaderboard-updates"
    private let proofSubscriptionID = "proof-updates"
    private let pointsSubscriptionID = "points-updates"
    
    // Subscription state
    private var activeSubscriptions: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    
    private init() {
        self.privateContainer = CKContainer.default()
        self.privateDatabase = privateContainer.privateCloudDatabase
        self.sharedDatabase = privateContainer.sharedCloudDatabase
        
        setupSubscriptions()
        setupNotifications()
        startSyncTimer()
    }
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        Task {
            await createAllSubscriptions()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteNotification),
            name: .CKRemoteNotificationReceived,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountStatusChanged),
            name: .CKAccountStatusDidChange,
            object: nil
        )
    }
    
    private func startSyncTimer() {
        // Sync every 5 minutes
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncWithCloudKit()
            }
        }
    }
    
    // MARK: - Subscription Creation
    private func createAllSubscriptions() async {
        do {
            // Create subscriptions for private database
            try await createPrivateSubscriptions()
            
            // Create subscriptions for shared database
            try await createSharedSubscriptions()
            
            await MainActor.run {
                isSubscribed = true
                subscriptionStatus = .active
            }
            
            print("All CloudKit subscriptions created successfully")
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create subscriptions: \(error.localizedDescription)"
                subscriptionStatus = .failed
            }
            print("Error creating subscriptions: \(error)")
        }
    }
    
    private func createPrivateSubscriptions() async throws {
        // Challenge subscription
        try await createChallengeSubscription()
        
        // Forfeit subscription
        try await createForfeitSubscription()
        
        // Hangout subscription
        try await createHangoutSubscription()
        
        // Proof subscription
        try await createProofSubscription()
        
        // Points subscription
        try await createPointsSubscription()
    }
    
    private func createSharedSubscriptions() async throws {
        // Leaderboard subscription
        try await createLeaderboardSubscription()
    }
    
    // MARK: - Individual Subscriptions
    private func createChallengeSubscription() async throws {
        let predicate = NSPredicate(value: true) // All challenges
        
        let subscription = CKQuerySubscription(
            recordType: "Challenge",
            predicate: predicate,
            subscriptionID: challengeSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Challenge updated in your circle"
        notificationInfo.soundName = "default"
        notificationInfo.shouldBadge = true
        notificationInfo.category = "CHALLENGE_CATEGORY"
        
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
        activeSubscriptions.insert(challengeSubscriptionID)
        
        print("Challenge subscription created")
    }
    
    private func createForfeitSubscription() async throws {
        let predicate = NSPredicate(value: true) // All forfeits
        
        let subscription = CKQuerySubscription(
            recordType: "Forfeit",
            predicate: predicate,
            subscriptionID: forfeitSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "New forfeit assigned to you"
        notificationInfo.soundName = "default"
        notificationInfo.shouldBadge = true
        notificationInfo.category = "FORFEIT_CATEGORY"
        
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
        activeSubscriptions.insert(forfeitSubscriptionID)
        
        print("Forfeit subscription created")
    }
    
    private func createHangoutSubscription() async throws {
        let predicate = NSPredicate(value: true) // All hangouts
        
        let subscription = CKQuerySubscription(
            recordType: "HangoutSession",
            predicate: predicate,
            subscriptionID: hangoutSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Hangout detected with friends"
        notificationInfo.soundName = "default"
        notificationInfo.shouldBadge = true
        notificationInfo.category = "HANGOUT_CATEGORY"
        
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
        activeSubscriptions.insert(hangoutSubscriptionID)
        
        print("Hangout subscription created")
    }
    
    private func createProofSubscription() async throws {
        let predicate = NSPredicate(value: true) // All proofs
        
        let subscription = CKQuerySubscription(
            recordType: "Proof",
            predicate: predicate,
            subscriptionID: proofSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Proof verification completed"
        notificationInfo.soundName = "default"
        notificationInfo.shouldBadge = true
        notificationInfo.category = "PROOF_CATEGORY"
        
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
        activeSubscriptions.insert(proofSubscriptionID)
        
        print("Proof subscription created")
    }
    
    private func createPointsSubscription() async throws {
        let predicate = NSPredicate(value: true) // All points
        
        let subscription = CKQuerySubscription(
            recordType: "PointsLedger",
            predicate: predicate,
            subscriptionID: pointsSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Points updated"
        notificationInfo.soundName = "default"
        notificationInfo.shouldBadge = true
        notificationInfo.category = "POINTS_CATEGORY"
        
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
        activeSubscriptions.insert(pointsSubscriptionID)
        
        print("Points subscription created")
    }
    
    private func createLeaderboardSubscription() async throws {
        let predicate = NSPredicate(value: true) // All leaderboard entries
        
        let subscription = CKQuerySubscription(
            recordType: "LeaderboardEntry",
            predicate: predicate,
            subscriptionID: leaderboardSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Leaderboard updated"
        notificationInfo.soundName = "default"
        notificationInfo.shouldBadge = true
        notificationInfo.category = "LEADERBOARD_CATEGORY"
        
        subscription.notificationInfo = notificationInfo
        
        try await sharedDatabase.save(subscription)
        activeSubscriptions.insert(leaderboardSubscriptionID)
        
        print("Leaderboard subscription created")
    }
    
    // MARK: - Remote Notification Handling
    @objc private func handleRemoteNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        Task {
            await processRemoteNotification(userInfo)
        }
    }
    
    private func processRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            print("Invalid CloudKit notification")
            return
        }
        
        switch ckNotification.notificationType {
        case .query:
            await handleQueryNotification(ckNotification as! CKQueryNotification)
        case .recordZone:
            await handleRecordZoneNotification(ckNotification as! CKRecordZoneNotification)
        case .database:
            await handleDatabaseNotification(ckNotification as! CKDatabaseNotification)
        default:
            print("Unknown notification type: \(ckNotification.notificationType)")
        }
    }
    
    private func handleQueryNotification(_ notification: CKQueryNotification) async {
        guard let recordID = notification.recordID else { return }
        
        let recordType = notification.recordType ?? "Unknown"
        
        switch recordType {
        case "Challenge":
            await handleChallengeUpdate(recordID: recordID, notification: notification)
        case "Forfeit":
            await handleForfeitUpdate(recordID: recordID, notification: notification)
        case "HangoutSession":
            await handleHangoutUpdate(recordID: recordID, notification: notification)
        case "Proof":
            await handleProofUpdate(recordID: recordID, notification: notification)
        case "PointsLedger":
            await handlePointsUpdate(recordID: recordID, notification: notification)
        case "LeaderboardEntry":
            await handleLeaderboardUpdate(recordID: recordID, notification: notification)
        default:
            print("Unknown record type: \(recordType)")
        }
    }
    
    private func handleRecordZoneNotification(_ notification: CKRecordZoneNotification) async {
        // Handle record zone notifications
        print("Record zone notification received")
    }
    
    private func handleDatabaseNotification(_ notification: CKDatabaseNotification) async {
        // Handle database notifications
        print("Database notification received")
    }
    
    // MARK: - Record Update Handlers
    private func handleChallengeUpdate(recordID: CKRecord.ID, notification: CKQueryNotification) async {
        do {
            let record = try await privateDatabase.record(for: recordID)
            
            // Update local Core Data
            await updateLocalChallenge(record: record)
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .challengeUpdated,
                object: nil,
                userInfo: ["record": record]
            )
            
        } catch {
            print("Error handling challenge update: \(error)")
        }
    }
    
    private func handleForfeitUpdate(recordID: CKRecord.ID, notification: CKQueryNotification) async {
        do {
            let record = try await privateDatabase.record(for: recordID)
            
            // Update local Core Data
            await updateLocalForfeit(record: record)
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .forfeitUpdated,
                object: nil,
                userInfo: ["record": record]
            )
            
        } catch {
            print("Error handling forfeit update: \(error)")
        }
    }
    
    private func handleHangoutUpdate(recordID: CKRecord.ID, notification: CKQueryNotification) async {
        do {
            let record = try await privateDatabase.record(for: recordID)
            
            // Update local Core Data
            await updateLocalHangout(record: record)
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .hangoutUpdated,
                object: nil,
                userInfo: ["record": record]
            )
            
        } catch {
            print("Error handling hangout update: \(error)")
        }
    }
    
    private func handleProofUpdate(recordID: CKRecord.ID, notification: CKQueryNotification) async {
        do {
            let record = try await privateDatabase.record(for: recordID)
            
            // Update local Core Data
            await updateLocalProof(record: record)
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .proofUpdated,
                object: nil,
                userInfo: ["record": record]
            )
            
        } catch {
            print("Error handling proof update: \(error)")
        }
    }
    
    private func handlePointsUpdate(recordID: CKRecord.ID, notification: CKQueryNotification) async {
        do {
            let record = try await privateDatabase.record(for: recordID)
            
            // Update local Core Data
            await updateLocalPoints(record: record)
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .pointsUpdated,
                object: nil,
                userInfo: ["record": record]
            )
            
        } catch {
            print("Error handling points update: \(error)")
        }
    }
    
    private func handleLeaderboardUpdate(recordID: CKRecord.ID, notification: CKQueryNotification) async {
        do {
            let record = try await sharedDatabase.record(for: recordID)
            
            // Update local Core Data
            await updateLocalLeaderboard(record: record)
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .leaderboardUpdated,
                object: nil,
                userInfo: ["record": record]
            )
            
        } catch {
            print("Error handling leaderboard update: \(error)")
        }
    }
    
    // MARK: - Local Data Updates
    private func updateLocalChallenge(record: CKRecord) async {
        // Update local Core Data with CloudKit record
        // This would be implemented based on the specific Core Data model
        print("Updating local challenge: \(record.recordID)")
    }
    
    private func updateLocalForfeit(record: CKRecord) async {
        // Update local Core Data with CloudKit record
        print("Updating local forfeit: \(record.recordID)")
    }
    
    private func updateLocalHangout(record: CKRecord) async {
        // Update local Core Data with CloudKit record
        print("Updating local hangout: \(record.recordID)")
    }
    
    private func updateLocalProof(record: CKRecord) async {
        // Update local Core Data with CloudKit record
        print("Updating local proof: \(record.recordID)")
    }
    
    private func updateLocalPoints(record: CKRecord) async {
        // Update local Core Data with CloudKit record
        print("Updating local points: \(record.recordID)")
    }
    
    private func updateLocalLeaderboard(record: CKRecord) async {
        // Update local Core Data with CloudKit record
        print("Updating local leaderboard: \(record.recordID)")
    }
    
    // MARK: - Sync Management
    private func syncWithCloudKit() async {
        guard isSubscribed else { return }
        
        do {
            // Sync local changes to CloudKit
            await syncLocalChangesToCloudKit()
            
            // Sync CloudKit changes to local
            await syncCloudKitChangesToLocal()
            
            await MainActor.run {
                lastSyncDate = Date()
            }
            
        } catch {
            print("Error syncing with CloudKit: \(error)")
        }
    }
    
    private func syncLocalChangesToCloudKit() async {
        // Sync local changes to CloudKit
        // This would be implemented based on the specific sync strategy
        print("Syncing local changes to CloudKit")
    }
    
    private func syncCloudKitChangesToLocal() async {
        // Sync CloudKit changes to local
        // This would be implemented based on the specific sync strategy
        print("Syncing CloudKit changes to local")
    }
    
    // MARK: - Account Status Handling
    @objc private func handleAccountStatusChanged(_ notification: Notification) {
        Task {
            await checkAccountStatus()
        }
    }
    
    private func checkAccountStatus() async {
        do {
            let status = try await privateContainer.accountStatus()
            
            await MainActor.run {
                switch status {
                case .available:
                    subscriptionStatus = .active
                    isSubscribed = true
                case .noAccount:
                    subscriptionStatus = .noAccount
                    isSubscribed = false
                case .restricted:
                    subscriptionStatus = .restricted
                    isSubscribed = false
                case .couldNotDetermine:
                    subscriptionStatus = .unknown
                    isSubscribed = false
                @unknown default:
                    subscriptionStatus = .unknown
                    isSubscribed = false
                }
            }
            
        } catch {
            await MainActor.run {
                subscriptionStatus = .failed
                isSubscribed = false
                errorMessage = "Failed to check account status: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Subscription Management
    func deleteAllSubscriptions() async {
        do {
            // Delete private database subscriptions
            let privateSubscriptions = try await privateDatabase.allSubscriptions()
            for subscription in privateSubscriptions {
                try await privateDatabase.deleteSubscription(withID: subscription.subscriptionID)
            }
            
            // Delete shared database subscriptions
            let sharedSubscriptions = try await sharedDatabase.allSubscriptions()
            for subscription in sharedSubscriptions {
                try await sharedDatabase.deleteSubscription(withID: subscription.subscriptionID)
            }
            
            await MainActor.run {
                isSubscribed = false
                subscriptionStatus = .inactive
                activeSubscriptions.removeAll()
            }
            
            print("All subscriptions deleted")
            
        } catch {
            print("Error deleting subscriptions: \(error)")
        }
    }
    
    func recreateSubscriptions() async {
        await deleteAllSubscriptions()
        await createAllSubscriptions()
    }
    
    // MARK: - Analytics
    func getSubscriptionStats() -> SubscriptionStats {
        return SubscriptionStats(
            isSubscribed: isSubscribed,
            subscriptionStatus: subscriptionStatus,
            activeSubscriptions: activeSubscriptions.count,
            lastSyncDate: lastSyncDate,
            totalSubscriptions: 6 // Total number of subscriptions we create
        )
    }
    
    // MARK: - Error Handling
    func handleSubscriptionError(_ error: Error) {
        print("Subscription error: \(error)")
        
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                subscriptionStatus = .noAccount
            case .quotaExceeded:
                subscriptionStatus = .quotaExceeded
            case .networkUnavailable:
                subscriptionStatus = .networkUnavailable
            default:
                subscriptionStatus = .failed
            }
        } else {
            subscriptionStatus = .failed
        }
        
        errorMessage = error.localizedDescription
    }
}

// MARK: - Supporting Types
enum SubscriptionStatus: String, CaseIterable {
    case unknown = "unknown"
    case active = "active"
    case inactive = "inactive"
    case failed = "failed"
    case noAccount = "no_account"
    case restricted = "restricted"
    case quotaExceeded = "quota_exceeded"
    case networkUnavailable = "network_unavailable"
    
    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .failed: return "Failed"
        case .noAccount: return "No Account"
        case .restricted: return "Restricted"
        case .quotaExceeded: return "Quota Exceeded"
        case .networkUnavailable: return "Network Unavailable"
        }
    }
    
    var isHealthy: Bool {
        return self == .active
    }
}

struct SubscriptionStats {
    let isSubscribed: Bool
    let subscriptionStatus: SubscriptionStatus
    let activeSubscriptions: Int
    let lastSyncDate: Date?
    let totalSubscriptions: Int
}

// MARK: - Notifications
extension Notification.Name {
    static let CKRemoteNotificationReceived = Notification.Name("CKRemoteNotificationReceived")
    static let CKAccountStatusDidChange = Notification.Name("CKAccountStatusDidChange")
    static let challengeUpdated = Notification.Name("challengeUpdated")
    static let forfeitUpdated = Notification.Name("forfeitUpdated")
    static let hangoutUpdated = Notification.Name("hangoutUpdated")
    static let proofUpdated = Notification.Name("proofUpdated")
    static let pointsUpdated = Notification.Name("pointsUpdated")
    static let leaderboardUpdated = Notification.Name("leaderboardUpdated")
}
