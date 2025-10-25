//
//  UWBProximityManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import NearbyInteraction
import CoreData
import Combine

@MainActor
class UWBProximityManager: ObservableObject {
    static let shared = UWBProximityManager()
    
    @Published var isUWBAvailable = false
    @Published var isSessionActive = false
    @Published var nearbyDevices: [UWBDevice] = []
    @Published var proximityAccuracy: UWBAccuracy = .high
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    // UWB components
    private var nearbyInteractionSession: NISession?
    private var discoveryToken: NIDiscoveryToken?
    private var configuration: NINearbyPeerConfiguration?
    
    // UWB configuration
    private let uwbConfig = UWBConfiguration()
    private var cancellables = Set<AnyCancellable>()
    
    // State management
    private var sessionTimer: Timer?
    private var isForegroundOnly = true
    
    private init() {
        setupUWB()
        setupNotifications()
    }
    
    deinit {
        sessionTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupUWB() {
        // Check UWB availability
        guard NISession.isSupported else {
            isUWBAvailable = false
            errorMessage = "UWB is not supported on this device"
            return
        }
        
        // Initialize UWB session
        nearbyInteractionSession = NISession()
        nearbyInteractionSession?.delegate = self
        
        isUWBAvailable = true
        
        logUWB("UWB session initialized")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    // MARK: - UWB Operations
    func startUWBSession() {
        guard isUWBAvailable && !isSessionActive else { return }
        
        // Only start session in foreground
        guard UIApplication.shared.applicationState == .active else {
            errorMessage = "UWB session only available in foreground"
            return
        }
        
        // Generate discovery token
        guard let discoveryToken = nearbyInteractionSession?.discoveryToken else {
            errorMessage = "Failed to generate discovery token"
            return
        }
        
        self.discoveryToken = discoveryToken
        
        // Create configuration
        let config = NINearbyPeerConfiguration(peerToken: discoveryToken)
        configuration = config
        
        // Start session
        nearbyInteractionSession?.run(config)
        isSessionActive = true
        
        // Set session timeout
        sessionTimer = Timer.scheduledTimer(withTimeInterval: uwbConfig.sessionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.stopUWBSession()
            }
        }
        
        logUWB("UWB session started")
    }
    
    func stopUWBSession() async {
        guard isSessionActive else { return }
        
        isSessionActive = false
        nearbyInteractionSession?.invalidate()
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        logUWB("UWB session stopped")
    }
    
    // MARK: - Device Discovery
    func discoverNearbyDevices() async -> [UWBDevice] {
        guard isSessionActive else { return [] }
        
        // This would integrate with actual device discovery
        // For now, return mock data
        let mockDevices = [
            UWBDevice(
                id: "device1",
                name: "Circle-User1",
                discoveryToken: discoveryToken,
                distance: 2.5,
                direction: UWBVector3(x: 0.5, y: 0.3, z: 0.1),
                accuracy: .high,
                lastSeen: Date()
            ),
            UWBDevice(
                id: "device2",
                name: "Circle-User2",
                discoveryToken: discoveryToken,
                distance: 5.1,
                direction: UWBVector3(x: -0.2, y: 0.8, z: -0.1),
                accuracy: .medium,
                lastSeen: Date()
            )
        ]
        
        nearbyDevices = mockDevices
        return mockDevices
    }
    
    // MARK: - Proximity Detection
    func detectProximity(to device: UWBDevice) async -> UWBProximityResult {
        // Calculate proximity based on distance and direction
        let proximity = calculateProximity(from: device.distance)
        let accuracy = calculateAccuracy(from: device.distance, direction: device.direction)
        
        let result = UWBProximityResult(
            device: device,
            proximity: proximity,
            accuracy: accuracy,
            distance: device.distance,
            direction: device.direction,
            timestamp: Date()
        )
        
        // Save result
        await saveProximityResult(result)
        
        return result
    }
    
    private func calculateProximity(from distance: Double) -> UWBProximityLevel {
        switch distance {
        case 0..<1.0:
            return .veryClose
        case 1.0..<2.0:
            return .close
        case 2.0..<5.0:
            return .medium
        case 5.0..<10.0:
            return .far
        default:
            return .veryFar
        }
    }
    
    private func calculateAccuracy(from distance: Double, direction: UWBVector3) -> UWBAccuracy {
        // Accuracy decreases with distance
        let distanceAccuracy = max(0.1, 1.0 - (distance / 10.0))
        
        // Accuracy increases with stable direction
        let directionStability = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        let directionAccuracy = min(1.0, directionStability)
        
        let combinedAccuracy = (distanceAccuracy + directionAccuracy) / 2.0
        
        switch combinedAccuracy {
        case 0.8...1.0:
            return .high
        case 0.5..<0.8:
            return .medium
        default:
            return .low
        }
    }
    
    // MARK: - Hangout Integration
    func refineHangoutDetection(with locationResult: LocationProximityResult) async -> UWBRefinedHangoutResult {
        // Get UWB proximity data
        let uwbResults = await getUWBProximityResults()
        
        // Combine location and UWB data
        let refinedResult = UWBRefinedHangoutResult(
            locationResult: locationResult,
            uwbResults: uwbResults,
            confidence: calculateCombinedConfidence(locationResult, uwbResults),
            timestamp: Date()
        )
        
        return refinedResult
    }
    
    private func getUWBProximityResults() async -> [UWBProximityResult] {
        var results: [UWBProximityResult] = []
        
        for device in nearbyDevices {
            let result = await detectProximity(to: device)
            results.append(result)
        }
        
        return results
    }
    
    private func calculateCombinedConfidence(_ locationResult: LocationProximityResult, _ uwbResults: [UWBProximityResult]) -> Double {
        let locationConfidence = locationResult.confidence
        let uwbConfidence = uwbResults.isEmpty ? 0.0 : uwbResults.map { $0.accuracy.rawValue }.reduce(0, +) / Double(uwbResults.count)
        
        // Weighted combination: 60% location, 40% UWB
        return (locationConfidence * 0.6) + (uwbConfidence * 0.4)
    }
    
    // MARK: - Data Management
    private func saveProximityResult(_ result: UWBProximityResult) async {
        let context = persistenceController.container.viewContext
        
        let proximityResult = UWBProximityResultEntity(context: context)
        proximityResult.id = UUID()
        proximityResult.deviceId = result.device.id
        proximityResult.deviceName = result.device.name
        proximityResult.proximity = result.proximity.rawValue
        proximityResult.accuracy = result.accuracy.rawValue
        proximityResult.distance = result.distance
        proximityResult.directionX = result.direction.x
        proximityResult.directionY = result.direction.y
        proximityResult.directionZ = result.direction.z
        proximityResult.timestamp = result.timestamp
        proximityResult.createdAt = Date()
        
        try? context.save()
    }
    
    func getProximityHistory(for deviceId: String, limit: Int = 50) -> [UWBProximityResultEntity] {
        let request: NSFetchRequest<UWBProximityResultEntity> = UWBProximityResultEntity.fetchRequest()
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UWBProximityResultEntity.timestamp, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            logUWB("Error loading proximity history: \(error)")
            return []
        }
    }
    
    // MARK: - Advanced Features
    func getSpatialRelationship(with device: UWBDevice) -> SpatialRelationship {
        let distance = device.distance
        let direction = device.direction
        
        // Calculate spatial relationship
        let relationship = SpatialRelationship(
            distance: distance,
            direction: direction,
            relativePosition: calculateRelativePosition(direction),
            movementPattern: calculateMovementPattern(device),
            stability: calculateStability(device)
        )
        
        return relationship
    }
    
    private func calculateRelativePosition(_ direction: UWBVector3) -> RelativePosition {
        // Determine relative position based on direction vector
        let absX = abs(direction.x)
        let absY = abs(direction.y)
        let absZ = abs(direction.z)
        
        if absX > absY && absX > absZ {
            return direction.x > 0 ? .right : .left
        } else if absY > absX && absY > absZ {
            return direction.y > 0 ? .front : .back
        } else {
            return direction.z > 0 ? .above : .below
        }
    }
    
    private func calculateMovementPattern(_ device: UWBDevice) -> MovementPattern {
        // This would analyze movement patterns over time
        // For now, return static pattern
        return .stationary
    }
    
    private func calculateStability(_ device: UWBDevice) -> Stability {
        // This would calculate stability based on distance and direction changes
        // For now, return high stability
        return .high
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAppDidBecomeActive() {
        // App became active - can start UWB session
        if !isSessionActive {
            startUWBSession()
        }
    }
    
    @objc private func handleAppWillResignActive() {
        // App will resign active - stop UWB session
        Task {
            await stopUWBSession()
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        // App entered background - stop UWB session
        Task {
            await stopUWBSession()
        }
    }
    
    // MARK: - Helper Methods
    private func logUWB(_ message: String) {
        print("[UWBProximity] \(message)")
    }
    
    // MARK: - Analytics
    func getUWBStats() -> UWBStats {
        return UWBStats(
            isUWBAvailable: isUWBAvailable,
            isSessionActive: isSessionActive,
            nearbyDevicesCount: nearbyDevices.count,
            proximityAccuracy: proximityAccuracy,
            totalSessions: getTotalSessions(),
            totalMeasurements: getTotalMeasurements(),
            averageDistance: getAverageDistance(),
            averageAccuracy: getAverageAccuracy()
        )
    }
    
    private func getTotalSessions() -> Int {
        // This would track actual session count
        return 0
    }
    
    private func getTotalMeasurements() -> Int {
        // This would track actual measurement count
        return 0
    }
    
    private func getAverageDistance() -> Double {
        guard !nearbyDevices.isEmpty else { return 0 }
        return nearbyDevices.map { $0.distance }.reduce(0, +) / Double(nearbyDevices.count)
    }
    
    private func getAverageAccuracy() -> Double {
        guard !nearbyDevices.isEmpty else { return 0 }
        return nearbyDevices.map { $0.accuracy.rawValue }.reduce(0, +) / Double(nearbyDevices.count)
    }
}

// MARK: - NISessionDelegate
extension UWBProximityManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        // Handle nearby objects updates
        for object in nearbyObjects {
            let device = UWBDevice(
                id: object.discoveryToken.uuidString,
                name: "Circle-Device",
                discoveryToken: object.discoveryToken,
                distance: object.distance,
                direction: UWBVector3(
                    x: object.direction?.x ?? 0,
                    y: object.direction?.y ?? 0,
                    z: object.direction?.z ?? 0
                ),
                accuracy: .high,
                lastSeen: Date()
            )
            
            // Update or add device
            if let index = nearbyDevices.firstIndex(where: { $0.id == device.id }) {
                nearbyDevices[index] = device
            } else {
                nearbyDevices.append(device)
            }
            
            logUWB("Updated UWB device: \(device.name) (distance: \(device.distance))")
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Handle nearby objects removal
        for object in nearbyObjects {
            nearbyDevices.removeAll { $0.id == object.discoveryToken.uuidString }
            logUWB("Removed UWB device: \(object.discoveryToken.uuidString), reason: \(reason)")
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        logUWB("UWB session was suspended")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        logUWB("UWB session suspension ended")
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        logUWB("UWB session invalidated with error: \(error.localizedDescription)")
        isSessionActive = false
    }
}

// MARK: - Supporting Types
struct UWBDevice {
    let id: String
    let name: String
    let discoveryToken: NIDiscoveryToken?
    let distance: Double
    let direction: UWBVector3
    let accuracy: UWBAccuracy
    let lastSeen: Date
}

struct UWBVector3 {
    let x: Float
    let y: Float
    let z: Float
}

enum UWBProximityLevel: String, CaseIterable {
    case veryClose = "very_close"
    case close = "close"
    case medium = "medium"
    case far = "far"
    case veryFar = "very_far"
    
    var displayName: String {
        switch self {
        case .veryClose: return "Very Close"
        case .close: return "Close"
        case .medium: return "Medium"
        case .far: return "Far"
        case .veryFar: return "Very Far"
        }
    }
}

enum UWBAccuracy: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var rawValue: Double {
        switch self {
        case .high: return 0.9
        case .medium: return 0.6
        case .low: return 0.3
        }
    }
}

struct UWBProximityResult {
    let device: UWBDevice
    let proximity: UWBProximityLevel
    let accuracy: UWBAccuracy
    let distance: Double
    let direction: UWBVector3
    let timestamp: Date
}

struct LocationProximityResult {
    let distance: Double
    let accuracy: Double
    let confidence: Double
    let timestamp: Date
}

struct UWBRefinedHangoutResult {
    let locationResult: LocationProximityResult
    let uwbResults: [UWBProximityResult]
    let confidence: Double
    let timestamp: Date
}

struct SpatialRelationship {
    let distance: Double
    let direction: UWBVector3
    let relativePosition: RelativePosition
    let movementPattern: MovementPattern
    let stability: Stability
}

enum RelativePosition: String, CaseIterable {
    case front = "front"
    case back = "back"
    case left = "left"
    case right = "right"
    case above = "above"
    case below = "below"
    
    var displayName: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        case .left: return "Left"
        case .right: return "Right"
        case .above: return "Above"
        case .below: return "Below"
        }
    }
}

enum MovementPattern: String, CaseIterable {
    case stationary = "stationary"
    case moving = "moving"
    case approaching = "approaching"
    case receding = "receding"
    
    var displayName: String {
        switch self {
        case .stationary: return "Stationary"
        case .moving: return "Moving"
        case .approaching: return "Approaching"
        case .receding: return "Receding"
        }
    }
}

enum Stability: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

struct UWBConfiguration {
    let sessionTimeout: TimeInterval = 60.0
    let measurementInterval: TimeInterval = 1.0
    let maxDistance: Double = 10.0
    let minAccuracy: Double = 0.1
}

struct UWBStats {
    let isUWBAvailable: Bool
    let isSessionActive: Bool
    let nearbyDevicesCount: Int
    let proximityAccuracy: UWBAccuracy
    let totalSessions: Int
    let totalMeasurements: Int
    let averageDistance: Double
    let averageAccuracy: Double
}

// MARK: - Core Data Extensions
extension UWBProximityResultEntity {
    static func fetchRequest() -> NSFetchRequest<UWBProximityResultEntity> {
        return NSFetchRequest<UWBProximityResultEntity>(entityName: "UWBProximityResultEntity")
    }
}
