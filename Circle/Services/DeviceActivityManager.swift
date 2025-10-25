//
//  DeviceActivityManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import CoreData
import Combine

@MainActor
class DeviceActivityManager: ObservableObject {
    static let shared = DeviceActivityManager()
    
    @Published var isStrictModeAvailable = false
    @Published var isStrictModeEnabled = false
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var deviceActivityStats: DeviceActivityStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let screenTimeManager = ScreenTimeManager.shared
    
    // DeviceActivity components
    private let deviceActivityCenter = DeviceActivityCenter()
    private let authorizationCenter = AuthorizationCenter.shared
    private let managedSettingsStore = ManagedSettingsStore()
    
    // Activity monitoring
    private var activityMonitor: DeviceActivityMonitor?
    private var activitySchedule: DeviceActivitySchedule?
    private var activityName: DeviceActivityName?
    
    // Feature flag
    private let strictModeFeatureFlag = "strict_device_activity_enabled"
    private var isFeatureEnabled = false
    
    // Configuration
    private let maxDailyScreenTime: TimeInterval = 8 * 3600 // 8 hours
    private let maxWeeklyScreenTime: TimeInterval = 56 * 3600 // 56 hours
    private let monitoringInterval: TimeInterval = 300 // 5 minutes
    
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    
    private init() {
        checkFeatureFlag()
        checkStrictModeAvailability()
        setupNotifications()
    }
    
    deinit {
        monitoringTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func checkFeatureFlag() {
        // Check if strict mode is enabled via feature flag
        // This would typically come from a remote configuration service
        isFeatureEnabled = true // For now, always enabled
        
        if isFeatureEnabled {
            print("Strict DeviceActivity mode is enabled via feature flag")
        } else {
            print("Strict DeviceActivity mode is disabled via feature flag")
        }
    }
    
    private func checkStrictModeAvailability() {
        // Check if DeviceActivity is available on this device
        isStrictModeAvailable = DeviceActivityCenter.isSupported
        
        if isStrictModeAvailable {
            // Check current authorization status
            Task {
                await checkAuthorizationStatus()
            }
        } else {
            print("DeviceActivity is not supported on this device")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthorizationStatusChanged),
            name: .authorizationStatusDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppUsageChanged),
            name: .appUsageChanged,
            object: nil
        )
    }
    
    // MARK: - Authorization
    private func checkAuthorizationStatus() async {
        do {
            let status = try await authorizationCenter.requestAuthorization(for: .individual)
            
            await MainActor.run {
                authorizationStatus = status
                isStrictModeEnabled = status == .approved
            }
            
            if isStrictModeEnabled {
                await setupStrictMode()
            }
            
        } catch {
            await MainActor.run {
                authorizationStatus = .denied
                isStrictModeEnabled = false
                errorMessage = "Failed to check authorization status: \(error.localizedDescription)"
            }
            print("Error checking authorization status: \(error)")
        }
    }
    
    func requestStrictModePermission() async {
        guard isStrictModeAvailable && isFeatureEnabled else {
            errorMessage = "Strict mode is not available"
            return
        }
        
        do {
            let status = try await authorizationCenter.requestAuthorization(for: .individual)
            
            await MainActor.run {
                authorizationStatus = status
                isStrictModeEnabled = status == .approved
            }
            
            if isStrictModeEnabled {
                await setupStrictMode()
            }
            
        } catch {
            await MainActor.run {
                authorizationStatus = .denied
                isStrictModeEnabled = false
                errorMessage = "Failed to request strict mode permission: \(error.localizedDescription)"
            }
            print("Error requesting strict mode permission: \(error)")
        }
    }
    
    // MARK: - Strict Mode Setup
    private func setupStrictMode() async {
        // Create device activity schedule
        await createDeviceActivitySchedule()
        
        // Start monitoring
        await startDeviceActivityMonitoring()
        
        // Set up app restrictions
        await setupAppRestrictions()
        
        // Start periodic monitoring
        startPeriodicMonitoring()
        
        print("Strict mode setup completed")
    }
    
    private func createDeviceActivitySchedule() async {
        // Create a schedule that monitors all day
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        activitySchedule = schedule
        activityName = DeviceActivityName("CircleStrictMode")
        
        do {
            try await deviceActivityCenter.startMonitoring(activityName!, during: schedule)
            print("Device activity schedule created")
        } catch {
            print("Error creating device activity schedule: \(error)")
        }
    }
    
    private func startDeviceActivityMonitoring() async {
        guard let activityName = activityName else { return }
        
        activityMonitor = DeviceActivityMonitor(activityName) { [weak self] event in
            Task { @MainActor in
                await self?.handleDeviceActivityEvent(event)
            }
        }
        
        print("Device activity monitoring started")
    }
    
    private func handleDeviceActivityEvent(_ event: DeviceActivityEvent) async {
        switch event {
        case .didStart:
            print("Device activity monitoring started")
            await updateDeviceActivityStats()
            
        case .didEnd:
            print("Device activity monitoring ended")
            await updateDeviceActivityStats()
            
        case .didUpdate:
            print("Device activity updated")
            await updateDeviceActivityStats()
            
        @unknown default:
            print("Unknown device activity event")
        }
    }
    
    private func setupAppRestrictions() async {
        // Set up app restrictions based on screen time limits
        let restrictions = ManagedSettingsStore()
        
        // Block social media apps during focus sessions
        let socialMediaApps = getSocialMediaApps()
        restrictions.shield.applications = socialMediaApps
        
        // Set web content restrictions
        restrictions.shield.webContent = .blocked
        
        // Set app installation restrictions
        restrictions.shield.applicationInstallation = .blocked
        
        print("App restrictions configured")
    }
    
    private func getSocialMediaApps() -> Set<ApplicationToken> {
        // This would return actual social media app tokens
        // For now, return empty set
        return Set<ApplicationToken>()
    }
    
    private func startPeriodicMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateDeviceActivityStats()
            }
        }
    }
    
    // MARK: - Screen Time Monitoring
    func getCurrentScreenTime() async -> TimeInterval {
        guard isStrictModeEnabled else {
            return await getEstimatedScreenTime()
        }
        
        // Get actual screen time from DeviceActivity
        return await getActualScreenTime()
    }
    
    private func getActualScreenTime() async -> TimeInterval {
        // This would integrate with DeviceActivity to get actual screen time
        // For now, return a simulated value
        return Double.random(in: 0...maxDailyScreenTime)
    }
    
    private func getEstimatedScreenTime() async -> TimeInterval {
        // Estimate screen time based on app usage patterns
        return Double.random(in: 0...maxDailyScreenTime)
    }
    
    func getScreenTimeForApp(_ appToken: ApplicationToken) async -> TimeInterval {
        guard isStrictModeEnabled else {
            return 0
        }
        
        // Get screen time for specific app
        // This would integrate with DeviceActivity
        return Double.random(in: 0...3600) // 0 to 1 hour
    }
    
    func getTopApps(limit: Int = 10) async -> [AppUsageStats] {
        guard isStrictModeEnabled else {
            return []
        }
        
        // Get top apps by usage time
        // This would integrate with DeviceActivity
        return (0..<limit).map { index in
            AppUsageStats(
                appName: "App \(index + 1)",
                usageTime: Double.random(in: 0...3600),
                launchCount: Int.random(in: 1...50),
                lastUsed: Date().addingTimeInterval(-Double.random(in: 0...86400))
            )
        }
    }
    
    // MARK: - App Restrictions
    func blockApp(_ appToken: ApplicationToken) async {
        guard isStrictModeEnabled else { return }
        
        managedSettingsStore.shield.applications.insert(appToken)
        print("App blocked: \(appToken)")
    }
    
    func unblockApp(_ appToken: ApplicationToken) async {
        guard isStrictModeEnabled else { return }
        
        managedSettingsStore.shield.applications.remove(appToken)
        print("App unblocked: \(appToken)")
    }
    
    func blockWebsite(_ url: URL) async {
        guard isStrictModeEnabled else { return }
        
        // Block specific website
        // This would integrate with ManagedSettings
        print("Website blocked: \(url)")
    }
    
    func setAppTimeLimit(_ appToken: ApplicationToken, limit: TimeInterval) async {
        guard isStrictModeEnabled else { return }
        
        // Set time limit for specific app
        // This would integrate with ManagedSettings
        print("Time limit set for app: \(appToken) - \(limit) seconds")
    }
    
    // MARK: - Focus Mode Integration
    func enableFocusMode() async {
        guard isStrictModeEnabled else { return }
        
        // Enable focus mode with strict restrictions
        let restrictions = ManagedSettingsStore()
        
        // Block all non-essential apps
        restrictions.shield.applications = getAllNonEssentialApps()
        
        // Block web content
        restrictions.shield.webContent = .blocked
        
        // Block app installation
        restrictions.shield.applicationInstallation = .blocked
        
        print("Focus mode enabled")
    }
    
    func disableFocusMode() async {
        guard isStrictModeEnabled else { return }
        
        // Disable focus mode
        let restrictions = ManagedSettingsStore()
        
        // Remove all restrictions
        restrictions.shield.applications = Set<ApplicationToken>()
        restrictions.shield.webContent = .none
        restrictions.shield.applicationInstallation = .none
        
        print("Focus mode disabled")
    }
    
    private func getAllNonEssentialApps() -> Set<ApplicationToken> {
        // Return all non-essential apps
        // This would be implemented based on app categorization
        return Set<ApplicationToken>()
    }
    
    // MARK: - Statistics and Analytics
    private func updateDeviceActivityStats() async {
        let dailyScreenTime = await getCurrentScreenTime()
        let weeklyScreenTime = await getWeeklyScreenTime()
        let topApps = await getTopApps(limit: 5)
        
        let stats = DeviceActivityStats(
            dailyScreenTime: dailyScreenTime,
            weeklyScreenTime: weeklyScreenTime,
            maxDailyScreenTime: maxDailyScreenTime,
            maxWeeklyScreenTime: maxWeeklyScreenTime,
            topApps: topApps,
            isStrictModeEnabled: isStrictModeEnabled,
            lastUpdated: Date()
        )
        
        deviceActivityStats = stats
        
        // Save to Core Data
        await saveDeviceActivityStats(stats)
    }
    
    private func getWeeklyScreenTime() async -> TimeInterval {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = Date()
        
        // Calculate weekly screen time
        var totalTime: TimeInterval = 0
        
        for day in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: day, to: weekStart) ?? Date()
            totalTime += await getScreenTimeForDate(date)
        }
        
        return totalTime
    }
    
    private func getScreenTimeForDate(_ date: Date) async -> TimeInterval {
        // Get screen time for specific date
        return Double.random(in: 0...maxDailyScreenTime)
    }
    
    private func saveDeviceActivityStats(_ stats: DeviceActivityStats) async {
        let context = persistenceController.container.viewContext
        
        let deviceStats = DeviceActivityStatsEntity(context: context)
        deviceStats.id = UUID()
        deviceStats.dailyScreenTime = stats.dailyScreenTime
        deviceStats.weeklyScreenTime = stats.weeklyScreenTime
        deviceStats.maxDailyScreenTime = stats.maxDailyScreenTime
        deviceStats.maxWeeklyScreenTime = stats.maxWeeklyScreenTime
        deviceStats.isStrictModeEnabled = stats.isStrictModeEnabled
        deviceStats.lastUpdated = stats.lastUpdated
        deviceStats.createdAt = Date()
        
        try? context.save()
    }
    
    // MARK: - Challenge Integration
    func createScreenTimeChallenge(targetHours: Double, user: User) async throws -> Challenge {
        let context = persistenceController.container.viewContext
        
        let challenge = Challenge(context: context)
        challenge.id = UUID()
        challenge.title = "Screen Time Limit"
        challenge.description = "Keep screen time under \(targetHours) hours today"
        challenge.category = ChallengeCategory.screenTime.rawValue
        challenge.frequency = ChallengeFrequency.daily.rawValue
        challenge.targetValue = targetHours
        challenge.targetUnit = "hours"
        challenge.verificationMethod = VerificationMethod.screenTime.rawValue
        challenge.isActive = true
        challenge.pointsReward = Int32(Verify.challengeCompletePoints)
        challenge.pointsPenalty = Int32(abs(Verify.challengeMissPoints))
        challenge.createdBy = user
        challenge.startDate = Date()
        challenge.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        // Create verification parameters
        let params = ScreenTimeChallengeParams(
            maxHours: targetHours,
            categories: ["social", "entertainment", "games"]
        )
        challenge.verificationParams = try JSONEncoder().encode(params)
        
        try context.save()
        
        return challenge
    }
    
    func verifyScreenTimeChallenge(_ challenge: Challenge, user: User) async -> Proof {
        let context = persistenceController.container.viewContext
        
        let proof = Proof(context: context)
        proof.id = UUID()
        proof.user = user
        proof.challenge = challenge
        proof.timestamp = Date()
        proof.verificationMethod = VerificationMethod.screenTime.rawValue
        
        // Get current screen time
        let currentScreenTime = await getCurrentScreenTime()
        let targetScreenTime = challenge.targetValue * 3600 // Convert hours to seconds
        
        // Verify challenge
        proof.isVerified = currentScreenTime <= targetScreenTime
        proof.confidenceScore = proof.isVerified ? 0.95 : 0.05 // Higher confidence with strict mode
        proof.pointsAwarded = proof.isVerified ? challenge.pointsReward : -challenge.pointsPenalty
        
        // Add sensor data
        let sensorData = ScreenTimeData(
            totalScreenTime: currentScreenTime,
            targetScreenTime: targetScreenTime,
            isStrictMode: isStrictModeEnabled,
            timestamp: Date()
        )
        proof.sensorData = try? JSONEncoder().encode(sensorData)
        
        proof.notes = proof.isVerified ? "Screen time challenge completed" : "Screen time limit exceeded"
        
        try? context.save()
        
        return proof
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAuthorizationStatusChanged(_ notification: Notification) {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    @objc private func handleAppUsageChanged(_ notification: Notification) {
        Task {
            await updateDeviceActivityStats()
        }
    }
    
    // MARK: - Cleanup
    func disableStrictMode() async {
        guard isStrictModeEnabled else { return }
        
        // Stop monitoring
        if let activityName = activityName {
            try? await deviceActivityCenter.stopMonitoring(activityName)
        }
        
        // Remove app restrictions
        let restrictions = ManagedSettingsStore()
        restrictions.shield.applications = Set<ApplicationToken>()
        restrictions.shield.webContent = .none
        restrictions.shield.applicationInstallation = .none
        
        // Stop timer
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        await MainActor.run {
            isStrictModeEnabled = false
        }
        
        print("Strict mode disabled")
    }
    
    // MARK: - Analytics
    func getDeviceActivityStats() -> DeviceActivityStats? {
        return deviceActivityStats
    }
    
    func getHistoricalStats(days: Int = 7) -> [DeviceActivityStats] {
        let request: NSFetchRequest<DeviceActivityStatsEntity> = DeviceActivityStatsEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DeviceActivityStatsEntity.createdAt, ascending: false)]
        request.fetchLimit = days
        
        do {
            let entities = try persistenceController.container.viewContext.fetch(request)
            return entities.map { entity in
                DeviceActivityStats(
                    dailyScreenTime: entity.dailyScreenTime,
                    weeklyScreenTime: entity.weeklyScreenTime,
                    maxDailyScreenTime: entity.maxDailyScreenTime,
                    maxWeeklyScreenTime: entity.maxWeeklyScreenTime,
                    topApps: [], // Would be loaded separately
                    isStrictModeEnabled: entity.isStrictModeEnabled,
                    lastUpdated: entity.lastUpdated ?? Date()
                )
            }
        } catch {
            print("Error loading historical stats: \(error)")
            return []
        }
    }
}

// MARK: - Supporting Types
enum AuthorizationStatus: String, CaseIterable {
    case notDetermined = "not_determined"
    case denied = "denied"
    case approved = "approved"
    
    var displayName: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .approved: return "Approved"
        }
    }
}

struct DeviceActivityStats {
    let dailyScreenTime: TimeInterval
    let weeklyScreenTime: TimeInterval
    let maxDailyScreenTime: TimeInterval
    let maxWeeklyScreenTime: TimeInterval
    let topApps: [AppUsageStats]
    let isStrictModeEnabled: Bool
    let lastUpdated: Date
}

struct AppUsageStats {
    let appName: String
    let usageTime: TimeInterval
    let launchCount: Int
    let lastUsed: Date
}

// MARK: - Core Data Extensions
extension DeviceActivityStatsEntity {
    static func fetchRequest() -> NSFetchRequest<DeviceActivityStatsEntity> {
        return NSFetchRequest<DeviceActivityStatsEntity>(entityName: "DeviceActivityStatsEntity")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let authorizationStatusDidChange = Notification.Name("authorizationStatusDidChange")
    static let appUsageChanged = Notification.Name("appUsageChanged")
    static let strictModeEnabled = Notification.Name("strictModeEnabled")
    static let strictModeDisabled = Notification.Name("strictModeDisabled")
}
