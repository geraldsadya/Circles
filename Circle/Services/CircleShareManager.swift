//
//  CircleShareManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CloudKit
import CoreData
import Combine
import MessageUI

@MainActor
class CircleShareManager: ObservableObject {
    static let shared = CircleShareManager()
    
    @Published var isSharing = false
    @Published var shareURL: URL?
    @Published var pendingInvites: [CircleInvite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let cloudKitManager = CloudKitManager.shared
    
    // CloudKit components
    private let privateContainer: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // Share state
    private var activeShares: [String: CKShare] = [:]
    private var shareParticipants: [String: [CKShareParticipant]] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.privateContainer = CKContainer.default()
        self.privateDatabase = privateContainer.privateCloudDatabase
        self.sharedDatabase = privateContainer.sharedCloudDatabase
        
        setupNotifications()
        loadPendingInvites()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShareReceived),
            name: .CKShareReceived,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShareAccepted),
            name: .CKShareAccepted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShareDeclined),
            name: .CKShareDeclined,
            object: nil
        )
    }
    
    // MARK: - Circle Creation and Sharing
    func createCircle(name: String, description: String?, user: User) async throws -> Circle {
        let context = persistenceController.container.viewContext
        
        // Create Circle entity
        let circle = Circle(context: context)
        circle.id = UUID()
        circle.name = name
        circle.description = description
        circle.createdAt = Date()
        circle.isActive = true
        circle.createdBy = user
        
        // Create membership for creator
        let membership = Membership(context: context)
        membership.id = UUID()
        membership.user = user
        membership.circle = circle
        membership.role = MembershipRole.owner.rawValue
        membership.joinedAt = Date()
        
        // Save to Core Data
        try context.save()
        
        // Create CloudKit share
        let share = try await createCloudKitShare(for: circle)
        
        // Store share reference
        activeShares[circle.id?.uuidString ?? ""] = share
        
        print("Circle created: \(circle.name ?? "Unknown")")
        
        return circle
    }
    
    private func createCloudKitShare(for circle: Circle) async throws -> CKShare {
        // Create CKShare for the circle
        let share = CKShare(record: CKRecord(recordType: "Circle", recordID: CKRecord.ID(recordName: circle.id?.uuidString ?? UUID().uuidString)))
        
        // Set share properties
        share[CKShare.SystemFieldKey.title] = circle.name
        share[CKShare.SystemFieldKey.shareURL] = URL(string: "https://circle.app/share/\(circle.id?.uuidString ?? "")")
        
        // Set permissions
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.ownerIdentity] = CKRecord.ID(recordName: "current_user")
        
        // Save share to private database
        let savedShare = try await privateDatabase.save(share)
        
        return savedShare
    }
    
    // MARK: - Invite Management
    func inviteUser(to circle: Circle, email: String, role: MembershipRole = .member) async throws -> CircleInvite {
        let context = persistenceController.container.viewContext
        
        // Create invite entity
        let invite = CircleInvite(context: context)
        invite.id = UUID()
        invite.circle = circle
        invite.invitedEmail = email
        invite.invitedRole = role.rawValue
        invite.invitedBy = getCurrentUser()
        invite.invitedAt = Date()
        invite.status = InviteStatus.pending.rawValue
        invite.expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        
        // Save to Core Data
        try context.save()
        
        // Send invite via iMessage
        try await sendInviteViaMessage(invite: invite)
        
        // Add to pending invites
        pendingInvites.append(invite)
        
        print("Invite sent to: \(email)")
        
        return invite
    }
    
    private func sendInviteViaMessage(invite: CircleInvite) async throws {
        guard let circle = invite.circle else { return }
        
        // Create share URL
        let shareURL = URL(string: "https://circle.app/join/\(invite.id?.uuidString ?? "")")!
        
        // Create message content
        let message = """
        You're invited to join "\(circle.name ?? "Circle")" on Circle!
        
        Join your friends in completing challenges, earning points, and staying accountable together.
        
        Tap to join: \(shareURL.absoluteString)
        """
        
        // Present message composer
        await presentMessageComposer(message: message, recipients: [invite.invitedEmail ?? ""])
    }
    
    private func presentMessageComposer(message: String, recipients: [String]) async {
        // This would present MFMessageComposeViewController
        // For now, we'll simulate the message sending
        print("Message sent: \(message)")
    }
    
    // MARK: - Share Acceptance
    func acceptInvite(inviteID: String, user: User) async throws {
        guard let invite = pendingInvites.first(where: { $0.id?.uuidString == inviteID }) else {
            throw CircleShareError.inviteNotFound
        }
        
        guard invite.status == InviteStatus.pending.rawValue else {
            throw CircleShareError.inviteAlreadyProcessed
        }
        
        guard let circle = invite.circle else {
            throw CircleShareError.circleNotFound
        }
        
        // Check if invite is expired
        if let expiresAt = invite.expiresAt, expiresAt < Date() {
            throw CircleShareError.inviteExpired
        }
        
        let context = persistenceController.container.viewContext
        
        // Create membership
        let membership = Membership(context: context)
        membership.id = UUID()
        membership.user = user
        membership.circle = circle
        membership.role = invite.invitedRole ?? MembershipRole.member.rawValue
        membership.joinedAt = Date()
        
        // Update invite status
        invite.status = InviteStatus.accepted.rawValue
        invite.acceptedAt = Date()
        invite.acceptedBy = user
        
        // Save to Core Data
        try context.save()
        
        // Remove from pending invites
        pendingInvites.removeAll { $0.id?.uuidString == inviteID }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .circleInviteAccepted,
            object: nil,
            userInfo: [
                "invite": invite,
                "user": user,
                "circle": circle
            ]
        )
        
        print("Invite accepted: \(inviteID)")
    }
    
    func declineInvite(inviteID: String, user: User) async throws {
        guard let invite = pendingInvites.first(where: { $0.id?.uuidString == inviteID }) else {
            throw CircleShareError.inviteNotFound
        }
        
        guard invite.status == InviteStatus.pending.rawValue else {
            throw CircleShareError.inviteAlreadyProcessed
        }
        
        let context = persistenceController.container.viewContext
        
        // Update invite status
        invite.status = InviteStatus.declined.rawValue
        invite.declinedAt = Date()
        invite.declinedBy = user
        
        // Save to Core Data
        try context.save()
        
        // Remove from pending invites
        pendingInvites.removeAll { $0.id?.uuidString == inviteID }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .circleInviteDeclined,
            object: nil,
            userInfo: [
                "invite": invite,
                "user": user
            ]
        )
        
        print("Invite declined: \(inviteID)")
    }
    
    // MARK: - Share Management
    func getShareURL(for circle: Circle) async throws -> URL {
        guard let circleID = circle.id?.uuidString else {
            throw CircleShareError.circleNotFound
        }
        
        if let existingShare = activeShares[circleID] {
            return existingShare[CKShare.SystemFieldKey.shareURL] as? URL ?? URL(string: "https://circle.app/share/\(circleID)")!
        }
        
        // Create new share
        let share = try await createCloudKitShare(for: circle)
        activeShares[circleID] = share
        
        return share[CKShare.SystemFieldKey.shareURL] as? URL ?? URL(string: "https://circle.app/share/\(circleID)")!
    }
    
    func updateSharePermissions(for circle: Circle, participant: CKShareParticipant, permission: CKShare.ParticipantPermission) async throws {
        guard let circleID = circle.id?.uuidString,
              let share = activeShares[circleID] else {
            throw CircleShareError.shareNotFound
        }
        
        // Update participant permission
        participant.permission = permission
        
        // Save updated share
        let updatedShare = try await privateDatabase.save(share)
        activeShares[circleID] = updatedShare
        
        print("Share permissions updated for circle: \(circle.name ?? "Unknown")")
    }
    
    func removeParticipant(from circle: Circle, participant: CKShareParticipant) async throws {
        guard let circleID = circle.id?.uuidString,
              let share = activeShares[circleID] else {
            throw CircleShareError.shareNotFound
        }
        
        // Remove participant from share
        share.removeParticipant(participant)
        
        // Save updated share
        let updatedShare = try await privateDatabase.save(share)
        activeShares[circleID] = updatedShare
        
        // Remove membership from Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<Membership> = Membership.fetchRequest()
        request.predicate = NSPredicate(format: "circle == %@ AND user.ckRecordID == %@", circle, participant.userIdentity.recordID)
        
        if let membership = try context.fetch(request).first {
            context.delete(membership)
            try context.save()
        }
        
        print("Participant removed from circle: \(circle.name ?? "Unknown")")
    }
    
    // MARK: - Share Participants
    func getShareParticipants(for circle: Circle) async throws -> [CKShareParticipant] {
        guard let circleID = circle.id?.uuidString,
              let share = activeShares[circleID] else {
            throw CircleShareError.shareNotFound
        }
        
        return share.participants
    }
    
    func addParticipant(to circle: Circle, email: String, permission: CKShare.ParticipantPermission = .readWrite) async throws {
        guard let circleID = circle.id?.uuidString,
              let share = activeShares[circleID] else {
            throw CircleShareError.shareNotFound
        }
        
        // Create new participant
        let participant = CKShareParticipant()
        participant.permission = permission
        participant.acceptanceStatus = .pending
        
        // Add participant to share
        share.addParticipant(participant)
        
        // Save updated share
        let updatedShare = try await privateDatabase.save(share)
        activeShares[circleID] = updatedShare
        
        print("Participant added to circle: \(circle.name ?? "Unknown")")
    }
    
    // MARK: - Share Status
    func getShareStatus(for circle: Circle) async -> ShareStatus {
        guard let circleID = circle.id?.uuidString,
              let share = activeShares[circleID] else {
            return .notShared
        }
        
        let participants = share.participants
        let pendingCount = participants.filter { $0.acceptanceStatus == .pending }.count
        let acceptedCount = participants.filter { $0.acceptanceStatus == .accepted }.count
        
        return ShareStatus(
            isShared: true,
            totalParticipants: participants.count,
            pendingParticipants: pendingCount,
            acceptedParticipants: acceptedCount,
            shareURL: share[CKShare.SystemFieldKey.shareURL] as? URL
        )
    }
    
    // MARK: - Notification Handlers
    @objc private func handleShareReceived(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let share = userInfo["share"] as? CKShare else { return }
        
        Task {
            await processReceivedShare(share)
        }
    }
    
    @objc private func handleShareAccepted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let share = userInfo["share"] as? CKShare else { return }
        
        Task {
            await processAcceptedShare(share)
        }
    }
    
    @objc private func handleShareDeclined(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let share = userInfo["share"] as? CKShare else { return }
        
        Task {
            await processDeclinedShare(share)
        }
    }
    
    private func processReceivedShare(_ share: CKShare) async {
        // Process received share
        print("Share received: \(share.recordID)")
    }
    
    private func processAcceptedShare(_ share: CKShare) async {
        // Process accepted share
        print("Share accepted: \(share.recordID)")
    }
    
    private func processDeclinedShare(_ share: CKShare) async {
        // Process declined share
        print("Share declined: \(share.recordID)")
    }
    
    // MARK: - Helper Methods
    private func getCurrentUser() -> User? {
        // This would be implemented to get the current authenticated user
        return nil
    }
    
    private func loadPendingInvites() {
        let request: NSFetchRequest<CircleInvite> = CircleInvite.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", InviteStatus.pending.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CircleInvite.invitedAt, ascending: false)]
        
        do {
            pendingInvites = try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error loading pending invites: \(error)")
        }
    }
    
    // MARK: - Analytics
    func getShareStats(for circle: Circle) -> ShareStats {
        let request: NSFetchRequest<CircleInvite> = CircleInvite.fetchRequest()
        request.predicate = NSPredicate(format: "circle == %@", circle)
        
        do {
            let invites = try persistenceController.container.viewContext.fetch(request)
            
            let totalInvites = invites.count
            let acceptedInvites = invites.filter { $0.status == InviteStatus.accepted.rawValue }.count
            let declinedInvites = invites.filter { $0.status == InviteStatus.declined.rawValue }.count
            let pendingInvites = invites.filter { $0.status == InviteStatus.pending.rawValue }.count
            
            return ShareStats(
                totalInvites: totalInvites,
                acceptedInvites: acceptedInvites,
                declinedInvites: declinedInvites,
                pendingInvites: pendingInvites,
                acceptanceRate: totalInvites > 0 ? Double(acceptedInvites) / Double(totalInvites) : 0.0
            )
            
        } catch {
            print("Error getting share stats: \(error)")
            return ShareStats(
                totalInvites: 0,
                acceptedInvites: 0,
                declinedInvites: 0,
                pendingInvites: 0,
                acceptanceRate: 0.0
            )
        }
    }
    
    // MARK: - Cleanup
    func cleanupExpiredInvites() {
        let expiredDate = Date()
        
        let request: NSFetchRequest<CircleInvite> = CircleInvite.fetchRequest()
        request.predicate = NSPredicate(format: "expiresAt < %@ AND status == %@", expiredDate as NSDate, InviteStatus.pending.rawValue)
        
        do {
            let expiredInvites = try persistenceController.container.viewContext.fetch(request)
            
            for invite in expiredInvites {
                invite.status = InviteStatus.expired.rawValue
            }
            
            try persistenceController.container.viewContext.save()
            
            // Remove from pending invites
            pendingInvites.removeAll { invite in
                expiredInvites.contains { $0.id == invite.id }
            }
            
            print("Cleaned up \(expiredInvites.count) expired invites")
            
        } catch {
            print("Error cleaning up expired invites: \(error)")
        }
    }
}

// MARK: - Supporting Types
enum MembershipRole: String, CaseIterable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        }
    }
    
    var permissions: [String] {
        switch self {
        case .owner:
            return ["create_challenges", "invite_members", "remove_members", "manage_circle", "delete_circle"]
        case .admin:
            return ["create_challenges", "invite_members", "remove_members", "manage_circle"]
        case .member:
            return ["create_challenges", "view_circle"]
        }
    }
}

enum InviteStatus: String, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .expired: return "Expired"
        }
    }
}

struct ShareStatus {
    let isShared: Bool
    let totalParticipants: Int
    let pendingParticipants: Int
    let acceptedParticipants: Int
    let shareURL: URL?
}

struct ShareStats {
    let totalInvites: Int
    let acceptedInvites: Int
    let declinedInvites: Int
    let pendingInvites: Int
    let acceptanceRate: Double
}

enum CircleShareError: LocalizedError {
    case inviteNotFound
    case inviteAlreadyProcessed
    case inviteExpired
    case circleNotFound
    case shareNotFound
    case permissionDenied
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .inviteNotFound:
            return "Invite not found"
        case .inviteAlreadyProcessed:
            return "Invite has already been processed"
        case .inviteExpired:
            return "Invite has expired"
        case .circleNotFound:
            return "Circle not found"
        case .shareNotFound:
            return "Share not found"
        case .permissionDenied:
            return "Permission denied"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Core Data Extensions
extension CircleInvite {
    static func fetchRequest() -> NSFetchRequest<CircleInvite> {
        return NSFetchRequest<CircleInvite>(entityName: "CircleInvite")
    }
    
    var statusEnum: InviteStatus? {
        return InviteStatus(rawValue: status ?? "")
    }
    
    var roleEnum: MembershipRole? {
        return MembershipRole(rawValue: invitedRole ?? "")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let CKShareReceived = Notification.Name("CKShareReceived")
    static let CKShareAccepted = Notification.Name("CKShareAccepted")
    static let CKShareDeclined = Notification.Name("CKShareDeclined")
    static let circleInviteAccepted = Notification.Name("circleInviteAccepted")
    static let circleInviteDeclined = Notification.Name("circleInviteDeclined")
    static let circleCreated = Notification.Name("circleCreated")
    static let circleJoined = Notification.Name("circleJoined")
}
