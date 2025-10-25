//
//  BatteryMonitoringManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import UIKit
import CoreData
import Combine

@MainActor
class BatteryMonitoringManager: ObservableObject {
    static let shared = BatteryMonitoringManager()
    
    @Published var batteryLevel: Float = 1.0
    @Published var isCharging = false
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var batteryImpact: BatteryImpact = BatteryImpact()
    @Published var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoring = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    // Monitoring components
    private var monitoringTimer: Timer?
    private var batterySnapshotTimer: Timer?
    private var performanceTimer: Timer?
    
    // Battery tracking
    private var batterySnapshots: [BatterySnapshot] = []
    private var performanceSnapshots: [PerformanceSnapshot] = []
    private var baselineMetrics: BaselineMetrics?
    
    // Configuration
    private let monitoringInterval: TimeInterval = 60 // 1 minute
    private let snapshotInterval: TimeInterval = 300 // 5 minutes
    private let performanceInterval: TimeInterval = 30 // 30 seconds
    
    // Battery impact thresholds
    private let batteryImpactThresholds = BatteryImpactThresholds()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBatteryMonitoring()
        setupNotifications()
        loadBaselineMetrics()
    }
    
    deinit {
        monitoringTimer?.invalidate()
        batterySnapshotTimer?.invalidate()
        performanceTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Initial battery state
        batteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging
        batteryState = UIDevice.current.batteryState
    }
    
    private func setupNotifications() {
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
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start monitoring timers
        startMonitoringTimer()
        startSnapshotTimer()
        startPerformanceTimer()
        
        // Record initial snapshot
        recordBatterySnapshot()
        recordPerformanceSnapshot()
        
        print("Battery monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // Stop timers
        monitoringTimer?.invalidate()
        batterySnapshotTimer?.invalidate()
        performanceTimer?.invalidate()
        
        monitoringTimer = nil
        batterySnapshotTimer = nil
        performanceTimer = nil
        
        print("Battery monitoring stopped")
    }
    
    // MARK: - Timers
    private func startMonitoringTimer() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateBatteryState()
            }
        }
    }
    
    private func startSnapshotTimer() {
        batterySnapshotTimer = Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.recordBatterySnapshot()
            }
        }
    }
    
    private func startPerformanceTimer() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: performanceInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.recordPerformanceSnapshot()
            }
        }
    }
    
    // MARK: - Battery State Updates
    @objc private func handleBatteryLevelChanged(_ notification: Notification) {
        Task {
            await updateBatteryState()
        }
    }
    
    @objc private func handleBatteryStateChanged(_ notification: Notification) {
        Task {
            await updateBatteryState()
        }
    }
    
    private func updateBatteryState() async {
        let newBatteryLevel = UIDevice.current.batteryLevel
        let newBatteryState = UIDevice.current.batteryState
        let newIsCharging = newBatteryState == .charging
        
        // Calculate battery drain
        let batteryDrain = calculateBatteryDrain(
            from: batteryLevel,
            to: newBatteryLevel,
            timeInterval: monitoringInterval
        )
        
        // Update battery impact
        updateBatteryImpact(batteryDrain: batteryDrain)
        
        // Update published properties
        batteryLevel = newBatteryLevel
        batteryState = newBatteryState
        isCharging = newIsCharging
        
        // Log significant changes
        if abs(batteryDrain) > batteryImpactThresholds.significantDrainThreshold {
            logBatteryEvent("Significant battery drain: \(batteryDrain * 100)%")
        }
    }
    
    // MARK: - Battery Snapshots
    private func recordBatterySnapshot() async {
        let snapshot = BatterySnapshot(
            timestamp: Date(),
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            isCharging: isCharging,
            appState: UIApplication.shared.applicationState,
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            networkUsage: getNetworkUsage()
        )
        
        batterySnapshots.append(snapshot)
        
        // Keep only last 100 snapshots
        if batterySnapshots.count > 100 {
            batterySnapshots.removeFirst()
        }
        
        // Save to Core Data
        await saveBatterySnapshot(snapshot)
        
        // Update battery impact
        await updateBatteryImpactFromSnapshots()
    }
    
    private func recordPerformanceSnapshot() async {
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            networkUsage: getNetworkUsage(),
            diskUsage: getDiskUsage(),
            appState: UIApplication.shared.applicationState
        )
        
        performanceSnapshots.append(snapshot)
        
        // Keep only last 200 snapshots
        if performanceSnapshots.count > 200 {
            performanceSnapshots.removeFirst()
        }
        
        // Update performance metrics
        updatePerformanceMetrics()
    }
    
    // MARK: - Battery Impact Calculation
    private func calculateBatteryDrain(from: Float, to: Float, timeInterval: TimeInterval) -> Float {
        // Calculate battery drain per hour
        let drain = from - to
        let hours = timeInterval / 3600
        return hours > 0 ? drain / Float(hours) : 0
    }
    
    private func updateBatteryImpact(batteryDrain: Float) {
        // Update battery impact metrics
        batteryImpact.totalDrain += batteryDrain
        batteryImpact.averageDrain = calculateAverageDrain()
        batteryImpact.peakDrain = max(batteryImpact.peakDrain, batteryDrain)
        batteryImpact.drainEvents += 1
        
        // Check for concerning patterns
        if batteryDrain > batteryImpactThresholds.highDrainThreshold {
            batteryImpact.highDrainEvents += 1
        }
        
        if batteryDrain > batteryImpactThresholds.criticalDrainThreshold {
            batteryImpact.criticalDrainEvents += 1
        }
    }
    
    private func updateBatteryImpactFromSnapshots() async {
        guard batterySnapshots.count >= 2 else { return }
        
        let recentSnapshots = Array(batterySnapshots.suffix(10))
        var totalDrain: Float = 0
        var drainCount = 0
        
        for i in 1..<recentSnapshots.count {
            let previous = recentSnapshots[i-1]
            let current = recentSnapshots[i]
            
            if !current.isCharging && !previous.isCharging {
                let timeInterval = current.timestamp.timeIntervalSince(previous.timestamp)
                let drain = calculateBatteryDrain(
                    from: previous.batteryLevel,
                    to: current.batteryLevel,
                    timeInterval: timeInterval
                )
                
                totalDrain += drain
                drainCount += 1
            }
        }
        
        if drainCount > 0 {
            batteryImpact.averageDrain = totalDrain / Float(drainCount)
        }
    }
    
    private func calculateAverageDrain() -> Float {
        guard batterySnapshots.count >= 2 else { return 0 }
        
        let nonChargingSnapshots = batterySnapshots.filter { !$0.isCharging }
        guard nonChargingSnapshots.count >= 2 else { return 0 }
        
        var totalDrain: Float = 0
        var drainCount = 0
        
        for i in 1..<nonChargingSnapshots.count {
            let previous = nonChargingSnapshots[i-1]
            let current = nonChargingSnapshots[i]
            
            let timeInterval = current.timestamp.timeIntervalSince(previous.timestamp)
            let drain = calculateBatteryDrain(
                from: previous.batteryLevel,
                to: current.batteryLevel,
                timeInterval: timeInterval
            )
            
            totalDrain += drain
            drainCount += 1
        }
        
        return drainCount > 0 ? totalDrain / Float(drainCount) : 0
    }
    
    // MARK: - Performance Metrics
    private func updatePerformanceMetrics() {
        guard !performanceSnapshots.isEmpty else { return }
        
        let recentSnapshots = Array(performanceSnapshots.suffix(20))
        
        // Calculate averages
        performanceMetrics.averageMemoryUsage = recentSnapshots.reduce(0) { $0 + $1.memoryUsage } / Double(recentSnapshots.count)
        performanceMetrics.averageCPUUsage = recentSnapshots.reduce(0) { $0 + $1.cpuUsage } / Double(recentSnapshots.count)
        performanceMetrics.averageNetworkUsage = recentSnapshots.reduce(0) { $0 + $1.networkUsage } / Double(recentSnapshots.count)
        
        // Calculate peaks
        performanceMetrics.peakMemoryUsage = recentSnapshots.map { $0.memoryUsage }.max() ?? 0
        performanceMetrics.peakCPUUsage = recentSnapshots.map { $0.cpuUsage }.max() ?? 0
        performanceMetrics.peakNetworkUsage = recentSnapshots.map { $0.networkUsage }.max() ?? 0
        
        // Calculate trends
        performanceMetrics.memoryTrend = calculateTrend(recentSnapshots.map { $0.memoryUsage })
        performanceMetrics.cpuTrend = calculateTrend(recentSnapshots.map { $0.cpuUsage })
        performanceMetrics.networkTrend = calculateTrend(recentSnapshots.map { $0.networkUsage })
    }
    
    private func calculateTrend(_ values: [Double]) -> Trend {
        guard values.count >= 2 else { return .stable }
        
        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let difference = secondAverage - firstAverage
        let threshold = 0.1 // 10% change threshold
        
        if difference > threshold {
            return .increasing
        } else if difference < -threshold {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    // MARK: - System Metrics
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
    
    private func getCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                        PROCESSOR_CPU_LOAD_INFO,
                                        &numCpus,
                                        &info,
                                        &numCpuInfo)
        
        if result == KERN_SUCCESS {
            let cpuInfo = info.withMemoryRebound(to: processor_cpu_load_info_t.self, capacity: 1) { $0 }
            let cpuLoad = cpuInfo.pointee
            
            let totalTicks = cpuLoad.cpu_ticks.0 + cpuLoad.cpu_ticks.1 + cpuLoad.cpu_ticks.2 + cpuLoad.cpu_ticks.3
            let idleTicks = cpuLoad.cpu_ticks.3
            
            if totalTicks > 0 {
                return Double(totalTicks - idleTicks) / Double(totalTicks)
            }
        }
        
        return 0
    }
    
    private func getNetworkUsage() -> Double {
        // This would integrate with network monitoring
        // For now, return a simulated value
        return Double.random(in: 0...100)
    }
    
    private func getDiskUsage() -> Double {
        // This would integrate with disk monitoring
        // For now, return a simulated value
        return Double.random(in: 0...1000)
    }
    
    // MARK: - Baseline Metrics
    private func loadBaselineMetrics() {
        let request: NSFetchRequest<BaselineMetrics> = BaselineMetrics.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BaselineMetrics.createdAt, ascending: false)]
        request.fetchLimit = 1
        
        do {
            baselineMetrics = try persistenceController.container.viewContext.fetch(request).first
        } catch {
            print("Error loading baseline metrics: \(error)")
        }
    }
    
    func establishBaseline() async {
        // Establish baseline metrics when app is idle
        let baseline = BaselineMetrics(context: persistenceController.container.viewContext)
        baseline.id = UUID()
        baseline.batteryDrain = batteryImpact.averageDrain
        baseline.memoryUsage = performanceMetrics.averageMemoryUsage
        baseline.cpuUsage = performanceMetrics.averageCPUUsage
        baseline.networkUsage = performanceMetrics.averageNetworkUsage
        baseline.createdAt = Date()
        
        try? persistenceController.container.viewContext.save()
        
        baselineMetrics = baseline
        
        print("Baseline metrics established")
    }
    
    // MARK: - Impact Analysis
    func analyzeBatteryImpact() -> BatteryImpactAnalysis {
        let baselineDrain = baselineMetrics?.batteryDrain ?? 0
        let currentDrain = batteryImpact.averageDrain
        
        let impactRatio = baselineDrain > 0 ? currentDrain / baselineDrain : 1.0
        
        let impactLevel: ImpactLevel
        if impactRatio < 1.2 {
            impactLevel = .low
        } else if impactRatio < 2.0 {
            impactLevel = .moderate
        } else {
            impactLevel = .high
        }
        
        return BatteryImpactAnalysis(
            impactLevel: impactLevel,
            impactRatio: impactRatio,
            baselineDrain: baselineDrain,
            currentDrain: currentDrain,
            recommendations: generateRecommendations(impactLevel: impactLevel),
            isConcerning: impactLevel == .high
        )
    }
    
    private func generateRecommendations(impactLevel: ImpactLevel) -> [String] {
        var recommendations: [String] = []
        
        switch impactLevel {
        case .low:
            recommendations.append("Battery impact is within acceptable limits")
        case .moderate:
            recommendations.append("Consider optimizing location services")
            recommendations.append("Reduce background task frequency")
        case .high:
            recommendations.append("Implement aggressive power management")
            recommendations.append("Reduce location accuracy")
            recommendations.append("Disable non-essential features")
            recommendations.append("Implement Low Power Mode detection")
        }
        
        return recommendations
    }
    
    // MARK: - Data Persistence
    private func saveBatterySnapshot(_ snapshot: BatterySnapshot) async {
        let context = persistenceController.container.viewContext
        
        let batterySnapshot = BatterySnapshotEntity(context: context)
        batterySnapshot.id = UUID()
        batterySnapshot.timestamp = snapshot.timestamp
        batterySnapshot.batteryLevel = snapshot.batteryLevel
        batterySnapshot.batteryState = snapshot.batteryState.rawValue
        batterySnapshot.isCharging = snapshot.isCharging
        batterySnapshot.appState = snapshot.appState.rawValue
        batterySnapshot.memoryUsage = snapshot.memoryUsage
        batterySnapshot.cpuUsage = snapshot.cpuUsage
        batterySnapshot.networkUsage = snapshot.networkUsage
        batterySnapshot.createdAt = Date()
        
        try? context.save()
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // App became active - record snapshot
        Task {
            await recordBatterySnapshot()
        }
    }
    
    @objc private func handleAppWillResignActive(_ notification: Notification) {
        // App will resign active - record snapshot
        Task {
            await recordBatterySnapshot()
        }
    }
    
    // MARK: - Helper Methods
    private func logBatteryEvent(_ message: String) {
        print("[BatteryMonitoring] \(message)")
        
        // This would integrate with OSLog for production logging
        // os_log("%{public}@", log: .batteryMonitoring, type: .info, message)
    }
    
    // MARK: - Analytics
    func getBatteryMonitoringStats() -> BatteryMonitoringStats {
        return BatteryMonitoringStats(
            isMonitoring: isMonitoring,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            batteryImpact: batteryImpact,
            performanceMetrics: performanceMetrics,
            snapshotCount: batterySnapshots.count,
            performanceSnapshotCount: performanceSnapshots.count,
            monitoringDuration: calculateMonitoringDuration()
        )
    }
    
    private func calculateMonitoringDuration() -> TimeInterval {
        guard let firstSnapshot = batterySnapshots.first else { return 0 }
        return Date().timeIntervalSince(firstSnapshot.timestamp)
    }
}

// MARK: - Supporting Types
struct BatterySnapshot {
    let timestamp: Date
    let batteryLevel: Float
    let batteryState: UIDevice.BatteryState
    let isCharging: Bool
    let appState: UIApplication.State
    let memoryUsage: Double
    let cpuUsage: Double
    let networkUsage: Double
}

struct PerformanceSnapshot {
    let timestamp: Date
    let memoryUsage: Double
    let cpuUsage: Double
    let networkUsage: Double
    let diskUsage: Double
    let appState: UIApplication.State
}

struct BatteryImpact {
    var totalDrain: Float = 0
    var averageDrain: Float = 0
    var peakDrain: Float = 0
    var drainEvents: Int = 0
    var highDrainEvents: Int = 0
    var criticalDrainEvents: Int = 0
}

struct PerformanceMetrics {
    var averageMemoryUsage: Double = 0
    var averageCPUUsage: Double = 0
    var averageNetworkUsage: Double = 0
    var peakMemoryUsage: Double = 0
    var peakCPUUsage: Double = 0
    var peakNetworkUsage: Double = 0
    var memoryTrend: Trend = .stable
    var cpuTrend: Trend = .stable
    var networkTrend: Trend = .stable
}

enum Trend: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

enum ImpactLevel: String, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
}

struct BatteryImpactAnalysis {
    let impactLevel: ImpactLevel
    let impactRatio: Float
    let baselineDrain: Float
    let currentDrain: Float
    let recommendations: [String]
    let isConcerning: Bool
}

struct BatteryImpactThresholds {
    let significantDrainThreshold: Float = 0.05 // 5%
    let highDrainThreshold: Float = 0.1 // 10%
    let criticalDrainThreshold: Float = 0.2 // 20%
}

struct BatteryMonitoringStats {
    let isMonitoring: Bool
    let batteryLevel: Float
    let isCharging: Bool
    let batteryImpact: BatteryImpact
    let performanceMetrics: PerformanceMetrics
    let snapshotCount: Int
    let performanceSnapshotCount: Int
    let monitoringDuration: TimeInterval
}

// MARK: - Core Data Extensions
extension BaselineMetrics {
    static func fetchRequest() -> NSFetchRequest<BaselineMetrics> {
        return NSFetchRequest<BaselineMetrics>(entityName: "BaselineMetrics")
    }
}

extension BatterySnapshotEntity {
    static func fetchRequest() -> NSFetchRequest<BatterySnapshotEntity> {
        return NSFetchRequest<BatterySnapshotEntity>(entityName: "BatterySnapshotEntity")
    }
}
