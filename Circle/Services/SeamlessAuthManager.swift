//
//  SeamlessAuthManager.swift
//  Circle
//
//  Automatic authentication using iCloud - no setup needed
//

import Foundation
import CloudKit
import Contacts

@MainActor
class SeamlessAuthManager: ObservableObject {
    static let shared = SeamlessAuthManager()
    
    @Published var isReady = false
    @Published var currentUserID: String?
    @Published var displayName: String?
    @Published var isSignedIn = false
    
    private let container = CKContainer(identifier: "iCloud.com.circle.app")
    private var userRecordID: CKRecord.ID?
    
    private init() {
        checkiCloudStatus()
    }
    
    // MARK: - Automatic iCloud Sign In
    func checkiCloudStatus() {
        print("🔐 Checking iCloud status...")
        
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ iCloud error: \(error.localizedDescription)")
                    return
                }
                
                switch status {
                case .available:
                    print("✅ iCloud is available - signing in automatically")
                    Task {
                        await self.automaticSignIn()
                    }
                case .noAccount:
                    print("⚠️ No iCloud account - user needs to sign in to iCloud in Settings")
                case .restricted:
                    print("⚠️ iCloud is restricted")
                case .couldNotDetermine:
                    print("⚠️ Could not determine iCloud status")
                @unknown default:
                    print("⚠️ Unknown iCloud status")
                }
            }
        }
    }
    
    // MARK: - Automatic Sign In
    private func automaticSignIn() async {
        print("🔄 Performing automatic sign-in...")
        
        do {
            // Get the user's iCloud record ID (unique to this user)
            let recordID = try await container.userRecordID()
            userRecordID = recordID
            currentUserID = recordID.recordName
            
            print("✅ Signed in with iCloud ID: \(recordID.recordName)")
            
            // Request discoverability permission (for contact matching)
            try await requestDiscoverability()
            
            // Fetch user info from CloudKit
            try await fetchUserInfo()
            
            isSignedIn = true
            isReady = true
            
            print("✅ Seamless auth complete - user is ready!")
            
        } catch {
            print("❌ Automatic sign-in failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Request Discoverability (Find My style)
    private func requestDiscoverability() async throws {
        print("🔍 Requesting discoverability permission...")
        
        do {
            let status = try await container.requestApplicationPermission(.userDiscoverability)
            
            switch status {
            case .granted:
                print("✅ Discoverability granted - can find friends!")
            case .denied:
                print("⚠️ Discoverability denied - can't auto-discover friends")
            case .initialState:
                print("ℹ️ Discoverability initial state")
            @unknown default:
                print("⚠️ Unknown discoverability status")
            }
        } catch {
            print("❌ Discoverability request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Fetch User Info
    private func fetchUserInfo() async throws {
        guard let recordID = userRecordID else {
            print("⚠️ No user record ID")
            return
        }
        
        print("👤 Fetching user info from iCloud...")
        
        do {
            // Discover user info (name, email, etc.)
            let userIdentity = try await container.userIdentity(forUserRecordID: recordID)
            
            if let nameComponents = userIdentity?.nameComponents {
                let formatter = PersonNameComponentsFormatter()
                displayName = formatter.string(from: nameComponents)
                print("✅ Got user name: \(displayName ?? "Unknown")")
            } else {
                // Fallback to device name
                displayName = UIDevice.current.name
                print("ℹ️ Using device name: \(displayName ?? "Unknown")")
            }
            
        } catch {
            print("⚠️ Failed to fetch user info: \(error.localizedDescription)")
            // Use device name as fallback
            displayName = UIDevice.current.name
        }
    }
    
    // MARK: - Create User Profile
    func getOrCreateUserProfile() async throws -> CKRecord {
        guard let userID = currentUserID else {
            throw NSError(domain: "SeamlessAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        let recordID = CKRecord.ID(recordName: "User_\(userID)")
        let privateDB = container.privateCloudDatabase
        
        do {
            // Try to fetch existing profile
            let record = try await privateDB.record(for: recordID)
            print("✅ Found existing user profile")
            return record
        } catch let error as CKError where error.code == .unknownItem {
            // Create new profile
            print("📝 Creating new user profile...")
            
            let record = CKRecord(recordType: "UserProfile", recordID: recordID)
            record["displayName"] = displayName ?? UIDevice.current.name
            record["deviceName"] = UIDevice.current.name
            record["createdAt"] = Date()
            record["isActive"] = 1
            
            let savedRecord = try await privateDB.save(record)
            print("✅ Created user profile")
            return savedRecord
        }
    }
}

