//
//  HomeView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var hangoutEngine = HangoutEngine.shared
    @StateObject private var challengeEngine = ChallengeEngine.shared
    
    @State private var showingNewChallenge = false
    @State private var showingHangoutMap = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Welcome Header
                    welcomeHeader
                    
                    // Quick Stats
                    quickStatsSection
                    
                    // Active Challenges
                    activeChallengesSection
                    
                    // Recent Activity
                    recentActivitySection
                    
                    // Hangout Status
                    hangoutStatusSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Circle")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewChallenge = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingNewChallenge) {
                ChallengeComposerView()
            }
            .sheet(isPresented: $showingHangoutMap) {
                HangoutMapView()
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Welcome Header
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(timeOfDay)")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(authManager.currentUser?.displayName ?? "Friend")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Profile Avatar - Minimalist
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            
            Text("Ready to prove it today?")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Points",
                    value: "\(authManager.currentUser?.weeklyPoints ?? 0)",
                    icon: "star.fill"
                )
                
                StatCard(
                    title: "Challenges",
                    value: "\(activeChallengesCount)",
                    icon: "target"
                )
                
                StatCard(
                    title: "Hangouts",
                    value: "\(hangoutEngine.activeHangouts.count)",
                    icon: "person.3.fill"
                )
            }
        }
    }
    
    // MARK: - Active Challenges
    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Challenges")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to challenges tab
                }
                .font(.subheadline)
                .foregroundColor(.primary)
            }
            
            if activeChallenges.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "No Active Challenges",
                    subtitle: "Create your first challenge to get started"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(activeChallenges.prefix(3), id: \.id) { challenge in
                        ChallengeCard(challenge: challenge)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if recentProofs.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No Recent Activity",
                    subtitle: "Complete challenges to see your progress here"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentProofs.prefix(5), id: \.id) { proof in
                        ActivityRow(proof: proof)
                    }
                }
            }
        }
    }
    
    // MARK: - Hangout Status
    private var hangoutStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hangout Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            if hangoutEngine.activeHangouts.isEmpty {
                EmptyStateView(
                    icon: "location",
                    title: "No Active Hangouts",
                    subtitle: "Meet up with friends to start earning hangout points"
                )
            } else {
                ForEach(hangoutEngine.activeHangouts, id: \.id) { hangout in
                    HangoutCard(hangout: hangout)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
    
    private var activeChallenges: [Challenge] {
        // Fetch active challenges from Core Data
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
    
    private var activeChallengesCount: Int {
        activeChallenges.count
    }
    
    private var recentProofs: [Proof] {
        // Fetch recent proofs from Core Data
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", authManager.currentUser ?? User())
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Proof.timestamp, ascending: false)]
        request.fetchLimit = 10
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching proofs: \(error)")
            return []
        }
    }
    
    // MARK: - Methods
    private func loadData() {
        // Load data from Core Data and services
        challengeEngine.loadChallenges()
        hangoutEngine.loadHangouts()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        HStack(spacing: 16) {
            // Challenge Icon - Minimalist
            Image(systemName: challengeIcon)
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title ?? "Untitled Challenge")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(challenge.descriptionText ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("\(Int(challenge.targetValue)) \(challenge.targetUnit ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("+\(challenge.pointsReward) pts")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Progress Indicator - Minimalist
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 2)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.7) // 70% progress
                        .stroke(Color(.systemGray4), lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
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
}

struct ActivityRow: View {
    let proof: Proof
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: proof.isVerified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(proof.isVerified ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(proof.challenge?.title ?? "Unknown Challenge")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(proof.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if proof.isVerified {
                Text("+\(proof.pointsAwarded)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
}

struct HangoutCard: View {
    let hangout: HangoutSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Hangout Icon
            Image(systemName: "person.3.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Active Hangout")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(hangout.participants?.count ?? 0) friends")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Started \(hangout.startTime, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("View") {
                // Show hangout map
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
