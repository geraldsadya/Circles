//
//  DegradedModeManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import CoreMotion
import AVFoundation
import HealthKit
import CoreData
import Combine

@MainActor
class DegradedModeManager: ObservableObject {
    static let shared = DegradedModeManager()
    
    @Published var isDegradedMode = false
    @Published var degradedFeatures: [DegradedFeature] = []
    @Published var availableFeatures: [AppFeature] = []
    @Published var degradedModeReason: DegradedModeReason?
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let locationManager = LocationManager.shared
    private let motionManager = CMMotionManager()
    private let cameraManager = CameraManager.shared
    
    // Permission states
    private var permissionStates: [PermissionType: PermissionState] = [:]
    private var featureCapabilities: [AppFeature: FeatureCapability] = [:]
    
    // Degraded mode configuration
    private let degradedModeThresholds = DegradedModeThresholds()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupPermissionMonitoring()
        setupFeatureCapabilities()
        checkDegradedMode()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupPermissionMonitoring() {
        // Monitor location permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationPermissionChanged),
            name: .locationPermissionChanged,
            object: nil
        )
        
        // Monitor motion permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMotionPermissionChanged),
            name: .motionPermissionChanged,
            object: nil
        )
        
        // Monitor camera permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCameraPermissionChanged),
            name: .cameraPermissionChanged,
            object: nil
        )
        
        // Monitor health permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHealthPermissionChanged),
            name: .healthPermissionChanged,
            object: nil
        )
    }
    
    private func setupFeatureCapabilities() {
        // Initialize feature capabilities
        featureCapabilities = [
            .locationTracking: FeatureCapability(
                feature: .locationTracking,
                requiredPermissions: [.locationAlways],
                degradedAlternatives: [.manualLocationEntry, .approximateLocation],
                isEssential: true
            ),
            .hangoutDetection: FeatureCapability(
                feature: .hangoutDetection,
                requiredPermissions: [.locationAlways],
                degradedAlternatives: [.manualHangoutEntry, .checkInBased],
                isEssential: false
            ),
            .motionTracking: FeatureCapability(
                feature: .motionTracking,
                requiredPermissions: [.motion],
                degradedAlternatives: [.manualStepEntry, .activityLogging],
                isEssential: false
            ),
            .cameraProofs: FeatureCapability(
                feature: .cameraProofs,
                requiredPermissions: [.camera],
                degradedAlternatives: [.textProofs, .voiceProofs],
                isEssential: false
            ),
            .healthTracking: FeatureCapability(
                feature: .healthTracking,
                requiredPermissions: [.health],
                degradedAlternatives: [.manualHealthEntry, .estimatedHealth],
                isEssential: false
            ),
            .screenTimeTracking: FeatureCapability(
                feature: .screenTimeTracking,
                requiredPermissions: [.screenTime],
                degradedAlternatives: [.manualScreenTimeEntry, .appUsageTracking],
                isEssential: false
            )
        ]
    }
    
    // MARK: - Permission Monitoring
    @objc private func handleLocationPermissionChanged(_ notification: Notification) {
        Task {
            await updateLocationPermissionState()
        }
    }
    
    @objc private func handleMotionPermissionChanged(_ notification: Notification) {
        Task {
            await updateMotionPermissionState()
        }
    }
    
    @objc private func handleCameraPermissionChanged(_ notification: Notification) {
        Task {
            await updateCameraPermissionState()
        }
    }
    
    @objc private func handleHealthPermissionChanged(_ notification: Notification) {
        Task {
            await updateHealthPermissionState()
        }
    }
    
    // MARK: - Permission State Updates
    private func updateLocationPermissionState() async {
        let status = CLLocationManager.authorizationStatus()
        
        let state: PermissionState
        switch status {
        case .authorizedWhenInUse:
            state = .partial
        case .authorizedAlways:
            state = .granted
        case .denied, .restricted:
            state = .denied
        case .notDetermined:
            state = .notDetermined
        @unknown default:
            state = .denied
        }
        
        permissionStates[.locationAlways] = state
        permissionStates[.locationWhenInUse] = state
        
        await checkDegradedMode()
    }
    
    private func updateMotionPermissionState() async {
        // Motion permission is always available on iOS
        permissionStates[.motion] = .granted
        await checkDegradedMode()
    }
    
    private func updateCameraPermissionState() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        let state: PermissionState
        switch status {
        case .authorized:
            state = .granted
        case .denied, .restricted:
            state = .denied
        case .notDetermined:
            state = .notDetermined
        @unknown default:
            state = .denied
        }
        
        permissionStates[.camera] = state
        await checkDegradedMode()
    }
    
    private func updateHealthPermissionState() async {
        // Health permission requires specific authorization
        permissionStates[.health] = .notDetermined
        await checkDegradedMode()
    }
    
    // MARK: - Degraded Mode Detection
    private func checkDegradedMode() async {
        let previousDegradedMode = isDegradedMode
        
        // Check if any essential features are degraded
        let essentialFeatures = featureCapabilities.values.filter { $0.isEssential }
        let degradedEssentialFeatures = essentialFeatures.filter { isFeatureDegraded($0.feature) }
        
        isDegradedMode = !degradedEssentialFeatures.isEmpty
        
        // Update degraded features
        await updateDegradedFeatures()
        
        // Update available features
        await updateAvailableFeatures()
        
        // Determine degraded mode reason
        degradedModeReason = determineDegradedModeReason()
        
        // Notify if degraded mode status changed
        if previousDegradedMode != isDegradedMode {
            NotificationCenter.default.post(
                name: .degradedModeChanged,
                object: nil,
                userInfo: [
                    "isDegraded": isDegradedMode,
                    "reason": degradedModeReason?.rawValue ?? ""
                ]
            )
        }
    }
    
    private func isFeatureDegraded(_ feature: AppFeature) -> Bool {
        guard let capability = featureCapabilities[feature] else { return false }
        
        // Check if all required permissions are granted
        for permission in capability.requiredPermissions {
            if permissionStates[permission] != .granted {
                return true
            }
        }
        
        return false
    }
    
    private func updateDegradedFeatures() async {
        degradedFeatures = featureCapabilities.compactMap { feature, capability in
            guard isFeatureDegraded(feature) else { return nil }
            
            return DegradedFeature(
                feature: feature,
                capability: capability,
                degradedAlternatives: capability.degradedAlternatives,
                isEssential: capability.isEssential
            )
        }
    }
    
    private func updateAvailableFeatures() async {
        availableFeatures = featureCapabilities.compactMap { feature, capability in
            guard !isFeatureDegraded(feature) else { return nil }
            return feature
        }
    }
    
    private func determineDegradedModeReason() -> DegradedModeReason? {
        if degradedFeatures.contains(where: { $0.isEssential }) {
            return .essentialPermissionDenied
        } else if degradedFeatures.count > 2 {
            return .multiplePermissionsDenied
        } else if degradedFeatures.count > 0 {
            return .optionalPermissionsDenied
        }
        
        return nil
    }
    
    // MARK: - Degraded Mode Alternatives
    func getDegradedAlternative(for feature: AppFeature) -> DegradedAlternative? {
        guard let degradedFeature = degradedFeatures.first(where: { $0.feature == feature }) else {
            return nil
        }
        
        // Return the first available alternative
        return degradedFeature.degradedAlternatives.first
    }
    
    func enableDegradedAlternative(_ alternative: DegradedAlternative, for feature: AppFeature) async {
        switch alternative {
        case .manualLocationEntry:
            await enableManualLocationEntry()
        case .approximateLocation:
            await enableApproximateLocation()
        case .manualHangoutEntry:
            await enableManualHangoutEntry()
        case .checkInBased:
            await enableCheckInBasedHangouts()
        case .manualStepEntry:
            await enableManualStepEntry()
        case .activityLogging:
            await enableActivityLogging()
        case .textProofs:
            await enableTextProofs()
        case .voiceProofs:
            await enableVoiceProofs()
        case .manualHealthEntry:
            await enableManualHealthEntry()
        case .estimatedHealth:
            await enableEstimatedHealth()
        case .manualScreenTimeEntry:
            await enableManualScreenTimeEntry()
        case .appUsageTracking:
            await enableAppUsageTracking()
        }
    }
    
    // MARK: - Alternative Implementations
    private func enableManualLocationEntry() async {
        // Enable manual location entry for challenges
        print("Manual location entry enabled")
    }
    
    private func enableApproximateLocation() async {
        // Use approximate location instead of precise
        await locationManager.setLocationAccuracy(.hundredMeters)
        print("Approximate location enabled")
    }
    
    private func enableManualHangoutEntry() async {
        // Enable manual hangout entry
        print("Manual hangout entry enabled")
    }
    
    private func enableCheckInBasedHangouts() async {
        // Enable check-in based hangout detection
        print("Check-in based hangouts enabled")
    }
    
    private func enableManualStepEntry() async {
        // Enable manual step entry
        print("Manual step entry enabled")
    }
    
    private func enableActivityLogging() async {
        // Enable basic activity logging
        print("Activity logging enabled")
    }
    
    private func enableTextProofs() async {
        // Enable text-based proofs
        print("Text proofs enabled")
    }
    
    private func enableVoiceProofs() async {
        // Enable voice-based proofs
        print("Voice proofs enabled")
    }
    
    private func enableManualHealthEntry() async {
        // Enable manual health data entry
        print("Manual health entry enabled")
    }
    
    private func enableEstimatedHealth() async {
        // Enable estimated health data
        print("Estimated health enabled")
    }
    
    private func enableManualScreenTimeEntry() async {
        // Enable manual screen time entry
        print("Manual screen time entry enabled")
    }
    
    private func enableAppUsageTracking() async {
        // Enable basic app usage tracking
        print("App usage tracking enabled")
    }
    
    // MARK: - Degraded Mode UI
    func getDegradedModeMessage() -> String {
        guard let reason = degradedModeReason else { return "" }
        
        switch reason {
        case .essentialPermissionDenied:
            return "Some features are limited due to denied permissions. Core functionality is still available."
        case .multiplePermissionsDenied:
            return "Several features are limited due to denied permissions. You can still use basic features."
        case .optionalPermissionsDenied:
            return "Some optional features are limited. Core functionality remains fully available."
        }
    }
    
    func getDegradedModeActions() -> [DegradedModeAction] {
        var actions: [DegradedModeAction] = []
        
        for degradedFeature in degradedFeatures {
            for alternative in degradedFeature.degradedAlternatives {
                actions.append(DegradedModeAction(
                    feature: degradedFeature.feature,
                    alternative: alternative,
                    title: alternative.displayName,
                    description: alternative.description
                ))
            }
        }
        
        return actions
    }
    
    // MARK: - Permission Recovery
    func requestPermissionRecovery(for feature: AppFeature) async {
        guard let degradedFeature = degradedFeatures.first(where: { $0.feature == feature }) else {
            return
        }
        
        // Request permissions for the feature
        for permission in degradedFeature.capability.requiredPermissions {
            await requestPermission(permission)
        }
        
        // Recheck degraded mode
        await checkDegradedMode()
    }
    
    private func requestPermission(_ permission: PermissionType) async {
        switch permission {
        case .locationAlways, .locationWhenInUse:
            await locationManager.requestLocationPermission()
        case .camera:
            await cameraManager.requestCameraPermission()
        case .motion:
            // Motion permission is always available
            break
        case .health:
            // Health permission requires specific implementation
            break
        case .screenTime:
            // Screen Time permission requires specific implementation
            break
        }
    }
    
    // MARK: - Analytics
    func getDegradedModeStats() -> DegradedModeStats {
        return DegradedModeStats(
            isDegradedMode: isDegradedMode,
            degradedFeaturesCount: degradedFeatures.count,
            availableFeaturesCount: availableFeatures.count,
            degradedModeReason: degradedModeReason,
            degradedFeatures: degradedFeatures.map { $0.feature },
            availableFeatures: availableFeatures
        )
    }
    
    // MARK: - Testing
    func simulateDegradedMode(for features: [AppFeature]) {
        // Simulate degraded mode for testing
        for feature in features {
            if let capability = featureCapabilities[feature] {
                for permission in capability.requiredPermissions {
                    permissionStates[permission] = .denied
                }
            }
        }
        
        Task {
            await checkDegradedMode()
        }
    }
    
    func resetDegradedMode() {
        // Reset all permission states
        permissionStates.removeAll()
        
        Task {
            await checkDegradedMode()
        }
    }
}

// MARK: - Supporting Types
enum PermissionType: String, CaseIterable {
    case locationAlways = "location_always"
    case locationWhenInUse = "location_when_in_use"
    case camera = "camera"
    case motion = "motion"
    case health = "health"
    case screenTime = "screen_time"
}

enum PermissionState: String, CaseIterable {
    case granted = "granted"
    case partial = "partial"
    case denied = "denied"
    case notDetermined = "not_determined"
}

enum AppFeature: String, CaseIterable {
    case locationTracking = "location_tracking"
    case hangoutDetection = "hangout_detection"
    case motionTracking = "motion_tracking"
    case cameraProofs = "camera_proofs"
    case healthTracking = "health_tracking"
    case screenTimeTracking = "screen_time_tracking"
    
    var displayName: String {
        switch self {
        case .locationTracking: return "Location Tracking"
        case .hangoutDetection: return "Hangout Detection"
        case .motionTracking: return "Motion Tracking"
        case .cameraProofs: return "Camera Proofs"
        case .healthTracking: return "Health Tracking"
        case .screenTimeTracking: return "Screen Time Tracking"
        }
    }
}

enum DegradedAlternative: String, CaseIterable {
    case manualLocationEntry = "manual_location_entry"
    case approximateLocation = "approximate_location"
    case manualHangoutEntry = "manual_hangout_entry"
    case checkInBased = "check_in_based"
    case manualStepEntry = "manual_step_entry"
    case activityLogging = "activity_logging"
    case textProofs = "text_proofs"
    case voiceProofs = "voice_proofs"
    case manualHealthEntry = "manual_health_entry"
    case estimatedHealth = "estimated_health"
    case manualScreenTimeEntry = "manual_screen_time_entry"
    case appUsageTracking = "app_usage_tracking"
    
    var displayName: String {
        switch self {
        case .manualLocationEntry: return "Manual Location Entry"
        case .approximateLocation: return "Approximate Location"
        case .manualHangoutEntry: return "Manual Hangout Entry"
        case .checkInBased: return "Check-in Based"
        case .manualStepEntry: return "Manual Step Entry"
        case .activityLogging: return "Activity Logging"
        case .textProofs: return "Text Proofs"
        case .voiceProofs: return "Voice Proofs"
        case .manualHealthEntry: return "Manual Health Entry"
        case .estimatedHealth: return "Estimated Health"
        case .manualScreenTimeEntry: return "Manual Screen Time Entry"
        case .appUsageTracking: return "App Usage Tracking"
        }
    }
    
    var description: String {
        switch self {
        case .manualLocationEntry: return "Enter locations manually for challenges"
        case .approximateLocation: return "Use approximate location instead of precise"
        case .manualHangoutEntry: return "Log hangouts manually"
        case .checkInBased: return "Use check-ins to detect hangouts"
        case .manualStepEntry: return "Enter step counts manually"
        case .activityLogging: return "Log activities manually"
        case .textProofs: return "Use text descriptions as proofs"
        case .voiceProofs: return "Use voice recordings as proofs"
        case .manualHealthEntry: return "Enter health data manually"
        case .estimatedHealth: return "Use estimated health data"
        case .manualScreenTimeEntry: return "Enter screen time manually"
        case .appUsageTracking: return "Track app usage manually"
        }
    }
}

enum DegradedModeReason: String, CaseIterable {
    case essentialPermissionDenied = "essential_permission_denied"
    case multiplePermissionsDenied = "multiple_permissions_denied"
    case optionalPermissionsDenied = "optional_permissions_denied"
}

struct FeatureCapability {
    let feature: AppFeature
    let requiredPermissions: [PermissionType]
    let degradedAlternatives: [DegradedAlternative]
    let isEssential: Bool
}

struct DegradedFeature {
    let feature: AppFeature
    let capability: FeatureCapability
    let degradedAlternatives: [DegradedAlternative]
    let isEssential: Bool
}

struct DegradedModeAction {
    let feature: AppFeature
    let alternative: DegradedAlternative
    let title: String
    let description: String
}

struct DegradedModeStats {
    let isDegradedMode: Bool
    let degradedFeaturesCount: Int
    let availableFeaturesCount: Int
    let degradedModeReason: DegradedModeReason?
    let degradedFeatures: [AppFeature]
    let availableFeatures: [AppFeature]
}

struct DegradedModeThresholds {
    let essentialFeatureThreshold = 1
    let multiplePermissionThreshold = 2
    let optionalPermissionThreshold = 0
}

// MARK: - Notifications
extension Notification.Name {
    static let locationPermissionChanged = Notification.Name("locationPermissionChanged")
    static let motionPermissionChanged = Notification.Name("motionPermissionChanged")
    static let cameraPermissionChanged = Notification.Name("cameraPermissionChanged")
    static let healthPermissionChanged = Notification.Name("healthPermissionChanged")
    static let degradedModeChanged = Notification.Name("degradedModeChanged")
}
