//
//  CircleModel.xcdatamodeld
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData

// MARK: - User Entity
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
    @NSManaged public var memberships: Set<Membership>
    @NSManaged public var consentLogs: Set<ConsentLog>
    @NSManaged public var devices: Set<Device>
    @NSManaged public var leaderboardEntries: Set<LeaderboardEntry>
    @NSManaged public var wrappedStats: Set<WrappedStats>
}

// MARK: - Circle Entity
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
    @NSManaged public var memberships: Set<Membership>
}

// MARK: - Membership Entity (User ↔ Circle join table)
@objc(Membership)
public class Membership: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var role: String // "owner", "admin", "member"
    @NSManaged public var joinedAt: Date
    @NSManaged public var user: User
    @NSManaged public var circle: Circle
}

// MARK: - Challenge Entity
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
    @NSManaged public var template: ChallengeTemplate?
}

// MARK: - ChallengeTemplate Entity
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
    @NSManaged public var challenges: Set<Challenge>
}

// MARK: - Proof Entity
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
    @NSManaged public var confidenceScore: Double
}

// MARK: - HangoutSession Entity
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
    @NSManaged public var hangoutParticipants: Set<HangoutParticipant>
}

// MARK: - HangoutParticipant Entity (per-user hangout tracking)
@objc(HangoutParticipant)
public class HangoutParticipant: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var joinedAt: Date
    @NSManaged public var leftAt: Date?
    @NSManaged public var durationSec: Int32
    @NSManaged public var user: User
    @NSManaged public var session: HangoutSession
}

// MARK: - LeaderboardEntry Entity
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

// MARK: - WrappedStats Entity
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

// MARK: - ConsentLog Entity
@objc(ConsentLog)
public class ConsentLog: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var kind: String // "location_always", "motion", "health", "screen_time", etc.
    @NSManaged public var granted: Bool
    @NSManaged public var timestamp: Date
    @NSManaged public var user: User
}

// MARK: - Device Entity
@objc(Device)
public class Device: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var model: String
    @NSManaged public var osVersion: String
    @NSManaged public var lastSeenAt: Date
    @NSManaged public var user: User
}

// MARK: - Forfeit Entity
@objc(Forfeit)
public class Forfeit: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var description: String?
    @NSManaged public var type: String // "camera", "text", "voice"
    @NSManaged public var assignedAt: Date
    @NSManaged public var completedAt: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var pointsAwarded: Int32
    @NSManaged public var user: User
    @NSManaged public var circle: Circle
    @NSManaged public var proof: Proof?
}

// MARK: - PointsLedger Entity
@objc(PointsLedger)
public class PointsLedger: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var user: User
    @NSManaged public var points: Int32
    @NSManaged public var reason: String // "challenge_complete", "hangout", "forfeit", etc.
    @NSManaged public var timestamp: Date
    @NSManaged public var challenge: Challenge?
    @NSManaged public var hangoutSession: HangoutSession?
    @NSManaged public var forfeit: Forfeit?
}
