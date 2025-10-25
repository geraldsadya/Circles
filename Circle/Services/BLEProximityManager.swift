//
//  BLEProximityManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreBluetooth
import CoreLocation
import Combine

@MainActor
class BLEProximityManager: ObservableObject {
    static let shared = BLEProximityManager()
    
    @Published var isBLEAvailable = false
    @Published var isScanning = false
    @Published var nearbyDevices: [BLEDevice] = []
    @Published var proximityAccuracy: ProximityAccuracy = .medium
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let locationManager = LocationManager.shared
    
    // BLE components
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var discoveredPeripherals: [CBPeripheral] = []
    private var connectedPeripherals: [CBPeripheral] = []
    
    // BLE configuration
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-CBA987654321")
    private let scanTimeout: TimeInterval = 30.0
    private let connectionTimeout: TimeInterval = 10.0
    
    // Proximity thresholds
    private let proximityThresholds = BLEProximityThresholds()
    private var cancellables = Set<AnyCancellable>()
    
    // State management
    private var scanTimer: Timer?
    private var connectionTimer: Timer?
    private var isForegroundOnly = true
    
    private init() {
        setupBLE()
        setupNotifications()
    }
    
    deinit {
        scanTimer?.invalidate()
        connectionTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupBLE() {
        // Initialize central manager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Initialize peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        // Check BLE availability
        isBLEAvailable = centralManager?.state == .poweredOn
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
    
    // MARK: - BLE Operations
    func startScanning() {
        guard isBLEAvailable && !isScanning else { return }
        
        // Only scan in foreground
        guard UIApplication.shared.applicationState == .active else {
            errorMessage = "BLE scanning only available in foreground"
            return
        }
        
        isScanning = true
        
        // Start scanning for Circle devices
        centralManager?.scanForPeripherals(
            withServices: [serviceUUID],
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false,
                CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [serviceUUID]
            ]
        )
        
        // Set scan timeout
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.stopScanning()
            }
        }
        
        logBLE("BLE scanning started")
    }
    
    func stopScanning() async {
        guard isScanning else { return }
        
        isScanning = false
        centralManager?.stopScan()
        scanTimer?.invalidate()
        scanTimer = nil
        
        logBLE("BLE scanning stopped")
    }
    
    func startAdvertising() {
        guard isBLEAvailable else { return }
        
        // Only advertise in foreground
        guard UIApplication.shared.applicationState == .active else {
            errorMessage = "BLE advertising only available in foreground"
            return
        }
        
        // Create service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Create characteristic
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        
        service.characteristics = [characteristic]
        
        // Add service
        peripheralManager?.add(service)
        
        // Start advertising
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Circle-\(getDeviceIdentifier())"
        ]
        
        peripheralManager?.startAdvertising(advertisementData)
        
        logBLE("BLE advertising started")
    }
    
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        logBLE("BLE advertising stopped")
    }
    
    // MARK: - Proximity Detection
    func detectProximity(to device: BLEDevice) async -> ProximityResult {
        guard let peripheral = device.peripheral else {
            return ProximityResult(
                device: device,
                proximity: .unknown,
                accuracy: .low,
                rssi: 0,
                timestamp: Date()
            )
        }
        
        // Connect to device for proximity measurement
        if peripheral.state != .connected {
            await connectToDevice(peripheral)
        }
        
        // Read RSSI for proximity calculation
        peripheral.readRSSI()
        
        // Wait for RSSI reading
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let rssi = device.rssi
        let proximity = calculateProximity(from: rssi)
        let accuracy = calculateAccuracy(from: rssi)
        
        return ProximityResult(
            device: device,
            proximity: proximity,
            accuracy: accuracy,
            rssi: rssi,
            timestamp: Date()
        )
    }
    
    private func calculateProximity(from rssi: Int) -> ProximityLevel {
        switch rssi {
        case -50...0:
            return .veryClose
        case -70..<(-50):
            return .close
        case -90..<(-70):
            return .medium
        case -110..<(-90):
            return .far
        default:
            return .veryFar
        }
    }
    
    private func calculateAccuracy(from rssi: Int) -> ProximityAccuracy {
        switch rssi {
        case -50...0:
            return .high
        case -70..<(-50):
            return .high
        case -90..<(-70):
            return .medium
        case -110..<(-90):
            return .low
        default:
            return .low
        }
    }
    
    // MARK: - Device Management
    private func connectToDevice(_ peripheral: CBPeripheral) async {
        centralManager?.connect(peripheral, options: nil)
        
        // Set connection timeout
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleConnectionTimeout(peripheral)
            }
        }
    }
    
    private func handleConnectionTimeout(_ peripheral: CBPeripheral) async {
        centralManager?.cancelPeripheralConnection(peripheral)
        logBLE("Connection timeout for peripheral: \(peripheral.identifier)")
    }
    
    private func disconnectFromDevice(_ peripheral: CBPeripheral) {
        centralManager?.cancelPeripheralConnection(peripheral)
        logBLE("Disconnected from peripheral: \(peripheral.identifier)")
    }
    
    // MARK: - Hangout Integration
    func refineHangoutDetection(with locationResult: LocationProximityResult) async -> RefinedHangoutResult {
        // Get BLE proximity data
        let bleResults = await getBLEProximityResults()
        
        // Combine location and BLE data
        let refinedResult = RefinedHangoutResult(
            locationResult: locationResult,
            bleResults: bleResults,
            confidence: calculateCombinedConfidence(locationResult, bleResults),
            timestamp: Date()
        )
        
        return refinedResult
    }
    
    private func getBLEProximityResults() async -> [ProximityResult] {
        var results: [ProximityResult] = []
        
        for device in nearbyDevices {
            let result = await detectProximity(to: device)
            results.append(result)
        }
        
        return results
    }
    
    private func calculateCombinedConfidence(_ locationResult: LocationProximityResult, _ bleResults: [ProximityResult]) -> Double {
        let locationConfidence = locationResult.confidence
        let bleConfidence = bleResults.isEmpty ? 0.0 : bleResults.map { $0.accuracy.rawValue }.reduce(0, +) / Double(bleResults.count)
        
        // Weighted combination: 70% location, 30% BLE
        return (locationConfidence * 0.7) + (bleConfidence * 0.3)
    }
    
    // MARK: - Data Management
    func saveProximityResult(_ result: ProximityResult) async {
        let context = persistenceController.container.viewContext
        
        let proximityResult = BLEProximityResult(context: context)
        proximityResult.id = UUID()
        proximityResult.deviceId = result.device.id
        proximityResult.deviceName = result.device.name
        proximityResult.proximity = result.proximity.rawValue
        proximityResult.accuracy = result.accuracy.rawValue
        proximityResult.rssi = Int32(result.rssi)
        proximityResult.timestamp = result.timestamp
        proximityResult.createdAt = Date()
        
        try? context.save()
    }
    
    func getProximityHistory(for deviceId: String, limit: Int = 50) -> [BLEProximityResult] {
        let request: NSFetchRequest<BLEProximityResult> = BLEProximityResult.fetchRequest()
        request.predicate = NSPredicate(format: "deviceId == %@", deviceId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BLEProximityResult.timestamp, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            logBLE("Error loading proximity history: \(error)")
            return []
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAppDidBecomeActive() {
        // App became active - can start BLE operations
        if isScanning {
            startScanning()
        }
        startAdvertising()
    }
    
    @objc private func handleAppWillResignActive() {
        // App will resign active - stop BLE operations
        Task {
            await stopScanning()
        }
        stopAdvertising()
    }
    
    @objc private func handleAppDidEnterBackground() {
        // App entered background - stop BLE operations
        Task {
            await stopScanning()
        }
        stopAdvertising()
    }
    
    // MARK: - Helper Methods
    private func getDeviceIdentifier() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    private func logBLE(_ message: String) {
        print("[BLEProximity] \(message)")
    }
    
    // MARK: - Analytics
    func getBLEStats() -> BLEStats {
        return BLEStats(
            isBLEAvailable: isBLEAvailable,
            isScanning: isScanning,
            nearbyDevicesCount: nearbyDevices.count,
            connectedDevicesCount: connectedPeripherals.count,
            proximityAccuracy: proximityAccuracy,
            totalScans: getTotalScans(),
            totalConnections: getTotalConnections(),
            averageRSSI: getAverageRSSI()
        )
    }
    
    private func getTotalScans() -> Int {
        // This would track actual scan count
        return 0
    }
    
    private func getTotalConnections() -> Int {
        // This would track actual connection count
        return 0
    }
    
    private func getAverageRSSI() -> Double {
        guard !nearbyDevices.isEmpty else { return 0 }
        return nearbyDevices.map { Double($0.rssi) }.reduce(0, +) / Double(nearbyDevices.count)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEProximityManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBLEAvailable = central.state == .poweredOn
        
        if central.state == .poweredOn {
            logBLE("BLE is available")
        } else {
            logBLE("BLE is not available: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Check if this is a Circle device
        guard let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
              localName.hasPrefix("Circle-") else {
            return
        }
        
        // Create BLEDevice
        let device = BLEDevice(
            id: peripheral.identifier.uuidString,
            name: localName,
            peripheral: peripheral,
            rssi: RSSI.intValue,
            lastSeen: Date()
        )
        
        // Update or add device
        if let index = nearbyDevices.firstIndex(where: { $0.id == device.id }) {
            nearbyDevices[index] = device
        } else {
            nearbyDevices.append(device)
        }
        
        logBLE("Discovered Circle device: \(device.name) (RSSI: \(device.rssi))")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripherals.append(peripheral)
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        logBLE("Connected to peripheral: \(peripheral.identifier)")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        logBLE("Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "Unknown")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
        
        logBLE("Disconnected from peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "None")")
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEProximityManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            logBLE("Peripheral manager is powered on")
        case .poweredOff:
            logBLE("Peripheral manager is powered off")
        case .resetting:
            logBLE("Peripheral manager is resetting")
        case .unauthorized:
            logBLE("Peripheral manager is unauthorized")
        case .unsupported:
            logBLE("Peripheral manager is unsupported")
        case .unknown:
            logBLE("Peripheral manager state is unknown")
        @unknown default:
            logBLE("Peripheral manager state is unknown")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            logBLE("Failed to start advertising: \(error.localizedDescription)")
        } else {
            logBLE("Successfully started advertising")
        }
    }
}

// MARK: - Supporting Types
struct BLEDevice {
    let id: String
    let name: String
    let peripheral: CBPeripheral?
    let rssi: Int
    let lastSeen: Date
}

enum ProximityLevel: String, CaseIterable {
    case veryClose = "very_close"
    case close = "close"
    case medium = "medium"
    case far = "far"
    case veryFar = "very_far"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .veryClose: return "Very Close"
        case .close: return "Close"
        case .medium: return "Medium"
        case .far: return "Far"
        case .veryFar: return "Very Far"
        case .unknown: return "Unknown"
        }
    }
}

enum ProximityAccuracy: String, CaseIterable {
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

struct ProximityResult {
    let device: BLEDevice
    let proximity: ProximityLevel
    let accuracy: ProximityAccuracy
    let rssi: Int
    let timestamp: Date
}

struct LocationProximityResult {
    let distance: Double
    let accuracy: Double
    let confidence: Double
    let timestamp: Date
}

struct RefinedHangoutResult {
    let locationResult: LocationProximityResult
    let bleResults: [ProximityResult]
    let confidence: Double
    let timestamp: Date
}

struct BLEProximityThresholds {
    let veryCloseRSSI = -50
    let closeRSSI = -70
    let mediumRSSI = -90
    let farRSSI = -110
}

struct BLEStats {
    let isBLEAvailable: Bool
    let isScanning: Bool
    let nearbyDevicesCount: Int
    let connectedDevicesCount: Int
    let proximityAccuracy: ProximityAccuracy
    let totalScans: Int
    let totalConnections: Int
    let averageRSSI: Double
}

// MARK: - Core Data Extensions
extension BLEProximityResult {
    static func fetchRequest() -> NSFetchRequest<BLEProximityResult> {
        return NSFetchRequest<BLEProximityResult>(entityName: "BLEProximityResult")
    }
}
