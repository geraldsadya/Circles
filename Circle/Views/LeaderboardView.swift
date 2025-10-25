//
//  LeaderboardView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData

struct LeaderboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var leaderboardManager = LeaderboardManager.shared
    
    @State private var selectedTimeframe: Timeframe = .weekly
    @State private var selectedCircle: Circle?
    
    enum Timeframe: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        case allTime = "All Time"
        
        var icon: String {
            switch self {
            case .weekly: return "calendar"
            case .monthly: return "calendar.badge.clock"
            case .allTime: return "infinity"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Timeframe Selector
                timeframeSelector
                
                // Circle Selector
                if userCircles.count > 1 {
                    circleSelector
                }
                
                // Leaderboard Content
                if leaderboardEntries.isEmpty {
                    emptyState
                } else {
                    leaderboardList
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadLeaderboard()
            }
        }
    }
    
    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Button(action: { selectedTimeframe = timeframe }) {
                    VStack(spacing: 4) {
                        Image(systemName: timeframe.icon)
                            .font(.title3)
                        
                        Text(timeframe.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTimeframe == timeframe ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Circle Selector
    private var circleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(userCircles, id: \.id) { circle in
                    Button(action: { selectedCircle = circle }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(circle.name?.prefix(1).uppercased() ?? "C")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            Text(circle.name ?? "Untitled")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedCircle?.id == circle.id ? .blue : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedCircle?.id == circle.id ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Leaderboard List
    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(
                        entry: entry,
                        rank: index + 1,
                        isCurrentUser: entry.user?.id == authManager.currentUser?.id
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "trophy")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Rankings Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Complete challenges to start earning points and climb the leaderboard")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var userCircles: [Circle] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.createdAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching circles: \(error)")
            return []
        }
    }
    
    private var leaderboardEntries: [LeaderboardEntry] {
        let request: NSFetchRequest<LeaderboardEntry> = LeaderboardEntry.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if let circle = selectedCircle {
            predicates.append(NSPredicate(format: "circle == %@", circle))
        }
        
        // Add timeframe filter
        let now = Date()
        switch selectedTimeframe {
        case .weekly:
            let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            predicates.append(NSPredicate(format: "weekStarting >= %@", weekAgo as NSDate))
        case .monthly:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            predicates.append(NSPredicate(format: "weekStarting >= %@", monthAgo as NSDate))
        case .allTime:
            break // No time filter for all time
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \LeaderboardEntry.points, ascending: false),
            NSSortDescriptor(keyPath: \LeaderboardEntry.createdAt, ascending: false)
        ]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching leaderboard entries: \(error)")
            return []
        }
    }
    
    // MARK: - Methods
    private func loadLeaderboard() {
        leaderboardManager.loadLeaderboard()
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                if rank <= 3 {
                    Image(systemName: rankIcon)
                        .font(.title3)
                        .foregroundColor(rankColor)
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                }
            }
            
            // User Avatar - Minimalist
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(
                    Text(entry.user?.displayName?.prefix(1).uppercased() ?? "U")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.user?.displayName ?? "Unknown User")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if isCurrentUser {
                        Text("You")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray5), lineWidth: 1)
                                    )
                            )
                    }
                }
                
                Text("\(entry.points) points")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Points Badge
            VStack(spacing: 4) {
                Text("\(entry.points)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color(.systemGray6) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .primary
        case 2: return .secondary
        case 3: return .secondary
        default: return .secondary
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "2.circle.fill"
        case 3: return "3.circle.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    LeaderboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
