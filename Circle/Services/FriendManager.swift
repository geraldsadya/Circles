//
//  FriendManager.swift
//  Circle
//
//  Real-time friend connection and invite system
//

import Foundation
import CloudKit
import Combine

@MainActor
class FriendManager: ObservableObject {
    static let shared = FriendManager()
    
    @Published var friends: [UserProfile] = []
    @Published var pendingInvites: [FriendInvite] = []
    @Published var myInviteCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let container = CKContainer(identifier: "iCloud.com.circle.app")
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var publicDatabase: CKDatabase { container.publicCloudDatabase }
    
    private var refreshTimer: Timer?
    
    private init() {
        startAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Invite Code Generation
    func generateInviteCode(for userProfile: UserProfile) async throws -> String {
        print("🎫 Generating invite code for user: \(userProfile.displayName)")
        
        // Generate a 6-character code
        let code = generateRandomCode()
        
        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: "InviteCode_\(code)")
        let record = CKRecord(recordType: "InviteCode", recordID: recordID)
        
        record["code"] = code
        record["userRecordName"] = userProfile.recordName
        record["displayName"] = userProfile.displayName
        record["profileEmoji"] = userProfile.profileEmoji
        record["createdAt"] = Date()
        record["expiresAt"] = Date().addingTimeInterval(86400 * 7) // 7 days
        record["isActive"] = true
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            print("✅ Invite code created: \(code)")
            myInviteCode = code
            return code
        } catch {
            print("❌ Failed to create invite code: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Add Friend by Code
    func addFriendByCode(_ code: String, currentUser: UserProfile) async throws {
        print("🔍 Looking up invite code: \(code)")
        
        // Find the invite code record
        let predicate = NSPredicate(format: "code == %@ AND isActive == YES", code.uppercased())
        let query = CKQuery(recordType: "InviteCode", predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query)
            
            guard let firstMatch = results.matchResults.first else {
                throw NSError(domain: "FriendManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invite code not found or expired"])
            }
            
            switch firstMatch.value {
            case .success(let record):
                guard let friendRecordName = record["userRecordName"] as? String else {
                    throw NSError(domain: "FriendManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid invite code data"])
                }
                
                // Don't add yourself as a friend
                if friendRecordName == currentUser.recordName {
                    throw NSError(domain: "FriendManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "You can't add yourself as a friend"])
                }
                
                // Create friend connection (both directions)
                try await createFriendConnection(from: currentUser.recordName, to: friendRecordName)
                try await createFriendConnection(from: friendRecordName, to: currentUser.recordName)
                
                print("✅ Friend connection created successfully")
                
                // Refresh friends list
                try await fetchFriends(for: currentUser.recordName)
                
            case .failure(let error):
                throw error
            }
        } catch {
            print("❌ Failed to add friend: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Create Friend Connection
    private func createFriendConnection(from userA: String, to userB: String) async throws {
        let recordID = CKRecord.ID(recordName: "Friend_\(userA)_\(userB)")
        let record = CKRecord(recordType: "FriendConnection", recordID: recordID)
        
        record["userA"] = userA
        record["userB"] = userB
        record["createdAt"] = Date()
        record["status"] = "accepted" // Auto-accept for now
        
        _ = try await privateDatabase.save(record)
        print("✅ Created friend connection: \(userA) -> \(userB)")
    }
    
    // MARK: - Fetch Friends
    func fetchFriends(for userRecordName: String) async throws {
        print("👥 Fetching friends for user: \(userRecordName)")
        
        let predicate = NSPredicate(format: "userA == %@", userRecordName)
        let query = CKQuery(recordType: "FriendConnection", predicate: predicate)
        
        do {
            let results = try await privateDatabase.records(matching: query)
            var friendRecordNames: [String] = []
            
            for (_, result) in results.matchResults {
                switch result {
                case .success(let record):
                    if let friendRecordName = record["userB"] as? String {
                        friendRecordNames.append(friendRecordName)
                    }
                case .failure(let error):
                    print("⚠️ Error loading friend connection: \(error.localizedDescription)")
                }
            }
            
            print("📋 Found \(friendRecordNames.count) friend connections")
            
            // Fetch friend profiles
            if !friendRecordNames.isEmpty {
                let friendProfiles = try await UserProfileManager.shared.fetchFriendProfiles(friendIDs: friendRecordNames)
                friends = friendProfiles
                print("✅ Loaded \(friends.count) friend profiles")
            } else {
                friends = []
            }
            
        } catch {
            print("❌ Failed to fetch friends: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Auto Refresh
    private func startAutoRefresh() {
        // Refresh friends every 10 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let currentUser = UserProfileManager.shared.currentUserProfile else {
                    return
                }
                
                do {
                    try await self.fetchFriends(for: currentUser.recordName)
                } catch {
                    print("⚠️ Auto-refresh failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Remove Friend
    func removeFriend(_ friendProfile: UserProfile, currentUser: UserProfile) async throws {
        print("🗑️ Removing friend: \(friendProfile.displayName)")
        
        // Delete both friend connections
        let recordID1 = CKRecord.ID(recordName: "Friend_\(currentUser.recordName)_\(friendProfile.recordName)")
        let recordID2 = CKRecord.ID(recordName: "Friend_\(friendProfile.recordName)_\(currentUser.recordName)")
        
        do {
            try await privateDatabase.deleteRecord(withID: recordID1)
            try await privateDatabase.deleteRecord(withID: recordID2)
            
            print("✅ Friend removed successfully")
            
            // Refresh friends list
            try await fetchFriends(for: currentUser.recordName)
        } catch {
            print("❌ Failed to remove friend: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    private func generateRandomCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Friend Invite Model
struct FriendInvite: Identifiable, Codable {
    let id: String
    let code: String
    let userRecordName: String
    let displayName: String
    let profileEmoji: String
    let createdAt: Date
    let expiresAt: Date
    var isActive: Bool
    
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.code = record["code"] as? String ?? ""
        self.userRecordName = record["userRecordName"] as? String ?? ""
        self.displayName = record["displayName"] as? String ?? "Unknown"
        self.profileEmoji = record["profileEmoji"] as? String ?? "👤"
        self.createdAt = record["createdAt"] as? Date ?? Date()
        self.expiresAt = record["expiresAt"] as? Date ?? Date()
        self.isActive = record["isActive"] as? Bool ?? true
    }
}

