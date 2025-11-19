//
//  UserProfileManager.swift
//  Circle
//
//  Real-time user profile management with CloudKit
//

import Foundation
import CloudKit
import CoreLocation
import Combine

@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var currentUserProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let container = CKContainer(identifier: "iCloud.com.circle.app")
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var publicDatabase: CKDatabase { container.publicCloudDatabase }
    
    private init() {}
    
    // MARK: - User Profile Creation
    func createUserProfile(appleUserID: String, displayName: String, profileEmoji: String) async throws -> UserProfile {
        print("👤 Creating user profile for: \(displayName)")
        
        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: "User_\(appleUserID)")
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        
        record["appleUserID"] = appleUserID
        record["displayName"] = displayName
        record["profileEmoji"] = profileEmoji
        record["createdAt"] = Date()
        record["totalPoints"] = 0
        record["weeklyPoints"] = 0
        record["isActive"] = true
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            print("✅ User profile created in CloudKit: \(savedRecord.recordID.recordName)")
            
            let profile = UserProfile(from: savedRecord)
            currentUserProfile = profile
            return profile
        } catch {
            print("❌ Failed to create user profile: \(error.localizedDescription)")
            errorMessage = "Failed to create profile: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Fetch User Profile
    func fetchUserProfile(appleUserID: String) async throws -> UserProfile? {
        print("🔍 Fetching user profile for: \(appleUserID)")
        
        let recordID = CKRecord.ID(recordName: "User_\(appleUserID)")
        
        do {
            let record = try await publicDatabase.record(for: recordID)
            print("✅ User profile found in CloudKit")
            let profile = UserProfile(from: record)
            currentUserProfile = profile
            return profile
        } catch let error as CKError where error.code == .unknownItem {
            print("ℹ️ User profile not found - needs to be created")
            return nil
        } catch {
            print("❌ Failed to fetch user profile: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Update Location
    func updateLocation(_ location: CLLocationCoordinate2D) async throws {
        guard let profile = currentUserProfile else {
            print("⚠️ No current user profile to update location")
            return
        }
        
        let recordID = CKRecord.ID(recordName: profile.recordName)
        
        do {
            let record = try await publicDatabase.record(for: recordID)
            record["latitude"] = location.latitude
            record["longitude"] = location.longitude
            record["lastLocationUpdate"] = Date()
            
            let savedRecord = try await publicDatabase.save(record)
            print("📍 Location updated in CloudKit: \(location.latitude), \(location.longitude)")
            
            // Update local profile
            var updatedProfile = profile
            updatedProfile.latitude = location.latitude
            updatedProfile.longitude = location.longitude
            updatedProfile.lastLocationUpdate = Date()
            currentUserProfile = updatedProfile
        } catch {
            print("❌ Failed to update location: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Fetch Friend Profiles
    func fetchFriendProfiles(friendIDs: [String]) async throws -> [UserProfile] {
        print("👥 Fetching \(friendIDs.count) friend profiles")
        
        let recordIDs = friendIDs.map { CKRecord.ID(recordName: $0) }
        
        do {
            let results = try await publicDatabase.records(for: recordIDs)
            var profiles: [UserProfile] = []
            
            for (recordID, result) in results {
                switch result {
                case .success(let record):
                    let profile = UserProfile(from: record)
                    profiles.append(profile)
                    print("✅ Loaded profile: \(profile.displayName)")
                case .failure(let error):
                    print("⚠️ Failed to load profile \(recordID.recordName): \(error.localizedDescription)")
                }
            }
            
            print("✅ Loaded \(profiles.count)/\(friendIDs.count) friend profiles")
            return profiles
        } catch {
            print("❌ Failed to fetch friend profiles: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Search Users
    func searchUsers(by displayName: String) async throws -> [UserProfile] {
        print("🔍 Searching for users with name: \(displayName)")
        
        let predicate = NSPredicate(format: "displayName CONTAINS[cd] %@", displayName)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
        
        do {
            let results = try await publicDatabase.records(matching: query)
            var profiles: [UserProfile] = []
            
            for (_, result) in results.matchResults {
                switch result {
                case .success(let record):
                    let profile = UserProfile(from: record)
                    profiles.append(profile)
                case .failure(let error):
                    print("⚠️ Error loading search result: \(error.localizedDescription)")
                }
            }
            
            print("✅ Found \(profiles.count) users matching '\(displayName)'")
            return profiles
        } catch {
            print("❌ Search failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - User Profile Model
struct UserProfile: Identifiable, Codable {
    let id: String
    let recordName: String
    let appleUserID: String
    var displayName: String
    var profileEmoji: String
    var latitude: Double?
    var longitude: Double?
    var lastLocationUpdate: Date?
    var totalPoints: Int
    var weeklyPoints: Int
    var isActive: Bool
    var createdAt: Date
    
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.recordName = record.recordID.recordName
        self.appleUserID = record["appleUserID"] as? String ?? ""
        self.displayName = record["displayName"] as? String ?? "Unknown"
        self.profileEmoji = record["profileEmoji"] as? String ?? "👤"
        self.latitude = record["latitude"] as? Double
        self.longitude = record["longitude"] as? Double
        self.lastLocationUpdate = record["lastLocationUpdate"] as? Date
        self.totalPoints = record["totalPoints"] as? Int ?? 0
        self.weeklyPoints = record["weeklyPoints"] as? Int ?? 0
        self.isActive = record["isActive"] as? Bool ?? true
        self.createdAt = record["createdAt"] as? Date ?? Date()
    }
    
    var location: CLLocationCoordinate2D? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

