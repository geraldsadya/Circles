//
//  CoreDataExtensions.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import CloudKit

// MARK: - Core Data Extensions for CloudKit Integration

extension User {
    /// CloudKit record name for User entity
    static let cloudKitRecordType = "User"
    
    /// Create CloudKit record from User entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["appleUserID"] = appleUserID
        record["displayName"] = displayName
        record["profileEmoji"] = profileEmoji
        record["createdAt"] = createdAt
        record["lastActiveAt"] = lastActiveAt
        record["totalPoints"] = totalPoints
        record["weeklyPoints"] = weeklyPoints
        
        return record
    }
    
    /// Update User from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        appleUserID = record["appleUserID"] as? String ?? appleUserID
        displayName = record["displayName"] as? String ?? displayName
        profileEmoji = record["profileEmoji"] as? String
        createdAt = record["createdAt"] as? Date ?? createdAt
        lastActiveAt = record["lastActiveAt"] as? Date ?? lastActiveAt
        totalPoints = record["totalPoints"] as? Int32 ?? totalPoints
        weeklyPoints = record["weeklyPoints"] as? Int32 ?? weeklyPoints
    }
}
extension Circle {
    /// CloudKit record name for Circle entity
    static let cloudKitRecordType = "Circle"
    
    /// Create CloudKit record from Circle entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["name"] = name
        record["inviteCode"] = inviteCode
        record["createdAt"] = createdAt
        record["isActive"] = isActive
        
        return record
    }
    
    /// Update Circle from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        name = record["name"] as? String ?? name
        inviteCode = record["inviteCode"] as? String
        createdAt = record["createdAt"] as? Date ?? createdAt
        isActive = record["isActive"] as? Bool ?? isActive
    }
}

extension Challenge {
    /// CloudKit record name for Challenge entity
    static let cloudKitRecordType = "Challenge"
    
    /// Create CloudKit record from Challenge entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["title"] = title
        record["descriptionText"] = descriptionText
        record["category"] = category
        record["verificationMethod"] = verificationMethod
        record["targetValue"] = targetValue
        record["targetUnit"] = targetUnit
        record["frequency"] = frequency
        record["pointsReward"] = pointsReward
        record["pointsPenalty"] = pointsPenalty
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["isActive"] = isActive
        record["createdAt"] = createdAt
        
        // Store verification parameters as JSON
        if let params = verificationParams {
            record["verificationParams"] = params
        }
        
        // Reference relationships
        if let circle = circle {
            record["circleID"] = circle.id.uuidString
        }
        if let createdBy = createdBy {
            record["createdByID"] = createdBy.id.uuidString
        }
        if let template = template {
            record["templateID"] = template.id.uuidString
        }
        
        return record
    }
    
    /// Update Challenge from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        title = record["title"] as? String ?? title
        descriptionText = record["descriptionText"] as? String
        category = record["category"] as? String
        verificationMethod = record["verificationMethod"] as? String
        targetValue = record["targetValue"] as? Double ?? targetValue
        targetUnit = record["targetUnit"] as? String
        frequency = record["frequency"] as? String
        pointsReward = record["pointsReward"] as? Int32 ?? pointsReward
        pointsPenalty = record["pointsPenalty"] as? Int32 ?? pointsPenalty
        startDate = record["startDate"] as? Date ?? startDate
        endDate = record["endDate"] as? Date
        isActive = record["isActive"] as? Bool ?? isActive
        createdAt = record["createdAt"] as? Date ?? createdAt
        
        // Update verification parameters
        if let params = record["verificationParams"] as? Data {
            verificationParams = params
        }
    }
}

extension Proof {
    /// CloudKit record name for Proof entity
    static let cloudKitRecordType = "Proof"
    
    /// Create CloudKit record from Proof entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["isVerified"] = isVerified
        record["confidenceScore"] = confidenceScore
        record["verificationMethod"] = verificationMethod
        record["pointsAwarded"] = pointsAwarded
        record["notes"] = notes
        record["timestamp"] = timestamp
        record["createdAt"] = createdAt
        
        // Store sensor data as JSON
        if let sensorData = sensorData {
            record["sensorData"] = sensorData
        }
        
        // Reference relationships
        if let challenge = challenge {
            record["challengeID"] = challenge.id.uuidString
        }
        if let user = user {
            record["userID"] = user.id.uuidString
        }
        
        return record
    }
    
    /// Update Proof from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        isVerified = record["isVerified"] as? Bool ?? isVerified
        confidenceScore = record["confidenceScore"] as? Double ?? confidenceScore
        verificationMethod = record["verificationMethod"] as? String
        pointsAwarded = record["pointsAwarded"] as? Int32 ?? pointsAwarded
        notes = record["notes"] as? String
        timestamp = record["timestamp"] as? Date ?? timestamp
        createdAt = record["createdAt"] as? Date ?? createdAt
        
        // Update sensor data
        if let sensorData = record["sensorData"] as? Data {
            self.sensorData = sensorData
        }
    }
}

extension HangoutSession {
    /// CloudKit record name for HangoutSession entity
    static let cloudKitRecordType = "HangoutSession"
    
    /// Create CloudKit record from HangoutSession entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["duration"] = duration
        record["isActive"] = isActive
        record["pointsAwarded"] = pointsAwarded
        record["createdAt"] = createdAt
        
        // Store location data as JSON
        if let location = location {
            record["location"] = location
        }
        
        // Reference relationships
        if let circle = circle {
            record["circleID"] = circle.id.uuidString
        }
        
        return record
    }
    
    /// Update HangoutSession from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        startTime = record["startTime"] as? Date ?? startTime
        endTime = record["endTime"] as? Date
        duration = record["duration"] as? Double ?? duration
        isActive = record["isActive"] as? Bool ?? isActive
        pointsAwarded = record["pointsAwarded"] as? Int32 ?? pointsAwarded
        createdAt = record["createdAt"] as? Date ?? createdAt
        
        // Update location data
        if let location = record["location"] as? Data {
            self.location = location
        }
    }
}

extension PointsLedger {
    /// CloudKit record name for PointsLedger entity
    static let cloudKitRecordType = "PointsLedger"
    
    /// Create CloudKit record from PointsLedger entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["points"] = points
        record["reason"] = reason
        record["timestamp"] = timestamp
        record["createdAt"] = createdAt
        
        // Reference relationships
        if let user = user {
            record["userID"] = user.id.uuidString
        }
        if let challenge = challenge {
            record["challengeID"] = challenge.id.uuidString
        }
        
        return record
    }
    
    /// Update PointsLedger from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        points = record["points"] as? Int32 ?? points
        reason = record["reason"] as? String
        timestamp = record["timestamp"] as? Date ?? timestamp
        createdAt = record["createdAt"] as? Date ?? createdAt
    }
}

extension LeaderboardEntry {
    /// CloudKit record name for LeaderboardEntry entity
    static let cloudKitRecordType = "LeaderboardEntry"
    
    /// Create CloudKit record from LeaderboardEntry entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["points"] = points
        record["rank"] = rank
        record["weekStarting"] = weekStarting
        record["weekEnding"] = weekEnding
        record["createdAt"] = createdAt
        
        // Reference relationships
        if let user = user {
            record["userID"] = user.id.uuidString
        }
        if let circle = circle {
            record["circleID"] = circle.id.uuidString
        }
        
        return record
    }
    
    /// Update LeaderboardEntry from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        points = record["points"] as? Int32 ?? points
        rank = record["rank"] as? Int32 ?? rank
        weekStarting = record["weekStarting"] as? Date ?? weekStarting
        weekEnding = record["weekEnding"] as? Date ?? weekEnding
        createdAt = record["createdAt"] as? Date ?? createdAt
    }
}

extension Membership {
    /// CloudKit record name for Membership entity
    static let cloudKitRecordType = "Membership"
    
    /// Create CloudKit record from Membership entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["role"] = role
        record["joinedAt"] = joinedAt
        
        // Reference relationships
        if let user = user {
            record["userID"] = user.id.uuidString
        }
        if let circle = circle {
            record["circleID"] = circle.id.uuidString
        }
        
        return record
    }
    
    /// Update Membership from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        role = record["role"] as? String ?? role
        joinedAt = record["joinedAt"] as? Date ?? joinedAt
    }
}

extension Forfeit {
    /// CloudKit record name for Forfeit entity
    static let cloudKitRecordType = "Forfeit"
    
    /// Create CloudKit record from Forfeit entity
    func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.cloudKitRecordType, recordID: CKRecord.ID(recordName: id.uuidString))
        
        record["type"] = type
        record["descriptionText"] = descriptionText
        record["isCompleted"] = isCompleted
        record["pointsAwarded"] = pointsAwarded
        record["completedAt"] = completedAt
        record["createdAt"] = createdAt
        
        // Reference relationships
        if let assignedTo = assignedTo {
            record["assignedToID"] = assignedTo.id.uuidString
        }
        if let circle = circle {
            record["circleID"] = circle.id.uuidString
        }
        
        return record
    }
    
    /// Update Forfeit from CloudKit record
    func updateFromCloudKitRecord(_ record: CKRecord) {
        type = record["type"] as? String
        descriptionText = record["descriptionText"] as? String
        isCompleted = record["isCompleted"] as? Bool ?? isCompleted
        pointsAwarded = record["pointsAwarded"] as? Int32 ?? pointsAwarded
        completedAt = record["completedAt"] as? Date
        createdAt = record["createdAt"] as? Date ?? createdAt
    }
}

// MARK: - Convenience Methods for Entity Creation

extension User {
    /// Create a new User entity
    static func create(in context: NSManagedObjectContext, appleUserID: String, displayName: String) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.appleUserID = appleUserID
        user.displayName = displayName
        user.createdAt = Date()
        user.lastActiveAt = Date()
        user.totalPoints = 0
        user.weeklyPoints = 0
        return user
    }
}

extension Circle {
    /// Create a new Circle entity
    static func create(in context: NSManagedObjectContext, name: String) -> Circle {
        let circle = Circle(context: context)
        circle.id = UUID()
        circle.name = name
        circle.inviteCode = generateInviteCode()
        circle.createdAt = Date()
        circle.isActive = true
        return circle
    }
    
    /// Generate a unique invite code
    private static func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
}

extension Challenge {
    /// Create a new Challenge entity
    static func create(in context: NSManagedObjectContext, title: String, category: String, verificationMethod: String) -> Challenge {
        let challenge = Challenge(context: context)
        challenge.id = UUID()
        challenge.title = title
        challenge.category = category
        challenge.verificationMethod = verificationMethod
        challenge.createdAt = Date()
        challenge.startDate = Date()
        challenge.isActive = true
        challenge.pointsReward = 10
        challenge.pointsPenalty = -5
        return challenge
    }
}

extension Proof {
    /// Create a new Proof entity
    static func create(in context: NSManagedObjectContext, isVerified: Bool, confidenceScore: Double, verificationMethod: String) -> Proof {
        let proof = Proof(context: context)
        proof.id = UUID()
        proof.isVerified = isVerified
        proof.confidenceScore = confidenceScore
        proof.verificationMethod = verificationMethod
        proof.timestamp = Date()
        proof.createdAt = Date()
        proof.pointsAwarded = isVerified ? 10 : -5
        return proof
    }
}

extension HangoutSession {
    /// Create a new HangoutSession entity
    static func create(in context: NSManagedObjectContext, startTime: Date) -> HangoutSession {
        let session = HangoutSession(context: context)
        session.id = UUID()
        session.startTime = startTime
        session.createdAt = Date()
        session.isActive = true
        session.duration = 0.0
        session.pointsAwarded = 0
        return session
    }
}

extension PointsLedger {
    /// Create a new PointsLedger entry
    static func create(in context: NSManagedObjectContext, points: Int32, reason: String) -> PointsLedger {
        let entry = PointsLedger(context: context)
        entry.id = UUID()
        entry.points = points
        entry.reason = reason
        entry.timestamp = Date()
        entry.createdAt = Date()
        return entry
    }
}

extension LeaderboardEntry {
    /// Create a new LeaderboardEntry
    static func create(in context: NSManagedObjectContext, points: Int32, rank: Int32, weekStarting: Date, weekEnding: Date) -> LeaderboardEntry {
        let entry = LeaderboardEntry(context: context)
        entry.id = UUID()
        entry.points = points
        entry.rank = rank
        entry.weekStarting = weekStarting
        entry.weekEnding = weekEnding
        entry.createdAt = Date()
        return entry
    }
}

extension Membership {
    /// Create a new Membership
    static func create(in context: NSManagedObjectContext, role: String) -> Membership {
        let membership = Membership(context: context)
        membership.id = UUID()
        membership.role = role
        membership.joinedAt = Date()
        return membership
    }
}

extension Forfeit {
    /// Create a new Forfeit
    static func create(in context: NSManagedObjectContext, type: String, descriptionText: String) -> Forfeit {
        let forfeit = Forfeit(context: context)
        forfeit.id = UUID()
        forfeit.type = type
        forfeit.descriptionText = descriptionText
        forfeit.createdAt = Date()
        forfeit.isCompleted = false
        forfeit.pointsAwarded = 0
        return forfeit
    }
}

extension HangoutParticipant {
    /// Create a new HangoutParticipant
    static func create(in context: NSManagedObjectContext, joinedAt: Date) -> HangoutParticipant {
        let participant = HangoutParticipant(context: context)
        participant.id = UUID()
        participant.joinedAt = joinedAt
        participant.durationSec = 0
        return participant
    }
}

extension Device {
    /// Create a new Device
    static func create(in context: NSManagedObjectContext, model: String, osVersion: String) -> Device {
        let device = Device(context: context)
        device.id = UUID()
        device.model = model
        device.osVersion = osVersion
        device.createdAt = Date()
        device.lastSeenAt = Date()
        return device
    }
}

extension ChallengeTemplate {
    /// Create a new ChallengeTemplate
    static func create(in context: NSManagedObjectContext, title: String, category: String, verificationMethod: String, isPreset: Bool = false) -> ChallengeTemplate {
        let template = ChallengeTemplate(context: context)
        template.id = UUID()
        template.title = title
        template.category = category
        template.verificationMethod = verificationMethod
        template.isPreset = isPreset
        template.createdAt = Date()
        return template
    }
}

extension WrappedStats {
    /// Create a new WrappedStats
    static func create(in context: NSManagedObjectContext, year: Int32) -> WrappedStats {
        let stats = WrappedStats(context: context)
        stats.id = UUID()
        stats.year = year
        stats.createdAt = Date()
        return stats
    }
}

extension ConsentLogEntity {
    /// Create a new ConsentLogEntity
    static func create(in context: NSManagedObjectContext, permissionType: String, currentStatus: String) -> ConsentLogEntity {
        let log = ConsentLogEntity(context: context)
        log.id = UUID()
        log.permissionType = permissionType
        log.currentStatus = currentStatus
        log.timestamp = Date()
        log.createdAt = Date()
        return log
    }
}

extension SuspiciousActivityEntity {
    /// Create a new SuspiciousActivityEntity
    static func create(in context: NSManagedObjectContext, type: String, severity: String, description: String) -> SuspiciousActivityEntity {
        let activity = SuspiciousActivityEntity(context: context)
        activity.id = UUID()
        activity.type = type
        activity.severity = severity
        activity.description = description
        activity.timestamp = Date()
        activity.createdAt = Date()
        return activity
    }
}

extension AnalyticsEventEntity {
    /// Create a new AnalyticsEventEntity
    static func create(in context: NSManagedObjectContext, name: String, metadata: [String: String]? = nil) -> AnalyticsEventEntity {
        let event = AnalyticsEventEntity(context: context)
        event.id = UUID()
        event.name = name
        event.timestamp = Date()
        event.metadata = metadata as NSDictionary?
        return event
    }
}
