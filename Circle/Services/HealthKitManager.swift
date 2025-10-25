//
//  HealthKitManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import HealthKit
import Combine
import CoreData

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    @Published var isAuthorized: Bool = false
    @Published var todaysSteps: Int = 0
    @Published var todaysDistance: Double = 0.0
    @Published var todaysSleepHours: Double = 0.0
    @Published var weeklySteps: Int = 0
    @Published var monthlySteps: Int = 0
    @Published var errorMessage: String?
    
    private let healthStore = HKHealthStore()
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Health data types we want to read
    private let healthDataTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.workoutType()
    ]
    
    // Health data types we want to write (for challenges)
    private let writeDataTypes: Set<HKObjectType> = [
        HKObjectType.workoutType()
    ]
    
    init() {
        checkHealthKitAvailability()
        setupHealthKitObservers()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }
        
        print("✅ HealthKit is available on this device")
    }
    
    private func setupHealthKitObservers() {
        // Observe changes to health data
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshHealthData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authorization
    func requestHealthKitAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: writeDataTypes, read: healthDataTypes)
            
            DispatchQueue.main.async {
                self.isAuthorized = true
                self.errorMessage = nil
            }
            
            // Refresh data after authorization
            await refreshHealthData()
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to authorize HealthKit: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Step Count Data
    func getStepsForDate(_ date: Date) async -> Int {
        guard isAuthorized else { return 0 }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Error fetching steps: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            
            healthStore.execute(query)
        }
    }
    
    func getDistanceForDate(_ date: Date) async -> Double {
        guard isAuthorized else { return 0.0 }
        
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    print("Error fetching distance: \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let distance = result?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0.0
                continuation.resume(returning: distance)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep Data
    func getSleepHoursForDate(_ date: Date) async -> Double {
        guard isAuthorized else { return 0.0 }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Error fetching sleep data: \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                
                var totalSleepHours: Double = 0.0
                
                if let sleepSamples = samples as? [HKCategorySample] {
                    for sample in sleepSamples {
                        if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                            let duration = sample.endDate.timeIntervalSince(sample.startDate)
                            totalSleepHours += duration / 3600.0 // Convert to hours
                        }
                    }
                }
                
                continuation.resume(returning: totalSleepHours)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Weekly/Monthly Aggregates
    func getWeeklySteps() async -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        var totalSteps = 0
        var currentDate = weekAgo
        
        while currentDate <= now {
            let steps = await getStepsForDate(currentDate)
            totalSteps += steps
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return totalSteps
    }
    
    func getMonthlySteps() async -> Int {
        let calendar = Calendar.current
        let now = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        
        var totalSteps = 0
        var currentDate = monthAgo
        
        while currentDate <= now {
            let steps = await getStepsForDate(currentDate)
            totalSteps += steps
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return totalSteps
    }
    
    // MARK: - Challenge Verification
    func verifyStepChallenge(targetSteps: Int, for date: Date) async -> Bool {
        let actualSteps = await getStepsForDate(date)
        return actualSteps >= targetSteps
    }
    
    func verifySleepChallenge(targetHours: Double, for date: Date) async -> Bool {
        let actualHours = await getSleepHoursForDate(date)
        return actualHours >= targetHours
    }
    
    func verifyDistanceChallenge(targetDistance: Double, for date: Date) async -> Bool {
        let actualDistance = await getDistanceForDate(date)
        return actualDistance >= targetDistance
    }
    
    // MARK: - Workout Creation
    func createWorkoutChallenge(workoutType: HKWorkoutActivityType, duration: TimeInterval, startDate: Date) async -> Bool {
        guard isAuthorized else { return false }
        
        let endDate = startDate.addingTimeInterval(duration)
        let workout = HKWorkout(
            activityType: workoutType,
            start: startDate,
            end: endDate
        )
        
        do {
            try await healthStore.save(workout)
            print("✅ Workout saved to HealthKit: \(workoutType.rawValue)")
            return true
        } catch {
            print("❌ Failed to save workout: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Data Refresh
    func refreshHealthData() async {
        guard isAuthorized else { return }
        
        let today = Date()
        
        // Fetch today's data
        let steps = await getStepsForDate(today)
        let distance = await getDistanceForDate(today)
        let sleepHours = await getSleepHoursForDate(today)
        
        // Fetch weekly data
        let weeklySteps = await getWeeklySteps()
        
        // Fetch monthly data
        let monthlySteps = await getMonthlySteps()
        
        DispatchQueue.main.async {
            self.todaysSteps = steps
            self.todaysDistance = distance
            self.todaysSleepHours = sleepHours
            self.weeklySteps = weeklySteps
            self.monthlySteps = monthlySteps
        }
        
        // Save to Core Data for offline access
        await saveHealthDataToCoreData(
            steps: steps,
            distance: distance,
            sleepHours: sleepHours,
            date: today
        )
    }
    
    // MARK: - Core Data Integration
    private func saveHealthDataToCoreData(steps: Int, distance: Double, sleepHours: Double, date: Date) async {
        let context = persistenceController.container.viewContext
        
        // Create or update health data entry
        let request: NSFetchRequest<HealthDataEntity> = HealthDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", date as NSDate)
        
        do {
            let existingEntries = try context.fetch(request)
            let healthData: HealthDataEntity
            
            if let existing = existingEntries.first {
                healthData = existing
            } else {
                healthData = HealthDataEntity(context: context)
                healthData.id = UUID()
                healthData.date = date
            }
            
            healthData.steps = Int32(steps)
            healthData.distance = distance
            healthData.sleepHours = sleepHours
            healthData.lastUpdated = Date()
            
            try context.save()
            print("✅ Health data saved to Core Data")
            
        } catch {
            print("❌ Failed to save health data to Core Data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Leaderboard Integration
    func getStepsLeaderboardData(for dateRange: DateInterval) async -> [HealthLeaderboardEntry] {
        var entries: [HealthLeaderboardEntry] = []
        
        // This would integrate with CloudKit to get friends' data
        // For now, return mock data
        entries = [
            HealthLeaderboardEntry(
                userID: "user1",
                userName: "Sarah",
                steps: 12500,
                distance: 8.5,
                sleepHours: 7.5,
                rank: 1,
                isCurrentUser: false
            ),
            HealthLeaderboardEntry(
                userID: "current",
                userName: "You",
                steps: todaysSteps,
                distance: todaysDistance,
                sleepHours: todaysSleepHours,
                rank: 2,
                isCurrentUser: true
            ),
            HealthLeaderboardEntry(
                userID: "user2",
                userName: "Mike",
                steps: 8900,
                distance: 6.2,
                sleepHours: 6.8,
                rank: 3,
                isCurrentUser: false
            )
        ]
        
        return entries.sorted { $0.steps > $1.steps }
    }
    
    // MARK: - Health Insights
    func getHealthInsights() -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Step goal achievement
        let stepGoal = 10000
        if todaysSteps >= stepGoal {
            insights.append(HealthInsight(
                type: .achievement,
                title: "Step Goal Achieved! 🎉",
                description: "You've reached your daily step goal of \(stepGoal) steps",
                icon: "figure.walk"
            ))
        } else {
            let remaining = stepGoal - todaysSteps
            insights.append(HealthInsight(
                type: .motivation,
                title: "Keep Going! 💪",
                description: "Just \(remaining) more steps to reach your daily goal",
                icon: "figure.walk"
            ))
        }
        
        // Sleep quality
        if todaysSleepHours >= 7.0 {
            insights.append(HealthInsight(
                type: .achievement,
                title: "Great Sleep! 😴",
                description: "You got \(String(format: "%.1f", todaysSleepHours)) hours of sleep",
                icon: "bed.double"
            ))
        } else if todaysSleepHours < 6.0 {
            insights.append(HealthInsight(
                type: .warning,
                title: "Need More Sleep ⚠️",
                description: "Only \(String(format: "%.1f", todaysSleepHours)) hours of sleep. Aim for 7-9 hours",
                icon: "bed.double"
            ))
        }
        
        return insights
    }
}

// MARK: - Supporting Types
struct HealthLeaderboardEntry: Identifiable {
    let id = UUID()
    let userID: String
    let userName: String
    let steps: Int
    let distance: Double
    let sleepHours: Double
    let rank: Int
    let isCurrentUser: Bool
}

struct HealthInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let icon: String
}

enum InsightType {
    case achievement
    case motivation
    case warning
    case tip
}

// MARK: - Core Data Entity (Placeholder)
class HealthDataEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var steps: Int32
    @NSManaged var distance: Double
    @NSManaged var sleepHours: Double
    @NSManaged var lastUpdated: Date
}
