//
//  PointsEngine.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class PointsEngine: ObservableObject {
    static let shared = PointsEngine()
    
    @Published var userPoints: Int32 = 0
    @Published var weeklyPoints: Int32 = 0
    @Published var dailyPoints: Int32 = 0
    @Published var pointsHistory: [PointsLedger] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let cancellables = Set<AnyCancellable>()
    
    // Points tracking
    private var dailyPointsCache: [Date: Int32] = [:]
    private var weeklyPointsCache: [Date: Int32] = [:]
    private var lastResetDate: Date?
    
    // Points limits and caps
    private let dailyHangoutCap = Verify.dailyHangoutCapPts
    private let weeklyResetDay = 1 // Monday (0 = Sunday)
    
    private init() {
        loadUserPoints()
        setupWeeklyReset()
        setupDailyReset()
    }
    
    // MARK: - Points Loading
    private func loadUserPoints() {
        isLoading = true
        errorMessage = nil
        
        guard let currentUser = getCurrentUser() else {
            isLoading = false
            return
        }
        
        userPoints = currentUser.totalPoints
        weeklyPoints = currentUser.weeklyPoints
        
        // Load points history
        loadPointsHistory(for: currentUser)
        
        // Calculate daily points
        calculateDailyPoints(for: currentUser)
        
        isLoading = false
    }
    
    private func loadPointsHistory(for user: User) {
        let request: NSFetchRequest<PointsLedger> = PointsLedger.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PointsLedger.timestamp, ascending: false)]
        request.fetchLimit = 100 // Last 100 transactions
        
        do {
            pointsHistory = try persistenceController.container.viewContext.fetch(request)
        } catch {
            errorMessage = "Failed to load points history: \(error.localizedDescription)"
            print("Error loading points history: \(error)")
        }
    }
    
    private func calculateDailyPoints(for user: User) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<PointsLedger> = PointsLedger.fetchRequest()
        request.predicate = NSPredicate(
            format: "user == %@ AND timestamp >= %@ AND timestamp < %@",
            user, today as NSDate, tomorrow as NSDate
        )
        
        do {
            let todayTransactions = try persistenceController.container.viewContext.fetch(request)
            dailyPoints = todayTransactions.reduce(0) { $0 + $1.points }
        } catch {
            print("Error calculating daily points: \(error)")
            dailyPoints = 0
        }
    }
    
    // MARK: - Points Awarding
    func awardPoints(
        _ points: Int32,
        reason: PointsReason,
        user: User,
        challenge: Challenge? = nil,
        hangoutSession: HangoutSession? = nil,
        forfeit: Forfeit? = nil
    ) async throws {
        // Validate points
        guard points != 0 else {
            throw PointsError.invalidPoints("Points cannot be zero")
        }
        
        // Check daily caps
        if reason == .hangout {
            let dailyHangoutPoints = getDailyHangoutPoints(for: user)
            if dailyHangoutPoints + points > dailyHangoutCap {
                throw PointsError.dailyCapExceeded("Daily hangout points cap exceeded")
            }
        }
        
        // Create points ledger entry
        let ledger = PointsLedger(context: persistenceController.container.viewContext)
        ledger.id = UUID()
        ledger.user = user
        ledger.points = points
        ledger.reason = reason.rawValue
        ledger.timestamp = Date()
        ledger.challenge = challenge
        ledger.hangoutSession = hangoutSession
        ledger.forfeit = forfeit
        
        // Update user totals
        user.totalPoints += points
        user.weeklyPoints += points
        
        // Update local state
        userPoints = user.totalPoints
        weeklyPoints = user.weeklyPoints
        dailyPoints += points
        
        // Add to history
        pointsHistory.insert(ledger, at: 0)
        
        // Keep history limited
        if pointsHistory.count > 100 {
            pointsHistory.removeLast()
        }
        
        // Save context
        try persistenceController.container.viewContext.save()
        
        // Update cache
        updatePointsCache(for: user, points: points)
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .pointsAwarded,
            object: nil,
            userInfo: [
                "user": user,
                "points": points,
                "reason": reason.rawValue,
                "totalPoints": user.totalPoints
            ]
        )
        
        print("Points awarded: \(points) (\(reason.rawValue)) - Total: \(user.totalPoints)")
    }
    
    // MARK: - Challenge Points
    func awardChallengePoints(
        for proof: Proof,
        user: User,
        challenge: Challenge
    ) async throws {
        let points = proof.pointsAwarded
        let reason: PointsReason = proof.isVerified ? .challengeComplete : .challengeMiss
        
        try await awardPoints(
            points,
            reason: reason,
            user: user,
            challenge: challenge
        )
    }
    
    // MARK: - Hangout Points
    func awardHangoutPoints(
        _ points: Int32,
        user: User,
        hangoutSession: HangoutSession
    ) async throws {
        // Check daily cap
        let dailyHangoutPoints = getDailyHangoutPoints(for: user)
        let cappedPoints = min(points, dailyHangoutCap - dailyHangoutPoints)
        
        guard cappedPoints > 0 else {
            print("Hangout points capped - daily limit reached")
            return
        }
        
        try await awardPoints(
            cappedPoints,
            reason: .hangout,
            user: user,
            hangoutSession: hangoutSession
        )
    }
    
    // MARK: - Forfeit Points
    func awardForfeitPoints(
        _ points: Int32,
        user: User,
        forfeit: Forfeit
    ) async throws {
        let reason: PointsReason = points > 0 ? .forfeitComplete : .forfeitMiss
        
        try await awardPoints(
            points,
            reason: reason,
            user: user,
            forfeit: forfeit
        )
    }
    
    // MARK: - Group Challenge Bonus
    func awardGroupChallengeBonus(
        _ points: Int32,
        user: User,
        challenge: Challenge
    ) async throws {
        try await awardPoints(
            points,
            reason: .groupChallengeBonus,
            user: user,
            challenge: challenge
        )
    }
    
    // MARK: - Points Deduction
    func deductPoints(
        _ points: Int32,
        reason: PointsReason,
        user: User,
        challenge: Challenge? = nil
    ) async throws {
        guard points > 0 else {
            throw PointsError.invalidPoints("Deduction points must be positive")
        }
        
        let deductionPoints = -points
        
        try await awardPoints(
            deductionPoints,
            reason: reason,
            user: user,
            challenge: challenge
        )
    }
    
    // MARK: - Weekly Reset
    private func setupWeeklyReset() {
        // Schedule weekly reset for Monday at midnight
        let calendar = Calendar.current
        let now = Date()
        
        // Find next Monday
        var nextMonday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: weeklyResetDay + 1),
            matchingPolicy: .nextTime
        ) ?? now
        
        // Set to midnight
        nextMonday = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: nextMonday) ?? nextMonday
        
        // Schedule reset
        let timeInterval = nextMonday.timeIntervalSince(now)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
            Task { @MainActor in
                await self.performWeeklyReset()
                self.setupWeeklyReset() // Schedule next reset
            }
        }
    }
    
    private func performWeeklyReset() async {
        print("Performing weekly points reset")
        
        // Reset weekly points for all users
        let request: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try persistenceController.container.viewContext.fetch(request)
            
            for user in users {
                user.weeklyPoints = 0
            }
            
            try persistenceController.container.viewContext.save()
            
            // Update local state
            if let currentUser = getCurrentUser() {
                weeklyPoints = currentUser.weeklyPoints
            }
            
            // Clear weekly cache
            weeklyPointsCache.removeAll()
            
            // Notify other systems
            NotificationCenter.default.post(name: .weeklyPointsReset, object: nil)
            
            print("Weekly points reset completed")
            
        } catch {
            errorMessage = "Failed to perform weekly reset: \(error.localizedDescription)"
            print("Error performing weekly reset: \(error)")
        }
    }
    
    // MARK: - Daily Reset
    private func setupDailyReset() {
        // Reset daily points cache at midnight
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
            Task { @MainActor in
                await self.performDailyReset()
                self.setupDailyReset() // Schedule next reset
            }
        }
    }
    
    private func performDailyReset() async {
        print("Performing daily points reset")
        
        // Clear daily cache
        dailyPointsCache.removeAll()
        
        // Recalculate daily points
        if let currentUser = getCurrentUser() {
            calculateDailyPoints(for: currentUser)
        }
        
        // Notify other systems
        NotificationCenter.default.post(name: .dailyPointsReset, object: nil)
        
        print("Daily points reset completed")
    }
    
    // MARK: - Helper Methods
    private func getCurrentUser() -> User? {
        // This would be implemented to get the current authenticated user
        // For now, return nil
        return nil
    }
    
    private func getDailyHangoutPoints(for user: User) -> Int32 {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let request: NSFetchRequest<PointsLedger> = PointsLedger.fetchRequest()
        request.predicate = NSPredicate(
            format: "user == %@ AND reason == %@ AND timestamp >= %@ AND timestamp < %@",
            user, PointsReason.hangout.rawValue, today as NSDate, tomorrow as NSDate
        )
        
        do {
            let hangoutTransactions = try persistenceController.container.viewContext.fetch(request)
            return hangoutTransactions.reduce(0) { $0 + $1.points }
        } catch {
            print("Error getting daily hangout points: \(error)")
            return 0
        }
    }
    
    private func updatePointsCache(for user: User, points: Int32) {
        let today = Calendar.current.startOfDay(for: Date())
        dailyPointsCache[today, default: 0] += points
        
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        weeklyPointsCache[weekStart, default: 0] += points
    }
    
    // MARK: - Analytics
    func getPointsStats(for user: User, timeInterval: TimeInterval = 86400) -> PointsStats {
        let cutoffTime = Date().addingTimeInterval(-timeInterval)
        
        let request: NSFetchRequest<PointsLedger> = PointsLedger.fetchRequest()
        request.predicate = NSPredicate(
            format: "user == %@ AND timestamp >= %@",
            user, cutoffTime as NSDate
        )
        
        do {
            let transactions = try persistenceController.container.viewContext.fetch(request)
            
            let totalPoints = transactions.reduce(0) { $0 + $1.points }
            let positivePoints = transactions.filter { $0.points > 0 }.reduce(0) { $0 + $1.points }
            let negativePoints = transactions.filter { $0.points < 0 }.reduce(0) { $0 + $1.points }
            
            let reasonCounts = Dictionary(grouping: transactions, by: { $0.reason })
                .mapValues { $0.count }
            
            return PointsStats(
                totalPoints: totalPoints,
                positivePoints: positivePoints,
                negativePoints: negativePoints,
                transactionCount: transactions.count,
                reasonCounts: reasonCounts,
                timeInterval: timeInterval
            )
            
        } catch {
            print("Error getting points stats: \(error)")
            return PointsStats(
                totalPoints: 0,
                positivePoints: 0,
                negativePoints: 0,
                transactionCount: 0,
                reasonCounts: [:],
                timeInterval: timeInterval
            )
        }
    }
    
    func getLeaderboardData(for circle: Circle) -> [LeaderboardEntry] {
        let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "circle == %@", circle)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LeaderboardEntry.weeklyPoints, ascending: false)]
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error getting leaderboard data: \(error)")
            return []
        }
    }
    
    // MARK: - Validation
    func validatePointsTransaction(
        points: Int32,
        reason: PointsReason,
        user: User
    ) -> ValidationResult {
        var errors: [String] = []
        
        // Validate points
        if points == 0 {
            errors.append("Points cannot be zero")
        }
        
        if abs(points) > 1000 {
            errors.append("Points amount too large")
        }
        
        // Validate reason
        if reason.rawValue.isEmpty {
            errors.append("Points reason cannot be empty")
        }
        
        // Validate user
        if user.id == UUID() {
            errors.append("Invalid user")
        }
        
        // Check daily caps
        if reason == .hangout {
            let dailyHangoutPoints = getDailyHangoutPoints(for: user)
            if dailyHangoutPoints + points > dailyHangoutCap {
                errors.append("Daily hangout points cap would be exceeded")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
}

// MARK: - Supporting Types
enum PointsReason: String, CaseIterable {
    case challengeComplete = "challenge_complete"
    case challengeMiss = "challenge_miss"
    case hangout = "hangout"
    case forfeitComplete = "forfeit_complete"
    case forfeitMiss = "forfeit_miss"
    case groupChallengeBonus = "group_challenge_bonus"
    case streakBonus = "streak_bonus"
    case penalty = "penalty"
    case adjustment = "adjustment"
    
    var displayName: String {
        switch self {
        case .challengeComplete: return "Challenge Completed"
        case .challengeMiss: return "Challenge Missed"
        case .hangout: return "Hangout"
        case .forfeitComplete: return "Forfeit Completed"
        case .forfeitMiss: return "Forfeit Missed"
        case .groupChallengeBonus: return "Group Challenge Bonus"
        case .streakBonus: return "Streak Bonus"
        case .penalty: return "Penalty"
        case .adjustment: return "Adjustment"
        }
    }
    
    var icon: String {
        switch self {
        case .challengeComplete: return "checkmark.circle.fill"
        case .challengeMiss: return "xmark.circle.fill"
        case .hangout: return "person.3.fill"
        case .forfeitComplete: return "camera.fill"
        case .forfeitMiss: return "camera"
        case .groupChallengeBonus: return "star.fill"
        case .streakBonus: return "flame.fill"
        case .penalty: return "exclamationmark.triangle.fill"
        case .adjustment: return "slider.horizontal.3"
        }
    }
}

struct PointsStats {
    let totalPoints: Int32
    let positivePoints: Int32
    let negativePoints: Int32
    let transactionCount: Int
    let reasonCounts: [String: Int]
    let timeInterval: TimeInterval
}

enum PointsError: LocalizedError {
    case invalidPoints(String)
    case dailyCapExceeded(String)
    case userNotFound
    case contextSaveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPoints(let message):
            return "Invalid points: \(message)"
        case .dailyCapExceeded(let message):
            return "Daily cap exceeded: \(message)"
        case .userNotFound:
            return "User not found"
        case .contextSaveFailed(let message):
            return "Failed to save context: \(message)"
        }
    }
}

// MARK: - Core Data Extensions
extension PointsLedger {
    static func fetchRequest() -> NSFetchRequest<PointsLedger> {
        return NSFetchRequest<PointsLedger>(entityName: "PointsLedger")
    }
    
    var reasonEnum: PointsReason? {
        return PointsReason(rawValue: reason ?? "")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let pointsAwarded = Notification.Name("pointsAwarded")
    static let weeklyPointsReset = Notification.Name("weeklyPointsReset")
    static let dailyPointsReset = Notification.Name("dailyPointsReset")
}
