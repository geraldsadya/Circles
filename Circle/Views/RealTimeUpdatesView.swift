//
//  RealTimeUpdatesView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CloudKit
import CoreData

struct RealTimeUpdatesView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var notificationManager: NotificationManager
    @StateObject private var updatesManager = RealTimeUpdatesManager.shared
    
    @State private var isConnected = false
    @State private var lastUpdateTime: Date?
    @State private var updateCount = 0
    @State private var showingUpdateDetails = false
    @State private var selectedUpdate: RealTimeUpdate?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Header
                connectionStatusHeader
                
                // Updates List
                updatesList
                
                // Bottom Controls
                bottomControls
            }
            .navigationTitle("Live Updates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        // Show settings
                    }
                }
            }
            .sheet(isPresented: $showingUpdateDetails) {
                if let update = selectedUpdate {
                    UpdateDetailsView(update: update)
                }
            }
            .onAppear {
                setupRealTimeUpdates()
            }
        }
    }
    
    // MARK: - Connection Status Header
    private var connectionStatusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                // Connection Indicator
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .scaleEffect(isConnected ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isConnected)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(isConnected ? "Receiving live updates" : "Checking connection...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Update Count Badge
                if updateCount > 0 {
                    Text("\(updateCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            
            // Last Update Time
            if let lastUpdate = lastUpdateTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("Last update: \(lastUpdate, formatter: timeFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Updates List
    private var updatesList: some View {
        List {
            ForEach(updatesManager.recentUpdates) { update in
                UpdateRowView(update: update) {
                    selectedUpdate = update
                    showingUpdateDetails = true
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            }
            
            if updatesManager.recentUpdates.isEmpty {
                emptyStateView
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await refreshUpdates()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Updates Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("When your friends complete challenges or join circles, you'll see live updates here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Enable Notifications") {
                Task {
                    await notificationManager.requestNotificationPermission()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Update Controls
            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        await refreshUpdates()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    Task {
                        await clearUpdates()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Connection Info
            if !isConnected {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("Unable to connect to live updates. Check your internet connection.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    private func setupRealTimeUpdates() {
        Task {
            await updatesManager.startRealTimeUpdates()
            
            await MainActor.run {
                isConnected = updatesManager.isConnected
                lastUpdateTime = updatesManager.lastUpdateTime
                updateCount = updatesManager.recentUpdates.count
            }
        }
    }
    
    private func refreshUpdates() async {
        await updatesManager.refreshUpdates()
        
        await MainActor.run {
            lastUpdateTime = updatesManager.lastUpdateTime
            updateCount = updatesManager.recentUpdates.count
        }
    }
    
    private func clearUpdates() async {
        await updatesManager.clearUpdates()
        
        await MainActor.run {
            updateCount = updatesManager.recentUpdates.count
        }
    }
    
    // MARK: - Formatters
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Update Row View
struct UpdateRowView: View {
    let update: RealTimeUpdate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Update Icon
                ZStack {
                    Circle()
                        .fill(update.type.color)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: update.type.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
                
                // Update Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(update.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(update.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        Text(update.timestamp, formatter: relativeTimeFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if update.isUnread {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var relativeTimeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}

// MARK: - Update Details View
struct UpdateDetailsView: View {
    let update: RealTimeUpdate
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(update.type.color)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: update.type.icon)
                                    .foregroundColor(.white)
                                    .font(.system(size: 24, weight: .medium))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(update.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(update.timestamp, formatter: detailedTimeFormatter)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Text(update.message)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                    }
                    
                    // Details
                    if let details = update.details {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Details")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ForEach(details.keys.sorted(), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(details[key] ?? "")")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Actions
                    if let actions = update.actions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actions")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ForEach(actions, id: \.title) { action in
                                Button(action.title) {
                                    // Handle action
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Update Details")
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
    
    private var detailedTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Real Time Updates Manager
@MainActor
class RealTimeUpdatesManager: ObservableObject {
    static let shared = RealTimeUpdatesManager()
    
    @Published var recentUpdates: [RealTimeUpdate] = []
    @Published var isConnected = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager.shared
    private let persistenceController = PersistenceController.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    private init() {
        setupNotifications()
        loadRecentUpdates()
    }
    
    deinit {
        updateTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChallengeUpdated),
            name: .challengeUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForfeitUpdated),
            name: .forfeitUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHangoutUpdated),
            name: .hangoutUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLeaderboardUpdated),
            name: .leaderboardUpdated,
            object: nil
        )
    }
    
    // MARK: - Real Time Updates
    func startRealTimeUpdates() async {
        // Start CloudKit subscriptions
        await cloudKitManager.setupSubscriptions()
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates()
            }
        }
        
        isConnected = true
        lastUpdateTime = Date()
        
        print("Real-time updates started")
    }
    
    func stopRealTimeUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        isConnected = false
        
        print("Real-time updates stopped")
    }
    
    func refreshUpdates() async {
        await checkForUpdates()
    }
    
    func clearUpdates() async {
        recentUpdates.removeAll()
        
        // Clear from Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<RealTimeUpdate> = RealTimeUpdate.fetchRequest()
        
        do {
            let updates = try context.fetch(request)
            for update in updates {
                context.delete(update)
            }
            try context.save()
        } catch {
            print("Error clearing updates: \(error)")
        }
    }
    
    private func checkForUpdates() async {
        // Check for new updates from CloudKit
        // This would integrate with CloudKit subscriptions
        
        // Simulate updates for now
        if Bool.random() {
            let update = RealTimeUpdate(
                id: UUID(),
                type: .challengeCompleted,
                title: "Challenge Completed",
                message: "Sarah completed the 'Gym Visit' challenge",
                timestamp: Date(),
                isUnread: true,
                details: [
                    "Challenge": "Gym Visit",
                    "Points": "10",
                    "User": "Sarah"
                ],
                actions: [
                    UpdateAction(title: "View Challenge", action: "view_challenge"),
                    UpdateAction(title: "Congratulate", action: "congratulate")
                ]
            )
            
            addUpdate(update)
        }
    }
    
    private func addUpdate(_ update: RealTimeUpdate) {
        recentUpdates.insert(update, at: 0)
        
        // Keep only last 50 updates
        if recentUpdates.count > 50 {
            recentUpdates.removeLast()
        }
        
        lastUpdateTime = Date()
        
        // Save to Core Data
        saveUpdate(update)
        
        // Send notification
        NotificationCenter.default.post(
            name: .realTimeUpdateReceived,
            object: nil,
            userInfo: ["update": update]
        )
    }
    
    private func saveUpdate(_ update: RealTimeUpdate) {
        let context = persistenceController.container.viewContext
        
        let updateEntity = RealTimeUpdate(context: context)
        updateEntity.id = update.id
        updateEntity.type = update.type.rawValue
        updateEntity.title = update.title
        updateEntity.message = update.message
        updateEntity.timestamp = update.timestamp
        updateEntity.isUnread = update.isUnread
        updateEntity.details = try? JSONEncoder().encode(update.details)
        updateEntity.actions = try? JSONEncoder().encode(update.actions)
        
        try? context.save()
    }
    
    private func loadRecentUpdates() {
        let request: NSFetchRequest<RealTimeUpdate> = RealTimeUpdate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RealTimeUpdate.timestamp, ascending: false)]
        request.fetchLimit = 50
        
        do {
            let entities = try persistenceController.container.viewContext.fetch(request)
            recentUpdates = entities.map { entity in
                RealTimeUpdate(
                    id: entity.id ?? UUID(),
                    type: UpdateType(rawValue: entity.type ?? "") ?? .challengeCompleted,
                    title: entity.title ?? "",
                    message: entity.message ?? "",
                    timestamp: entity.timestamp ?? Date(),
                    isUnread: entity.isUnread,
                    details: entity.details != nil ? try? JSONDecoder().decode([String: String].self, from: entity.details!) : nil,
                    actions: entity.actions != nil ? try? JSONDecoder().decode([UpdateAction].self, from: entity.actions!) : nil
                )
            }
        } catch {
            print("Error loading recent updates: \(error)")
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleChallengeUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let record = userInfo["record"] as? CKRecord else { return }
        
        let update = RealTimeUpdate(
            id: UUID(),
            type: .challengeCompleted,
            title: "Challenge Updated",
            message: "A challenge has been updated",
            timestamp: Date(),
            isUnread: true
        )
        
        addUpdate(update)
    }
    
    @objc private func handleForfeitUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let record = userInfo["record"] as? CKRecord else { return }
        
        let update = RealTimeUpdate(
            id: UUID(),
            type: .forfeitCompleted,
            title: "Forfeit Completed",
            message: "A forfeit has been completed",
            timestamp: Date(),
            isUnread: true
        )
        
        addUpdate(update)
    }
    
    @objc private func handleHangoutUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let record = userInfo["record"] as? CKRecord else { return }
        
        let update = RealTimeUpdate(
            id: UUID(),
            type: .hangoutDetected,
            title: "Hangout Detected",
            message: "A hangout has been detected",
            timestamp: Date(),
            isUnread: true
        )
        
        addUpdate(update)
    }
    
    @objc private func handleLeaderboardUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let record = userInfo["record"] as? CKRecord else { return }
        
        let update = RealTimeUpdate(
            id: UUID(),
            type: .leaderboardUpdated,
            title: "Leaderboard Updated",
            message: "The leaderboard has been updated",
            timestamp: Date(),
            isUnread: true
        )
        
        addUpdate(update)
    }
}

// MARK: - Supporting Types
struct RealTimeUpdate: Identifiable {
    let id: UUID
    let type: UpdateType
    let title: String
    let message: String
    let timestamp: Date
    let isUnread: Bool
    let details: [String: String]?
    let actions: [UpdateAction]?
}

enum UpdateType: String, CaseIterable {
    case challengeCompleted = "challenge_completed"
    case forfeitCompleted = "forfeit_completed"
    case hangoutDetected = "hangout_detected"
    case leaderboardUpdated = "leaderboard_updated"
    case userJoined = "user_joined"
    case circleCreated = "circle_created"
    
    var displayName: String {
        switch self {
        case .challengeCompleted: return "Challenge Completed"
        case .forfeitCompleted: return "Forfeit Completed"
        case .hangoutDetected: return "Hangout Detected"
        case .leaderboardUpdated: return "Leaderboard Updated"
        case .userJoined: return "User Joined"
        case .circleCreated: return "Circle Created"
        }
    }
    
    var icon: String {
        switch self {
        case .challengeCompleted: return "checkmark.circle.fill"
        case .forfeitCompleted: return "camera.fill"
        case .hangoutDetected: return "person.3.fill"
        case .leaderboardUpdated: return "chart.bar.fill"
        case .userJoined: return "person.badge.plus"
        case .circleCreated: return "plus.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .challengeCompleted: return .green
        case .forfeitCompleted: return .orange
        case .hangoutDetected: return .blue
        case .leaderboardUpdated: return .purple
        case .userJoined: return .cyan
        case .circleCreated: return .pink
        }
    }
}

struct UpdateAction: Codable {
    let title: String
    let action: String
}

// MARK: - Core Data Extensions
extension RealTimeUpdate {
    static func fetchRequest() -> NSFetchRequest<RealTimeUpdate> {
        return NSFetchRequest<RealTimeUpdate>(entityName: "RealTimeUpdate")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let realTimeUpdateReceived = Notification.Name("realTimeUpdateReceived")
}

#Preview {
    RealTimeUpdatesView()
        .environmentObject(CloudKitManager.shared)
        .environmentObject(NotificationManager.shared)
}
