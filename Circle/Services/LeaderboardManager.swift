//
//  LeaderboardManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class LeaderboardManager: ObservableObject {
    static let shared = LeaderboardManager()
    
    @Published var currentLeaderboard: [LeaderboardEntry] = []
    @Published var weeklySnapshots: [LeaderboardSnapshot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let pointsEngine = PointsEngine.shared
    private let cancellables = Set<AnyCancellable>()
    
    // Snapshot scheduling
    private var snapshotTimer: Timer?
    private let snapshotTime = "23:55" // Sunday 11:55 PM
    private let snapshotDay = 1 // Monday (0 = Sunday)
    
    // Ranking algorithm
    private let rankingAlgorithm = RankingAlgorithm()
    
    private init() {
        loadCurrentLeaderboard()
        loadWeeklySnapshots()
        setupSnapshotScheduling()
        setupNotifications()
    }
    
    deinit {
        snapshotTimer?.invalidate()
    }
    
    // MARK: - Setup
    private func setupSnapshotScheduling() {
        // Schedule weekly snapshot for Sunday at 11:55 PM
        scheduleNextSnapshot()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePointsAwarded),
            name: .pointsAwarded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWeeklyReset),
            name: .weeklyPointsReset,
            object: nil
        )
    }
    
    // MARK: - Leaderboard Loading
    private func loadCurrentLeaderboard() {
        isLoading = true
        errorMessage = nil
        
        // Get current week's leaderboard
        let weekStart = getCurrentWeekStart()
        let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "weekStart == %@", weekStart as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LeaderboardEntry.rank, ascending: true)]
        
        do {
            currentLeaderboard = try persistenceController.container.viewContext.fetch(request)
            isLoading = false
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            isLoading = false
            print("Error loading leaderboard: \(error)")
        }
    }
    
    private func loadWeeklySnapshots() {
        let request: NSFetchRequest<LeaderboardSnapshot> = LeaderboardSnapshot.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LeaderboardSnapshot.weekStart, ascending: false)]
        request.fetchLimit = 12 // Last 12 weeks
        
        do {
            weeklySnapshots = try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error loading weekly snapshots: \(error)")
        }
    }
    
    // MARK: - Leaderboard Updates
    func updateLeaderboard(for circle: Circle) async {
        guard let members = circle.members?.allObjects as? [User] else { return }
        
        let weekStart = getCurrentWeekStart()
        
        // Get or create leaderboard entries for this week
        let entries = await getOrCreateLeaderboardEntries(for: members, circle: circle, weekStart: weekStart)
        
        // Calculate rankings
        let rankedEntries = rankingAlgorithm.calculateRankings(entries)
        
        // Update Core Data
        await updateLeaderboardEntries(rankedEntries)
        
        // Update local state
        currentLeaderboard = rankedEntries.sorted { $0.rank < $1.rank }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .leaderboardUpdated,
            object: nil,
            userInfo: ["circle": circle, "entries": rankedEntries]
        )
    }
    
    private func getOrCreateLeaderboardEntries(
        for members: [User],
        circle: Circle,
        weekStart: Date
    ) async -> [LeaderboardEntry] {
        var entries: [LeaderboardEntry] = []
        
        for member in members {
            // Check if entry exists
            let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "user == %@ AND circle == %@ AND weekStart == %@",
                member, circle, weekStart as NSDate
            )
            
            do {
                let existingEntries = try persistenceController.container.viewContext.fetch(request)
                
                if let existingEntry = existingEntries.first {
                    // Update existing entry
                    existingEntry.weeklyPoints = member.weeklyPoints
                    existingEntry.totalPoints = member.totalPoints
                    existingEntry.lastUpdated = Date()
                    entries.append(existingEntry)
                } else {
                    // Create new entry
                    let newEntry = LeaderboardEntry(context: persistenceController.container.viewContext)
                    newEntry.id = UUID()
                    newEntry.user = member
                    newEntry.circle = circle
                    newEntry.weeklyPoints = member.weeklyPoints
                    newEntry.totalPoints = member.totalPoints
                    newEntry.weekStart = weekStart
                    newEntry.rank = 0 // Will be calculated
                    newEntry.createdAt = Date()
                    newEntry.lastUpdated = Date()
                    entries.append(newEntry)
                }
            } catch {
                print("Error getting/creating leaderboard entry: \(error)")
            }
        }
        
        return entries
    }
    
    private func updateLeaderboardEntries(_ entries: [LeaderboardEntry]) async {
        for entry in entries {
            // Update rank and other calculated fields
            entry.rank = Int32(entries.firstIndex(of: entry) ?? 0) + 1
            entry.lastUpdated = Date()
            
            // Calculate additional metrics
            entry.challengesCompleted = getChallengesCompleted(for: entry.user, weekStart: entry.weekStart)
            entry.hangoutTime = getHangoutTime(for: entry.user, weekStart: entry.weekStart)
            entry.streakCount = getStreakCount(for: entry.user)
        }
        
        // Save context
        do {
            try persistenceController.container.viewContext.save()
        } catch {
            print("Error updating leaderboard entries: \(error)")
        }
    }
    
    // MARK: - Weekly Snapshots
    private func scheduleNextSnapshot() {
        let calendar = Calendar.current
        let now = Date()
        
        // Find next Sunday
        var nextSunday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: 1), // Sunday
            matchingPolicy: .nextTime
        ) ?? now
        
        // Set to 11:55 PM
        nextSunday = calendar.date(bySettingHour: 23, minute: 55, second: 0, of: nextSunday) ?? nextSunday
        
        let timeInterval = nextSunday.timeIntervalSince(now)
        
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.createWeeklySnapshot()
                self?.scheduleNextSnapshot() // Schedule next snapshot
            }
        }
        
        print("Next leaderboard snapshot scheduled for: \(nextSunday)")
    }
    
    private func createWeeklySnapshot() async {
        print("Creating weekly leaderboard snapshot")
        
        let weekStart = getCurrentWeekStart()
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        
        // Get all circles
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        
        do {
            let circles = try persistenceController.container.viewContext.fetch(request)
            
            for circle in circles {
                // Create snapshot for this circle
                let snapshot = LeaderboardSnapshot(context: persistenceController.container.viewContext)
                snapshot.id = UUID()
                snapshot.circle = circle
                snapshot.weekStart = weekStart
                snapshot.weekEnd = weekEnd
                snapshot.createdAt = Date()
                
                // Get leaderboard entries for this circle
                let entryRequest: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
                entryRequest.predicate = NSPredicate(
                    format: "circle == %@ AND weekStart == %@",
                    circle, weekStart as NSDate
                )
                entryRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LeaderboardEntry.rank, ascending: true)]
                
                let entries = try persistenceController.container.viewContext.fetch(entryRequest)
                snapshot.entries = NSSet(array: entries)
                
                // Calculate snapshot statistics
                snapshot.totalParticipants = Int32(entries.count)
                snapshot.totalPoints = entries.reduce(0) { $0 + $1.weeklyPoints }
                snapshot.averagePoints = entries.isEmpty ? 0 : snapshot.totalPoints / Int32(entries.count)
                
                // Determine winner
                if let winner = entries.first {
                    snapshot.winner = winner.user
                    snapshot.winnerPoints = winner.weeklyPoints
                }
            }
            
            try persistenceController.container.viewContext.save()
            
            // Reload snapshots
            loadWeeklySnapshots()
            
            // Notify other systems
            NotificationCenter.default.post(name: .weeklySnapshotCreated, object: nil)
            
            print("Weekly snapshot created successfully")
            
        } catch {
            errorMessage = "Failed to create weekly snapshot: \(error.localizedDescription)"
            print("Error creating weekly snapshot: \(error)")
        }
    }
    
    // MARK: - Ranking Algorithm
    func calculateRankings(for entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        return rankingAlgorithm.calculateRankings(entries)
    }
    
    // MARK: - Helper Methods
    private func getCurrentWeekStart() -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }
    
    private func getChallengesCompleted(for user: User, weekStart: Date) -> Int32 {
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(
            format: "user == %@ AND timestamp >= %@ AND timestamp < %@ AND isVerified == YES",
            user, weekStart as NSDate, weekEnd as NSDate
        )
        
        do {
            let proofs = try persistenceController.container.viewContext.fetch(request)
            return Int32(proofs.count)
        } catch {
            print("Error getting challenges completed: \(error)")
            return 0
        }
    }
    
    private func getHangoutTime(for user: User, weekStart: Date) -> Double {
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        
        let request: NSFetchRequest<HangoutSession> = HangoutSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "participants CONTAINS %@ AND startTime >= %@ AND startTime < %@",
            user, weekStart as NSDate, weekEnd as NSDate
        )
        
        do {
            let sessions = try persistenceController.container.viewContext.fetch(request)
            return sessions.reduce(0) { $0 + $1.duration }
        } catch {
            print("Error getting hangout time: \(error)")
            return 0.0
        }
    }
    
    private func getStreakCount(for user: User) -> Int32 {
        // Calculate current streak of completed challenges
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var streak = 0
        var currentDate = today
        
        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            
            let request: NSFetchRequest<Proof> = Proof.fetchRequest()
            request.predicate = NSPredicate(
                format: "user == %@ AND timestamp >= %@ AND timestamp < %@ AND isVerified == YES",
                user, currentDate as NSDate, nextDay as NSDate
            )
            
            do {
                let proofs = try persistenceController.container.viewContext.fetch(request)
                if proofs.isEmpty {
                    break
                }
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } catch {
                break
            }
        }
        
        return Int32(streak)
    }
    
    // MARK: - Notification Handlers
    @objc private func handlePointsAwarded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let user = userInfo["user"] as? User else { return }
        
        // Find the circle this user belongs to
        let request: NSFetchRequest<Membership> = Membership.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        
        do {
            let memberships = try persistenceController.container.viewContext.fetch(request)
            for membership in memberships {
                if let circle = membership.circle {
                    Task {
                        await updateLeaderboard(for: circle)
                    }
                }
            }
        } catch {
            print("Error handling points awarded: \(error)")
        }
    }
    
    @objc private func handleWeeklyReset(_ notification: Notification) {
        // Clear current leaderboard
        currentLeaderboard.removeAll()
        
        // Reload for new week
        loadCurrentLeaderboard()
    }
    
    // MARK: - Analytics
    func getLeaderboardStats(for circle: Circle) -> LeaderboardStats {
        let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "circle == %@", circle)
        
        do {
            let entries = try persistenceController.container.viewContext.fetch(request)
            
            let totalParticipants = entries.count
            let totalPoints = entries.reduce(0) { $0 + $1.weeklyPoints }
            let averagePoints = totalParticipants > 0 ? totalPoints / Int32(totalParticipants) : 0
            
            let topThree = entries.sorted { $0.weeklyPoints > $1.weeklyPoints }.prefix(3)
            
            return LeaderboardStats(
                totalParticipants: totalParticipants,
                totalPoints: totalPoints,
                averagePoints: averagePoints,
                topThree: Array(topThree),
                weekStart: getCurrentWeekStart()
            )
            
        } catch {
            print("Error getting leaderboard stats: \(error)")
            return LeaderboardStats(
                totalParticipants: 0,
                totalPoints: 0,
                averagePoints: 0,
                topThree: [],
                weekStart: getCurrentWeekStart()
            )
        }
    }
    
    func getHistoricalRankings(for user: User, weeks: Int = 12) -> [HistoricalRanking] {
        let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LeaderboardEntry.weekStart, ascending: false)]
        request.fetchLimit = weeks
        
        do {
            let entries = try persistenceController.container.viewContext.fetch(request)
            return entries.map { entry in
                HistoricalRanking(
                    weekStart: entry.weekStart ?? Date(),
                    rank: Int(entry.rank),
                    points: entry.weeklyPoints,
                    circle: entry.circle
                )
            }
        } catch {
            print("Error getting historical rankings: \(error)")
            return []
        }
    }
}

// MARK: - Ranking Algorithm
class RankingAlgorithm {
    func calculateRankings(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        // Primary sort: Weekly points (descending)
        // Secondary sort: Total points (descending)
        // Tertiary sort: Challenges completed (descending)
        // Quaternary sort: Hangout time (descending)
        // Quinary sort: Streak count (descending)
        // Final sort: User ID (ascending) for deterministic ranking
        
        let sortedEntries = entries.sorted { entry1, entry2 in
            // Primary: Weekly points
            if entry1.weeklyPoints != entry2.weeklyPoints {
                return entry1.weeklyPoints > entry2.weeklyPoints
            }
            
            // Secondary: Total points
            if entry1.totalPoints != entry2.totalPoints {
                return entry1.totalPoints > entry2.totalPoints
            }
            
            // Tertiary: Challenges completed
            if entry1.challengesCompleted != entry2.challengesCompleted {
                return entry1.challengesCompleted > entry2.challengesCompleted
            }
            
            // Quaternary: Hangout time
            if entry1.hangoutTime != entry2.hangoutTime {
                return entry1.hangoutTime > entry2.hangoutTime
            }
            
            // Quinary: Streak count
            if entry1.streakCount != entry2.streakCount {
                return entry1.streakCount > entry2.streakCount
            }
            
            // Final: User ID for deterministic ranking
            return entry1.user?.id?.uuidString ?? "" < entry2.user?.id?.uuidString ?? ""
        }
        
        // Assign ranks
        for (index, entry) in sortedEntries.enumerated() {
            entry.rank = Int32(index + 1)
        }
        
        return sortedEntries
    }
}

// MARK: - Supporting Types
struct LeaderboardStats {
    let totalParticipants: Int
    let totalPoints: Int32
    let averagePoints: Int32
    let topThree: [LeaderboardEntry]
    let weekStart: Date
}

struct HistoricalRanking {
    let weekStart: Date
    let rank: Int
    let points: Int32
    let circle: Circle?
}

// MARK: - Core Data Extensions
extension LeaderboardEntry {
    static func fetchRequest() -> NSFetchRequest<LeaderboardEntry> {
        return NSFetchRequest<LeaderboardEntry>(entityName: "LeaderboardEntry")
    }
}

extension LeaderboardSnapshot {
    static func fetchRequest() -> NSFetchRequest<LeaderboardSnapshot> {
        return NSFetchRequest<LeaderboardSnapshot>(entityName: "LeaderboardSnapshot")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let leaderboardUpdated = Notification.Name("leaderboardUpdated")
    static let weeklySnapshotCreated = Notification.Name("weeklySnapshotCreated")
}
