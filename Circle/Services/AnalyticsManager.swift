//
//  AnalyticsManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var isAnalyticsEnabled = true
    @Published var analyticsData: [AnalyticsEvent] = []
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadAnalyticsSettings()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Initialization
    func initialize() {
        // Initialize analytics
        logEvent(.appLaunch, properties: ["timestamp": Date().timeIntervalSince1970])
        
        // Start analytics collection
        startAnalyticsCollection()
    }
    
    // MARK: - Event Logging
    func logEvent(_ event: AnalyticsEventType, properties: [String: Any] = [:]) {
        guard isAnalyticsEnabled else { return }
        
        let analyticsEvent = AnalyticsEvent(
            id: UUID(),
            eventType: event,
            properties: properties,
            timestamp: Date(),
            sessionId: getCurrentSessionId()
        )
        
        analyticsData.append(analyticsEvent)
        
        // Save to Core Data
        saveAnalyticsEvent(analyticsEvent)
        
        // Log to console in debug mode
        #if DEBUG
        print("[Analytics] \(event.rawValue): \(properties)")
        #endif
    }
    
    // MARK: - User Actions
    func logUserAction(_ action: UserAction, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["action"] = action.rawValue
        eventProperties["user_id"] = getCurrentUserId()
        
        logEvent(.userAction, properties: eventProperties)
    }
    
    // MARK: - Performance Metrics
    func logPerformanceMetric(_ metric: PerformanceMetric, value: Double, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["metric"] = metric.rawValue
        eventProperties["value"] = value
        eventProperties["unit"] = metric.unit
        
        logEvent(.performanceMetric, properties: eventProperties)
    }
    
    // MARK: - Error Tracking
    func logError(_ error: Error, context: String = "", properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["error"] = error.localizedDescription
        eventProperties["context"] = context
        eventProperties["error_code"] = (error as NSError).code
        
        logEvent(.error, properties: eventProperties)
    }
    
    // MARK: - Feature Usage
    func logFeatureUsage(_ feature: Feature, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["feature"] = feature.rawValue
        eventProperties["usage_count"] = getFeatureUsageCount(feature)
        
        logEvent(.featureUsage, properties: eventProperties)
    }
    
    // MARK: - Analytics Collection
    private func startAnalyticsCollection() {
        // Collect app usage metrics
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.collectAppMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func collectAppMetrics() {
        // Collect memory usage
        let memoryUsage = getMemoryUsage()
        logPerformanceMetric(.memoryUsage, value: memoryUsage)
        
        // Collect battery level
        let batteryLevel = getBatteryLevel()
        logPerformanceMetric(.batteryLevel, value: batteryLevel)
        
        // Collect network status
        let networkStatus = getNetworkStatus()
        logEvent(.networkStatus, properties: ["status": networkStatus])
    }
    
    // MARK: - Data Management
    func exportAnalyticsData() -> Data? {
        let exportData = AnalyticsExportData(
            events: analyticsData,
            exportDate: Date(),
            appVersion: getAppVersion(),
            deviceInfo: getDeviceInfo()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    func clearAnalyticsData() {
        analyticsData.removeAll()
        
        // Clear Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<AnalyticsEventEntity> = AnalyticsEventEntity.fetchRequest()
        
        if let entities = try? context.fetch(request) {
            for entity in entities {
                context.delete(entity)
            }
            try? context.save()
        }
    }
    
    // MARK: - Settings
    func setAnalyticsEnabled(_ enabled: Bool) {
        isAnalyticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analytics_enabled")
        
        if !enabled {
            clearAnalyticsData()
        }
    }
    
    private func loadAnalyticsSettings() {
        isAnalyticsEnabled = UserDefaults.standard.bool(forKey: "analytics_enabled")
    }
    
    // MARK: - Helper Methods
    private func getCurrentSessionId() -> String {
        if let sessionId = UserDefaults.standard.string(forKey: "current_session_id") {
            return sessionId
        } else {
            let sessionId = UUID().uuidString
            UserDefaults.standard.set(sessionId, forKey: "current_session_id")
            return sessionId
        }
    }
    
    private func getCurrentUserId() -> String {
        // This would get the current user ID from AuthenticationManager
        return "user_\(UUID().uuidString)"
    }
    
    private func getFeatureUsageCount(_ feature: Feature) -> Int {
        return analyticsData.filter { 
            $0.eventType == .featureUsage && 
            $0.properties["feature"] as? String == feature.rawValue 
        }.count
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024 // MB
        }
        
        return 0
    }
    
    private func getBatteryLevel() -> Double {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return Double(UIDevice.current.batteryLevel * 100)
    }
    
    private func getNetworkStatus() -> String {
        // This would use Network framework to get actual network status
        return "connected"
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model) \(device.systemName) \(device.systemVersion)"
    }
    
    private func saveAnalyticsEvent(_ event: AnalyticsEvent) {
        let context = persistenceController.container.viewContext
        
        let entity = AnalyticsEventEntity(context: context)
        entity.id = event.id
        entity.eventType = event.eventType.rawValue
        entity.properties = try? JSONSerialization.data(withJSONObject: event.properties)
        entity.timestamp = event.timestamp
        entity.sessionId = event.sessionId
        entity.createdAt = Date()
        
        try? context.save()
    }
}

// MARK: - Supporting Types
enum AnalyticsEventType: String, CaseIterable {
    case appLaunch = "app_launch"
    case appBackground = "app_background"
    case appForeground = "app_foreground"
    case userAction = "user_action"
    case performanceMetric = "performance_metric"
    case error = "error"
    case featureUsage = "feature_usage"
    case networkStatus = "network_status"
    case permissionGranted = "permission_granted"
    case permissionDenied = "permission_denied"
    case challengeCompleted = "challenge_completed"
    case challengeFailed = "challenge_failed"
    case hangoutDetected = "hangout_detected"
    case pointsEarned = "points_earned"
    case leaderboardUpdate = "leaderboard_update"
}

enum UserAction: String, CaseIterable {
    case signIn = "sign_in"
    case signOut = "sign_out"
    case createCircle = "create_circle"
    case joinCircle = "join_circle"
    case createChallenge = "create_challenge"
    case acceptChallenge = "accept_challenge"
    case completeChallenge = "complete_challenge"
    case skipChallenge = "skip_challenge"
    case viewLeaderboard = "view_leaderboard"
    case viewProfile = "view_profile"
    case updateSettings = "update_settings"
    case exportData = "export_data"
    case deleteData = "delete_data"
}

enum PerformanceMetric: String, CaseIterable {
    case memoryUsage = "memory_usage"
    case batteryLevel = "battery_level"
    case networkLatency = "network_latency"
    case appLaunchTime = "app_launch_time"
    case screenLoadTime = "screen_load_time"
    case dataSyncTime = "data_sync_time"
    
    var unit: String {
        switch self {
        case .memoryUsage: return "MB"
        case .batteryLevel: return "%"
        case .networkLatency: return "ms"
        case .appLaunchTime: return "s"
        case .screenLoadTime: return "s"
        case .dataSyncTime: return "s"
        }
    }
}

enum Feature: String, CaseIterable {
    case locationTracking = "location_tracking"
    case motionTracking = "motion_tracking"
    case cameraProof = "camera_proof"
    case healthKit = "healthkit"
    case screenTime = "screentime"
    case notifications = "notifications"
    case cloudKit = "cloudkit"
    case backgroundTasks = "background_tasks"
    case hapticFeedback = "haptic_feedback"
    case darkMode = "dark_mode"
    case accessibility = "accessibility"
    case dataExport = "data_export"
    case privacyControls = "privacy_controls"
}

struct AnalyticsEvent {
    let id: UUID
    let eventType: AnalyticsEventType
    let properties: [String: Any]
    let timestamp: Date
    let sessionId: String
}

struct AnalyticsExportData: Codable {
    let events: [AnalyticsEvent]
    let exportDate: Date
    let appVersion: String
    let deviceInfo: String
}

// MARK: - Core Data Extensions
extension AnalyticsEventEntity {
    static func fetchRequest() -> NSFetchRequest<AnalyticsEventEntity> {
        return NSFetchRequest<AnalyticsEventEntity>(entityName: "AnalyticsEventEntity")
    }
}
