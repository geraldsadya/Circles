//
//  ChallengesView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData

struct ChallengesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var challengeEngine = ChallengeEngine.shared
    @StateObject private var challengeTemplateManager = ChallengeTemplateManager.shared
    
    @State private var showingCreateChallenge = false
    @State private var selectedCategory: ChallengeCategory? = nil
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Category Filter
                categoryFilter
                
                // Challenges List
                if filteredChallenges.isEmpty {
                    emptyState
                } else {
                    challengesList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateChallenge = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingCreateChallenge) {
                ChallengeComposerView()
            }
            .onAppear {
                loadChallenges()
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search challenges...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Categories
                Button(action: { selectedCategory = nil }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                        Text("All")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(selectedCategory == nil ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedCategory == nil ? Color.blue : Color(.systemGray6))
                    )
                }
                
                // Individual Categories
                ForEach(ChallengeCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedCategory == category ? Color.blue : Color(.systemGray6))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Challenges List
    private var challengesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredChallenges, id: \.id) { challenge in
                    ChallengeDetailCard(challenge: challenge)
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
            
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Challenges Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Create your first challenge or join a circle to start proving it together")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { showingCreateChallenge = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Challenge")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var allChallenges: [Challenge] {
        let request: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Challenge.createdAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching challenges: \(error)")
            return []
        }
    }
    
    private var filteredChallenges: [Challenge] {
        var challenges = allChallenges
        
        // Filter by category
        if let category = selectedCategory {
            challenges = challenges.filter { $0.category == category.rawValue }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            challenges = challenges.filter { challenge in
                challenge.title?.localizedCaseInsensitiveContains(searchText) == true ||
                challenge.descriptionText?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return challenges
    }
    
    // MARK: - Methods
    private func loadChallenges() {
        challengeEngine.loadChallenges()
        challengeTemplateManager.loadTemplates()
    }
}

// MARK: - Challenge Detail Card
struct ChallengeDetailCard: View {
    let challenge: Challenge
    @State private var showingChallengeDetails = false
    
    var body: some View {
        Button(action: { showingChallengeDetails = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Challenge Icon
                    Image(systemName: challengeIcon)
                        .font(.title2)
                        .foregroundColor(challengeColor)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(challengeColor.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title ?? "Untitled Challenge")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(challenge.circle?.name ?? "Personal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(challenge.isActive ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(challenge.isActive ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundColor(challenge.isActive ? .green : .gray)
                    }
                }
                
                // Description
                if let description = challenge.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Target and Points
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(challenge.targetValue)) \(challenge.targetUnit ?? "")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Reward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("+\(challenge.pointsReward) pts")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Penalty")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(challenge.pointsPenalty) pts")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("70%") // This would be calculated from actual progress
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: 0.7)
                        .progressViewStyle(LinearProgressViewStyle(tint: challengeColor))
                }
                
                // Footer
                HStack {
                    Text("Created \(challenge.createdAt, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingChallengeDetails) {
            ChallengeDetailView(challenge: challenge)
        }
    }
    
    private var challengeIcon: String {
        switch challenge.category {
        case "fitness": return "figure.walk"
        case "screen_time": return "iphone"
        case "sleep": return "moon.fill"
        case "social": return "person.3.fill"
        default: return "target"
        }
    }
    
    private var challengeColor: Color {
        switch challenge.category {
        case "fitness": return .green
        case "screen_time": return .orange
        case "sleep": return .purple
        case "social": return .blue
        default: return .gray
        }
    }
}

// MARK: - Challenge Detail View
struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Challenge Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: challengeIcon)
                                .font(.title)
                                .foregroundColor(challengeColor)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(challengeColor.opacity(0.1))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.title ?? "Untitled Challenge")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(challenge.circle?.name ?? "Personal")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        if let description = challenge.descriptionText, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    
                    // Challenge Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Challenge Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            StatRow(
                                icon: "target",
                                title: "Target",
                                value: "\(Int(challenge.targetValue)) \(challenge.targetUnit ?? "")"
                            )
                            
                            StatRow(
                                icon: "star.fill",
                                title: "Reward",
                                value: "+\(challenge.pointsReward) points"
                            )
                            
                            StatRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Penalty",
                                value: "\(challenge.pointsPenalty) points"
                            )
                            
                            StatRow(
                                icon: "calendar",
                                title: "Duration",
                                value: "\(challenge.startDate, style: .date) - \(challenge.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "Ongoing")"
                            )
                            
                            StatRow(
                                icon: "gear",
                                title: "Verification",
                                value: challenge.verificationMethod?.capitalized ?? "Unknown"
                            )
                        }
                    }
                    
                    // Progress Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Progress")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Overall Progress")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("70%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: 0.7)
                                .progressViewStyle(LinearProgressViewStyle(tint: challengeColor))
                        }
                    }
                    
                    // Recent Proofs
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Proofs")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Proof history coming soon...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var challengeIcon: String {
        switch challenge.category {
        case "fitness": return "figure.walk"
        case "screen_time": return "iphone"
        case "sleep": return "moon.fill"
        case "social": return "person.3.fill"
        default: return "target"
        }
    }
    
    private var challengeColor: Color {
        switch challenge.category {
        case "fitness": return .green
        case "screen_time": return .orange
        case "sleep": return .purple
        case "social": return .blue
        default: return .gray
        }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    ChallengesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
