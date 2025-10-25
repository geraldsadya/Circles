//
//  FieldTestManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreLocation
import CoreData
import Combine

@MainActor
class FieldTestManager: ObservableObject {
    static let shared = FieldTestManager()
    
    @Published var isTesting = false
    @Published var currentTest: FieldTest?
    @Published var testResults: [FieldTestResult] = []
    @Published var testStatistics: TestStatistics?
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let locationManager = LocationManager.shared
    private let geofenceManager = GeofenceManager.shared
    
    // Test configuration
    private let testDuration: TimeInterval = 300 // 5 minutes per test
    private let accuracyThresholds: [Double] = [10, 25, 50, 100] // meters
    private let testEnvironments: [TestEnvironment] = [
        .urbanCanyon,
        .indoorMall,
        .suburban,
        .park,
        .highway
    ]
    
    // Test state
    private var testTimer: Timer?
    private var locationUpdates: [LocationUpdate] = []
    private var geofenceEvents: [GeofenceEvent] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
        loadTestResults()
    }
    
    deinit {
        testTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationUpdate),
            name: .locationUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGeofenceEvent),
            name: .geofenceEvent,
            object: nil
        )
    }
    
    // MARK: - Test Execution
    func startFieldTest(environment: TestEnvironment) async {
        guard !isTesting else { return }
        
        isTesting = true
        
        // Create new test
        let test = FieldTest(
            id: UUID(),
            environment: environment,
            startTime: Date(),
            endTime: nil,
            isActive: true,
            locationUpdates: [],
            geofenceEvents: [],
            accuracyResults: [],
            falsePositives: 0,
            falseNegatives: 0
        )
        
        currentTest = test
        
        // Clear previous data
        locationUpdates.removeAll()
        geofenceEvents.removeAll()
        
        // Start location monitoring with high accuracy
        await locationManager.startHighAccuracyMonitoring()
        
        // Start test timer
        startTestTimer()
        
        // Log test start
        logTestEvent("Field test started for \(environment.displayName)")
        
        print("Field test started: \(environment.displayName)")
    }
    
    func stopFieldTest() async {
        guard let test = currentTest else { return }
        
        isTesting = false
        
        // Stop location monitoring
        await locationManager.stopHighAccuracyMonitoring()
        
        // Stop test timer
        testTimer?.invalidate()
        testTimer = nil
        
        // Complete test
        let completedTest = FieldTest(
            id: test.id,
            environment: test.environment,
            startTime: test.startTime,
            endTime: Date(),
            isActive: false,
            locationUpdates: locationUpdates,
            geofenceEvents: geofenceEvents,
            accuracyResults: calculateAccuracyResults(),
            falsePositives: calculateFalsePositives(),
            falseNegatives: calculateFalseNegatives()
        )
        
        // Save test result
        await saveTestResult(completedTest)
        
        // Update statistics
        await updateTestStatistics()
        
        // Clear current test
        currentTest = nil
        
        logTestEvent("Field test completed for \(test.environment.displayName)")
        
        print("Field test completed: \(test.environment.displayName)")
    }
    
    // MARK: - Test Timer
    private func startTestTimer() {
        testTimer = Timer.scheduledTimer(withTimeInterval: testDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.stopFieldTest()
            }
        }
    }
    
    // MARK: - Location Monitoring
    @objc private func handleLocationUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let location = userInfo["location"] as? CLLocation else { return }
        
        let update = LocationUpdate(
            timestamp: Date(),
            location: location,
            accuracy: location.horizontalAccuracy,
            speed: location.speed,
            course: location.course
        )
        
        locationUpdates.append(update)
        
        // Update current test
        if var test = currentTest {
            test.locationUpdates = locationUpdates
            currentTest = test
        }
    }
    
    @objc private func handleGeofenceEvent(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let event = userInfo["event"] as? GeofenceEvent else { return }
        
        geofenceEvents.append(event)
        
        // Update current test
        if var test = currentTest {
            test.geofenceEvents = geofenceEvents
            currentTest = test
        }
    }
    
    // MARK: - Accuracy Analysis
    private func calculateAccuracyResults() -> [AccuracyResult] {
        var results: [AccuracyResult] = []
        
        for threshold in accuracyThresholds {
            let accurateUpdates = locationUpdates.filter { $0.accuracy <= threshold }
            let accuracyPercentage = locationUpdates.isEmpty ? 0 : Double(accurateUpdates.count) / Double(locationUpdates.count)
            
            results.append(AccuracyResult(
                threshold: threshold,
                accurateCount: accurateUpdates.count,
                totalCount: locationUpdates.count,
                accuracyPercentage: accuracyPercentage
            ))
        }
        
        return results
    }
    
    private func calculateFalsePositives() -> Int {
        // Calculate false positives based on geofence events
        // This would be implemented based on specific test criteria
        return geofenceEvents.filter { $0.isFalsePositive }.count
    }
    
    private func calculateFalseNegatives() -> Int {
        // Calculate false negatives based on missed geofence events
        // This would be implemented based on specific test criteria
        return geofenceEvents.filter { $0.isFalseNegative }.count
    }
    
    // MARK: - Test Results Management
    private func saveTestResult(_ test: FieldTest) async {
        let context = persistenceController.container.viewContext
        
        let testResult = FieldTestResult(context: context)
        testResult.id = test.id
        testResult.environment = test.environment.rawValue
        testResult.startTime = test.startTime
        testResult.endTime = test.endTime ?? Date()
        testResult.duration = test.endTime?.timeIntervalSince(test.startTime) ?? 0
        testResult.totalLocationUpdates = Int32(test.locationUpdates.count)
        testResult.totalGeofenceEvents = Int32(test.geofenceEvents.count)
        testResult.falsePositives = Int32(test.falsePositives)
        testResult.falseNegatives = Int32(test.falseNegatives)
        testResult.averageAccuracy = calculateAverageAccuracy(test.locationUpdates)
        testResult.bestAccuracy = calculateBestAccuracy(test.locationUpdates)
        testResult.worstAccuracy = calculateWorstAccuracy(test.locationUpdates)
        testResult.createdAt = Date()
        
        // Save accuracy results
        testResult.accuracyResults = try? JSONEncoder().encode(test.accuracyResults)
        
        try? context.save()
        
        // Add to results array
        testResults.append(testResult)
    }
    
    private func calculateAverageAccuracy(_ updates: [LocationUpdate]) -> Double {
        guard !updates.isEmpty else { return 0 }
        return updates.reduce(0) { $0 + $1.accuracy } / Double(updates.count)
    }
    
    private func calculateBestAccuracy(_ updates: [LocationUpdate]) -> Double {
        return updates.map { $0.accuracy }.min() ?? 0
    }
    
    private func calculateWorstAccuracy(_ updates: [LocationUpdate]) -> Double {
        return updates.map { $0.accuracy }.max() ?? 0
    }
    
    private func loadTestResults() {
        let request: NSFetchRequest<FieldTestResult> = FieldTestResult.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FieldTestResult.createdAt, ascending: false)]
        request.fetchLimit = 100
        
        do {
            testResults = try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error loading test results: \(error)")
        }
    }
    
    // MARK: - Statistics
    private func updateTestStatistics() async {
        let statistics = TestStatistics(
            totalTests: testResults.count,
            averageAccuracy: calculateOverallAverageAccuracy(),
            bestAccuracy: calculateOverallBestAccuracy(),
            worstAccuracy: calculateOverallWorstAccuracy(),
            falsePositiveRate: calculateFalsePositiveRate(),
            falseNegativeRate: calculateFalseNegativeRate(),
            environmentStats: calculateEnvironmentStats(),
            passRate: calculatePassRate()
        )
        
        testStatistics = statistics
    }
    
    private func calculateOverallAverageAccuracy() -> Double {
        guard !testResults.isEmpty else { return 0 }
        return testResults.reduce(0) { $0 + $1.averageAccuracy } / Double(testResults.count)
    }
    
    private func calculateOverallBestAccuracy() -> Double {
        return testResults.map { $0.bestAccuracy }.min() ?? 0
    }
    
    private func calculateOverallWorstAccuracy() -> Double {
        return testResults.map { $0.worstAccuracy }.max() ?? 0
    }
    
    private func calculateFalsePositiveRate() -> Double {
        let totalEvents = testResults.reduce(0) { $0 + Int($1.totalGeofenceEvents) }
        let totalFalsePositives = testResults.reduce(0) { $0 + Int($1.falsePositives) }
        
        guard totalEvents > 0 else { return 0 }
        return Double(totalFalsePositives) / Double(totalEvents)
    }
    
    private func calculateFalseNegativeRate() -> Double {
        let totalEvents = testResults.reduce(0) { $0 + Int($1.totalGeofenceEvents) }
        let totalFalseNegatives = testResults.reduce(0) { $0 + Int($1.falseNegatives) }
        
        guard totalEvents > 0 else { return 0 }
        return Double(totalFalseNegatives) / Double(totalEvents)
    }
    
    private func calculateEnvironmentStats() -> [EnvironmentStats] {
        let environmentGroups = Dictionary(grouping: testResults) { $0.environment }
        
        return environmentGroups.map { environment, results in
            let averageAccuracy = results.reduce(0) { $0 + $1.averageAccuracy } / Double(results.count)
            let passRate = results.filter { $0.averageAccuracy <= 50 }.count / Double(results.count)
            
            return EnvironmentStats(
                environment: TestEnvironment(rawValue: environment) ?? .urbanCanyon,
                testCount: results.count,
                averageAccuracy: averageAccuracy,
                passRate: passRate
            )
        }
    }
    
    private func calculatePassRate() -> Double {
        let passingTests = testResults.filter { $0.averageAccuracy <= 50 && $0.falsePositives <= 2 }
        return testResults.isEmpty ? 0 : Double(passingTests.count) / Double(testResults.count)
    }
    
    // MARK: - Test Validation
    func validateTestResults() -> ValidationResult {
        let passRate = calculatePassRate()
        let averageAccuracy = calculateOverallAverageAccuracy()
        let falsePositiveRate = calculateFalsePositiveRate()
        
        let isPassing = passRate >= 0.95 && averageAccuracy <= 50 && falsePositiveRate <= 0.05
        
        return ValidationResult(
            isPassing: isPassing,
            passRate: passRate,
            averageAccuracy: averageAccuracy,
            falsePositiveRate: falsePositiveRate,
            issues: generateIssues()
        )
    }
    
    private func generateIssues() -> [String] {
        var issues: [String] = []
        
        let passRate = calculatePassRate()
        if passRate < 0.95 {
            issues.append("Pass rate below 95% threshold")
        }
        
        let averageAccuracy = calculateOverallAverageAccuracy()
        if averageAccuracy > 50 {
            issues.append("Average accuracy above 50m threshold")
        }
        
        let falsePositiveRate = calculateFalsePositiveRate()
        if falsePositiveRate > 0.05 {
            issues.append("False positive rate above 5% threshold")
        }
        
        return issues
    }
    
    // MARK: - Test Reports
    func generateTestReport() -> TestReport {
        let validation = validateTestResults()
        
        return TestReport(
            generatedAt: Date(),
            totalTests: testResults.count,
            testDuration: testResults.reduce(0) { $0 + $1.duration },
            validation: validation,
            statistics: testStatistics,
            environmentBreakdown: calculateEnvironmentStats(),
            recommendations: generateRecommendations()
        )
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let passRate = calculatePassRate()
        if passRate < 0.95 {
            recommendations.append("Improve location accuracy algorithms for better pass rate")
        }
        
        let averageAccuracy = calculateOverallAverageAccuracy()
        if averageAccuracy > 50 {
            recommendations.append("Optimize location services for better accuracy")
        }
        
        let falsePositiveRate = calculateFalsePositiveRate()
        if falsePositiveRate > 0.05 {
            recommendations.append("Refine geofence detection to reduce false positives")
        }
        
        return recommendations
    }
    
    // MARK: - Helper Methods
    private func logTestEvent(_ message: String) {
        print("[FieldTest] \(message)")
        
        // This would integrate with OSLog for production logging
        // os_log("%{public}@", log: .fieldTest, type: .info, message)
    }
    
    // MARK: - Test Data Export
    func exportTestData() -> Data? {
        let exportData = TestExportData(
            tests: testResults.map { result in
                TestExport(
                    id: result.id?.uuidString ?? "",
                    environment: result.environment,
                    startTime: result.startTime ?? Date(),
                    endTime: result.endTime ?? Date(),
                    duration: result.duration,
                    averageAccuracy: result.averageAccuracy,
                    bestAccuracy: result.bestAccuracy,
                    worstAccuracy: result.worstAccuracy,
                    falsePositives: Int(result.falsePositives),
                    falseNegatives: Int(result.falseNegatives),
                    totalLocationUpdates: Int(result.totalLocationUpdates),
                    totalGeofenceEvents: Int(result.totalGeofenceEvents)
                )
            },
            statistics: testStatistics,
            exportedAt: Date()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
}

// MARK: - Supporting Types
enum TestEnvironment: String, CaseIterable {
    case urbanCanyon = "urban_canyon"
    case indoorMall = "indoor_mall"
    case suburban = "suburban"
    case park = "park"
    case highway = "highway"
    
    var displayName: String {
        switch self {
        case .urbanCanyon: return "Urban Canyon"
        case .indoorMall: return "Indoor Mall"
        case .suburban: return "Suburban"
        case .park: return "Park"
        case .highway: return "Highway"
        }
    }
    
    var description: String {
        switch self {
        case .urbanCanyon: return "Dense urban environment with tall buildings"
        case .indoorMall: return "Indoor shopping mall with GPS challenges"
        case .suburban: return "Residential suburban area"
        case .park: return "Open park environment"
        case .highway: return "Highway with high-speed movement"
        }
    }
}

struct FieldTest {
    let id: UUID
    let environment: TestEnvironment
    let startTime: Date
    let endTime: Date?
    let isActive: Bool
    var locationUpdates: [LocationUpdate]
    var geofenceEvents: [GeofenceEvent]
    var accuracyResults: [AccuracyResult]
    var falsePositives: Int
    var falseNegatives: Int
}

struct LocationUpdate {
    let timestamp: Date
    let location: CLLocation
    let accuracy: Double
    let speed: Double
    let course: Double
}

struct GeofenceEvent {
    let timestamp: Date
    let eventType: GeofenceEventType
    let location: CLLocation
    let isFalsePositive: Bool
    let isFalseNegative: Bool
}

enum GeofenceEventType: String, CaseIterable {
    case enter = "enter"
    case exit = "exit"
    case dwell = "dwell"
}

struct AccuracyResult {
    let threshold: Double
    let accurateCount: Int
    let totalCount: Int
    let accuracyPercentage: Double
}

struct TestStatistics {
    let totalTests: Int
    let averageAccuracy: Double
    let bestAccuracy: Double
    let worstAccuracy: Double
    let falsePositiveRate: Double
    let falseNegativeRate: Double
    let environmentStats: [EnvironmentStats]
    let passRate: Double
}

struct EnvironmentStats {
    let environment: TestEnvironment
    let testCount: Int
    let averageAccuracy: Double
    let passRate: Double
}

struct ValidationResult {
    let isPassing: Bool
    let passRate: Double
    let averageAccuracy: Double
    let falsePositiveRate: Double
    let issues: [String]
}

struct TestReport {
    let generatedAt: Date
    let totalTests: Int
    let testDuration: TimeInterval
    let validation: ValidationResult
    let statistics: TestStatistics?
    let environmentBreakdown: [EnvironmentStats]
    let recommendations: [String]
}

struct TestExportData: Codable {
    let tests: [TestExport]
    let statistics: TestStatistics?
    let exportedAt: Date
}

struct TestExport: Codable {
    let id: String
    let environment: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let averageAccuracy: Double
    let bestAccuracy: Double
    let worstAccuracy: Double
    let falsePositives: Int
    let falseNegatives: Int
    let totalLocationUpdates: Int
    let totalGeofenceEvents: Int
}

// MARK: - Core Data Extensions
extension FieldTestResult {
    static func fetchRequest() -> NSFetchRequest<FieldTestResult> {
        return NSFetchRequest<FieldTestResult>(entityName: "FieldTestResult")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let locationUpdated = Notification.Name("locationUpdated")
    static let geofenceEvent = Notification.Name("geofenceEvent")
    static let fieldTestStarted = Notification.Name("fieldTestStarted")
    static let fieldTestCompleted = Notification.Name("fieldTestCompleted")
}
