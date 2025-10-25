//
//  CloudKitSharingManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CloudKit
import Combine
import CoreData

@MainActor
class CloudKitSharingManager: ObservableObject {
    static let shared = CloudKitSharingManager()
    
    @Published var isSharingEnabled: Bool = false
    @Published var sharedCircles: [SharedCircle] = []
    @Published var pendingInvitations: [CircleInvitation] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let cloudKitManager = CloudKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // CloudKit containers
    private let privateContainer = CKContainer.default()
    private let sharedContainer = CKContainer.default()
    
    init() {
        setupCloudKitSharing()
        setupNotifications()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupCloudKitSharing() {
        // Check if user is signed in to iCloud
        privateContainer.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "iCloud error: \(error.localizedDescription)"
                    return
                }
                
                switch status {
                case .available:
                    self?.isSharingEnabled = true
                    self?.loadSharedCircles()
                case .noAccount:
                    self?.errorMessage = "Please sign in to iCloud to share circles"
                case .restricted:
                    self?.errorMessage = "iCloud sharing is restricted on this device"
                case .couldNotDetermine:
                    self?.errorMessage = "Could not determine iCloud status"
                @unknown default:
                    self?.errorMessage = "Unknown iCloud status"
                }
            }
        }
    }
    
    private func setupNotifications() {
        // Listen for CloudKit changes
        NotificationCenter.default.publisher(for: .CKDatabaseChanged)
            .sink { [weak self] notification in
                self?.handleCloudKitChange(notification)
            }
            .store(in: &cancellables)
        
        // Listen for circle updates
        NotificationCenter.default.publisher(for: .circleUpdated)
            .sink { [weak self] notification in
                if let circle = notification.userInfo?["circle"] as? Circle {
                    self?.syncCircleToCloudKit(circle)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Circle Sharing
    func shareCircle(_ circle: Circle, with users: [User]) async -> Bool {
        guard isSharingEnabled else {
            errorMessage = "CloudKit sharing is not available"
            return false
        }
        
        do {
            // Create CloudKit share
            let share = CKShare(rootRecord: circle.cloudKitRecord)
            share[CKShare.SystemFieldKey.title] = circle.name
            share.publicPermission = .none // Private sharing only
            
            // Add participants
            for user in users {
                let participant = CKShare.Participant()
                participant.userIdentity = CKUserIdentity(lookupInfo: CKUserIdentity.LookupInfo(emailAddress: user.email))
                participant.permission = .readWrite
                participant.acceptanceStatus = .pending
                share.participants.append(participant)
            }
            
            // Save share to CloudKit
            let operation = CKModifyRecordsOperation(recordsToSave: [circle.cloudKitRecord, share])
            operation.savePolicy = .changedKeys
            operation.qualityOfService = .userInitiated
            
            let (savedRecords, deletedRecordIDs, error) = await privateContainer.privateCloudDatabase.modifyRecords(saving: [circle.cloudKitRecord, share], deleting: [])
            
            if let error = error {
                self.errorMessage = "Failed to share circle: \(error.localizedDescription)"
                return false
            }
            
            // Create local invitation records
            await createInvitations(for: circle, users: users, share: share)
            
            print("✅ Circle '\(circle.name)' shared successfully")
            return true
            
        } catch {
            self.errorMessage = "Failed to share circle: \(error.localizedDescription)"
            return false
        }
    }
    
    func acceptCircleInvitation(_ invitation: CircleInvitation) async -> Bool {
        guard isSharingEnabled else { return false }
        
        do {
            // Accept the CloudKit share
            let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [invitation.shareMetadata])
            
            let (acceptedShares, errors) = await privateContainer.acceptShares(acceptOperation)
            
            if let error = errors.first {
                self.errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
                return false
            }
            
            // Update local invitation status
            await updateInvitationStatus(invitation, status: .accepted)
            
            // Load the shared circle
            await loadSharedCircle(from: acceptedShares.first!)
            
            print("✅ Circle invitation accepted")
            return true
            
        } catch {
            self.errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
            return false
        }
    }
    
    func declineCircleInvitation(_ invitation: CircleInvitation) async -> Bool {
        await updateInvitationStatus(invitation, status: .declined)
        pendingInvitations.removeAll { $0.id == invitation.id }
        return true
    }
    
    // MARK: - Real-time Updates
    func enableRealTimeUpdates() async {
        guard isSharingEnabled else { return }
        
        // Set up CloudKit subscriptions for real-time updates
        let subscriptions = [
            createCircleSubscription(),
            createChallengeSubscription(),
            createHangoutSubscription(),
            createPhotoStorySubscription()
        ]
        
        for subscription in subscriptions {
            do {
                try await privateContainer.privateCloudDatabase.save(subscription)
                print("✅ Subscription created: \(subscription.subscriptionID)")
            } catch {
                print("❌ Failed to create subscription: \(error.localizedDescription)")
            }
        }
    }
    
    private func createCircleSubscription() -> CKQuerySubscription {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "Circle",
            predicate: predicate,
            subscriptionID: "CircleUpdates",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.alertBody = "Circle updated"
        notification.shouldBadge = true
        subscription.notificationInfo = notification
        
        return subscription
    }
    
    private func createChallengeSubscription() -> CKQuerySubscription {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "Challenge",
            predicate: predicate,
            subscriptionID: "ChallengeUpdates",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.alertBody = "New challenge available"
        notification.shouldBadge = true
        subscription.notificationInfo = notification
        
        return subscription
    }
    
    private func createHangoutSubscription() -> CKQuerySubscription {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "HangoutSession",
            predicate: predicate,
            subscriptionID: "HangoutUpdates",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.alertBody = "Hangout activity"
        notification.shouldBadge = true
        subscription.notificationInfo = notification
        
        return subscription
    }
    
    private func createPhotoStorySubscription() -> CKQuerySubscription {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "PhotoStory",
            predicate: predicate,
            subscriptionID: "PhotoStoryUpdates",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.alertBody = "New photo story"
        notification.shouldBadge = true
        subscription.notificationInfo = notification
        
        return subscription
    }
    
    // MARK: - Data Synchronization
    func syncCircleToCloudKit(_ circle: Circle) async {
        guard isSharingEnabled else { return }
        
        do {
            let record = circle.cloudKitRecord
            try await privateContainer.privateCloudDatabase.save(record)
            print("✅ Circle synced to CloudKit")
        } catch {
            print("❌ Failed to sync circle: \(error.localizedDescription)")
        }
    }
    
    func syncChallengeToCloudKit(_ challenge: Challenge) async {
        guard isSharingEnabled else { return }
        
        do {
            let record = challenge.cloudKitRecord
            try await privateContainer.privateCloudDatabase.save(record)
            print("✅ Challenge synced to CloudKit")
        } catch {
            print("❌ Failed to sync challenge: \(error.localizedDescription)")
        }
    }
    
    func syncHangoutToCloudKit(_ hangout: HangoutSession) async {
        guard isSharingEnabled else { return }
        
        do {
            let record = hangout.cloudKitRecord
            try await privateContainer.privateCloudDatabase.save(record)
            print("✅ Hangout synced to CloudKit")
        } catch {
            print("❌ Failed to sync hangout: \(error.localizedDescription)")
        }
    }
    
    func syncPhotoStoryToCloudKit(_ photoStory: PhotoStory) async {
        guard isSharingEnabled else { return }
        
        do {
            let record = photoStory.cloudKitRecord
            try await privateContainer.privateCloudDatabase.save(record)
            print("✅ Photo story synced to CloudKit")
        } catch {
            print("❌ Failed to sync photo story: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Loading
    private func loadSharedCircles() async {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SharedCircleEntity> = SharedCircleEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            sharedCircles = entities.compactMap { entity in
                SharedCircle(
                    id: entity.id!,
                    circle: entity.circle!,
                    shareRecord: entity.shareRecord!,
                    participants: [], // Would load from relationships
                    createdAt: entity.createdAt!,
                    isActive: entity.isActive
                )
            }
        } catch {
            print("Error loading shared circles: \(error)")
        }
    }
    
    private func loadSharedCircle(from share: CKShare) async {
        // Load the shared circle data from CloudKit
        let record = share.rootRecord
        
        // Convert CloudKit record to local Circle entity
        let context = persistenceController.container.viewContext
        let circle = Circle(context: context)
        circle.id = UUID()
        circle.name = record["name"] as? String ?? "Shared Circle"
        circle.createdAt = Date()
        
        // Save shared circle entity
        let sharedCircleEntity = SharedCircleEntity(context: context)
        sharedCircleEntity.id = UUID()
        sharedCircleEntity.circle = circle
        sharedCircleEntity.shareRecord = share
        sharedCircleEntity.createdAt = Date()
        sharedCircleEntity.isActive = true
        
        do {
            try context.save()
            
            // Add to local collection
            let sharedCircle = SharedCircle(
                id: sharedCircleEntity.id!,
                circle: circle,
                shareRecord: share,
                participants: [], // Would load from relationships
                createdAt: sharedCircleEntity.createdAt!,
                isActive: true
            )
            
            sharedCircles.append(sharedCircle)
            
        } catch {
            print("Error saving shared circle: \(error)")
        }
    }
    
    // MARK: - Invitation Management
    private func createInvitations(for circle: Circle, users: [User], share: CKShare) async {
        let context = persistenceController.container.viewContext
        
        for user in users {
            let invitation = CircleInvitationEntity(context: context)
            invitation.id = UUID()
            invitation.circle = circle
            invitation.invitedUser = user
            invitation.shareMetadata = share.shareMetadata
            invitation.status = "pending"
            invitation.createdAt = Date()
        }
        
        do {
            try context.save()
        } catch {
            print("Error creating invitations: \(error)")
        }
    }
    
    private func updateInvitationStatus(_ invitation: CircleInvitation, status: InvitationStatus) async {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<CircleInvitationEntity> = CircleInvitationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", invitation.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let entity = results.first {
                entity.status = status.rawValue
                entity.respondedAt = Date()
                try context.save()
            }
        } catch {
            print("Error updating invitation status: \(error)")
        }
    }
    
    // MARK: - CloudKit Change Handling
    private func handleCloudKitChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notification = userInfo[CKNotification.NotificationUserInfoKey] as? CKNotification else {
            return
        }
        
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
        // Handle specific record changes
        let recordID = notification.recordID
        
        switch notification.querySubscriptionID {
        case "CircleUpdates":
            // Reload circle data
            Task {
                await loadCircleFromCloudKit(recordID)
            }
        case "ChallengeUpdates":
            // Reload challenge data
            Task {
                await loadChallengeFromCloudKit(recordID)
            }
        case "HangoutUpdates":
            // Reload hangout data
            Task {
                await loadHangoutFromCloudKit(recordID)
            }
        case "PhotoStoryUpdates":
            // Reload photo story data
            Task {
                await loadPhotoStoryFromCloudKit(recordID)
            }
        default:
            break
        }
    }
    
    private func handleDatabaseNotification(_ notification: CKDatabaseNotification) {
        // Handle database-level changes
        print("Database notification received")
    }
    
    // MARK: - CloudKit Record Loading
    private func loadCircleFromCloudKit(_ recordID: CKRecord.ID) async {
        do {
            let record = try await privateContainer.privateCloudDatabase.record(for: recordID)
            // Update local circle with CloudKit data
            print("✅ Circle loaded from CloudKit: \(record.recordID)")
        } catch {
            print("❌ Failed to load circle from CloudKit: \(error)")
        }
    }
    
    private func loadChallengeFromCloudKit(_ recordID: CKRecord.ID) async {
        do {
            let record = try await privateContainer.privateCloudDatabase.record(for: recordID)
            // Update local challenge with CloudKit data
            print("✅ Challenge loaded from CloudKit: \(record.recordID)")
        } catch {
            print("❌ Failed to load challenge from CloudKit: \(error)")
        }
    }
    
    private func loadHangoutFromCloudKit(_ recordID: CKRecord.ID) async {
        do {
            let record = try await privateContainer.privateCloudDatabase.record(for: recordID)
            // Update local hangout with CloudKit data
            print("✅ Hangout loaded from CloudKit: \(record.recordID)")
        } catch {
            print("❌ Failed to load hangout from CloudKit: \(error)")
        }
    }
    
    private func loadPhotoStoryFromCloudKit(_ recordID: CKRecord.ID) async {
        do {
            let record = try await privateContainer.privateCloudDatabase.record(for: recordID)
            // Update local photo story with CloudKit data
            print("✅ Photo story loaded from CloudKit: \(record.recordID)")
        } catch {
            print("❌ Failed to load photo story from CloudKit: \(error)")
        }
    }
}

// MARK: - Supporting Types
struct SharedCircle: Identifiable {
    let id: UUID
    let circle: Circle
    let shareRecord: CKShare
    let participants: [User]
    let createdAt: Date
    let isActive: Bool
}

struct CircleInvitation: Identifiable {
    let id: UUID
    let circle: Circle
    let invitedUser: User
    let shareMetadata: CKShare.Metadata
    let status: InvitationStatus
    let createdAt: Date
}

enum InvitationStatus: String, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        }
    }
}

// MARK: - Core Data Entities (Placeholders)
class SharedCircleEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var circle: Circle?
    @NSManaged var shareRecord: CKShare?
    @NSManaged var createdAt: Date?
    @NSManaged var isActive: Bool
}

class CircleInvitationEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var circle: Circle?
    @NSManaged var invitedUser: User?
    @NSManaged var shareMetadata: CKShare.Metadata?
    @NSManaged var status: String?
    @NSManaged var createdAt: Date?
    @NSManaged var respondedAt: Date?
}

// MARK: - CloudKit Record Extensions
extension Circle {
    var cloudKitRecord: CKRecord {
        let record = CKRecord(recordType: "Circle", recordID: CKRecord.ID(recordName: id.uuidString))
        record["name"] = name
        record["createdAt"] = createdAt
        record["isActive"] = isActive
        return record
    }
}

extension Challenge {
    var cloudKitRecord: CKRecord {
        let record = CKRecord(recordType: "Challenge", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title
        record["description"] = challengeDescription
        record["points"] = points
        record["isActive"] = isActive
        return record
    }
}

extension HangoutSession {
    var cloudKitRecord: CKRecord {
        let record = CKRecord(recordType: "HangoutSession", recordID: CKRecord.ID(recordName: id.uuidString))
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["isActive"] = isActive
        record["duration"] = duration
        return record
    }
}

extension PhotoStory {
    var cloudKitRecord: CKRecord {
        let record = CKRecord(recordType: "PhotoStory", recordID: CKRecord.ID(recordName: id.uuidString))
        record["hangoutSessionID"] = hangoutSession.id.uuidString
        record["takenBy"] = takenBy.name
        record["createdAt"] = createdAt
        record["isApproved"] = isApproved
        return record
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let circleUpdated = Notification.Name("circleUpdated")
    static let challengeUpdated = Notification.Name("challengeUpdated")
    static let hangoutUpdated = Notification.Name("hangoutUpdated")
    static let photoStoryUpdated = Notification.Name("photoStoryUpdated")
}
