//
//  HealthKitSleepManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import HealthKit
import CoreData
import Combine

@MainActor
class HealthKitSleepManager: ObservableObject {
    static let shared = HealthKitSleepManager()
    
    @Published var isHealthKitAvailable = false
    @Published var isAuthorized = false
    @Published var sleepData: [SleepData] = []
    @Published var currentSleepGoal: SleepGoal?
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    // HealthKit components
    private let healthStore = HKHealthStore()
    private var sleepQuery: HKAnchoredObjectQuery?
    private var cancellables = Set<AnyCancellable>()
    
    // Sleep configuration
    private let sleepConfig = SleepConfiguration()
    
    private init() {
        checkHealthKitAvailability()
        setupNotifications()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func checkHealthKitAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        
        if isHealthKitAvailable {
            checkAuthorizationStatus()
        } else {
            errorMessage = "HealthKit is not available on this device"
        }
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
    }
    
    // MARK: - Authorization
    private func checkAuthorizationStatus() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let authorizationStatus = healthStore.authorizationStatus(for: sleepType)
        
        isAuthorized = authorizationStatus == .sharingAuthorized
    }
    
    func requestHealthKitPermission() async {
        guard isHealthKitAvailable else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let readTypes: Set<HKObjectType> = [sleepType]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            
            await MainActor.run {
                checkAuthorizationStatus()
            }
            
            if isAuthorized {
                await startSleepDataCollection()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to request HealthKit permission: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Sleep Data Collection
    private func startSleepDataCollection() async {
        guard isAuthorized else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        // Create anchored query for sleep data
        sleepQuery = HKAnchoredObjectQuery(
            type: sleepType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                await self?.handleSleepDataUpdate(samples: samples, error: error)
            }
        }
        
        // Set update handler
        sleepQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                await self?.handleSleepDataUpdate(samples: samples, error: error)
            }
        }
        
        // Execute query
        healthStore.execute(sleepQuery!)
        
        logSleep("Sleep data collection started")
    }
    
    private func handleSleepDataUpdate(samples: [HKSample]?, error: Error?) async {
        if let error = error {
            logSleep("Error updating sleep data: \(error.localizedDescription)")
            return
        }
        
        guard let samples = samples else { return }
        
        // Process sleep samples
        let sleepSamples = samples.compactMap { $0 as? HKCategorySample }
        let processedSleepData = processSleepSamples(sleepSamples)
        
        // Update sleep data
        sleepData = processedSleepData
        
        // Save to Core Data
        await saveSleepData(processedSleepData)
        
        logSleep("Updated sleep data: \(processedSleepData.count) samples")
    }
    
    private func processSleepSamples(_ samples: [HKCategorySample]) -> [SleepData] {
        var processedData: [SleepData] = []
        
        for sample in samples {
            let sleepData = SleepData(
                id: sample.uuid.uuidString,
                startDate: sample.startDate,
                endDate: sample.endDate,
                duration: sample.endDate.timeIntervalSince(sample.startDate),
                sleepStage: getSleepStage(from: sample),
                source: sample.sourceRevision.source.name,
                metadata: sample.metadata
            )
            
            processedData.append(sleepData)
        }
        
        return processedData.sorted { $0.startDate > $1.startDate }
    }
    
    private func getSleepStage(from sample: HKCategorySample) -> SleepStage {
        // Map HealthKit sleep analysis values to our sleep stages
        switch sample.value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return .inBed
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return .lightSleep
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return .deepSleep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return .remSleep
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return .awake
        default:
            return .unknown
        }
    }
    
    // MARK: - Sleep Verification
    func verifySleepChallenge(_ challenge: Challenge, user: User) async -> SleepVerificationResult {
        guard isAuthorized else {
            return SleepVerificationResult(
                challenge: challenge,
                user: user,
                isVerified: false,
                confidence: 0.0,
                sleepData: nil,
                verificationMethod: .healthKit,
                timestamp: Date(),
                error: "HealthKit not authorized"
            )
        }
        
        // Get sleep data for challenge period
        let challengeStart = challenge.startDate ?? Date()
        let challengeEnd = challenge.endDate ?? Date()
        
        let relevantSleepData = getSleepDataForPeriod(start: challengeStart, end: challengeEnd)
        
        // Verify challenge based on type
        let verificationResult = await verifySleepChallengeType(challenge, sleepData: relevantSleepData)
        
        return SleepVerificationResult(
            challenge: challenge,
            user: user,
            isVerified: verificationResult.isVerified,
            confidence: verificationResult.confidence,
            sleepData: relevantSleepData,
            verificationMethod: .healthKit,
            timestamp: Date(),
            error: verificationResult.error
        )
    }
    
    private func verifySleepChallengeType(_ challenge: Challenge, sleepData: [SleepData]) async -> SleepVerificationResult {
        let challengeType = challenge.category ?? ""
        
        switch challengeType.lowercased() {
        case "sleep_before_time":
            return verifySleepBeforeTime(challenge, sleepData: sleepData)
        case "sleep_duration":
            return verifySleepDuration(challenge, sleepData: sleepData)
        case "sleep_quality":
            return verifySleepQuality(challenge, sleepData: sleepData)
        case "wake_up_time":
            return verifyWakeUpTime(challenge, sleepData: sleepData)
        default:
            return SleepVerificationResult(
                challenge: challenge,
                user: nil,
                isVerified: false,
                confidence: 0.0,
                sleepData: sleepData,
                verificationMethod: .healthKit,
                timestamp: Date(),
                error: "Unknown sleep challenge type"
            )
        }
    }
    
    private func verifySleepBeforeTime(_ challenge: Challenge, sleepData: [SleepData]) -> SleepVerificationResult {
        let targetTime = challenge.targetValue // Target bedtime in hours (e.g., 23.0 for 11 PM)
        let targetBedtime = Calendar.current.date(bySettingHour: Int(targetTime), minute: 0, second: 0, of: Date()) ?? Date()
        
        // Find sleep sessions that started before target time
        let earlySleepSessions = sleepData.filter { sleep in
            sleep.sleepStage == .inBed && sleep.startDate < targetBedtime
        }
        
        let isVerified = !earlySleepSessions.isEmpty
        let confidence = isVerified ? 0.9 : 0.1
        
        return SleepVerificationResult(
            challenge: challenge,
            user: nil,
            isVerified: isVerified,
            confidence: confidence,
            sleepData: sleepData,
            verificationMethod: .healthKit,
            timestamp: Date(),
            error: nil
        )
    }
    
    private func verifySleepDuration(_ challenge: Challenge, sleepData: [SleepData]) -> SleepVerificationResult {
        let targetDuration = challenge.targetValue // Target duration in hours
        let totalSleepDuration = sleepData.reduce(0) { $0 + $1.duration }
        let totalSleepHours = totalSleepDuration / 3600
        
        let isVerified = totalSleepHours >= targetDuration
        let confidence = min(1.0, totalSleepHours / targetDuration)
        
        return SleepVerificationResult(
            challenge: challenge,
            user: nil,
            isVerified: isVerified,
            confidence: confidence,
            sleepData: sleepData,
            verificationMethod: .healthKit,
            timestamp: Date(),
            error: nil
        )
    }
    
    private func verifySleepQuality(_ challenge: Challenge, sleepData: [SleepData]) -> SleepVerificationResult {
        // Calculate sleep quality based on sleep stages
        let totalSleepDuration = sleepData.reduce(0) { $0 + $1.duration }
        let deepSleepDuration = sleepData.filter { $0.sleepStage == .deepSleep }.reduce(0) { $0 + $1.duration }
        let remSleepDuration = sleepData.filter { $0.sleepStage == .remSleep }.reduce(0) { $0 + $1.duration }
        
        let deepSleepPercentage = totalSleepDuration > 0 ? deepSleepDuration / totalSleepDuration : 0
        let remSleepPercentage = totalSleepDuration > 0 ? remSleepDuration / totalSleepDuration : 0
        
        // Quality threshold: 20% deep sleep + 20% REM sleep
        let qualityScore = (deepSleepPercentage + remSleepPercentage) / 2
        let targetQuality = challenge.targetValue / 100 // Convert percentage to decimal
        
        let isVerified = qualityScore >= targetQuality
        let confidence = min(1.0, qualityScore / targetQuality)
        
        return SleepVerificationResult(
            challenge: challenge,
            user: nil,
            isVerified: isVerified,
            confidence: confidence,
            sleepData: sleepData,
            verificationMethod: .healthKit,
            timestamp: Date(),
            error: nil
        )
    }
    
    private func verifyWakeUpTime(_ challenge: Challenge, sleepData: [SleepData]) -> SleepVerificationResult {
        let targetTime = challenge.targetValue // Target wake time in hours (e.g., 7.0 for 7 AM)
        let targetWakeTime = Calendar.current.date(bySettingHour: Int(targetTime), minute: 0, second: 0, of: Date()) ?? Date()
        
        // Find sleep sessions that ended around target time
        let onTimeWakeSessions = sleepData.filter { sleep in
            sleep.sleepStage == .awake && abs(sleep.endDate.timeIntervalSince(targetWakeTime)) < 3600 // Within 1 hour
        }
        
        let isVerified = !onTimeWakeSessions.isEmpty
        let confidence = isVerified ? 0.9 : 0.1
        
        return SleepVerificationResult(
            challenge: challenge,
            user: nil,
            isVerified: isVerified,
            confidence: confidence,
            sleepData: sleepData,
            verificationMethod: .healthKit,
            timestamp: Date(),
            error: nil
        )
    }
    
    // MARK: - Sleep Data Management
    private func getSleepDataForPeriod(start: Date, end: Date) -> [SleepData] {
        return sleepData.filter { sleep in
            sleep.startDate >= start && sleep.endDate <= end
        }
    }
    
    private func saveSleepData(_ sleepData: [SleepData]) async {
        let context = persistenceController.container.viewContext
        
        for sleep in sleepData {
            let sleepEntity = SleepDataEntity(context: context)
            sleepEntity.id = UUID(uuidString: sleep.id)
            sleepEntity.startDate = sleep.startDate
            sleepEntity.endDate = sleep.endDate
            sleepEntity.duration = sleep.duration
            sleepEntity.sleepStage = sleep.sleepStage.rawValue
            sleepEntity.source = sleep.source
            sleepEntity.metadata = sleep.metadata
            sleepEntity.createdAt = Date()
            
            try? context.save()
        }
    }
    
    // MARK: - Sleep Goals
    func createSleepGoal(_ goal: SleepGoal) async {
        currentSleepGoal = goal
        
        // Save to Core Data
        let context = persistenceController.container.viewContext
        let sleepGoalEntity = SleepGoalEntity(context: context)
        sleepGoalEntity.id = goal.id
        sleepGoalEntity.type = goal.type.rawValue
        sleepGoalEntity.targetValue = goal.targetValue
        sleepGoalEntity.targetUnit = goal.targetUnit
        sleepGoalEntity.isActive = goal.isActive
        sleepGoalEntity.createdAt = goal.createdAt
        
        try? context.save()
        
        logSleep("Sleep goal created: \(goal.type.displayName)")
    }
    
    func updateSleepGoal(_ goal: SleepGoal) async {
        currentSleepGoal = goal
        
        // Update in Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepGoalEntity> = SleepGoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", goal.id as CVarArg)
        
        if let sleepGoalEntity = try? context.fetch(request).first {
            sleepGoalEntity.type = goal.type.rawValue
            sleepGoalEntity.targetValue = goal.targetValue
            sleepGoalEntity.targetUnit = goal.targetUnit
            sleepGoalEntity.isActive = goal.isActive
            
            try? context.save()
        }
        
        logSleep("Sleep goal updated: \(goal.type.displayName)")
    }
    
    // MARK: - Sleep Analytics
    func getSleepAnalytics(for period: SleepAnalyticsPeriod) -> SleepAnalytics {
        let startDate = period.startDate
        let endDate = period.endDate
        
        let relevantSleepData = getSleepDataForPeriod(start: startDate, end: endDate)
        
        let totalSleepDuration = relevantSleepData.reduce(0) { $0 + $1.duration }
        let averageSleepDuration = relevantSleepData.isEmpty ? 0 : totalSleepDuration / Double(relevantSleepData.count)
        
        let sleepStages = Dictionary(grouping: relevantSleepData) { $0.sleepStage }
        let stageDurations = sleepStages.mapValues { stages in
            stages.reduce(0) { $0 + $1.duration }
        }
        
        let sleepEfficiency = calculateSleepEfficiency(sleepData: relevantSleepData)
        let sleepConsistency = calculateSleepConsistency(sleepData: relevantSleepData)
        
        return SleepAnalytics(
            period: period,
            totalSleepDuration: totalSleepDuration,
            averageSleepDuration: averageSleepDuration,
            sleepStages: stageDurations,
            sleepEfficiency: sleepEfficiency,
            sleepConsistency: sleepConsistency,
            sleepData: relevantSleepData
        )
    }
    
    private func calculateSleepEfficiency(sleepData: [SleepData]) -> Double {
        let totalTimeInBed = sleepData.filter { $0.sleepStage == .inBed }.reduce(0) { $0 + $1.duration }
        let totalSleepTime = sleepData.filter { $0.sleepStage != .awake && $0.sleepStage != .inBed }.reduce(0) { $0 + $1.duration }
        
        return totalTimeInBed > 0 ? totalSleepTime / totalTimeInBed : 0
    }
    
    private func calculateSleepConsistency(sleepData: [SleepData]) -> Double {
        let bedtimes = sleepData.filter { $0.sleepStage == .inBed }.map { $0.startDate }
        let wakeTimes = sleepData.filter { $0.sleepStage == .awake }.map { $0.endDate }
        
        // Calculate variance in bedtimes and wake times
        let bedtimeVariance = calculateVariance(bedtimes)
        let wakeTimeVariance = calculateVariance(wakeTimes)
        
        // Lower variance = higher consistency
        return 1.0 - min(1.0, (bedtimeVariance + wakeTimeVariance) / 2)
    }
    
    private func calculateVariance(_ dates: [Date]) -> Double {
        guard dates.count > 1 else { return 0 }
        
        let timeIntervals = dates.map { $0.timeIntervalSince1970 }
        let mean = timeIntervals.reduce(0, +) / Double(timeIntervals.count)
        let variance = timeIntervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(timeIntervals.count)
        
        return variance
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAppDidBecomeActive() {
        // App became active - refresh sleep data
        Task {
            await refreshSleepData()
        }
    }
    
    @objc private func handleAppWillResignActive() {
        // App will resign active - pause data collection
        sleepQuery?.stop()
    }
    
    private func refreshSleepData() async {
        guard isAuthorized else { return }
        
        // Refresh sleep data from HealthKit
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-7 * 24 * 3600), end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { [weak self] query, samples, error in
            Task { @MainActor in
                await self?.handleSleepDataUpdate(samples: samples, error: error)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Helper Methods
    private func logSleep(_ message: String) {
        print("[HealthKitSleep] \(message)")
    }
    
    // MARK: - Analytics
    func getSleepStats() -> SleepStats {
        return SleepStats(
            isHealthKitAvailable: isHealthKitAvailable,
            isAuthorized: isAuthorized,
            totalSleepSessions: sleepData.count,
            currentSleepGoal: currentSleepGoal,
            averageSleepDuration: getAverageSleepDuration(),
            sleepEfficiency: getAverageSleepEfficiency(),
            sleepConsistency: getAverageSleepConsistency()
        )
    }
    
    private func getAverageSleepDuration() -> Double {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.reduce(0) { $0 + $1.duration } / Double(sleepData.count)
    }
    
    private func getAverageSleepEfficiency() -> Double {
        let analytics = getSleepAnalytics(for: SleepAnalyticsPeriod.lastWeek)
        return analytics.sleepEfficiency
    }
    
    private func getAverageSleepConsistency() -> Double {
        let analytics = getSleepAnalytics(for: SleepAnalyticsPeriod.lastWeek)
        return analytics.sleepConsistency
    }
}

// MARK: - Supporting Types
struct SleepData {
    let id: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let sleepStage: SleepStage
    let source: String
    let metadata: [String: Any]?
}

enum SleepStage: String, CaseIterable {
    case inBed = "in_bed"
    case lightSleep = "light_sleep"
    case deepSleep = "deep_sleep"
    case remSleep = "rem_sleep"
    case awake = "awake"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .inBed: return "In Bed"
        case .lightSleep: return "Light Sleep"
        case .deepSleep: return "Deep Sleep"
        case .remSleep: return "REM Sleep"
        case .awake: return "Awake"
        case .unknown: return "Unknown"
        }
    }
}

struct SleepVerificationResult {
    let challenge: Challenge
    let user: User?
    let isVerified: Bool
    let confidence: Double
    let sleepData: [SleepData]?
    let verificationMethod: VerificationMethod
    let timestamp: Date
    let error: String?
}

enum VerificationMethod: String, CaseIterable {
    case healthKit = "healthkit"
    case manual = "manual"
    case estimated = "estimated"
    
    var displayName: String {
        switch self {
        case .healthKit: return "HealthKit"
        case .manual: return "Manual"
        case .estimated: return "Estimated"
        }
    }
}

struct SleepGoal {
    let id: UUID
    let type: SleepGoalType
    let targetValue: Double
    let targetUnit: String
    let isActive: Bool
    let createdAt: Date
}

enum SleepGoalType: String, CaseIterable {
    case bedtime = "bedtime"
    case wakeTime = "wake_time"
    case duration = "duration"
    case quality = "quality"
    
    var displayName: String {
        switch self {
        case .bedtime: return "Bedtime"
        case .wakeTime: return "Wake Time"
        case .duration: return "Duration"
        case .quality: return "Quality"
        }
    }
}

struct SleepAnalyticsPeriod {
    let startDate: Date
    let endDate: Date
    
    static let lastWeek = SleepAnalyticsPeriod(
        startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
        endDate: Date()
    )
    
    static let lastMonth = SleepAnalyticsPeriod(
        startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
        endDate: Date()
    )
}

struct SleepAnalytics {
    let period: SleepAnalyticsPeriod
    let totalSleepDuration: TimeInterval
    let averageSleepDuration: TimeInterval
    let sleepStages: [SleepStage: TimeInterval]
    let sleepEfficiency: Double
    let sleepConsistency: Double
    let sleepData: [SleepData]
}

struct SleepConfiguration {
    let dataRetentionDays = 30
    let refreshInterval: TimeInterval = 3600 // 1 hour
    let maxSleepDuration: TimeInterval = 12 * 3600 // 12 hours
    let minSleepDuration: TimeInterval = 1 * 3600 // 1 hour
}

struct SleepStats {
    let isHealthKitAvailable: Bool
    let isAuthorized: Bool
    let totalSleepSessions: Int
    let currentSleepGoal: SleepGoal?
    let averageSleepDuration: Double
    let sleepEfficiency: Double
    let sleepConsistency: Double
}

// MARK: - Core Data Extensions
extension SleepDataEntity {
    static func fetchRequest() -> NSFetchRequest<SleepDataEntity> {
        return NSFetchRequest<SleepDataEntity>(entityName: "SleepDataEntity")
    }
}

extension SleepGoalEntity {
    static func fetchRequest() -> NSFetchRequest<SleepGoalEntity> {
        return NSFetchRequest<SleepGoalEntity>(entityName: "SleepGoalEntity")
    }
}
