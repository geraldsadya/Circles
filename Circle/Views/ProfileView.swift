//
//  ProfileView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var permissionsManager = PermissionsManager.shared
    
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    @State private var showingPrivacySettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Quick Stats
                    quickStatsSection
                    
                    // Recent Activity
                    recentActivitySection
                    
                    // Settings
                    settingsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingPrivacySettings) {
                PrivacySettingsView()
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar - Minimalist
            Button(action: { showingEditProfile = true }) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 2)
                    )
                    .overlay(
                        Text(authManager.currentUser?.displayName?.prefix(1).uppercased() ?? "U")
                            .font(.system(size: 40))
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    )
            }
            
            // User Info
            VStack(spacing: 4) {
                Text(authManager.currentUser?.displayName ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Member since \(authManager.currentUser?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Edit Profile Button
            Button(action: { showingEditProfile = true }) {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Points",
                    value: "\(authManager.currentUser?.totalPoints ?? 0)",
                    icon: "star.fill",
                    color: .yellow
                )
                
                StatCard(
                    title: "This Week",
                    value: "\(authManager.currentUser?.weeklyPoints ?? 0)",
                    icon: "calendar",
                    color: .blue
                )
                
                StatCard(
                    title: "Challenges",
                    value: "\(completedChallengesCount)",
                    icon: "target",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                LazyVStack(spacing: 12) {
                    ForEach(recentProofs.prefix(5), id: \.id) { proof in
                        ActivityRow(proof: proof)
                    }
                }
            }
        }
    }
    
    // MARK: - Settings
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "lock.fill",
                    title: "Privacy & Security",
                    subtitle: "Manage your data and privacy settings",
                    action: { showingPrivacySettings = true }
                )
                
                Divider()
                    .padding(.leading, 50)
                
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Customize your notification preferences",
                    action: { /* Show notifications settings */ }
                )
                
                Divider()
                    .padding(.leading, 50)
                
                SettingsRow(
                    icon: "location.fill",
                    title: "Location Services",
                    subtitle: "Manage location permissions",
                    action: { /* Show location settings */ }
                )
                
                Divider()
                    .padding(.leading, 50)
                
                SettingsRow(
                    icon: "square.and.arrow.up",
                    title: "Export Data",
                    subtitle: "Download your data",
                    action: { /* Export data */ }
                )
                
                Divider()
                    .padding(.leading, 50)
                
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "Get help and contact support",
                    action: { /* Show help */ }
                )
                
                Divider()
                    .padding(.leading, 50)
                
                SettingsRow(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: "App version and information",
                    action: { /* Show about */ }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
    
    // MARK: - Computed Properties
    private var completedChallengesCount: Int {
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@ AND isVerified == YES", authManager.currentUser ?? User())
        
        do {
            return try viewContext.count(for: request)
        } catch {
            print("Error counting completed challenges: \(error)")
            return 0
        }
    }
    
    private var recentProofs: [Proof] {
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", authManager.currentUser ?? User())
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Proof.timestamp, ascending: false)]
        request.fetchLimit = 10
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching recent proofs: \(error)")
            return []
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        Text("Account")
                    }
                    
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.blue)
                        Text("Notifications")
                    }
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                        Text("Privacy")
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Help & Support")
                    }
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("About")
                    }
                }
                
                Section {
                    Button(action: {
                        authManager.signOut()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
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
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var displayName: String = ""
    @State private var profileEmoji: String = ""
    @State private var isSaving = false
    
    private let emojiOptions = ["🚀", "💪", "🏃‍♂️", "🧘‍♀️", "📚", "🎯", "⭐", "🔥", "💎", "🌟"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Display Name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } header: {
                    Text("Profile Information")
                }
                
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button(action: { profileEmoji = emoji }) {
                                Text(emoji)
                                    .font(.title)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(profileEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Choose Emoji")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(displayName.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            displayName = authManager.currentUser?.displayName ?? ""
            profileEmoji = authManager.currentUser?.profileEmoji ?? "👤"
        }
    }
    
    private func saveProfile() {
        guard !displayName.isEmpty else { return }
        
        isSaving = true
        
        // Update user profile
        authManager.currentUser?.displayName = displayName
        authManager.currentUser?.profileEmoji = profileEmoji
        
        // Save to Core Data
        do {
            try authManager.currentUser?.managedObjectContext?.save()
            dismiss()
        } catch {
            print("Error saving profile: \(error)")
            isSaving = false
        }
    }
}

// MARK: - Preview
#Preview {
    ProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
