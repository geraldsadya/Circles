//
//  CoreDataMigration.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData

// MARK: - Core Data Migration Support

class CoreDataMigrationManager {
    static let shared = CoreDataMigrationManager()
    
    private init() {}
    
    /// Check if migration is needed
    func isMigrationNeeded(for storeURL: URL) -> Bool {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else {
            return false
        }
        
        let currentModel = PersistenceController.shared.container.managedObjectModel
        return !currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }
    
    /// Perform migration if needed
    func migrateStoreIfNeeded(at storeURL: URL) throws {
        guard isMigrationNeeded(for: storeURL) else {
            print("✅ No migration needed")
            return
        }
        
        print("🔄 Starting Core Data migration...")
        
        // Create backup
        let backupURL = storeURL.appendingPathExtension("backup")
        try FileManager.default.copyItem(at: storeURL, to: backupURL)
        
        do {
            // Perform migration
            try performMigration(from: storeURL, to: storeURL)
            print("✅ Migration completed successfully")
            
            // Remove backup
            try FileManager.default.removeItem(at: backupURL)
        } catch {
            print("❌ Migration failed: \(error)")
            
            // Restore backup
            try? FileManager.default.removeItem(at: storeURL)
            try FileManager.default.copyItem(at: backupURL, to: storeURL)
            try FileManager.default.removeItem(at: backupURL)
            
            throw error
        }
    }
    
    /// Perform the actual migration
    private func performMigration(from sourceURL: URL, to destinationURL: URL) throws {
        let sourceModel = try getSourceModel(for: sourceURL)
        let destinationModel = PersistenceController.shared.container.managedObjectModel
        
        // Create mapping model
        guard let mappingModel = NSMappingModel(from: [Bundle.main], forSourceModel: sourceModel, destinationModel: destinationModel) else {
            throw CoreDataMigrationError.mappingModelNotFound
        }
        
        // Create migration manager
        let migrationManager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        
        // Perform migration
        try migrationManager.migrateStore(from: sourceURL, sourceType: NSSQLiteStoreType, options: nil, with: mappingModel, toDestinationURL: destinationURL, destinationType: NSSQLiteStoreType, destinationOptions: nil)
    }
    
    /// Get source model for migration
    private func getSourceModel(for storeURL: URL) throws -> NSManagedObjectModel {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else {
            throw CoreDataMigrationError.metadataNotFound
        }
        
        guard let sourceModel = NSManagedObjectModel.mergedModel(from: [Bundle.main], forStoreMetadata: metadata) else {
            throw CoreDataMigrationError.sourceModelNotFound
        }
        
        return sourceModel
    }
}

// MARK: - Migration Errors

enum CoreDataMigrationError: Error, LocalizedError {
    case mappingModelNotFound
    case metadataNotFound
    case sourceModelNotFound
    case migrationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .mappingModelNotFound:
            return "Core Data mapping model not found"
        case .metadataNotFound:
            return "Core Data store metadata not found"
        case .sourceModelNotFound:
            return "Core Data source model not found"
        case .migrationFailed(let error):
            return "Core Data migration failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Core Data Model Versions

enum CoreDataModelVersion: String, CaseIterable {
    case version1 = "Circle"
    case version2 = "Circle_v2"
    case version3 = "Circle_v3"
    
    var versionNumber: Int {
        switch self {
        case .version1: return 1
        case .version2: return 2
        case .version3: return 3
        }
    }
    
    var modelName: String {
        return rawValue
    }
    
    var modelURL: URL? {
        return Bundle.main.url(forResource: modelName, withExtension: "momd")
    }
    
    var managedObjectModel: NSManagedObjectModel? {
        guard let modelURL = modelURL else { return nil }
        return NSManagedObjectModel(contentsOf: modelURL)
    }
}

// MARK: - Core Data Store Options

struct CoreDataStoreOptions {
    static let defaultOptions: [String: Any] = [
        NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        NSSQLitePragmasOption: ["journal_mode": "WAL"],
        NSSQLiteAnalyzeOption: true,
        NSSQLiteManualVacuumOption: true
    ]
    
    static let cloudKitOptions: [String: Any] = [
        NSPersistentStoreFileProtectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        NSSQLitePragmasOption: ["journal_mode": "WAL"],
        NSSQLiteAnalyzeOption: true,
        NSSQLiteManualVacuumOption: true,
        NSPersistentHistoryTrackingKey: true,
        NSPersistentStoreRemoteChangeNotificationPostOptionKey: true
    ]
    
    static let inMemoryOptions: [String: Any] = [
        NSPersistentStoreFileProtectionKey: FileProtectionType.none
    ]
}

// MARK: - Core Data Performance Monitoring

class CoreDataPerformanceMonitor {
    static let shared = CoreDataPerformanceMonitor()
    
    private var operationTimes: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "com.circle.coredata.performance", attributes: .concurrent)
    
    private init() {}
    
    /// Start timing an operation
    func startTiming(_ operation: String) {
        queue.async(flags: .barrier) {
            self.operationTimes[operation] = Date().timeIntervalSince1970
        }
    }
    
    /// End timing an operation
    func endTiming(_ operation: String) -> TimeInterval {
        let endTime = Date().timeIntervalSince1970
        
        return queue.sync(flags: .barrier) {
            guard let startTime = operationTimes[operation] else {
                return 0
            }
            
            let duration = endTime - startTime
            operationTimes.removeValue(forKey: operation)
            
            // Log performance if operation takes too long
            if duration > 1.0 {
                print("⚠️ Slow Core Data operation '\(operation)' took \(duration)s")
            }
            
            return duration
        }
    }
    
    /// Get performance statistics
    func getPerformanceStats() -> [String: TimeInterval] {
        return queue.sync {
            return operationTimes
        }
    }
}

// MARK: - Core Data Debugging

class CoreDataDebugger {
    static let shared = CoreDataDebugger()
    
    private init() {}
    
    /// Log Core Data context state
    func logContextState(_ context: NSManagedObjectContext) {
        print("📊 Core Data Context State:")
        print("   - Has changes: \(context.hasChanges)")
        print("   - Inserted objects: \(context.insertedObjects.count)")
        print("   - Updated objects: \(context.updatedObjects.count)")
        print("   - Deleted objects: \(context.deletedObjects.count)")
        print("   - Registered objects: \(context.registeredObjects.count)")
    }
    
    /// Log entity counts
    func logEntityCounts(in context: NSManagedObjectContext) {
        let entityNames = [
            "User", "Circle", "Challenge", "Proof", "HangoutSession",
            "PointsLedger", "LeaderboardEntry", "Membership", "Forfeit",
            "HangoutParticipant", "Device", "ChallengeTemplate", "WrappedStats",
            "ConsentLogEntity", "SuspiciousActivityEntity", "AnalyticsEventEntity"
        ]
        
        print("📈 Entity Counts:")
        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let count = try context.count(for: request)
                print("   - \(entityName): \(count)")
            } catch {
                print("   - \(entityName): Error counting (\(error.localizedDescription))")
            }
        }
    }
    
    /// Log Core Data store information
    func logStoreInfo(for storeURL: URL) {
        print("💾 Core Data Store Info:")
        print("   - URL: \(storeURL)")
        print("   - Exists: \(FileManager.default.fileExists(atPath: storeURL.path))")
        
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
                if let size = attributes[.size] as? Int64 {
                    print("   - Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                }
                if let modificationDate = attributes[.modificationDate] as? Date {
                    print("   - Last modified: \(modificationDate)")
                }
            } catch {
                print("   - Error getting attributes: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Core Data Validation

class CoreDataValidator {
    static let shared = CoreDataValidator()
    
    private init() {}
    
    /// Validate Core Data model
    func validateModel(_ model: NSManagedObjectModel) -> [String] {
        var issues: [String] = []
        
        // Check for duplicate entity names
        let entityNames = model.entities.map { $0.name ?? "Unknown" }
        let duplicateNames = Dictionary(grouping: entityNames, by: { $0 }).filter { $0.value.count > 1 }
        
        for (name, _) in duplicateNames {
            issues.append("Duplicate entity name: \(name)")
        }
        
        // Check for missing relationships
        for entity in model.entities {
            for relationship in entity.relationshipsByName.values {
                if relationship.destinationEntity == nil {
                    issues.append("Missing destination entity for relationship '\(relationship.name)' in entity '\(entity.name ?? "Unknown")'")
                }
            }
        }
        
        // Check for missing inverse relationships
        for entity in model.entities {
            for relationship in entity.relationshipsByName.values {
                if relationship.inverseRelationship == nil {
                    issues.append("Missing inverse relationship for '\(relationship.name)' in entity '\(entity.name ?? "Unknown")'")
                }
            }
        }
        
        return issues
    }
    
    /// Validate Core Data context
    func validateContext(_ context: NSManagedObjectContext) -> [String] {
        var issues: [String] = []
        
        // Check for validation errors
        for object in context.registeredObjects {
            if let managedObject = object as? NSManagedObject {
                do {
                    try managedObject.validateForInsert()
                    try managedObject.validateForUpdate()
                    try managedObject.validateForDelete()
                } catch {
                    issues.append("Validation error for \(type(of: managedObject)): \(error.localizedDescription)")
                }
            }
        }
        
        return issues
    }
}
