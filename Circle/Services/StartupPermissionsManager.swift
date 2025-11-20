//
//  StartupPermissionsManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import HealthKit
import CoreLocation
import UserNotifications
import Contacts
import AVFoundation
import Combine

@MainActor
class StartupPermissionsManager: ObservableObject {
    static let shared = StartupPermissionsManager()
    
    @Published var permissionsStatus: [PermissionType: PermissionStatus] = [:]
    @Published var isShowingPermissionsFlow = false
    @Published var currentPermissionStep = 0
    
    private let healthKitManager = HealthKitManager.shared
    private let locationManager = LocationManager.shared
    private let notificationManager = PushNotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum PermissionType: String, CaseIterable {
        case healthKit = "Health App"
        case location = "Location"
        case notifications = "Notifications"
        case contacts = "Contacts"
        case camera = "Camera"
        case motion = "Motion & Fitness"
        
        var description: String {
            switch self {
            case .healthKit: return "Access your health data to track steps, sleep, and fitness goals"
            case .location: return "Find friends nearby and verify location-based challenges"
            case .notifications: return "Get reminders about challenges and hangout invitations"
            case .contacts: return "Find friends who use Circle and invite them to circles"
            case .camera: return "Take photos for challenges and photo stories"
            case .motion: return "Track your activity and verify motion-based challenges"
            }
        }
        
        var icon: String {
            switch self {
            case .healthKit: return "heart.fill"
            case .location: return "location.fill"
            case .notifications: return "bell.fill"
            case .contacts: return "person.2.fill"
            case .camera: return "camera.fill"
            case .motion: return "figure.walk"
            }
        }
    }
    
    enum PermissionStatus {
        case notRequested
        case denied
        case authorized
        case restricted
    }
    
    init() {
        checkAllPermissions()
        setupObservers()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Listen for app becoming active to refresh permission status
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkAllPermissions()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permission Checking
    func checkAllPermissions() {
        checkHealthKitPermission()
        checkLocationPermission()
        checkNotificationPermission()
        checkContactsPermission()
        checkCameraPermission()
        checkMotionPermission()
    }
    
    private func checkHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            permissionsStatus[.healthKit] = .restricted
            return
        }
        
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let status = HKHealthStore().authorizationStatus(for: stepType)
        
        switch status {
        case .notDetermined:
            permissionsStatus[.healthKit] = .notRequested
        case .sharingDenied:
            permissionsStatus[.healthKit] = .denied
        case .sharingAuthorized:
            permissionsStatus[.healthKit] = .authorized
        @unknown default:
            permissionsStatus[.healthKit] = .notRequested
        }
    }
    
    private func checkLocationPermission() {
        let status = CLLocationManager().authorizationStatus
        
        switch status {
        case .notDetermined:
            permissionsStatus[.location] = .notRequested
        case .denied, .restricted:
            permissionsStatus[.location] = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            permissionsStatus[.location] = .authorized
        @unknown default:
            permissionsStatus[.location] = .notRequested
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.permissionsStatus[.notifications] = .notRequested
                case .denied:
                    self.permissionsStatus[.notifications] = .denied
                case .authorized, .provisional:
                    self.permissionsStatus[.notifications] = .authorized
                case .ephemeral:
                    self.permissionsStatus[.notifications] = .authorized
                @unknown default:
                    self.permissionsStatus[.notifications] = .notRequested
                }
            }
        }
    }
    
    private func checkContactsPermission() {
        let status = CNContactStore().authorizationStatus(for: .contacts)
        
        switch status {
        case .notDetermined:
            permissionsStatus[.contacts] = .notRequested
        case .denied, .restricted:
            permissionsStatus[.contacts] = .denied
        case .authorized:
            permissionsStatus[.contacts] = .authorized
        @unknown default:
            permissionsStatus[.contacts] = .notRequested
        }
    }
    
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            permissionsStatus[.camera] = .notRequested
        case .denied, .restricted:
            permissionsStatus[.camera] = .denied
        case .authorized:
            permissionsStatus[.camera] = .authorized
        @unknown default:
            permissionsStatus[.camera] = .notRequested
        }
    }
    
    private func checkMotionPermission() {
        // Motion permission is always available on iOS
        permissionsStatus[.motion] = .authorized
    }
    
    // MARK: - Permission Requesting
    func requestPermission(_ type: PermissionType) async {
        switch type {
        case .healthKit:
            await healthKitManager.requestHealthKitAuthorization()
        case .location:
            await locationManager.requestLocationPermission()
        case .notifications:
            await notificationManager.requestNotificationPermission()
        case .contacts:
            await requestContactsPermission()
        case .camera:
            await requestCameraPermission()
        case .motion:
            // Motion permission is always available
            permissionsStatus[.motion] = .authorized
        }
        
        // Refresh status after requesting
        checkAllPermissions()
    }
    
    private func requestContactsPermission() async {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            DispatchQueue.main.async {
                self.permissionsStatus[.contacts] = granted ? .authorized : .denied
            }
        } catch {
            DispatchQueue.main.async {
                self.permissionsStatus[.contacts] = .denied
            }
        }
    }
    
    private func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        DispatchQueue.main.async {
            self.permissionsStatus[.camera] = granted ? .authorized : .denied
        }
    }
    
    // MARK: - Permission Flow
    func startPermissionsFlow() {
        isShowingPermissionsFlow = true
        currentPermissionStep = 0
    }
    
    func nextPermissionStep() {
        currentPermissionStep += 1
        if currentPermissionStep >= PermissionType.allCases.count {
            isShowingPermissionsFlow = false
        }
    }
    
    func skipPermissionsFlow() {
        isShowingPermissionsFlow = false
    }
    
    // MARK: - Helper Methods
    func getCurrentPermission() -> PermissionType? {
        let permissions = PermissionType.allCases
        guard currentPermissionStep < permissions.count else { return nil }
        return permissions[currentPermissionStep]
    }
    
    func getPermissionStatus(_ type: PermissionType) -> PermissionStatus {
        return permissionsStatus[type] ?? .notRequested
    }
    
    func isPermissionAuthorized(_ type: PermissionType) -> Bool {
        return getPermissionStatus(type) == .authorized
    }
    
    func hasUnauthorizedPermissions() -> Bool {
        return permissionsStatus.values.contains { status in
            status == .notRequested || status == .denied
        }
    }
    
    func getUnauthorizedPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { type in
            let status = getPermissionStatus(type)
            return status == .notRequested || status == .denied
        }
    }
    
    // MARK: - App Startup
    func handleAppStartup() {
        // Check if this is the first launch
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        
        if !hasLaunchedBefore {
            // First launch - show permissions flow
            startPermissionsFlow()
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        } else {
            // Not first launch - check if we need to request any permissions
            checkAllPermissions()
            if hasUnauthorizedPermissions() {
                // Show permissions flow for missing permissions
                startPermissionsFlow()
            }
        }
    }
}





