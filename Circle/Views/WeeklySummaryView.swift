//
//  WeeklySummaryView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData
import Charts

struct WeeklySummaryView: View {
    @EnvironmentObject var persistenceController: PersistenceController
    @StateObject private var summaryManager = WeeklySummaryManager.shared
    
    @State private var selectedWeek: Date = Date()
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Week Selector
                    weekSelector
                    
                    // Summary Cards
                    if isLoading {
                        loadingView
                    } else if let summary = summaryManager.currentSummary {
                        summaryCards(summary)
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Weekly Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        generateShareImage()
                    }
                    .disabled(isLoading || summaryManager.currentSummary == nil)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
            .onAppear {
                loadWeeklySummary()
            }
        }
    }
    
    // MARK: - Week Selector
    private var weekSelector: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Week")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Current Week") {
                    selectedWeek = Date()
                    loadWeeklySummary()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Week picker
            DatePicker(
                "Week",
                selection: $selectedWeek,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .onChange(of: selectedWeek) { _ in
                loadWeeklySummary()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Summary Cards
    private func summaryCards(_ summary: WeeklySummary) -> some View {
        VStack(spacing: 20) {
            // Header Card
            headerCard(summary)
            
            // Stats Cards
            statsCards(summary)
            
            // Challenges Card
            challengesCard(summary)
            
            // Hangouts Card
            hangoutsCard(summary)
            
            // Leaderboard Card
            leaderboardCard(summary)
            
            // Insights Card
            insightsCard(summary)
        }
    }
    
    // MARK: - Header Card
    private func headerCard(_ summary: WeeklySummary) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Week of \(summary.weekStart, formatter: weekFormatter)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(summary.totalChallenges) challenges • \(summary.totalHangouts) hangouts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Points Badge
                VStack(spacing: 4) {
                    Text("\(summary.totalPoints)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weekly Progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(summary.completionRate * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                ProgressView(value: summary.completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Stats Cards
    private func statsCards(_ summary: WeeklySummary) -> some View {
        HStack(spacing: 16) {
            // Challenges Completed
            StatCard(
                title: "Challenges",
                value: "\(summary.completedChallenges)",
                total: "\(summary.totalChallenges)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            // Hangouts
            StatCard(
                title: "Hangouts",
                value: "\(summary.totalHangouts)",
                total: "\(summary.totalHangoutHours)h",
                icon: "person.3.fill",
                color: .blue
            )
        }
    }
    
    // MARK: - Challenges Card
    private func challengesCard(_ summary: WeeklySummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Challenges")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(summary.completedChallenges)/\(summary.totalChallenges)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Challenge Categories
            VStack(spacing: 12) {
                ForEach(summary.challengeCategories, id: \.category) { category in
                    ChallengeCategoryRow(
                        category: category,
                        totalChallenges: summary.totalChallenges
                    )
                }
            }
            
            // Challenge Chart
            if !summary.challengeCategories.isEmpty {
                ChallengeChart(categories: summary.challengeCategories)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Hangouts Card
    private func hangoutsCard(_ summary: WeeklySummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Hangouts")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(summary.totalHangoutHours)h total")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Hangout Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.totalHangouts)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.averageHangoutDuration, specifier: "%.1f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Avg Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.longestHangout, specifier: "%.1f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Longest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Top Hangout Locations
            if !summary.topHangoutLocations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Locations")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(summary.topHangoutLocations.prefix(3), id: \.location) { location in
                        HStack {
                            Text(location.location)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(location.count) times")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Leaderboard Card
    private func leaderboardCard(_ summary: WeeklySummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Leaderboard")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Your Rank: #\(summary.userRank)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Top 3 Users
            VStack(spacing: 12) {
                ForEach(Array(summary.topUsers.enumerated()), id: \.element.id) { index, user in
                    LeaderboardRow(
                        user: user,
                        rank: index + 1,
                        isCurrentUser: user.id == summary.currentUserId
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Insights Card
    private func insightsCard(_ summary: WeeklySummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(summary.insights, id: \.id) { insight in
                    InsightRow(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Generating Summary...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Data Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Complete some challenges and hangouts to see your weekly summary.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helper Methods
    private func loadWeeklySummary() {
        isLoading = true
        
        Task {
            do {
                try await summaryManager.generateWeeklySummary(for: selectedWeek)
                
                await MainActor.run {
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to generate summary: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func generateShareImage() {
        // Generate shareable image of the summary
        // This would create a beautiful image with the summary data
        shareImage = UIImage(systemName: "chart.bar.fill")
        showingShareSheet = true
    }
    
    // MARK: - Formatters
    private var weekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let total: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(total)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Challenge Category Row
struct ChallengeCategoryRow: View {
    let category: ChallengeCategoryStats
    let totalChallenges: Int
    
    var body: some View {
        HStack {
            Text(category.category)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(category.completed)/\(category.total)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Progress Bar
            ProgressView(value: Double(category.completed), total: Double(category.total))
                .progressViewStyle(LinearProgressViewStyle(tint: category.color))
                .frame(width: 60)
        }
    }
}

// MARK: - Challenge Chart
struct ChallengeChart: View {
    let categories: [ChallengeCategoryStats]
    
    var body: some View {
        Chart(categories, id: \.category) { category in
            BarMark(
                x: .value("Category", category.category),
                y: .value("Completed", category.completed)
            )
            .foregroundStyle(category.color)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let user: LeaderboardUser
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rank <= 3 ? .orange : .secondary)
                .frame(width: 30, alignment: .leading)
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(isCurrentUser ? .bold : .medium)
                    .foregroundColor(.primary)
                
                Text("\(user.points) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Crown for top 3
            if rank <= 3 {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Insight Row
struct InsightRow: View {
    let insight: WeeklyInsight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .foregroundColor(insight.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Weekly Summary Manager
@MainActor
class WeeklySummaryManager: ObservableObject {
    static let shared = WeeklySummaryManager()
    
    @Published var currentSummary: WeeklySummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    private init() {}
    
    // MARK: - Summary Generation
    func generateWeeklySummary(for date: Date) async throws {
        isLoading = true
        
        do {
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let weekEnd = Calendar.current.dateInterval(of: .weekOfYear, for: date)?.end ?? date
            
            // Generate summary data
            let summary = try await createWeeklySummary(
                weekStart: weekStart,
                weekEnd: weekEnd
            )
            
            currentSummary = summary
            
        } catch {
            errorMessage = "Failed to generate summary: \(error.localizedDescription)"
            throw error
        }
        
        isLoading = false
    }
    
    private func createWeeklySummary(weekStart: Date, weekEnd: Date) async throws -> WeeklySummary {
        let context = persistenceController.container.viewContext
        
        // Get challenges for the week
        let challengeRequest: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        challengeRequest.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            weekStart as NSDate,
            weekEnd as NSDate
        )
        let challenges = try context.fetch(challengeRequest)
        
        // Get hangouts for the week
        let hangoutRequest: NSFetchRequest<HangoutSession> = HangoutSession.fetchRequest()
        hangoutRequest.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@",
            weekStart as NSDate,
            weekEnd as NSDate
        )
        let hangouts = try context.fetch(hangoutRequest)
        
        // Get points for the week
        let pointsRequest: NSFetchRequest<PointsLedger> = PointsLedger.fetchRequest()
        pointsRequest.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            weekStart as NSDate,
            weekEnd as NSDate
        )
        let points = try context.fetch(pointsRequest)
        
        // Calculate statistics
        let totalChallenges = challenges.count
        let completedChallenges = challenges.filter { $0.isActive == false }.count
        let totalHangouts = hangouts.count
        let totalHangoutHours = hangouts.reduce(0) { $0 + $1.duration } / 3600
        let totalPoints = points.reduce(0) { $0 + Int($1.points) }
        
        // Calculate completion rate
        let completionRate = totalChallenges > 0 ? Double(completedChallenges) / Double(totalChallenges) : 0.0
        
        // Get challenge categories
        let challengeCategories = getChallengeCategories(challenges: challenges)
        
        // Get hangout locations
        let hangoutLocations = getHangoutLocations(hangouts: hangouts)
        
        // Get leaderboard data
        let leaderboardData = try await getLeaderboardData(weekStart: weekStart, weekEnd: weekEnd)
        
        // Generate insights
        let insights = generateInsights(
            challenges: challenges,
            hangouts: hangouts,
            points: points
        )
        
        return WeeklySummary(
            weekStart: weekStart,
            weekEnd: weekEnd,
            totalChallenges: totalChallenges,
            completedChallenges: completedChallenges,
            totalHangouts: totalHangouts,
            totalHangoutHours: totalHangoutHours,
            totalPoints: totalPoints,
            completionRate: completionRate,
            challengeCategories: challengeCategories,
            topHangoutLocations: hangoutLocations,
            topUsers: leaderboardData.topUsers,
            userRank: leaderboardData.userRank,
            currentUserId: leaderboardData.currentUserId,
            insights: insights,
            averageHangoutDuration: totalHangouts > 0 ? totalHangoutHours / Double(totalHangouts) : 0,
            longestHangout: hangouts.map { $0.duration / 3600 }.max() ?? 0
        )
    }
    
    private func getChallengeCategories(challenges: [Challenge]) -> [ChallengeCategoryStats] {
        let categories = Dictionary(grouping: challenges) { $0.category ?? "Unknown" }
        
        return categories.map { category, challenges in
            let completed = challenges.filter { $0.isActive == false }.count
            let total = challenges.count
            
            return ChallengeCategoryStats(
                category: category,
                completed: completed,
                total: total,
                color: getCategoryColor(category)
            )
        }
    }
    
    private func getHangoutLocations(hangouts: [HangoutSession]) -> [HangoutLocationStats] {
        let locations = Dictionary(grouping: hangouts) { $0.location ?? "Unknown" }
        
        return locations.map { location, hangouts in
            HangoutLocationStats(
                location: location,
                count: hangouts.count,
                totalHours: hangouts.reduce(0) { $0 + $1.duration } / 3600
            )
        }.sorted { $0.count > $1.count }
    }
    
    private func getLeaderboardData(weekStart: Date, weekEnd: Date) async throws -> LeaderboardData {
        // This would integrate with LeaderboardManager
        // For now, return mock data
        return LeaderboardData(
            topUsers: [
                LeaderboardUser(id: "1", name: "Sarah", points: 150),
                LeaderboardUser(id: "2", name: "Mike", points: 120),
                LeaderboardUser(id: "3", name: "Emma", points: 100)
            ],
            userRank: 2,
            currentUserId: "2"
        )
    }
    
    private func generateInsights(challenges: [Challenge], hangouts: [HangoutSession], points: [PointsLedger]) -> [WeeklyInsight] {
        var insights: [WeeklyInsight] = []
        
        // Challenge insights
        if let topCategory = getChallengeCategories(challenges: challenges).max(by: { $0.completed < $1.completed }) {
            insights.append(WeeklyInsight(
                id: "top_category",
                title: "Top Category",
                description: "You completed \(topCategory.completed) \(topCategory.category.lowercased()) challenges",
                icon: "star.fill",
                color: .orange
            ))
        }
        
        // Hangout insights
        if !hangouts.isEmpty {
            let totalHours = hangouts.reduce(0) { $0 + $1.duration } / 3600
            insights.append(WeeklyInsight(
                id: "hangout_hours",
                title: "Social Time",
                description: "You spent \(totalHours, specifier: "%.1f") hours hanging out with friends",
                icon: "person.3.fill",
                color: .blue
            ))
        }
        
        // Points insights
        let totalPoints = points.reduce(0) { $0 + Int($1.points) }
        if totalPoints > 0 {
            insights.append(WeeklyInsight(
                id: "points_earned",
                title: "Points Earned",
                description: "You earned \(totalPoints) points this week",
                icon: "star.fill",
                color: .green
            ))
        }
        
        return insights
    }
    
    private func getCategoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "fitness": return .green
        case "social": return .blue
        case "study": return .purple
        case "health": return .red
        case "screentime": return .orange
        default: return .gray
        }
    }
}

// MARK: - Supporting Types
struct WeeklySummary {
    let weekStart: Date
    let weekEnd: Date
    let totalChallenges: Int
    let completedChallenges: Int
    let totalHangouts: Int
    let totalHangoutHours: Double
    let totalPoints: Int
    let completionRate: Double
    let challengeCategories: [ChallengeCategoryStats]
    let topHangoutLocations: [HangoutLocationStats]
    let topUsers: [LeaderboardUser]
    let userRank: Int
    let currentUserId: String
    let insights: [WeeklyInsight]
    let averageHangoutDuration: Double
    let longestHangout: Double
}

struct ChallengeCategoryStats {
    let category: String
    let completed: Int
    let total: Int
    let color: Color
}

struct HangoutLocationStats {
    let location: String
    let count: Int
    let totalHours: Double
}

struct LeaderboardUser {
    let id: String
    let name: String
    let points: Int
}

struct LeaderboardData {
    let topUsers: [LeaderboardUser]
    let userRank: Int
    let currentUserId: String
}

struct WeeklyInsight {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
}

#Preview {
    WeeklySummaryView()
        .environmentObject(PersistenceController.shared)
}
