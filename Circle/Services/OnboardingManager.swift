//
//  OnboardingManager.swift
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
import Combine

@MainActor
class OnboardingManager: NSObject, ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var isOnboardingComplete = false
    @Published var currentStep = 0
    @Published var permissionsGranted: Set<PermissionType> = []
    @Published var permissionsDenied: Set<PermissionType> = []
    @Published var isRequestingPermission = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    // Permission request flow
    private let permissionFlow: [PermissionType] = [
        .locationWhenInUse,
        .motion,
        .notifications,
        .camera,
        .locationAlways,
        .health
    ]
    
    override init() {
        super.init()
        locationManager.delegate = self
        checkOnboardingStatus()
        setupNotificationObservers()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Onboarding Flow
    func startOnboarding() {
        currentStep = 0
        isOnboardingComplete = false
        permissionsGranted.removeAll()
        permissionsDenied.removeAll()
        errorMessage = nil
        
        // Log onboarding start
        AnalyticsManager.shared.logUserAction(.signIn)
    }
    
    func nextStep() {
        currentStep += 1
        
        // Check if we've completed all steps
        if currentStep >= permissionFlow.count {
            completeOnboarding()
        }
    }
    
    func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboarding_complete")
        
        // Log onboarding completion
        AnalyticsManager.shared.logUserAction(.signIn)
        
        // Log permission analytics
        for permission in permissionsGranted {
            AnalyticsManager.shared.logEvent(.permissionGranted, properties: [
                "permission": permission.rawValue,
                "step": currentStep
            ])
        }
        
        for permission in permissionsDenied {
            AnalyticsManager.shared.logEvent(.permissionDenied, properties: [
                "permission": permission.rawValue,
                "step": currentStep
            ])
        }
    }
    
    private func checkOnboardingStatus() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_complete")
        
        if !isOnboardingComplete {
            // Check existing permissions
            checkExistingPermissions()
        }
    }
    
    private func checkExistingPermissions() {
        // Check location permission
        let locationStatus = locationManager.authorizationStatus
        if locationStatus == .authorizedWhenInUse {
            permissionsGranted.insert(.locationWhenInUse)
        } else if locationStatus == .authorizedAlways {
            permissionsGranted.insert(.locationWhenInUse)
            permissionsGranted.insert(.locationAlways)
        }
        
        // Check motion permission
        if CMPedometer.isStepCountingAvailable() {
            permissionsGranted.insert(.motion)
        }
        
        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    self.permissionsGranted.insert(.notifications)
                }
            }
        }
        
        // Check camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .authorized {
            permissionsGranted.insert(.camera)
        }
        
        // Check health permission
        if HKHealthStore.isHealthDataAvailable() {
            let healthTypes: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            ]
            
            for healthType in healthTypes {
                let status = healthStore.authorizationStatus(for: healthType)
                if status == .sharingAuthorized {
                    permissionsGranted.insert(.health)
                    break
                }
            }
        }
    }
    
    // MARK: - Permission Requests
    func requestCurrentPermission() {
        guard currentStep < permissionFlow.count else { return }
        
        let permission = permissionFlow[currentStep]
        requestPermission(permission)
    }
    
    func requestPermission(_ permission: PermissionType) {
        guard !isRequestingPermission else { return }
        
        isRequestingPermission = true
        errorMessage = nil
        
        switch permission {
        case .locationWhenInUse:
            requestLocationPermission()
        case .locationAlways:
            requestAlwaysLocationPermission()
        case .motion:
            requestMotionPermission()
        case .notifications:
            requestNotificationPermission()
        case .camera:
            requestCameraPermission()
        case .health:
            requestHealthPermission()
        }
    }
    
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func requestAlwaysLocationPermission() {
        // Only request Always if When-In-Use is already granted
        guard permissionsGranted.contains(.locationWhenInUse) else {
            permissionsDenied.insert(.locationAlways)
            isRequestingPermission = false
            nextStep()
            return
        }
        
        locationManager.requestAlwaysAuthorization()
    }
    
    private func requestMotionPermission() {
        // Motion permission is automatic on iOS
        if CMPedometer.isStepCountingAvailable() {
            permissionsGranted.insert(.motion)
            isRequestingPermission = false
            nextStep()
        } else {
            permissionsDenied.insert(.motion)
            isRequestingPermission = false
            nextStep()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.permissionsGranted.insert(.notifications)
                } else {
                    self.permissionsDenied.insert(.notifications)
                }
                
                if let error = error {
                    self.errorMessage = "Notification permission error: \(error.localizedDescription)"
                }
                
                self.isRequestingPermission = false
                self.nextStep()
            }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.permissionsGranted.insert(.camera)
                } else {
                    self.permissionsDenied.insert(.camera)
                }
                
                self.isRequestingPermission = false
                self.nextStep()
            }
        }
    }
    
    private func requestHealthPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            permissionsDenied.insert(.health)
            isRequestingPermission = false
            nextStep()
            return
        }
        
        let healthTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: healthTypes) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.permissionsGranted.insert(.health)
                } else {
                    self.permissionsDenied.insert(.health)
                }
                
                if let error = error {
                    self.errorMessage = "Health permission error: \(error.localizedDescription)"
                }
                
                self.isRequestingPermission = false
                self.nextStep()
            }
        }
    }
    
    // MARK: - Degraded Mode
    func getDegradedModeFeatures() -> [DegradedModeFeature] {
        var features: [DegradedModeFeature] = []
        
        if permissionsDenied.contains(.locationWhenInUse) {
            features.append(DegradedModeFeature(
                permission: .locationWhenInUse,
                alternative: "Manual location entry for challenges",
                impact: "You'll need to manually confirm your location for location-based challenges"
            ))
        }
        
        if permissionsDenied.contains(.locationAlways) {
            features.append(DegradedModeFeature(
                permission: .locationAlways,
                alternative: "Foreground-only hangout detection",
                impact: "Hangouts will only be detected when the app is open"
            ))
        }
        
        if permissionsDenied.contains(.motion) {
            features.append(DegradedModeFeature(
                permission: .motion,
                alternative: "Manual step entry",
                impact: "You'll need to manually enter your step count for fitness challenges"
            ))
        }
        
        if permissionsDenied.contains(.notifications) {
            features.append(DegradedModeFeature(
                permission: .notifications,
                alternative: "In-app notifications only",
                impact: "You'll only see notifications when the app is open"
            ))
        }
        
        if permissionsDenied.contains(.camera) {
            features.append(DegradedModeFeature(
                permission: .camera,
                alternative: "Text-based proofs",
                impact: "You'll use text descriptions instead of camera proofs"
            ))
        }
        
        if permissionsDenied.contains(.health) {
            features.append(DegradedModeFeature(
                permission: .health,
                alternative: "Manual health data entry",
                impact: "You'll need to manually enter health data for sleep challenges"
            ))
        }
        
        return features
    }
    
    // MARK: - Permission Recovery
    func canRecoverPermission(_ permission: PermissionType) -> Bool {
        switch permission {
        case .locationWhenInUse, .locationAlways:
            return locationManager.authorizationStatus == .denied
        case .notifications:
            return true // Can always request again
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .denied
        case .motion, .health:
            return false // These can't be recovered
        }
    }
    
    func openPermissionSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkExistingPermissions()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Analytics
    func getPermissionAnalytics() -> PermissionAnalytics {
        return PermissionAnalytics(
            totalPermissions: permissionFlow.count,
            grantedPermissions: permissionsGranted.count,
            deniedPermissions: permissionsDenied.count,
            completionRate: Double(permissionsGranted.count) / Double(permissionFlow.count),
            degradedModeFeatures: getDegradedModeFeatures().count
        )
    }
}

// MARK: - CLLocationManagerDelegate
extension OnboardingManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            switch status {
            case .authorizedWhenInUse:
                self.permissionsGranted.insert(.locationWhenInUse)
                self.permissionsDenied.remove(.locationWhenInUse)
            case .authorizedAlways:
                self.permissionsGranted.insert(.locationAlways)
                self.permissionsDenied.remove(.locationAlways)
            case .denied, .restricted:
                if self.currentStep < self.permissionFlow.count {
                    let currentPermission = self.permissionFlow[self.currentStep]
                    if currentPermission == .locationWhenInUse || currentPermission == .locationAlways {
                        self.permissionsDenied.insert(currentPermission)
                    }
                }
            case .notDetermined:
                break
            @unknown default:
                break
            }
            
            self.isRequestingPermission = false
            self.nextStep()
        }
    }
}

// MARK: - Supporting Types
enum PermissionType: String, CaseIterable {
    case locationWhenInUse = "location_when_in_use"
    case locationAlways = "location_always"
    case motion = "motion"
    case notifications = "notifications"
    case camera = "camera"
    case health = "health"
    
    var title: String {
        switch self {
        case .locationWhenInUse:
            return "Location Access"
        case .locationAlways:
            return "Background Location"
        case .motion:
            return "Motion & Fitness"
        case .notifications:
            return "Notifications"
        case .camera:
            return "Camera Access"
        case .health:
            return "Health Data"
        }
    }
    
    var description: String {
        switch self {
        case .locationWhenInUse:
            return "Circle uses your location to verify that you visited your saved gym location for at least 20 minutes. This helps ensure challenge authenticity."
        case .locationAlways:
            return "Circle needs your location to detect 5-minute hangouts with friends you've added and verify gym visits. Location data is processed on your device and never uploaded to servers."
        case .motion:
            return "Circle tracks your steps and workouts to verify runs and walks you choose to track. This data helps verify fitness challenges automatically."
        case .notifications:
            return "Circle sends reminders for active challenges and hangout notifications. This helps you stay on track with your goals."
        case .camera:
            return "Circle uses your camera for live proof check-ins and forfeit challenges. All photos are processed on your device and immediately deleted - no images are stored or uploaded."
        case .health:
            return "Circle can verify sleep-before-11-pm goals you explicitly enable using your Health app data. This is optional and only used for sleep-based challenges."
        }
    }
    
    var icon: String {
        switch self {
        case .locationWhenInUse, .locationAlways:
            return "location.fill"
        case .motion:
            return "figure.walk"
        case .notifications:
            return "bell.fill"
        case .camera:
            return "camera.fill"
        case .health:
            return "heart.fill"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .locationWhenInUse, .motion, .notifications:
            return true
        case .locationAlways, .camera, .health:
            return false
        }
    }
}

struct DegradedModeFeature {
    let permission: PermissionType
    let alternative: String
    let impact: String
}

struct PermissionAnalytics {
    let totalPermissions: Int
    let grantedPermissions: Int
    let deniedPermissions: Int
    let completionRate: Double
    let degradedModeFeatures: Int
}
