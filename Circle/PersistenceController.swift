//
//  PersistenceController.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import CoreData
import CloudKit
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        createSampleData(in: viewContext)
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Circle")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure persistent store
        configurePersistentStore()
        
        // Load persistent stores
        loadPersistentStores()
        
        // Configure view context
        configureViewContext()
    }
    
    // MARK: - Configuration
    private func configurePersistentStore() {
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Enable CloudKit integration
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Configure CloudKit container
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: CloudKitConfiguration.containerIdentifier
        )
        
        // Configure store options
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        // Set store type
        if description.url?.path.contains("/dev/null") == true {
            description.type = NSInMemoryStoreType
        } else {
            description.type = NSSQLiteStoreType
        }
    }
    
    private func loadPersistentStores() {
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                // Handle Core Data errors gracefully
                self?.handleCoreDataError(error)
            }
        }
    }
    
    private func configureViewContext() {
        let viewContext = container.viewContext
        
        // Enable automatic merging
        viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure merge policy
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set undo manager
        viewContext.undoManager = nil
        
        // Configure fetch request templates
        configureFetchRequestTemplates()
    }
    
    private func configureFetchRequestTemplates() {
        // Configure common fetch request templates
        let context = container.viewContext
        
        // User fetch template
        let userTemplate = NSFetchRequest<User>(entityName: "User")
        userTemplate.returnsObjectsAsFaults = false
        userTemplate.fetchBatchSize = 20
        
        // Circle fetch template
        let circleTemplate = NSFetchRequest<Circle>(entityName: "Circle")
        circleTemplate.returnsObjectsAsFaults = false
        circleTemplate.fetchBatchSize = 20
        
        // Challenge fetch template
        let challengeTemplate = NSFetchRequest<Challenge>(entityName: "Challenge")
        challengeTemplate.returnsObjectsAsFaults = false
        challengeTemplate.fetchBatchSize = 20
    }
    
    // MARK: - Error Handling
    private func handleCoreDataError(_ error: NSError) {
        switch error.code {
        case NSPersistentStoreIncompatibleVersionHashError:
            // Handle schema migration
            handleSchemaMigration()
        case NSPersistentStoreIncompatibleSchemaError:
            // Handle incompatible schema
            handleIncompatibleSchema()
        case NSPersistentStoreCannotLoadError:
            // Handle store loading error
            handleStoreLoadingError()
        default:
            // Log unknown error
            print("Unknown Core Data error: \(error.localizedDescription)")
        }
    }
    
    private func handleSchemaMigration() {
        // Implement lightweight migration
        print("Handling schema migration...")
        
        // This would implement proper migration logic
        // For now, we'll rely on automatic migration
    }
    
    private func handleIncompatibleSchema() {
        // Handle incompatible schema
        print("Handling incompatible schema...")
        
        // This would implement schema compatibility handling
    }
    
    private func handleStoreLoadingError() {
        // Handle store loading error
        print("Handling store loading error...")
        
        // This would implement store recovery logic
    }
    
    // MARK: - Data Operations
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveContext() {
        save()
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
    
    // MARK: - CloudKit Operations
    func syncWithCloudKit() async {
        do {
            try await container.viewContext.perform {
                try self.container.viewContext.save()
            }
        } catch {
            print("CloudKit sync error: \(error)")
        }
    }
    
    // MARK: - Sample Data
    private static func createSampleData(in context: NSManagedObjectContext) {
        // Create sample user
        let sampleUser = User.create(in: context, appleUserID: "sample-user-123", displayName: "Alex")
        sampleUser.profileEmoji = "🚀"
        sampleUser.totalPoints = 150
        sampleUser.weeklyPoints = 45
        
        // Create sample circle
        let sampleCircle = Circle.create(in: context, name: "Fitness Buddies")
        
        // Create sample challenge
        let sampleChallenge = Challenge.create(in: context, title: "Daily Steps", category: "fitness", verificationMethod: "motion")
        sampleChallenge.descriptionText = "Walk 10,000 steps every day"
        sampleChallenge.targetValue = 10000
        sampleChallenge.targetUnit = "steps"
        sampleChallenge.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        sampleChallenge.pointsReward = 10
        sampleChallenge.pointsPenalty = -5
        
        // Create sample proof
        let sampleProof = Proof.create(in: context, isVerified: true, confidenceScore: 0.95, verificationMethod: "motion")
        sampleProof.notes = "Completed 10,000 steps"
        sampleProof.pointsAwarded = 10
        
        // Create sample hangout session
        let sampleHangout = HangoutSession.create(in: context, startTime: Date())
        sampleHangout.endTime = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
        sampleHangout.duration = 1800
        sampleHangout.pointsAwarded = 15
        
        // Create sample points ledger entry
        let samplePoints = PointsLedger.create(in: context, points: 10, reason: "Daily Steps completed")
        
        // Create sample leaderboard entry
        let sampleLeaderboard = LeaderboardEntry.create(
            in: context,
            points: 45,
            rank: 1,
            weekStarting: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            weekEnding: Date()
        )
        
        // Create sample membership
        let sampleMembership = Membership.create(in: context, role: "owner")
        
        // Create sample forfeit
        let sampleForfeit = Forfeit.create(in: context, type: "camera", descriptionText: "Take a selfie with your workout gear")
        
        // Create sample device
        let sampleDevice = Device.create(in: context, model: "iPhone 15 Pro", osVersion: "17.0")
        
        // Create sample challenge template
        let sampleTemplate = ChallengeTemplate.create(in: context, title: "Gym Visit", category: "fitness", verificationMethod: "location", isPreset: true)
        sampleTemplate.descriptionText = "Visit the gym for at least 30 minutes"
        sampleTemplate.targetValue = 30
        sampleTemplate.targetUnit = "minutes"
        sampleTemplate.frequency = "weekly"
        
        // Create sample wrapped stats
        let sampleWrapped = WrappedStats.create(in: context, year: 2024)
        
        // Create sample consent log
        let sampleConsent = ConsentLogEntity.create(in: context, permissionType: "location", currentStatus: "granted")
        sampleConsent.userAction = "granted"
        sampleConsent.reason = "User granted location permission during onboarding"
        
        // Create sample suspicious activity
        let sampleSuspicious = SuspiciousActivityEntity.create(in: context, type: "clock_tampering", severity: "medium", description: "Detected potential clock tampering")
        
        // Create sample analytics event
        let sampleAnalytics = AnalyticsEventEntity.create(in: context, name: "app_launch", metadata: ["version": "1.0.0"])
        
        // Set up relationships
        sampleChallenge.circle = sampleCircle
        sampleChallenge.createdBy = sampleUser
        sampleChallenge.template = sampleTemplate
        sampleChallenge.proofs = NSSet(object: sampleProof)
        
        sampleProof.challenge = sampleChallenge
        sampleProof.user = sampleUser
        
        sampleHangout.circle = sampleCircle
        
        samplePoints.user = sampleUser
        samplePoints.challenge = sampleChallenge
        
        sampleLeaderboard.user = sampleUser
        sampleLeaderboard.circle = sampleCircle
        
        sampleMembership.user = sampleUser
        sampleMembership.circle = sampleCircle
        
        sampleForfeit.assignedTo = sampleUser
        sampleForfeit.circle = sampleCircle
        
        sampleDevice.user = sampleUser
        
        sampleTemplate.challenges = NSSet(object: sampleChallenge)
        
        sampleWrapped.user = sampleUser
        
        // Add to collections
        sampleUser.createdChallenges = NSSet(object: sampleChallenge)
        sampleUser.proofs = NSSet(object: sampleProof)
        sampleUser.pointsLedger = NSSet(object: samplePoints)
        sampleUser.leaderboardEntries = NSSet(object: sampleLeaderboard)
        sampleUser.memberships = NSSet(object: sampleMembership)
        sampleUser.forfeits = NSSet(object: sampleForfeit)
        sampleUser.devices = NSSet(object: sampleDevice)
        sampleUser.wrappedStats = NSSet(object: sampleWrapped)
        
        sampleCircle.challenges = NSSet(object: sampleChallenge)
        sampleCircle.leaderboardEntries = NSSet(object: sampleLeaderboard)
        sampleCircle.memberships = NSSet(object: sampleMembership)
        sampleCircle.forfeits = NSSet(object: sampleForfeit)
        sampleCircle.hangoutSessions = NSSet(object: sampleHangout)
    }
    
    // MARK: - Debugging
    func printCoreDataStats() {
        let context = container.viewContext
        
        // Print entity counts
        let entities = [
            "User", "Circle", "Challenge", "Proof", "HangoutSession", 
            "PointsLedger", "LeaderboardEntry", "Membership", "Forfeit",
            "HangoutParticipant", "Device", "ChallengeTemplate", "WrappedStats",
            "ConsentLogEntity", "SuspiciousActivityEntity", "AnalyticsEventEntity"
        ]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            do {
                let count = try context.count(for: request)
                print("\(entityName): \(count) records")
            } catch {
                print("Error counting \(entityName): \(error)")
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        // Clean up old data
        let context = container.viewContext
        
        // Delete old analytics events (older than 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let request: NSFetchRequest<AnalyticsEventEntity> = AnalyticsEventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", thirtyDaysAgo as NSDate)
        
        do {
            let oldEvents = try context.fetch(request)
            for event in oldEvents {
                context.delete(event)
            }
            try context.save()
        } catch {
            print("Error cleaning up old analytics events: \(error)")
        }
    }
}
