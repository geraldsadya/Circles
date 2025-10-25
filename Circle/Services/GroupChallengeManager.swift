//
//  GroupChallengeManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class GroupChallengeManager: ObservableObject {
    static let shared = GroupChallengeManager()
    
    @Published var activeGroupChallenges: [GroupChallenge] = []
    @Published var groupChallengeResults: [GroupChallengeResult] = []
    @Published var groupBonusHistory: [GroupBonus] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let challengeEngine = ChallengeEngine.shared
    private let pointsEngine = PointsEngine.shared
    private let hangoutEngine = HangoutEngine.shared
    
    // Group challenge configuration
    private let groupConfig = GroupChallengeConfiguration()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
        loadGroupChallenges()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChallengeCompleted),
            name: .challengeCompleted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHangoutDetected),
            name: .hangoutDetected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePointsEarned),
            name: .pointsEarned,
            object: nil
        )
    }
    
    // MARK: - Group Challenge Creation
    func createGroupChallenge(_ challenge: Challenge, circle: Circle) async -> GroupChallenge? {
        guard let challengeId = challenge.id else { return nil }
        
        let groupChallenge = GroupChallenge(
            id: UUID(),
            challengeId: challengeId,
            circleId: circle.id ?? UUID(),
            circleName: circle.name ?? "Unknown Circle",
            challengeName: challenge.name ?? "Unknown Challenge",
            challengeType: challenge.category ?? "general",
            startDate: challenge.startDate ?? Date(),
            endDate: challenge.endDate ?? Date(),
            targetValue: challenge.targetValue,
            targetUnit: challenge.targetUnit ?? "",
            isActive: true,
            participants: getCircleMembers(circle),
            completionThreshold: groupConfig.defaultCompletionThreshold,
            bonusMultiplier: groupConfig.defaultBonusMultiplier,
            createdAt: Date()
        )
        
        // Save to Core Data
        await saveGroupChallenge(groupChallenge)
        
        // Add to active challenges
        activeGroupChallenges.append(groupChallenge)
        
        logGroup("Group challenge created: \(groupChallenge.challengeName)")
        
        return groupChallenge
    }
    
    private func getCircleMembers(_ circle: Circle) -> [GroupChallengeParticipant] {
        // Get circle members from Core Data
        let request: NSFetchRequest<Membership> = Membership.fetchRequest()
        request.predicate = NSPredicate(format: "circle == %@", circle)
        
        do {
            let memberships = try persistenceController.container.viewContext.fetch(request)
            return memberships.map { membership in
                GroupChallengeParticipant(
                    userId: membership.user?.id ?? UUID(),
                    userName: membership.user?.name ?? "Unknown User",
                    role: membership.role ?? "member",
                    isActive: true,
                    joinedAt: membership.joinedAt ?? Date()
                )
            }
        } catch {
            logGroup("Error loading circle members: \(error)")
            return []
        }
    }
    
    // MARK: - Group Challenge Tracking
    func trackGroupChallengeProgress(_ groupChallenge: GroupChallenge) async {
        // Get all participants' challenge results
        let participantResults = await getParticipantResults(for: groupChallenge)
        
        // Calculate group progress
        let groupProgress = calculateGroupProgress(participantResults)
        
        // Check if group challenge is completed
        let isCompleted = groupProgress.completionPercentage >= groupChallenge.completionThreshold
        
        if isCompleted && groupChallenge.isActive {
            await completeGroupChallenge(groupChallenge, progress: groupProgress)
        }
        
        // Update group challenge
        await updateGroupChallenge(groupChallenge, progress: groupProgress)
    }
    
    private func getParticipantResults(for groupChallenge: GroupChallenge) async -> [GroupChallengeParticipantResult] {
        var results: [GroupChallengeParticipantResult] = []
        
        for participant in groupChallenge.participants {
            let result = await getParticipantResult(participant, groupChallenge: groupChallenge)
            results.append(result)
        }
        
        return results
    }
    
    private func getParticipantResult(_ participant: GroupChallengeParticipant, groupChallenge: GroupChallenge) async -> GroupChallengeParticipantResult {
        // Get challenge result for participant
        let request: NSFetchRequest<ChallengeResult> = ChallengeResult.fetchRequest()
        request.predicate = NSPredicate(format: "challenge.id == %@ AND user.id == %@", groupChallenge.challengeId as CVarArg, participant.userId as CVarArg)
        
        do {
            let challengeResults = try persistenceController.container.viewContext.fetch(request)
            let isCompleted = challengeResults.contains { $0.isCompleted }
            let completionCount = challengeResults.filter { $0.isCompleted }.count
            
            return GroupChallengeParticipantResult(
                participant: participant,
                isCompleted: isCompleted,
                completionCount: completionCount,
                lastCompletedAt: challengeResults.first?.completedAt,
                pointsEarned: challengeResults.reduce(0) { $0 + Int($1.pointsEarned) }
            )
        } catch {
            logGroup("Error loading participant result: \(error)")
            return GroupChallengeParticipantResult(
                participant: participant,
                isCompleted: false,
                completionCount: 0,
                lastCompletedAt: nil,
                pointsEarned: 0
            )
        }
    }
    
    private func calculateGroupProgress(_ results: [GroupChallengeParticipantResult]) -> GroupChallengeProgress {
        let totalParticipants = results.count
        let completedParticipants = results.filter { $0.isCompleted }.count
        let completionPercentage = totalParticipants > 0 ? Double(completedParticipants) / Double(totalParticipants) : 0
        
        let totalPoints = results.reduce(0) { $0 + $1.pointsEarned }
        let averagePoints = totalParticipants > 0 ? totalPoints / totalParticipants : 0
        
        let completionStreak = calculateCompletionStreak(results)
        let groupCohesion = calculateGroupCohesion(results)
        
        return GroupChallengeProgress(
            totalParticipants: totalParticipants,
            completedParticipants: completedParticipants,
            completionPercentage: completionPercentage,
            totalPoints: totalPoints,
            averagePoints: averagePoints,
            completionStreak: completionStreak,
            groupCohesion: groupCohesion,
            lastUpdated: Date()
        )
    }
    
    private func calculateCompletionStreak(_ results: [GroupChallengeParticipantResult]) -> Int {
        // Calculate consecutive days of group completion
        // This would analyze historical data
        return results.filter { $0.isCompleted }.count
    }
    
    private func calculateGroupCohesion(_ results: [GroupChallengeParticipantResult]) -> Double {
        // Calculate group cohesion based on participation patterns
        let activeParticipants = results.filter { $0.completionCount > 0 }.count
        let totalParticipants = results.count
        
        return totalParticipants > 0 ? Double(activeParticipants) / Double(totalParticipants) : 0
    }
    
    // MARK: - Group Challenge Completion
    private func completeGroupChallenge(_ groupChallenge: GroupChallenge, progress: GroupChallengeProgress) async {
        // Create group challenge result
        let result = GroupChallengeResult(
            id: UUID(),
            groupChallengeId: groupChallenge.id,
            circleId: groupChallenge.circleId,
            challengeName: groupChallenge.challengeName,
            completedAt: Date(),
            completionPercentage: progress.completionPercentage,
            totalParticipants: progress.totalParticipants,
            completedParticipants: progress.completedParticipants,
            totalPoints: progress.totalPoints,
            averagePoints: progress.averagePoints,
            bonusPoints: calculateBonusPoints(groupChallenge, progress: progress),
            bonusMultiplier: groupChallenge.bonusMultiplier
        )
        
        // Save result
        await saveGroupChallengeResult(result)
        
        // Award bonus points to all participants
        await awardBonusPoints(groupChallenge, result: result)
        
        // Deactivate group challenge
        await deactivateGroupChallenge(groupChallenge)
        
        // Add to results
        groupChallengeResults.append(result)
        
        logGroup("Group challenge completed: \(groupChallenge.challengeName)")
    }
    
    private func calculateBonusPoints(_ groupChallenge: GroupChallenge, progress: GroupChallengeProgress) -> Int {
        let basePoints = groupChallenge.targetValue * 10 // Base points per challenge
        let completionBonus = progress.completionPercentage * 100 // Completion bonus
        let cohesionBonus = progress.groupCohesion * 50 // Cohesion bonus
        
        let totalBonus = (basePoints + completionBonus + cohesionBonus) * groupChallenge.bonusMultiplier
        
        return Int(totalBonus)
    }
    
    private func awardBonusPoints(_ groupChallenge: GroupChallenge, result: GroupChallengeResult) async {
        for participant in groupChallenge.participants {
            let bonus = GroupBonus(
                id: UUID(),
                userId: participant.userId,
                groupChallengeId: groupChallenge.id,
                challengeName: groupChallenge.challengeName,
                bonusPoints: result.bonusPoints,
                bonusMultiplier: result.bonusMultiplier,
                awardedAt: Date(),
                reason: "Group challenge completion bonus"
            )
            
            // Save bonus
            await saveGroupBonus(bonus)
            
            // Award points
            await pointsEngine.awardPoints(
                userId: participant.userId,
                points: result.bonusPoints,
                reason: "Group Challenge Bonus",
                category: .groupChallenge,
                metadata: [
                    "groupChallengeId": groupChallenge.id.uuidString,
                    "challengeName": groupChallenge.challengeName,
                    "bonusMultiplier": String(result.bonusMultiplier)
                ]
            )
            
            // Add to history
            groupBonusHistory.append(bonus)
        }
    }
    
    // MARK: - Do It Together Bonus
    func checkDoItTogetherBonus(_ challenge: Challenge, circle: Circle) async -> DoItTogetherBonus? {
        // Check if multiple members completed the same challenge on the same day
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let request: NSFetchRequest<ChallengeResult> = ChallengeResult.fetchRequest()
        request.predicate = NSPredicate(format: "challenge.id == %@ AND completedAt >= %@ AND completedAt < %@ AND isCompleted == YES", challenge.id as CVarArg, today as CVarArg, tomorrow as CVarArg)
        
        do {
            let results = try persistenceController.container.viewContext.fetch(request)
            let completedUsers = Set(results.map { $0.user?.id })
            
            // Check if at least 2 users completed the challenge
            if completedUsers.count >= 2 {
                let bonus = DoItTogetherBonus(
                    id: UUID(),
                    challengeId: challenge.id ?? UUID(),
                    challengeName: challenge.name ?? "Unknown Challenge",
                    circleId: circle.id ?? UUID(),
                    circleName: circle.name ?? "Unknown Circle",
                    completedUsers: Array(completedUsers),
                    bonusPoints: groupConfig.doItTogetherBonusPoints,
                    completedAt: Date(),
                    reason: "Do It Together Bonus"
                )
                
                // Award bonus points
                await awardDoItTogetherBonus(bonus)
                
                return bonus
            }
        } catch {
            logGroup("Error checking Do It Together bonus: \(error)")
        }
        
        return nil
    }
    
    private func awardDoItTogetherBonus(_ bonus: DoItTogetherBonus) async {
        for userId in bonus.completedUsers {
            // Award bonus points
            await pointsEngine.awardPoints(
                userId: userId,
                points: bonus.bonusPoints,
                reason: "Do It Together Bonus",
                category: .groupChallenge,
                metadata: [
                    "challengeId": bonus.challengeId.uuidString,
                    "challengeName": bonus.challengeName,
                    "circleId": bonus.circleId.uuidString,
                    "circleName": bonus.circleName,
                    "completedUsers": String(bonus.completedUsers.count)
                ]
            )
            
            // Save bonus
            let groupBonus = GroupBonus(
                id: UUID(),
                userId: userId,
                groupChallengeId: nil,
                challengeName: bonus.challengeName,
                bonusPoints: bonus.bonusPoints,
                bonusMultiplier: 1.0,
                awardedAt: Date(),
                reason: bonus.reason
            )
            
            await saveGroupBonus(groupBonus)
            groupBonusHistory.append(groupBonus)
        }
    }
    
    // MARK: - Data Persistence
    private func saveGroupChallenge(_ groupChallenge: GroupChallenge) async {
        let context = persistenceController.container.viewContext
        
        let groupChallengeEntity = GroupChallengeEntity(context: context)
        groupChallengeEntity.id = groupChallenge.id
        groupChallengeEntity.challengeId = groupChallenge.challengeId
        groupChallengeEntity.circleId = groupChallenge.circleId
        groupChallengeEntity.circleName = groupChallenge.circleName
        groupChallengeEntity.challengeName = groupChallenge.challengeName
        groupChallengeEntity.challengeType = groupChallenge.challengeType
        groupChallengeEntity.startDate = groupChallenge.startDate
        groupChallengeEntity.endDate = groupChallenge.endDate
        groupChallengeEntity.targetValue = groupChallenge.targetValue
        groupChallengeEntity.targetUnit = groupChallenge.targetUnit
        groupChallengeEntity.isActive = groupChallenge.isActive
        groupChallengeEntity.completionThreshold = groupChallenge.completionThreshold
        groupChallengeEntity.bonusMultiplier = groupChallenge.bonusMultiplier
        groupChallengeEntity.createdAt = groupChallenge.createdAt
        
        try? context.save()
    }
    
    private func saveGroupChallengeResult(_ result: GroupChallengeResult) async {
        let context = persistenceController.container.viewContext
        
        let resultEntity = GroupChallengeResultEntity(context: context)
        resultEntity.id = result.id
        resultEntity.groupChallengeId = result.groupChallengeId
        resultEntity.circleId = result.circleId
        resultEntity.challengeName = result.challengeName
        resultEntity.completedAt = result.completedAt
        resultEntity.completionPercentage = result.completionPercentage
        resultEntity.totalParticipants = Int32(result.totalParticipants)
        resultEntity.completedParticipants = Int32(result.completedParticipants)
        resultEntity.totalPoints = Int32(result.totalPoints)
        resultEntity.averagePoints = Int32(result.averagePoints)
        resultEntity.bonusPoints = Int32(result.bonusPoints)
        resultEntity.bonusMultiplier = result.bonusMultiplier
        resultEntity.createdAt = Date()
        
        try? context.save()
    }
    
    private func saveGroupBonus(_ bonus: GroupBonus) async {
        let context = persistenceController.container.viewContext
        
        let bonusEntity = GroupBonusEntity(context: context)
        bonusEntity.id = bonus.id
        bonusEntity.userId = bonus.userId
        bonusEntity.groupChallengeId = bonus.groupChallengeId
        bonusEntity.challengeName = bonus.challengeName
        bonusEntity.bonusPoints = Int32(bonus.bonusPoints)
        bonusEntity.bonusMultiplier = bonus.bonusMultiplier
        bonusEntity.awardedAt = bonus.awardedAt
        bonusEntity.reason = bonus.reason
        bonusEntity.createdAt = Date()
        
        try? context.save()
    }
    
    private func loadGroupChallenges() {
        let request: NSFetchRequest<GroupChallengeEntity> = GroupChallengeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GroupChallengeEntity.createdAt, ascending: false)]
        
        do {
            let entities = try persistenceController.container.viewContext.fetch(request)
            activeGroupChallenges = entities.map { entity in
                GroupChallenge(
                    id: entity.id ?? UUID(),
                    challengeId: entity.challengeId ?? UUID(),
                    circleId: entity.circleId ?? UUID(),
                    circleName: entity.circleName ?? "Unknown Circle",
                    challengeName: entity.challengeName ?? "Unknown Challenge",
                    challengeType: entity.challengeType ?? "general",
                    startDate: entity.startDate ?? Date(),
                    endDate: entity.endDate ?? Date(),
                    targetValue: entity.targetValue,
                    targetUnit: entity.targetUnit ?? "",
                    isActive: entity.isActive,
                    participants: [], // Would load from Core Data
                    completionThreshold: entity.completionThreshold,
                    bonusMultiplier: entity.bonusMultiplier,
                    createdAt: entity.createdAt ?? Date()
                )
            }
        } catch {
            logGroup("Error loading group challenges: \(error)")
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleChallengeCompleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let challenge = userInfo["challenge"] as? Challenge,
              let user = userInfo["user"] as? User else { return }
        
        Task {
            await processChallengeCompletion(challenge, user: user)
        }
    }
    
    @objc private func handleHangoutDetected(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hangoutSession = userInfo["hangoutSession"] as? HangoutSession else { return }
        
        Task {
            await processHangoutBonus(hangoutSession)
        }
    }
    
    @objc private func handlePointsEarned(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let points = userInfo["points"] as? Int,
              let userId = userInfo["userId"] as? UUID else { return }
        
        Task {
            await processPointsBonus(points: points, userId: userId)
        }
    }
    
    private func processChallengeCompletion(_ challenge: Challenge, user: User) async {
        // Check for Do It Together bonus
        if let circle = challenge.circle {
            await checkDoItTogetherBonus(challenge, circle: circle)
        }
        
        // Update group challenge progress
        for groupChallenge in activeGroupChallenges {
            if groupChallenge.challengeId == challenge.id {
                await trackGroupChallengeProgress(groupChallenge)
            }
        }
    }
    
    private func processHangoutBonus(_ hangoutSession: HangoutSession) async {
        // Award hangout bonus for group activities
        let participants = hangoutSession.participants?.allObjects as? [HangoutParticipant] ?? []
        
        if participants.count >= 2 {
            let bonusPoints = groupConfig.hangoutBonusPoints * participants.count
            
            for participant in participants {
                if let user = participant.user {
                    await pointsEngine.awardPoints(
                        userId: user.id ?? UUID(),
                        points: bonusPoints,
                        reason: "Group Hangout Bonus",
                        category: .hangout,
                        metadata: [
                            "hangoutSessionId": hangoutSession.id?.uuidString ?? "",
                            "participantCount": String(participants.count)
                        ]
                    )
                }
            }
        }
    }
    
    private func processPointsBonus(points: Int, userId: UUID) async {
        // Check for group achievement bonuses
        // This would implement group achievement logic
    }
    
    // MARK: - Helper Methods
    private func deactivateGroupChallenge(_ groupChallenge: GroupChallenge) async {
        // Update group challenge to inactive
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<GroupChallengeEntity> = GroupChallengeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", groupChallenge.id as CVarArg)
        
        if let entity = try? context.fetch(request).first {
            entity.isActive = false
            try? context.save()
        }
        
        // Remove from active challenges
        activeGroupChallenges.removeAll { $0.id == groupChallenge.id }
    }
    
    private func updateGroupChallenge(_ groupChallenge: GroupChallenge, progress: GroupChallengeProgress) async {
        // Update group challenge progress in Core Data
        // This would implement progress tracking
    }
    
    private func logGroup(_ message: String) {
        print("[GroupChallenge] \(message)")
    }
    
    // MARK: - Analytics
    func getGroupChallengeStats() -> GroupChallengeStats {
        return GroupChallengeStats(
            activeGroupChallenges: activeGroupChallenges.count,
            completedGroupChallenges: groupChallengeResults.count,
            totalBonusPoints: groupBonusHistory.reduce(0) { $0 + $1.bonusPoints },
            averageCompletionRate: calculateAverageCompletionRate(),
            mostActiveCircle: getMostActiveCircle(),
            topPerformingChallenge: getTopPerformingChallenge()
        )
    }
    
    private func calculateAverageCompletionRate() -> Double {
        guard !groupChallengeResults.isEmpty else { return 0 }
        return groupChallengeResults.reduce(0) { $0 + $1.completionPercentage } / Double(groupChallengeResults.count)
    }
    
    private func getMostActiveCircle() -> String? {
        let circleCounts = Dictionary(grouping: groupChallengeResults) { $0.circleId }
        return circleCounts.max(by: { $0.value.count < $1.value.count })?.key.uuidString
    }
    
    private func getTopPerformingChallenge() -> String? {
        let challengeCounts = Dictionary(grouping: groupChallengeResults) { $0.challengeName }
        return challengeCounts.max(by: { $0.value.count < $1.value.count })?.key
    }
}

// MARK: - Supporting Types
struct GroupChallenge {
    let id: UUID
    let challengeId: UUID
    let circleId: UUID
    let circleName: String
    let challengeName: String
    let challengeType: String
    let startDate: Date
    let endDate: Date
    let targetValue: Double
    let targetUnit: String
    let isActive: Bool
    let participants: [GroupChallengeParticipant]
    let completionThreshold: Double
    let bonusMultiplier: Double
    let createdAt: Date
}

struct GroupChallengeParticipant {
    let userId: UUID
    let userName: String
    let role: String
    let isActive: Bool
    let joinedAt: Date
}

struct GroupChallengeParticipantResult {
    let participant: GroupChallengeParticipant
    let isCompleted: Bool
    let completionCount: Int
    let lastCompletedAt: Date?
    let pointsEarned: Int
}

struct GroupChallengeProgress {
    let totalParticipants: Int
    let completedParticipants: Int
    let completionPercentage: Double
    let totalPoints: Int
    let averagePoints: Int
    let completionStreak: Int
    let groupCohesion: Double
    let lastUpdated: Date
}

struct GroupChallengeResult {
    let id: UUID
    let groupChallengeId: UUID
    let circleId: UUID
    let challengeName: String
    let completedAt: Date
    let completionPercentage: Double
    let totalParticipants: Int
    let completedParticipants: Int
    let totalPoints: Int
    let averagePoints: Int
    let bonusPoints: Int
    let bonusMultiplier: Double
}

struct GroupBonus {
    let id: UUID
    let userId: UUID
    let groupChallengeId: UUID?
    let challengeName: String
    let bonusPoints: Int
    let bonusMultiplier: Double
    let awardedAt: Date
    let reason: String
}

struct DoItTogetherBonus {
    let id: UUID
    let challengeId: UUID
    let challengeName: String
    let circleId: UUID
    let circleName: String
    let completedUsers: [UUID]
    let bonusPoints: Int
    let completedAt: Date
    let reason: String
}

struct GroupChallengeConfiguration {
    let defaultCompletionThreshold = 0.8 // 80% completion required
    let defaultBonusMultiplier = 1.5 // 50% bonus multiplier
    let doItTogetherBonusPoints = 15 // Bonus points for Do It Together
    let hangoutBonusPoints = 5 // Bonus points per participant in hangout
    let maxGroupSize = 10 // Maximum group size
    let minGroupSize = 2 // Minimum group size
}

struct GroupChallengeStats {
    let activeGroupChallenges: Int
    let completedGroupChallenges: Int
    let totalBonusPoints: Int
    let averageCompletionRate: Double
    let mostActiveCircle: String?
    let topPerformingChallenge: String?
}

// MARK: - Core Data Extensions
extension GroupChallengeEntity {
    static func fetchRequest() -> NSFetchRequest<GroupChallengeEntity> {
        return NSFetchRequest<GroupChallengeEntity>(entityName: "GroupChallengeEntity")
    }
}

extension GroupChallengeResultEntity {
    static func fetchRequest() -> NSFetchRequest<GroupChallengeResultEntity> {
        return NSFetchRequest<GroupChallengeResultEntity>(entityName: "GroupChallengeResultEntity")
    }
}

extension GroupBonusEntity {
    static func fetchRequest() -> NSFetchRequest<GroupBonusEntity> {
        return NSFetchRequest<GroupBonusEntity>(entityName: "GroupBonusEntity")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let challengeCompleted = Notification.Name("challengeCompleted")
    static let hangoutDetected = Notification.Name("hangoutDetected")
    static let pointsEarned = Notification.Name("pointsEarned")
    static let groupChallengeCompleted = Notification.Name("groupChallengeCompleted")
    static let doItTogetherBonus = Notification.Name("doItTogetherBonus")
}
