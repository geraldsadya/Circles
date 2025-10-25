//
//  VerificationConstants.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation

// MARK: - Verification Constants (iOS-Optimized)
enum Verify {
    // Hangout detection thresholds
    static let hangoutProximity = 10.0        // m (target)
    static let candidateBuffer = 15.0         // m (GPS buffer)
    static let hangoutPromote = 60.0          // s continuous candidate
    static let hangoutStale = 180.0           // s no updates
    static let hangoutMergeGap = 120.0        // s merge sessions
    
    // Location verification
    static let geofenceRadius = 75.0          // m default
    static let minDwellGym = 20.0             // min
    static let accThreshold = 50.0            // m required for credit
    static let locationAccuracyIdle = kCLLocationAccuracyHundredMeters
    static let locationAccuracyActive = kCLLocationAccuracyNearestTenMeters
    
    // Points and limits
    static let hangoutPtsPer5 = 5             // pts per 5 min
    static let dailyHangoutCapPts = 60        // max daily hangout points
    static let geofenceCooldownHours = 3.0    // hours between gym credits
    
    // Anti-cheat thresholds
    static let motionLocationMismatchMinutes = 10.0 // flag if GPS stationary but motion active
    static let clockTamperThreshold = 300.0   // s system uptime vs wall clock
    static let cameraLivenessFrames = 3        // frames for liveness check
    
    // Challenge points
    static let challengeCompletePoints = 10
    static let challengeMissPoints = -5
    static let groupChallengeBonus = 15
    static let forfeitCompletePoints = 5
    static let forfeitMissPoints = -10
}

// MARK: - Challenge Categories
enum ChallengeCategory: String, CaseIterable {
    case fitness = "fitness"
    case screenTime = "screen_time"
    case sleep = "sleep"
    case social = "social"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .fitness: return "Fitness"
        case .screenTime: return "Screen Time"
        case .sleep: return "Sleep"
        case .social: return "Social"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .fitness: return "figure.walk"
        case .screenTime: return "iphone"
        case .sleep: return "moon.fill"
        case .social: return "person.3.fill"
        case .custom: return "star.fill"
        }
    }
}

// MARK: - Verification Methods
enum VerificationMethod: String, CaseIterable {
    case location = "location"
    case motion = "motion"
    case health = "health"
    case screenTime = "screen_time"
    case camera = "camera"
    
    var displayName: String {
        switch self {
        case .location: return "Location"
        case .motion: return "Motion"
        case .health: return "Health"
        case .screenTime: return "Screen Time"
        case .camera: return "Camera"
        }
    }
    
    var icon: String {
        switch self {
        case .location: return "location.fill"
        case .motion: return "figure.walk"
        case .health: return "heart.fill"
        case .screenTime: return "iphone"
        case .camera: return "camera.fill"
        }
    }
}

// MARK: - Challenge Frequency
enum ChallengeFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Membership Roles
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
    
    var canCreateChallenges: Bool {
        switch self {
        case .owner, .admin: return true
        case .member: return false
        }
    }
    
    var canInviteMembers: Bool {
        switch self {
        case .owner, .admin: return true
        case .member: return false
        }
    }
}

// MARK: - Forfeit Types
enum ForfeitType: String, CaseIterable {
    case camera = "camera"
    case text = "text"
    case voice = "voice"
    
    var displayName: String {
        switch self {
        case .camera: return "Camera Proof"
        case .text: return "Text Challenge"
        case .voice: return "Voice Note"
        }
    }
    
    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .text: return "text.bubble.fill"
        case .voice: return "mic.fill"
        }
    }
}

// MARK: - JSON Structures for Verification Parameters
struct LocationChallengeParams: Codable {
    let targetLocation: CLLocationCoordinate2D
    let radiusMeters: Double
    let minDurationMinutes: Double
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case targetLocation = "target_location"
        case radiusMeters = "radius_meters"
        case minDurationMinutes = "min_duration_minutes"
        case name
    }
}

struct MotionChallengeParams: Codable {
    let minSteps: Int
    let activityType: String?
    let timeWindow: String?
    let minDistance: Double?
    
    enum CodingKeys: String, CodingKey {
        case minSteps = "min_steps"
        case activityType = "activity_type"
        case timeWindow = "time_window"
        case minDistance = "min_distance"
    }
}

struct ScreenTimeChallengeParams: Codable {
    let maxHours: Double
    let categories: [String]?
    
    enum CodingKeys: String, CodingKey {
        case maxHours = "max_hours"
        case categories
    }
}

struct SleepChallengeParams: Codable {
    let bedtimeBefore: String
    let wakeupAfter: String
    let minHours: Double?
    
    enum CodingKeys: String, CodingKey {
        case bedtimeBefore = "bedtime_before"
        case wakeupAfter = "wakeup_after"
        case minHours = "min_hours"
    }
}

struct CameraChallengeParams: Codable {
    let livenessRequired: Bool
    let durationSeconds: Int
    let prompts: [String]
    
    enum CodingKeys: String, CodingKey {
        case livenessRequired = "liveness_required"
        case durationSeconds = "duration_seconds"
        case prompts
    }
}

// MARK: - Verification Result Data
struct VerificationResult: Codable {
    let isVerified: Bool
    let confidenceScore: Double
    let verificationTimestamp: Date
    let sensorData: SensorData?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case isVerified = "is_verified"
        case confidenceScore = "confidence_score"
        case verificationTimestamp = "verification_timestamp"
        case sensorData = "sensor_data"
        case notes
    }
}

struct SensorData: Codable {
    let location: LocationData?
    let motion: MotionData?
    let health: HealthData?
    let camera: CameraData?
    
    enum CodingKeys: String, CodingKey {
        case location
        case motion
        case health
        case camera
    }
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    let durationAtLocation: Double?
    
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case accuracy
        case timestamp
        case durationAtLocation = "duration_at_location"
    }
}

struct MotionData: Codable {
    let stepCount: Int
    let distance: Double
    let activityType: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case stepCount = "step_count"
        case distance
        case activityType = "activity_type"
        case timestamp
    }
}

struct HealthData: Codable {
    let sleepStartTime: Date?
    let sleepEndTime: Date?
    let activeMinutes: Int?
    let heartRate: Double?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case sleepStartTime = "sleep_start_time"
        case sleepEndTime = "sleep_end_time"
        case activeMinutes = "active_minutes"
        case heartRate = "heart_rate"
        case timestamp
    }
}

struct CameraData: Codable {
    let frameHashes: [String]
    let livenessScore: Double?
    let duration: Double
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case frameHashes = "frame_hashes"
        case livenessScore = "liveness_score"
        case duration
        case timestamp
    }
}
