//
//  ChallengeTemplateManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class ChallengeTemplateManager: ObservableObject {
    static let shared = ChallengeTemplateManager()
    
    @Published var templates: [ChallengeTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadTemplates()
        createDefaultTemplatesIfNeeded()
    }
    
    // MARK: - Template Loading
    private func loadTemplates() {
        isLoading = true
        errorMessage = nil
        
        let request: NSFetchRequest<ChallengeTemplate> = ChallengeTemplate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChallengeTemplate.title, ascending: true)]
        
        do {
            templates = try persistenceController.container.viewContext.fetch(request)
            isLoading = false
        } catch {
            errorMessage = "Failed to load challenge templates: \(error.localizedDescription)"
            isLoading = false
            print("Error loading templates: \(error)")
        }
    }
    
    // MARK: - Default Templates Creation
    private func createDefaultTemplatesIfNeeded() {
        guard templates.isEmpty else { return }
        
        let context = persistenceController.container.viewContext
        
        // Gym Challenge Template
        let gymTemplate = ChallengeTemplate(context: context)
        gymTemplate.id = UUID()
        gymTemplate.title = "Gym Visit"
        gymTemplate.description = "Visit the gym for at least 20 minutes"
        gymTemplate.category = ChallengeCategory.fitness.rawValue
        gymTemplate.frequency = ChallengeFrequency.daily.rawValue
        gymTemplate.targetValue = 20.0
        gymTemplate.targetUnit = "minutes"
        gymTemplate.verificationMethod = VerificationMethod.location.rawValue
        gymTemplate.isPreset = true
        gymTemplate.localizedTitle = "Gym Visit"
        
        let gymParams = LocationChallengeParams(
            targetLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0), // Will be set by user
            radiusMeters: Verify.geofenceRadius,
            minDurationMinutes: Verify.minDwellGym,
            name: "Gym"
        )
        gymTemplate.verificationParams = try? JSONEncoder().encode(gymParams)
        
        // Running Challenge Template
        let runningTemplate = ChallengeTemplate(context: context)
        runningTemplate.id = UUID()
        runningTemplate.title = "Morning Run"
        runningTemplate.description = "Run at least 5,000 steps before 8 AM"
        runningTemplate.category = ChallengeCategory.fitness.rawValue
        runningTemplate.frequency = ChallengeFrequency.daily.rawValue
        runningTemplate.targetValue = 5000.0
        runningTemplate.targetUnit = "steps"
        runningTemplate.verificationMethod = VerificationMethod.motion.rawValue
        runningTemplate.isPreset = true
        runningTemplate.localizedTitle = "Morning Run"
        
        let runningParams = MotionChallengeParams(
            minSteps: 5000,
            activityType: "running",
            timeWindow: "morning",
            minDistance: nil
        )
        runningTemplate.verificationParams = try? JSONEncoder().encode(runningParams)
        
        // Screen Time Challenge Template
        let screenTimeTemplate = ChallengeTemplate(context: context)
        screenTimeTemplate.id = UUID()
        screenTimeTemplate.title = "Screen Time Limit"
        screenTimeTemplate.description = "Keep screen time under 2 hours today"
        screenTimeTemplate.category = ChallengeCategory.screenTime.rawValue
        screenTimeTemplate.frequency = ChallengeFrequency.daily.rawValue
        screenTimeTemplate.targetValue = 2.0
        screenTimeTemplate.targetUnit = "hours"
        screenTimeTemplate.verificationMethod = VerificationMethod.screenTime.rawValue
        screenTimeTemplate.isPreset = true
        screenTimeTemplate.localizedTitle = "Screen Time Limit"
        
        let screenTimeParams = ScreenTimeChallengeParams(
            maxHours: 2.0,
            categories: ["social", "entertainment"]
        )
        screenTimeTemplate.verificationParams = try? JSONEncoder().encode(screenTimeParams)
        
        // Sleep Challenge Template
        let sleepTemplate = ChallengeTemplate(context: context)
        sleepTemplate.id = UUID()
        sleepTemplate.title = "Early Bedtime"
        sleepTemplate.description = "Go to sleep before 11 PM"
        sleepTemplate.category = ChallengeCategory.sleep.rawValue
        sleepTemplate.frequency = ChallengeFrequency.daily.rawValue
        sleepTemplate.targetValue = 23.0
        sleepTemplate.targetUnit = "time"
        sleepTemplate.verificationMethod = VerificationMethod.health.rawValue
        sleepTemplate.isPreset = true
        sleepTemplate.localizedTitle = "Early Bedtime"
        
        let sleepParams = SleepChallengeParams(
            bedtimeBefore: "23:00",
            wakeupAfter: "07:00",
            minHours: 7.0
        )
        sleepTemplate.verificationParams = try? JSONEncoder().encode(sleepParams)
        
        // Social Challenge Template
        let socialTemplate = ChallengeTemplate(context: context)
        socialTemplate.id = UUID()
        socialTemplate.title = "Friend Hangout"
        socialTemplate.description = "Spend at least 30 minutes with friends"
        socialTemplate.category = ChallengeCategory.social.rawValue
        socialTemplate.frequency = ChallengeFrequency.daily.rawValue
        socialTemplate.targetValue = 30.0
        socialTemplate.targetUnit = "minutes"
        socialTemplate.verificationMethod = VerificationMethod.location.rawValue
        socialTemplate.isPreset = true
        socialTemplate.localizedTitle = "Friend Hangout"
        
        let socialParams = LocationChallengeParams(
            targetLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0), // Will be set by user
            radiusMeters: Verify.hangoutProximity,
            minDurationMinutes: 30.0,
            name: "Hangout Location"
        )
        socialTemplate.verificationParams = try? JSONEncoder().encode(socialParams)
        
        // Save context
        do {
            try context.save()
            loadTemplates() // Reload to get the new templates
        } catch {
            errorMessage = "Failed to create default templates: \(error.localizedDescription)"
            print("Error creating default templates: \(error)")
        }
    }
    
    // MARK: - Template Management
    func createCustomTemplate(
        title: String,
        description: String?,
        category: ChallengeCategory,
        frequency: ChallengeFrequency,
        targetValue: Double,
        targetUnit: String,
        verificationMethod: VerificationMethod,
        verificationParams: Data
    ) -> ChallengeTemplate? {
        let context = persistenceController.container.viewContext
        
        let template = ChallengeTemplate(context: context)
        template.id = UUID()
        template.title = title
        template.description = description
        template.category = category.rawValue
        template.frequency = frequency.rawValue
        template.targetValue = targetValue
        template.targetUnit = targetUnit
        template.verificationMethod = verificationMethod.rawValue
        template.verificationParams = verificationParams
        template.isPreset = false
        template.localizedTitle = title
        
        do {
            try context.save()
            loadTemplates()
            return template
        } catch {
            errorMessage = "Failed to create custom template: \(error.localizedDescription)"
            print("Error creating custom template: \(error)")
            return nil
        }
    }
    
    func deleteTemplate(_ template: ChallengeTemplate) {
        let context = persistenceController.container.viewContext
        context.delete(template)
        
        do {
            try context.save()
            loadTemplates()
        } catch {
            errorMessage = "Failed to delete template: \(error.localizedDescription)"
            print("Error deleting template: \(error)")
        }
    }
    
    func updateTemplate(_ template: ChallengeTemplate) {
        let context = persistenceController.container.viewContext
        
        do {
            try context.save()
            loadTemplates()
        } catch {
            errorMessage = "Failed to update template: \(error.localizedDescription)"
            print("Error updating template: \(error)")
        }
    }
    
    // MARK: - Template Filtering
    func templates(for category: ChallengeCategory) -> [ChallengeTemplate] {
        return templates.filter { $0.category == category.rawValue }
    }
    
    func presetTemplates() -> [ChallengeTemplate] {
        return templates.filter { $0.isPreset }
    }
    
    func customTemplates() -> [ChallengeTemplate] {
        return templates.filter { !$0.isPreset }
    }
    
    // MARK: - Template Validation
    func validateTemplate(
        title: String,
        targetValue: Double,
        verificationMethod: VerificationMethod,
        verificationParams: Data?
    ) -> ValidationResult {
        var errors: [String] = []
        
        // Title validation
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Title cannot be empty")
        }
        
        if title.count > 50 {
            errors.append("Title must be 50 characters or less")
        }
        
        // Target value validation
        if targetValue <= 0 {
            errors.append("Target value must be greater than 0")
        }
        
        // Verification method specific validation
        switch verificationMethod {
        case .location:
            if let params = verificationParams,
               let locationParams = try? JSONDecoder().decode(LocationChallengeParams.self, from: params) {
                if locationParams.radiusMeters <= 0 {
                    errors.append("Geofence radius must be greater than 0")
                }
                if locationParams.minDurationMinutes <= 0 {
                    errors.append("Minimum duration must be greater than 0")
                }
            } else {
                errors.append("Invalid location verification parameters")
            }
            
        case .motion:
            if let params = verificationParams,
               let motionParams = try? JSONDecoder().decode(MotionChallengeParams.self, from: params) {
                if motionParams.minSteps <= 0 {
                    errors.append("Minimum steps must be greater than 0")
                }
            } else {
                errors.append("Invalid motion verification parameters")
            }
            
        case .screenTime:
            if let params = verificationParams,
               let screenTimeParams = try? JSONDecoder().decode(ScreenTimeChallengeParams.self, from: params) {
                if screenTimeParams.maxHours <= 0 {
                    errors.append("Maximum screen time must be greater than 0")
                }
            } else {
                errors.append("Invalid screen time verification parameters")
            }
            
        case .health:
            if let params = verificationParams,
               let sleepParams = try? JSONDecoder().decode(SleepChallengeParams.self, from: params) {
                if sleepParams.minHours != nil && sleepParams.minHours! <= 0 {
                    errors.append("Minimum sleep hours must be greater than 0")
                }
            } else {
                errors.append("Invalid health verification parameters")
            }
            
        case .camera:
            if let params = verificationParams,
               let cameraParams = try? JSONDecoder().decode(CameraChallengeParams.self, from: params) {
                if cameraParams.durationSeconds <= 0 {
                    errors.append("Camera duration must be greater than 0")
                }
            } else {
                errors.append("Invalid camera verification parameters")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
}

// MARK: - Supporting Types
struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

// MARK: - Core Data Extensions
extension ChallengeTemplate {
    static func fetchRequest() -> NSFetchRequest<ChallengeTemplate> {
        return NSFetchRequest<ChallengeTemplate>(entityName: "ChallengeTemplate")
    }
    
    var categoryEnum: ChallengeCategory? {
        return ChallengeCategory(rawValue: category ?? "")
    }
    
    var frequencyEnum: ChallengeFrequency? {
        return ChallengeFrequency(rawValue: frequency ?? "")
    }
    
    var verificationMethodEnum: VerificationMethod? {
        return VerificationMethod(rawValue: verificationMethod ?? "")
    }
    
    func getVerificationParams<T: Codable>(as type: T.Type) -> T? {
        guard let data = verificationParams else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
