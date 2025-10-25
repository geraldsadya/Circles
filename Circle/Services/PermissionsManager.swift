//
//  PermissionsManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import CoreMotion
import UserNotifications
import AVFoundation
import HealthKit
import CoreData
import Combine

@MainActor
class PermissionsManager: NSObject, ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    @Published var consentLogs: [ConsentLog] = []
    @Published var isMonitoringPermissions = false
    
    private let persistenceController = PersistenceController.shared
    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    // Permission monitoring
    private var permissionTimers: [PermissionType: Timer] = [:]
    private var lastPermissionCheck: [PermissionType: Date] = [:]
    
    override init() {
        super.init()
        locationManager.delegate = self
        setupPermissionMonitoring()
        loadConsentLogs()
    }
    
    deinit {
        cancellables.removeAll()
        stopAllPermissionMonitoring()
    }
    
    // MARK: - Permission Monitoring
    private func setupPermissionMonitoring() {
        // Monitor app lifecycle for permission changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkAllPermissions()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pausePermissionMonitoring()
            }
            .store(in: &cancellables)
        
        // Start monitoring
        startPermissionMonitoring()
    }
    
    func startPermissionMonitoring() {
        guard !isMonitoringPermissions else { return }
        
        isMonitoringPermissions = true
        
        // Check all permissions immediately
        checkAllPermissions()
        
        // Set up periodic checks
        for permission in PermissionType.allCases {
            startMonitoringPermission(permission)
        }
    }
    
    func stopPermissionMonitoring() {
        isMonitoringPermissions = false
        stopAllPermissionMonitoring()
    }
    
    private func startMonitoringPermission(_ permission: PermissionType) {
        // Check every 5 minutes
        let timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkPermission(permission)
        }
        
        permissionTimers[permission] = timer
    }
    
    private func stopAllPermissionMonitoring() {
        for timer in permissionTimers.values {
            timer.invalidate()
        }
        permissionTimers.removeAll()
    }
    
    private func pausePermissionMonitoring() {
        // Pause timers but keep monitoring active
        for timer in permissionTimers.values {
            timer.invalidate()
        }
        permissionTimers.removeAll()
    }
    
    // MARK: - Permission Checking
    func checkAllPermissions() {
        for permission in PermissionType.allCases {
            checkPermission(permission)
        }
    }
    
    func checkPermission(_ permission: PermissionType) {
        let currentStatus = getPermissionStatus(permission)
        let previousStatus = permissionStatuses[permission]
        
        // Update status
        permissionStatuses[permission] = currentStatus
        lastPermissionCheck[permission] = Date()
        
        // Log consent change if status changed
        if let previous = previousStatus, previous != currentStatus {
            logConsentChange(permission: permission, from: previous, to: currentStatus)
        }
        
        // Log initial permission status
        if previousStatus == nil {
            logConsentChange(permission: permission, from: nil, to: currentStatus)
        }
    }
    
    private func getPermissionStatus(_ permission: PermissionType) -> PermissionStatus {
        switch permission {
        case .locationWhenInUse, .locationAlways:
            return getLocationPermissionStatus(permission)
        case .motion:
            return getMotionPermissionStatus()
        case .notifications:
            return getNotificationPermissionStatus()
        case .camera:
            return getCameraPermissionStatus()
        case .health:
            return getHealthPermissionStatus()
        }
    }
    
    private func getLocationPermissionStatus(_ permission: PermissionType) -> PermissionStatus {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse:
            return permission == .locationWhenInUse ? .granted : .denied
        case .authorizedAlways:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    private func getMotionPermissionStatus() -> PermissionStatus {
        if CMPedometer.isStepCountingAvailable() {
            return .granted
        } else {
            return .notAvailable
        }
    }
    
    private func getNotificationPermissionStatus() -> PermissionStatus {
        // This is asynchronous, so we'll return a placeholder
        // The actual status will be updated when we get the callback
        return .notDetermined
    }
    
    private func getCameraPermissionStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    private func getHealthPermissionStatus() -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .notAvailable
        }
        
        let healthTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        for healthType in healthTypes {
            let status = healthStore.authorizationStatus(for: healthType)
            if status == .sharingAuthorized {
                return .granted
            }
        }
        
        return .notDetermined
    }
    
    // MARK: - Consent Logging
    private func logConsentChange(permission: PermissionType, from: PermissionStatus?, to: PermissionStatus) {
        let consentLog = ConsentLog(
            id: UUID(),
            permissionType: permission.rawValue,
            previousStatus: from?.rawValue,
            currentStatus: to.rawValue,
            timestamp: Date(),
            reason: getConsentReason(permission: permission, status: to),
            userAction: from != nil ? "permission_changed" : "permission_checked",
            appVersion: getAppVersion(),
            deviceInfo: getDeviceInfo()
        )
        
        consentLogs.append(consentLog)
        
        // Save to Core Data
        saveConsentLog(consentLog)
        
        // Log analytics
        AnalyticsManager.shared.logEvent(.permissionGranted, properties: [
            "permission": permission.rawValue,
            "status": to.rawValue,
            "previous_status": from?.rawValue ?? "unknown"
        ])
    }
    
    private func getConsentReason(permission: PermissionType, status: PermissionStatus) -> String {
        switch status {
        case .granted:
            return "User granted \(permission.title) permission"
        case .denied:
            return "User denied \(permission.title) permission"
        case .restricted:
            return "\(permission.title) permission is restricted by device policy"
        case .notDetermined:
            return "\(permission.title) permission not yet requested"
        case .notAvailable:
            return "\(permission.title) permission not available on this device"
        }
    }
    
    // MARK: - Core Data Integration
    private func saveConsentLog(_ consentLog: ConsentLog) {
        let context = persistenceController.container.viewContext
        
        let entity = ConsentLogEntity(context: context)
        entity.id = consentLog.id
        entity.permissionType = consentLog.permissionType
        entity.previousStatus = consentLog.previousStatus
        entity.currentStatus = consentLog.currentStatus
        entity.timestamp = consentLog.timestamp
        entity.reason = consentLog.reason
        entity.userAction = consentLog.userAction
        entity.appVersion = consentLog.appVersion
        entity.deviceInfo = consentLog.deviceInfo
        entity.createdAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Error saving consent log: \(error)")
        }
    }
    
    private func loadConsentLogs() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<ConsentLogEntity> = ConsentLogEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ConsentLogEntity.timestamp, ascending: false)]
        request.fetchLimit = 100
        
        do {
            let entities = try context.fetch(request)
            consentLogs = entities.map { entity in
                ConsentLog(
                    id: entity.id ?? UUID(),
                    permissionType: entity.permissionType ?? "",
                    previousStatus: entity.previousStatus,
                    currentStatus: entity.currentStatus ?? "",
                    timestamp: entity.timestamp ?? Date(),
                    reason: entity.reason ?? "",
                    userAction: entity.userAction ?? "",
                    appVersion: entity.appVersion ?? "",
                    deviceInfo: entity.deviceInfo ?? ""
                )
            }
        } catch {
            print("Error loading consent logs: \(error)")
        }
    }
    
    // MARK: - Permission Analytics
    func getPermissionAnalytics() -> PermissionAnalytics {
        let totalPermissions = PermissionType.allCases.count
        let grantedPermissions = permissionStatuses.values.filter { $0 == .granted }.count
        let deniedPermissions = permissionStatuses.values.filter { $0 == .denied }.count
        let restrictedPermissions = permissionStatuses.values.filter { $0 == .restricted }.count
        let notDeterminedPermissions = permissionStatuses.values.filter { $0 == .notDetermined }.count
        let notAvailablePermissions = permissionStatuses.values.filter { $0 == .notAvailable }.count
        
        return PermissionAnalytics(
            totalPermissions: totalPermissions,
            grantedPermissions: grantedPermissions,
            deniedPermissions: deniedPermissions,
            restrictedPermissions: restrictedPermissions,
            notDeterminedPermissions: notDeterminedPermissions,
            notAvailablePermissions: notAvailablePermissions,
            completionRate: Double(grantedPermissions) / Double(totalPermissions),
            consentLogCount: consentLogs.count,
            lastPermissionCheck: lastPermissionCheck.values.max()
        )
    }
    
    // MARK: - Consent Log Management
    func exportConsentLogs() -> Data? {
        let exportData = ConsentLogExportData(
            logs: consentLogs,
            exportDate: Date(),
            appVersion: getAppVersion(),
            deviceInfo: getDeviceInfo()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    func clearConsentLogs() {
        consentLogs.removeAll()
        
        // Clear Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<ConsentLogEntity> = ConsentLogEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
        } catch {
            print("Error clearing consent logs: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model) \(device.systemName) \(device.systemVersion)"
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionsManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.checkPermission(.locationWhenInUse)
            self.checkPermission(.locationAlways)
        }
    }
}

// MARK: - Supporting Types
enum PermissionStatus: String, CaseIterable {
    case granted = "granted"
    case denied = "denied"
    case restricted = "restricted"
    case notDetermined = "not_determined"
    case notAvailable = "not_available"
    
    var displayName: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        case .notAvailable: return "Not Available"
        }
    }
    
    var isGranted: Bool {
        return self == .granted
    }
}

struct ConsentLog {
    let id: UUID
    let permissionType: String
    let previousStatus: String?
    let currentStatus: String
    let timestamp: Date
    let reason: String
    let userAction: String
    let appVersion: String
    let deviceInfo: String
}

struct ConsentLogExportData: Codable {
    let logs: [ConsentLog]
    let exportDate: Date
    let appVersion: String
    let deviceInfo: String
}

struct PermissionAnalytics {
    let totalPermissions: Int
    let grantedPermissions: Int
    let deniedPermissions: Int
    let restrictedPermissions: Int
    let notDeterminedPermissions: Int
    let notAvailablePermissions: Int
    let completionRate: Double
    let consentLogCount: Int
    let lastPermissionCheck: Date?
}

// MARK: - Core Data Extensions
extension ConsentLogEntity {
    static func fetchRequest() -> NSFetchRequest<ConsentLogEntity> {
        return NSFetchRequest<ConsentLogEntity>(entityName: "ConsentLogEntity")
    }
}
