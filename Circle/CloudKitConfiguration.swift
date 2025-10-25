//
//  CloudKitConfiguration.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CloudKit
import CoreData

// MARK: - CloudKit Configuration

struct CloudKitConfiguration {
    /// CloudKit container identifier
    static let containerIdentifier = "iCloud.com.circle.app"
    
    /// CloudKit database types
    enum DatabaseType {
        case `private`
        case shared
        case `public`
    }
    
    /// Get CloudKit container
    static var container: CKContainer {
        return CKContainer(identifier: containerIdentifier)
    }
    
    /// Get CloudKit database
    static func database(for type: DatabaseType) -> CKDatabase {
        switch type {
        case .private:
            return container.privateCloudDatabase
        case .shared:
            return container.sharedCloudDatabase
        case .public:
            return container.publicCloudDatabase
        }
    }
    
    /// CloudKit record types
    enum RecordType: String, CaseIterable {
        case user = "User"
        case circle = "Circle"
        case challenge = "Challenge"
        case proof = "Proof"
        case hangoutSession = "HangoutSession"
        case pointsLedger = "PointsLedger"
        case leaderboardEntry = "LeaderboardEntry"
        case membership = "Membership"
        case forfeit = "Forfeit"
        case hangoutParticipant = "HangoutParticipant"
        case device = "Device"
        case challengeTemplate = "ChallengeTemplate"
        case wrappedStats = "WrappedStats"
        case consentLog = "ConsentLog"
        case suspiciousActivity = "SuspiciousActivity"
        case analyticsEvent = "AnalyticsEvent"
    }
    
    /// CloudKit subscription types
    enum SubscriptionType: String, CaseIterable {
        case challengeCreated = "ChallengeCreated"
        case challengeUpdated = "ChallengeUpdated"
        case proofCreated = "ProofCreated"
        case hangoutStarted = "HangoutStarted"
        case hangoutEnded = "HangoutEnded"
        case forfeitAssigned = "ForfeitAssigned"
        case forfeitCompleted = "ForfeitCompleted"
        case leaderboardUpdated = "LeaderboardUpdated"
        case membershipChanged = "MembershipChanged"
    }
}

// MARK: - CloudKit Record Field Names

struct CloudKitFields {
    // User fields
    static let userAppleID = "appleUserID"
    static let userDisplayName = "displayName"
    static let userProfileEmoji = "profileEmoji"
    static let userCreatedAt = "createdAt"
    static let userLastActiveAt = "lastActiveAt"
    static let userTotalPoints = "totalPoints"
    static let userWeeklyPoints = "weeklyPoints"
    
    // Circle fields
    static let circleName = "name"
    static let circleInviteCode = "inviteCode"
    static let circleCreatedAt = "createdAt"
    static let circleIsActive = "isActive"
    
    // Challenge fields
    static let challengeTitle = "title"
    static let challengeDescription = "descriptionText"
    static let challengeCategory = "category"
    static let challengeVerificationMethod = "verificationMethod"
    static let challengeTargetValue = "targetValue"
    static let challengeTargetUnit = "targetUnit"
    static let challengeFrequency = "frequency"
    static let challengePointsReward = "pointsReward"
    static let challengePointsPenalty = "pointsPenalty"
    static let challengeStartDate = "startDate"
    static let challengeEndDate = "endDate"
    static let challengeIsActive = "isActive"
    static let challengeCreatedAt = "createdAt"
    static let challengeVerificationParams = "verificationParams"
    
    // Proof fields
    static let proofIsVerified = "isVerified"
    static let proofConfidenceScore = "confidenceScore"
    static let proofVerificationMethod = "verificationMethod"
    static let proofPointsAwarded = "pointsAwarded"
    static let proofNotes = "notes"
    static let proofTimestamp = "timestamp"
    static let proofCreatedAt = "createdAt"
    static let proofSensorData = "sensorData"
    
    // HangoutSession fields
    static let hangoutStartTime = "startTime"
    static let hangoutEndTime = "endTime"
    static let hangoutDuration = "duration"
    static let hangoutIsActive = "isActive"
    static let hangoutPointsAwarded = "pointsAwarded"
    static let hangoutCreatedAt = "createdAt"
    static let hangoutLocation = "location"
    
    // PointsLedger fields
    static let pointsLedgerPoints = "points"
    static let pointsLedgerReason = "reason"
    static let pointsLedgerTimestamp = "timestamp"
    static let pointsLedgerCreatedAt = "createdAt"
    
    // LeaderboardEntry fields
    static let leaderboardPoints = "points"
    static let leaderboardRank = "rank"
    static let leaderboardWeekStarting = "weekStarting"
    static let leaderboardWeekEnding = "weekEnding"
    static let leaderboardCreatedAt = "createdAt"
    
    // Membership fields
    static let membershipRole = "role"
    static let membershipJoinedAt = "joinedAt"
    
    // Forfeit fields
    static let forfeitType = "type"
    static let forfeitDescription = "descriptionText"
    static let forfeitIsCompleted = "isCompleted"
    static let forfeitPointsAwarded = "pointsAwarded"
    static let forfeitCompletedAt = "completedAt"
    static let forfeitCreatedAt = "createdAt"
    
    // HangoutParticipant fields
    static let participantDurationSec = "durationSec"
    static let participantJoinedAt = "joinedAt"
    static let participantLeftAt = "leftAt"
    
    // Device fields
    static let deviceModel = "model"
    static let deviceOSVersion = "osVersion"
    static let deviceCreatedAt = "createdAt"
    static let deviceLastSeenAt = "lastSeenAt"
    
    // ChallengeTemplate fields
    static let templateTitle = "title"
    static let templateDescription = "descriptionText"
    static let templateCategory = "category"
    static let templateVerificationMethod = "verificationMethod"
    static let templateTargetValue = "targetValue"
    static let templateTargetUnit = "targetUnit"
    static let templateFrequency = "frequency"
    static let templateIsPreset = "isPreset"
    static let templateLocalizedTitle = "localizedTitle"
    static let templateCreatedAt = "createdAt"
    static let templateVerificationParams = "verificationParams"
    
    // WrappedStats fields
    static let wrappedYear = "year"
    static let wrappedStatsData = "statsData"
    static let wrappedCreatedAt = "createdAt"
    
    // ConsentLog fields
    static let consentPermissionType = "permissionType"
    static let consentCurrentStatus = "currentStatus"
    static let consentPreviousStatus = "previousStatus"
    static let consentTimestamp = "timestamp"
    static let consentCreatedAt = "createdAt"
    static let consentUserAction = "userAction"
    static let consentReason = "reason"
    static let consentAppVersion = "appVersion"
    static let consentDeviceInfo = "deviceInfo"
    
    // SuspiciousActivity fields
    static let suspiciousType = "type"
    static let suspiciousSeverity = "severity"
    static let suspiciousDescription = "description"
    static let suspiciousTimestamp = "timestamp"
    static let suspiciousCreatedAt = "createdAt"
    static let suspiciousDetails = "details"
    
    // AnalyticsEvent fields
    static let analyticsName = "name"
    static let analyticsTimestamp = "timestamp"
    static let analyticsMetadata = "metadata"
    
    // Reference fields
    static let userID = "userID"
    static let circleID = "circleID"
    static let challengeID = "challengeID"
    static let proofID = "proofID"
    static let hangoutSessionID = "hangoutSessionID"
    static let pointsLedgerID = "pointsLedgerID"
    static let leaderboardEntryID = "leaderboardEntryID"
    static let membershipID = "membershipID"
    static let forfeitID = "forfeitID"
    static let hangoutParticipantID = "hangoutParticipantID"
    static let deviceID = "deviceID"
    static let templateID = "templateID"
    static let wrappedStatsID = "wrappedStatsID"
    static let consentLogID = "consentLogID"
    static let suspiciousActivityID = "suspiciousActivityID"
    static let analyticsEventID = "analyticsEventID"
    static let createdByID = "createdByID"
    static let assignedToID = "assignedToID"
}

// MARK: - CloudKit Error Handling

extension CloudKitConfiguration {
    /// Handle CloudKit errors
    static func handleCloudKitError(_ error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable:
                return "Network unavailable. Please check your internet connection."
            case .networkFailure:
                return "Network failure. Please try again."
            case .serviceUnavailable:
                return "CloudKit service is temporarily unavailable."
            case .requestRateLimited:
                return "Too many requests. Please wait a moment and try again."
            case .quotaExceeded:
                return "Storage quota exceeded. Please contact support."
            case .userDeletedZone:
                return "User data has been deleted. Please sign in again."
            case .zoneNotFound:
                return "Data zone not found. Please contact support."
            case .operationCancelled:
                return "Operation was cancelled."
            case .changeTokenExpired:
                return "Sync token expired. Please restart the app."
            case .batchRequestFailed:
                return "Batch request failed. Some operations may not have completed."
            case .zoneBusy:
                return "Data zone is busy. Please try again in a moment."
            case .badDatabase:
                return "Database error. Please contact support."
            case .quotaExceeded:
                return "Storage quota exceeded. Please contact support."
            case .notAuthenticated:
                return "Not authenticated. Please sign in again."
            case .permissionFailure:
                return "Permission denied. Please check your iCloud settings."
            case .unknownItem:
                return "Item not found."
            case .invalidArguments:
                return "Invalid arguments. Please contact support."
            case .resultsTruncated:
                return "Results were truncated. Some data may be missing."
            case .serverRecordChanged:
                return "Record was changed by another device. Please try again."
            case .serverRejectedRequest:
                return "Server rejected request. Please try again."
            case .assetFileNotFound:
                return "Asset file not found."
            case .assetFileModified:
                return "Asset file was modified."
            case .incompatibleVersion:
                return "Incompatible version. Please update the app."
            case .constraintViolation:
                return "Constraint violation. Please check your data."
            case .operationNotAllowed:
                return "Operation not allowed."
            case .capabilityUnavailable:
                return "Capability unavailable."
            case .fileSizeExceeded:
                return "File size exceeded."
            case .itemExists:
                return "Item already exists."
            case .readOnly:
                return "Read-only operation."
            case .atomicWrite:
                return "Atomic write failed."
            case .serverResponseLost:
                return "Server response lost."
            case .assetNotAvailable:
                return "Asset not available."
            case .tooManyParticipants:
                return "Too many participants."
            case .alreadyShared:
                return "Already shared."
            case .referenceViolation:
                return "Reference violation."
            case .managedAccountRestricted:
                return "Managed account restricted."
            case .participantMayNeedVerification:
                return "Participant may need verification."
            case .serverResponseLost:
                return "Server response lost."
            case .assetNotAvailable:
                return "Asset not available."
            case .tooManyParticipants:
                return "Too many participants."
            case .alreadyShared:
                return "Already shared."
            case .referenceViolation:
                return "Reference violation."
            case .managedAccountRestricted:
                return "Managed account restricted."
            case .participantMayNeedVerification:
                return "Participant may need verification."
            case .serverResponseLost:
                return "Server response lost."
            case .assetNotAvailable:
                return "Asset not available."
            case .tooManyParticipants:
                return "Too many participants."
            case .alreadyShared:
                return "Already shared."
            case .referenceViolation:
                return "Reference violation."
            case .managedAccountRestricted:
                return "Managed account restricted."
            case .participantMayNeedVerification:
                return "Participant may need verification."
            default:
                return "CloudKit error: \(ckError.localizedDescription)"
            }
        }
        return "Unknown error: \(error.localizedDescription)"
    }
}

// MARK: - CloudKit Sync Status

enum CloudKitSyncStatus {
    case notStarted
    case inProgress
    case completed
    case failed(Error)
    case paused
    
    var isActive: Bool {
        switch self {
        case .inProgress:
            return true
        default:
            return false
        }
    }
    
    var isCompleted: Bool {
        switch self {
        case .completed:
            return true
        default:
            return false
        }
    }
    
    var isFailed: Bool {
        switch self {
        case .failed:
            return true
        default:
            return false
        }
    }
}
