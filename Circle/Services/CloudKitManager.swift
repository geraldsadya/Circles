//
//  CloudKitManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CloudKit
import CoreData

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer(identifier: "iCloud.com.circle.app")
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    @Published var isSignedIn = false
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    
    private init() {
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        checkAccountStatus()
    }
    
    // MARK: - Account Status
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.accountStatus = status
                self?.isSignedIn = (status == .available)
                
                if let error = error {
                    print("CloudKit account status error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - CloudKit Subscriptions
    func setupSubscriptions() {
        setupChallengeSubscription()
        setupProofSubscription()
        setupHangoutSubscription()
        setupForfeitSubscription()
    }
    
    private func setupChallengeSubscription() {
        let subscription = CKQuerySubscription(
            recordType: "Challenge",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "New challenge in your circle!"
        notificationInfo.shouldBadge = true
        notificationInfo.soundName = "default"
        
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("Challenge subscription created successfully")
            case .failure(let error):
                print("Failed to create challenge subscription: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    private func setupProofSubscription() {
        let subscription = CKQuerySubscription(
            recordType: "Proof",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Challenge result updated!"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("Proof subscription created successfully")
            case .failure(let error):
                print("Failed to create proof subscription: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    private func setupHangoutSubscription() {
        let subscription = CKQuerySubscription(
            recordType: "HangoutSession",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "Hangout detected with friends!"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("Hangout subscription created successfully")
            case .failure(let error):
                print("Failed to create hangout subscription: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    private func setupForfeitSubscription() {
        let subscription = CKQuerySubscription(
            recordType: "Forfeit",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "New forfeit assigned!"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("Forfeit subscription created successfully")
            case .failure(let error):
                print("Failed to create forfeit subscription: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    // MARK: - Remote Notification Handling
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        switch notification.notificationType {
        case .query:
            if let queryNotification = notification as? CKQueryNotification {
                handleQueryNotification(queryNotification)
            }
        case .database:
            if let databaseNotification = notification as? CKDatabaseNotification {
                handleDatabaseNotification(databaseNotification)
            }
        default:
            break
        }
    }
    
    private func handleQueryNotification(_ notification: CKQueryNotification) {
        // Process the notification and update local data
        switch notification.recordType {
        case "Challenge":
            fetchUpdatedChallenge(recordID: notification.recordID)
        case "Proof":
            fetchUpdatedProof(recordID: notification.recordID)
        case "HangoutSession":
            fetchUpdatedHangoutSession(recordID: notification.recordID)
        case "Forfeit":
            fetchUpdatedForfeit(recordID: notification.recordID)
        default:
            break
        }
    }
    
    private func handleDatabaseNotification(_ notification: CKDatabaseNotification) {
        // Handle database-level changes
        print("Database notification received")
    }
    
    // MARK: - Record Fetching
    private func fetchUpdatedChallenge(recordID: CKRecord.ID) {
        let operation = CKFetchRecordsOperation(recordIDs: [recordID])
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success(let records):
                if let record = records[recordID] {
                    self.processChallengeRecord(record)
                }
            case .failure(let error):
                print("Failed to fetch challenge record: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    private func fetchUpdatedProof(recordID: CKRecord.ID) {
        let operation = CKFetchRecordsOperation(recordIDs: [recordID])
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success(let records):
                if let record = records[recordID] {
                    self.processProofRecord(record)
                }
            case .failure(let error):
                print("Failed to fetch proof record: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    private func fetchUpdatedHangoutSession(recordID: CKRecord.ID) {
        let operation = CKFetchRecordsOperation(recordIDs: [recordID])
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success(let records):
                if let record = records[recordID] {
                    self.processHangoutSessionRecord(record)
                }
            case .failure(let error):
                print("Failed to fetch hangout session record: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    private func fetchUpdatedForfeit(recordID: CKRecord.ID) {
        let operation = CKFetchRecordsOperation(recordIDs: [recordID])
        operation.fetchRecordsResultBlock = { result in
            switch result {
            case .success(let records):
                if let record = records[recordID] {
                    self.processForfeitRecord(record)
                }
            case .failure(let error):
                print("Failed to fetch forfeit record: \(error.localizedDescription)")
            }
        }
        
        sharedDatabase.add(operation)
    }
    
    // MARK: - Record Processing
    private func processChallengeRecord(_ record: CKRecord) {
        // Update local Core Data with the new challenge
        DispatchQueue.main.async {
            // This will be implemented when we have the full Core Data integration
            print("Processing challenge record: \(record.recordID)")
        }
    }
    
    private func processProofRecord(_ record: CKRecord) {
        // Update local Core Data with the new proof
        DispatchQueue.main.async {
            print("Processing proof record: \(record.recordID)")
        }
    }
    
    private func processHangoutSessionRecord(_ record: CKRecord) {
        // Update local Core Data with the new hangout session
        DispatchQueue.main.async {
            print("Processing hangout session record: \(record.recordID)")
        }
    }
    
    private func processForfeitRecord(_ record: CKRecord) {
        // Update local Core Data with the new forfeit
        DispatchQueue.main.async {
            print("Processing forfeit record: \(record.recordID)")
        }
    }
    
    // MARK: - Sharing
    func shareCircle(_ circle: Circle, with users: [User]) {
        // This will be implemented when we have the full Core Data integration
        print("Sharing circle with users")
    }
    
    // MARK: - Sync Status
    func getSyncStatus() -> String {
        switch accountStatus {
        case .available:
            return "Synced"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - CloudKit Record Types
struct CloudKitRecordTypes {
    static let user = "User"
    static let circle = "Circle"
    static let membership = "Membership"
    static let challenge = "Challenge"
    static let challengeTemplate = "ChallengeTemplate"
    static let proof = "Proof"
    static let hangoutSession = "HangoutSession"
    static let hangoutParticipant = "HangoutParticipant"
    static let leaderboardEntry = "LeaderboardEntry"
    static let wrappedStats = "WrappedStats"
    static let consentLog = "ConsentLog"
    static let device = "Device"
    static let forfeit = "Forfeit"
    static let pointsLedger = "PointsLedger"
}

// MARK: - CloudKit Zones
struct CloudKitZones {
    static let privateZone = CKRecordZone(zoneName: "CirclePrivate")
    static let sharedZone = CKRecordZone(zoneName: "CircleShared")
}
