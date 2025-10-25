//
//  PowerManagementManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import Network
import CoreData
import Combine

@MainActor
class PowerManagementManager: ObservableObject {
    static let shared = PowerManagementManager()
    
    @Published var isLowPowerMode = false
    @Published var isCellularConnection = false
    @Published var batteryLevel: Float = 1.0
    @Published var isCharging = false
    @Published var powerSettings: PowerSettings = PowerSettings()
    @Published var isThrottling = false
    @Published var throttlingReason: ThrottlingReason?
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let locationManager = LocationManager.shared
    private let backgroundTaskManager = BackgroundTaskManager.shared
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Power monitoring
    private var powerTimer: Timer?
    private var throttlingTimer: Timer?
    
    // Throttling state
    private var isThrottlingActive = false
    private var throttlingStartTime: Date?
    private var originalSettings: PowerSettings?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupPowerMonitoring()
        setupNetworkMonitoring()
        setupNotifications()
        loadPowerSettings()
    }
    
    deinit {
        powerTimer?.invalidate()
        throttlingTimer?.invalidate()
        networkMonitor.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupPowerMonitoring() {
        // Monitor battery level and charging status
        powerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updatePowerStatus()
            }
        }
        
        // Initial power status update
        Task {
            await updatePowerStatus()
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.handleNetworkChange(path)
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Power Status Updates
    private func updatePowerStatus() async {
        // Update battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        
        // Update charging status
        isCharging = UIDevice.current.batteryState == .charging
        
        // Update low power mode
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        // Check if throttling should be applied
        await checkThrottlingConditions()
    }
    
    private func handleNetworkChange(_ path: NWPath) async {
        let wasCellular = isCellularConnection
        isCellularConnection = path.usesInterfaceType(.cellular)
        
        // If network type changed, check throttling conditions
        if wasCellular != isCellularConnection {
            await checkThrottlingConditions()
        }
    }
    
    // MARK: - Throttling Management
    private func checkThrottlingConditions() async {
        let shouldThrottle = shouldApplyThrottling()
        
        if shouldThrottle && !isThrottlingActive {
            await startThrottling()
        } else if !shouldThrottle && isThrottlingActive {
            await stopThrottling()
        }
    }
    
    private func shouldApplyThrottling() -> Bool {
        // Check low power mode
        if isLowPowerMode {
            throttlingReason = .lowPowerMode
            return true
        }
        
        // Check battery level
        if batteryLevel < 0.2 && !isCharging {
            throttlingReason = .lowBattery
            return true
        }
        
        // Check cellular connection
        if isCellularConnection {
            throttlingReason = .cellularConnection
            return true
        }
        
        // Check if charging and battery is low
        if isCharging && batteryLevel < 0.1 {
            throttlingReason = .chargingLowBattery
            return true
        }
        
        throttlingReason = nil
        return false
    }
    
    private func startThrottling() async {
        guard !isThrottlingActive else { return }
        
        isThrottlingActive = true
        isThrottling = true
        throttlingStartTime = Date()
        
        // Store original settings
        originalSettings = powerSettings
        
        // Apply throttling based on reason
        switch throttlingReason {
        case .lowPowerMode:
            await applyLowPowerModeThrottling()
        case .lowBattery:
            await applyLowBatteryThrottling()
        case .cellularConnection:
            await applyCellularThrottling()
        case .chargingLowBattery:
            await applyChargingThrottling()
        case .none:
            break
        }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .powerThrottlingStarted,
            object: nil,
            userInfo: ["reason": throttlingReason?.rawValue ?? ""]
        )
        
        print("Power throttling started: \(throttlingReason?.rawValue ?? "unknown")")
    }
    
    private func stopThrottling() async {
        guard isThrottlingActive else { return }
        
        isThrottlingActive = false
        isThrottling = false
        
        // Restore original settings
        if let original = originalSettings {
            powerSettings = original
            originalSettings = nil
        }
        
        // Restore normal operation
        await restoreNormalOperation()
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .powerThrottlingStopped,
            object: nil
        )
        
        print("Power throttling stopped")
    }
    
    // MARK: - Throttling Strategies
    private func applyLowPowerModeThrottling() async {
        // Reduce location accuracy
        powerSettings.locationAccuracy = .hundredMeters
        powerSettings.locationUpdateInterval = 300 // 5 minutes
        
        // Reduce background task frequency
        powerSettings.backgroundTaskInterval = 600 // 10 minutes
        
        // Disable non-essential features
        powerSettings.enableHangoutDetection = false
        powerSettings.enableRandomProofs = false
        
        // Reduce sync frequency
        powerSettings.syncInterval = 1800 // 30 minutes
        
        // Apply settings
        await applyPowerSettings()
    }
    
    private func applyLowBatteryThrottling() async {
        // Reduce location accuracy
        powerSettings.locationAccuracy = .kilometer
        powerSettings.locationUpdateInterval = 600 // 10 minutes
        
        // Reduce background task frequency
        powerSettings.backgroundTaskInterval = 900 // 15 minutes
        
        // Disable non-essential features
        powerSettings.enableHangoutDetection = false
        powerSettings.enableRandomProofs = false
        
        // Reduce sync frequency
        powerSettings.syncInterval = 3600 // 1 hour
        
        // Apply settings
        await applyPowerSettings()
    }
    
    private func applyCellularThrottling() async {
        // Reduce sync frequency
        powerSettings.syncInterval = 1800 // 30 minutes
        
        // Reduce background task frequency
        powerSettings.backgroundTaskInterval = 600 // 10 minutes
        
        // Disable large data transfers
        powerSettings.enableLargeDataTransfers = false
        
        // Apply settings
        await applyPowerSettings()
    }
    
    private func applyChargingThrottling() async {
        // Reduce location accuracy
        powerSettings.locationAccuracy = .hundredMeters
        powerSettings.locationUpdateInterval = 300 // 5 minutes
        
        // Reduce background task frequency
        powerSettings.backgroundTaskInterval = 600 // 10 minutes
        
        // Apply settings
        await applyPowerSettings()
    }
    
    private func restoreNormalOperation() async {
        // Restore normal settings
        powerSettings.locationAccuracy = .nearestTenMeters
        powerSettings.locationUpdateInterval = 60 // 1 minute
        powerSettings.backgroundTaskInterval = 300 // 5 minutes
        powerSettings.enableHangoutDetection = true
        powerSettings.enableRandomProofs = true
        powerSettings.syncInterval = 300 // 5 minutes
        powerSettings.enableLargeDataTransfers = true
        
        // Apply settings
        await applyPowerSettings()
    }
    
    // MARK: - Settings Application
    private func applyPowerSettings() async {
        // Apply location settings
        await locationManager.updateLocationSettings(
            accuracy: powerSettings.locationAccuracy,
            updateInterval: powerSettings.locationUpdateInterval
        )
        
        // Apply background task settings
        await backgroundTaskManager.updateBackgroundTaskSettings(
            interval: powerSettings.backgroundTaskInterval
        )
        
        // Apply sync settings
        await updateSyncSettings()
        
        // Save settings
        savePowerSettings()
    }
    
    private func updateSyncSettings() async {
        // Update CloudKit sync frequency
        // This would integrate with CloudKitManager
        print("Sync interval updated to: \(powerSettings.syncInterval) seconds")
    }
    
    // MARK: - Power Settings Management
    func updatePowerSettings(_ settings: PowerSettings) {
        powerSettings = settings
        savePowerSettings()
        
        // Apply settings if not throttling
        if !isThrottlingActive {
            Task {
                await applyPowerSettings()
            }
        }
    }
    
    func resetPowerSettings() {
        powerSettings = PowerSettings()
        savePowerSettings()
        
        // Apply default settings
        Task {
            await applyPowerSettings()
        }
    }
    
    private func loadPowerSettings() {
        if let data = UserDefaults.standard.data(forKey: "power_settings"),
           let settings = try? JSONDecoder().decode(PowerSettings.self, from: data) {
            powerSettings = settings
        }
    }
    
    private func savePowerSettings() {
        if let data = try? JSONEncoder().encode(powerSettings) {
            UserDefaults.standard.set(data, forKey: "power_settings")
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleLowPowerModeChanged(_ notification: Notification) {
        Task {
            await updatePowerStatus()
        }
    }
    
    @objc private func handleBatteryLevelChanged(_ notification: Notification) {
        Task {
            await updatePowerStatus()
        }
    }
    
    @objc private func handleBatteryStateChanged(_ notification: Notification) {
        Task {
            await updatePowerStatus()
        }
    }
    
    // MARK: - Manual Throttling
    func enableManualThrottling() async {
        throttlingReason = .manual
        await startThrottling()
    }
    
    func disableManualThrottling() async {
        if throttlingReason == .manual {
            await stopThrottling()
        }
    }
    
    // MARK: - Power Statistics
    func getPowerStatistics() -> PowerStatistics {
        let throttlingDuration = throttlingStartTime != nil ? Date().timeIntervalSince(throttlingStartTime!) : 0
        
        return PowerStatistics(
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            isLowPowerMode: isLowPowerMode,
            isCellularConnection: isCellularConnection,
            isThrottling: isThrottling,
            throttlingReason: throttlingReason,
            throttlingDuration: throttlingDuration,
            powerSettings: powerSettings
        )
    }
    
    // MARK: - Battery Optimization
    func optimizeBatteryUsage() async {
        // Apply aggressive battery optimization
        powerSettings.locationAccuracy = .kilometer
        powerSettings.locationUpdateInterval = 900 // 15 minutes
        powerSettings.backgroundTaskInterval = 1800 // 30 minutes
        powerSettings.enableHangoutDetection = false
        powerSettings.enableRandomProofs = false
        powerSettings.syncInterval = 3600 // 1 hour
        
        await applyPowerSettings()
        
        print("Battery optimization applied")
    }
    
    func restoreNormalBatteryUsage() async {
        // Restore normal battery usage
        powerSettings.locationAccuracy = .nearestTenMeters
        powerSettings.locationUpdateInterval = 60 // 1 minute
        powerSettings.backgroundTaskInterval = 300 // 5 minutes
        powerSettings.enableHangoutDetection = true
        powerSettings.enableRandomProofs = true
        powerSettings.syncInterval = 300 // 5 minutes
        
        await applyPowerSettings()
        
        print("Normal battery usage restored")
    }
    
    // MARK: - Network Optimization
    func optimizeNetworkUsage() async {
        // Apply network optimization
        powerSettings.syncInterval = 1800 // 30 minutes
        powerSettings.enableLargeDataTransfers = false
        
        await applyPowerSettings()
        
        print("Network optimization applied")
    }
    
    func restoreNormalNetworkUsage() async {
        // Restore normal network usage
        powerSettings.syncInterval = 300 // 5 minutes
        powerSettings.enableLargeDataTransfers = true
        
        await applyPowerSettings()
        
        print("Normal network usage restored")
    }
}

// MARK: - Supporting Types
struct PowerSettings: Codable {
    var locationAccuracy: LocationAccuracy = .nearestTenMeters
    var locationUpdateInterval: TimeInterval = 60 // 1 minute
    var backgroundTaskInterval: TimeInterval = 300 // 5 minutes
    var enableHangoutDetection: Bool = true
    var enableRandomProofs: Bool = true
    var syncInterval: TimeInterval = 300 // 5 minutes
    var enableLargeDataTransfers: Bool = true
    var enableBackgroundRefresh: Bool = true
    var enablePushNotifications: Bool = true
}

enum LocationAccuracy: String, Codable, CaseIterable {
    case nearestTenMeters = "nearest_ten_meters"
    case hundredMeters = "hundred_meters"
    case kilometer = "kilometer"
    case threeKilometers = "three_kilometers"
    
    var displayName: String {
        switch self {
        case .nearestTenMeters: return "Most Accurate"
        case .hundredMeters: return "Accurate"
        case .kilometer: return "Less Accurate"
        case .threeKilometers: return "Least Accurate"
        }
    }
    
    var accuracyValue: Double {
        switch self {
        case .nearestTenMeters: return 10
        case .hundredMeters: return 100
        case .kilometer: return 1000
        case .threeKilometers: return 3000
        }
    }
}

enum ThrottlingReason: String, CaseIterable {
    case lowPowerMode = "low_power_mode"
    case lowBattery = "low_battery"
    case cellularConnection = "cellular_connection"
    case chargingLowBattery = "charging_low_battery"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .lowPowerMode: return "Low Power Mode"
        case .lowBattery: return "Low Battery"
        case .cellularConnection: return "Cellular Connection"
        case .chargingLowBattery: return "Charging Low Battery"
        case .manual: return "Manual"
        }
    }
    
    var description: String {
        switch self {
        case .lowPowerMode: return "Reducing activity due to Low Power Mode"
        case .lowBattery: return "Reducing activity due to low battery level"
        case .cellularConnection: return "Reducing activity due to cellular connection"
        case .chargingLowBattery: return "Reducing activity while charging low battery"
        case .manual: return "Manual throttling enabled"
        }
    }
}

struct PowerStatistics {
    let batteryLevel: Float
    let isCharging: Bool
    let isLowPowerMode: Bool
    let isCellularConnection: Bool
    let isThrottling: Bool
    let throttlingReason: ThrottlingReason?
    let throttlingDuration: TimeInterval
    let powerSettings: PowerSettings
}

// MARK: - Notifications
extension Notification.Name {
    static let powerThrottlingStarted = Notification.Name("powerThrottlingStarted")
    static let powerThrottlingStopped = Notification.Name("powerThrottlingStopped")
    static let batteryLevelChanged = Notification.Name("batteryLevelChanged")
    static let chargingStateChanged = Notification.Name("chargingStateChanged")
}
