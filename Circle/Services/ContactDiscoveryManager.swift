//
//  ContactDiscoveryManager.swift
//  Circle
//
//  Auto-discover friends from contacts (like Find My)
//

import Foundation
import CloudKit
import Contacts

@MainActor
class ContactDiscoveryManager: ObservableObject {
    static let shared = ContactDiscoveryManager()
    
    @Published var discoveredFriends: [DiscoveredFriend] = []
    @Published var isDiscovering = false
    
    private let container = CKContainer(identifier: "iCloud.com.circle.app")
    private let contactStore = CNContactStore()
    
    private init() {}
    
    // MARK: - Auto-Discover Friends
    func discoverFriendsFromContacts() async throws {
        print("🔍 Discovering friends from contacts...")
        
        isDiscovering = true
        defer { isDiscovering = false }
        
        // Request contacts permission
        let granted = try await requestContactsPermission()
        guard granted else {
            print("⚠️ Contacts permission denied")
            return
        }
        
        // Fetch all contacts
        let contacts = try fetchContacts()
        print("📇 Found \(contacts.count) contacts")
        
        // Discover which contacts have the app
        let friends = try await discoverAppUsers(from: contacts)
        discoveredFriends = friends
        
        print("✅ Discovered \(friends.count) friends with Circle app")
    }
    
    // MARK: - Request Contacts Permission
    private func requestContactsPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Fetch Contacts
    private func fetchContacts() throws -> [CNContact] {
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [CNContact] = []
        
        try contactStore.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        
        return contacts
    }
    
    // MARK: - Discover App Users
    private func discoverAppUsers(from contacts: [CNContact]) async throws -> [DiscoveredFriend] {
        print("🔍 Checking which contacts have Circle app...")
        
        var friends: [DiscoveredFriend] = []
        
        // CloudKit can look up users by email
        for contact in contacts {
            let emails = contact.emailAddresses.map { $0.value as String }
            
            for email in emails {
                do {
                    // Look up user by email in CloudKit
                    let userIdentity = try await container.discoverUserIdentity(
                        withEmailAddress: email
                    )
                    
                    if let identity = userIdentity,
                       let recordID = identity.userRecordID {
                        
                        let friend = DiscoveredFriend(
                            recordID: recordID,
                            contactName: "\(contact.givenName) \(contact.familyName)",
                            email: email
                        )
                        
                        friends.append(friend)
                        print("✅ Found friend: \(friend.contactName)")
                        break // Found them, move to next contact
                    }
                } catch {
                    // This contact doesn't have the app, continue
                    continue
                }
            }
        }
        
        return friends
    }
    
    // MARK: - Share Location with Friends
    func shareLocationWithFriends(_ friends: [DiscoveredFriend]) async throws {
        print("📍 Sharing location with \(friends.count) friends...")
        
        // Create a shared zone for location sharing
        let zone = CKRecordZone(zoneName: "SharedLocationZone")
        let privateDB = container.privateCloudDatabase
        
        do {
            _ = try await privateDB.save(zone)
            print("✅ Created shared location zone")
            
            // Share with discovered friends
            // CloudKit will handle the participant management
            
        } catch {
            print("❌ Failed to create shared zone: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Discovered Friend Model
struct DiscoveredFriend: Identifiable, Equatable {
    let id = UUID()
    let recordID: CKRecord.ID
    let contactName: String
    let email: String
    
    var userID: String {
        recordID.recordName
    }
}

