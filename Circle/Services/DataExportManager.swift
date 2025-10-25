//
//  DataExportManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class DataExportManager: ObservableObject {
    static let shared = DataExportManager()
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportHistory: [DataExport] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    // Export configuration
    private let exportConfig = DataExportConfiguration()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadExportHistory()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func loadExportHistory() {
        let request: NSFetchRequest<DataExportEntity> = DataExportEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DataExportEntity.createdAt, ascending: false)]
        request.fetchLimit = 50
        
        do {
            let entities = try persistenceController.container.viewContext.fetch(request)
            exportHistory = entities.map { entity in
                DataExport(
                    id: entity.id ?? UUID(),
                    exportType: DataExportType(rawValue: entity.exportType ?? "full") ?? .full,
                    fileSize: Int(entity.fileSize),
                    recordCount: Int(entity.recordCount),
                    exportedAt: entity.exportedAt ?? Date(),
                    schemaVersion: entity.schemaVersion ?? "1.0",
                    isCompressed: entity.isCompressed,
                    checksum: entity.checksum ?? ""
                )
            }
        } catch {
            logExport("Error loading export history: \(error)")
        }
    }
    
    // MARK: - Export Functions
    func exportUserData(exportType: DataExportType = .full) async -> Data? {
        guard !isExporting else { return nil }
        
        isExporting = true
        exportProgress = 0.0
        
        do {
            let exportData = try await createExportData(exportType: exportType)
            let jsonData = try JSONEncoder().encode(exportData)
            
            // Compress if needed
            let finalData = exportConfig.compressExports ? try compressData(jsonData) : jsonData
            
            // Save export record
            try await saveExportRecord(exportData: finalData, exportType: exportType)
            
            exportProgress = 1.0
            isExporting = false
            
            logExport("Successfully exported user data")
            return finalData
            
        } catch {
            isExporting = false
            errorMessage = "Export failed: \(error.localizedDescription)"
            logExport("Export failed: \(error)")
            return nil
        }
    }
    
    private func createExportData(exportType: DataExportType) async throws -> CircleExportData {
        var recordCount = 0
        
        // Export user data
        let userData = try await exportUserData()
        recordCount += userData.count
        
        exportProgress = 0.2
        
        // Export circles
        let circleData = try await exportCircleData()
        recordCount += circleData.count
        
        exportProgress = 0.4
        
        // Export challenges
        let challengeData = try await exportChallengeData()
        recordCount += challengeData.count
        
        exportProgress = 0.6
        
        // Export hangouts
        let hangoutData = try await exportHangoutData()
        recordCount += hangoutData.count
        
        exportProgress = 0.8
        
        // Export points
        let pointsData = try await exportPointsData()
        recordCount += pointsData.count
        
        exportProgress = 0.9
        
        // Create export metadata
        let metadata = ExportMetadata(
            exportVersion: "1.0",
            exportDate: Date(),
            exportType: exportType,
            recordCount: recordCount,
            schemaVersion: "1.0",
            appVersion: getAppVersion(),
            deviceInfo: getDeviceInfo()
        )
        
        return CircleExportData(
            metadata: metadata,
            users: userData,
            circles: circleData,
            challenges: challengeData,
            hangouts: hangoutData,
            points: pointsData,
            privacySettings: try await exportPrivacySettings(),
            consentLogs: try await exportConsentLogs()
        )
    }
    
    // MARK: - Data Export Methods
    private func exportUserData() async throws -> [UserExport] {
        let request: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try persistenceController.container.viewContext.fetch(request)
            return users.map { user in
                UserExport(
                    id: user.id?.uuidString ?? "",
                    name: user.name ?? "",
                    email: user.email ?? "",
                    createdAt: user.createdAt ?? Date(),
                    lastActiveAt: user.lastActiveAt ?? Date(),
                    isActive: user.isActive,
                    preferences: UserPreferencesExport(
                        notificationsEnabled: user.notificationsEnabled,
                        privacyLevel: user.privacyLevel ?? "standard",
                        theme: user.theme ?? "system"
                    )
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    private func exportCircleData() async throws -> [CircleExport] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        
        do {
            let circles = try persistenceController.container.viewContext.fetch(request)
            return circles.map { circle in
                CircleExport(
                    id: circle.id?.uuidString ?? "",
                    name: circle.name ?? "",
                    description: circle.description ?? "",
                    createdAt: circle.createdAt ?? Date(),
                    isActive: circle.isActive,
                    memberCount: Int(circle.memberCount),
                    settings: CircleSettingsExport(
                        isPublic: circle.isPublic,
                        allowInvites: circle.allowInvites,
                        requireApproval: circle.requireApproval
                    )
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    private func exportChallengeData() async throws -> [ChallengeExport] {
        let request: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        
        do {
            let challenges = try persistenceController.container.viewContext.fetch(request)
            return challenges.map { challenge in
                ChallengeExport(
                    id: challenge.id?.uuidString ?? "",
                    name: challenge.name ?? "",
                    description: challenge.description ?? "",
                    category: challenge.category ?? "",
                    targetValue: challenge.targetValue,
                    targetUnit: challenge.targetUnit ?? "",
                    startDate: challenge.startDate ?? Date(),
                    endDate: challenge.endDate ?? Date(),
                    isActive: challenge.isActive,
                    verificationMethod: challenge.verificationMethod ?? "",
                    results: try await exportChallengeResults(for: challenge)
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    private func exportChallengeResults(for challenge: Challenge) async throws -> [ChallengeResultExport] {
        let request: NSFetchRequest<ChallengeResult> = ChallengeResult.fetchRequest()
        request.predicate = NSPredicate(format: "challenge == %@", challenge)
        
        do {
            let results = try persistenceController.container.viewContext.fetch(request)
            return results.map { result in
                ChallengeResultExport(
                    id: result.id?.uuidString ?? "",
                    challengeId: challenge.id?.uuidString ?? "",
                    userId: result.user?.id?.uuidString ?? "",
                    isCompleted: result.isCompleted,
                    completedAt: result.completedAt,
                    pointsEarned: Int(result.pointsEarned),
                    verificationMethod: result.verificationMethod ?? "",
                    confidence: result.confidence
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    private func exportHangoutData() async throws -> [HangoutExport] {
        let request: NSFetchRequest<HangoutSession> = HangoutSession.fetchRequest()
        
        do {
            let hangouts = try persistenceController.container.viewContext.fetch(request)
            return hangouts.map { hangout in
                HangoutExport(
                    id: hangout.id?.uuidString ?? "",
                    startTime: hangout.startTime ?? Date(),
                    endTime: hangout.endTime,
                    duration: hangout.duration,
                    location: HangoutLocationExport(
                        latitude: hangout.latitude,
                        longitude: hangout.longitude,
                        accuracy: hangout.accuracy
                    ),
                    participants: try await exportHangoutParticipants(for: hangout),
                    pointsEarned: Int(hangout.pointsEarned)
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    private func exportHangoutParticipants(for hangout: HangoutSession) async throws -> [HangoutParticipantExport] {
        let request: NSFetchRequest<HangoutParticipant> = HangoutParticipant.fetchRequest()
        request.predicate = NSPredicate(format: "session == %@", hangout)
        
        do {
            let participants = try persistenceController.container.viewContext.fetch(request)
            return participants.map { participant in
                HangoutParticipantExport(
                    id: participant.id?.uuidString ?? "",
                    userId: participant.user?.id?.uuidString ?? "",
                    joinedAt: participant.joinedAt ?? Date(),
                    leftAt: participant.leftAt,
                    duration: participant.duration
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    private func exportPointsData() async throws -> [PointsExport] {
        let request: NSFetchRequest<PointsLedger> = PointsLedger.fetchRequest()
        
        do {
            let points = try persistenceController.container.viewContext.fetch(request)
            return points.map { point in
                PointsExport(
                    id: point.id?.uuidString ?? "",
                    userId: point.user?.id?.uuidString ?? "",
                    points: Int(point.points),
                    category: point.category ?? "",
                    reason: point.reason ?? "",
                    timestamp: point.timestamp ?? Date(),
                    metadata: point.metadata
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    private func exportPrivacySettings() async throws -> PrivacySettingsExport {
        // Export privacy settings
        return PrivacySettingsExport(
            preciseLocationEnabled: UserDefaults.standard.bool(forKey: "precise_location_enabled"),
            analyticsEnabled: UserDefaults.standard.bool(forKey: "analytics_enabled"),
            crashReportingEnabled: UserDefaults.standard.bool(forKey: "crash_reporting_enabled"),
            dataRetentionDays: UserDefaults.standard.integer(forKey: "data_retention_days")
        )
    }
    
    private func exportConsentLogs() async throws -> [ConsentLogExport] {
        let request: NSFetchRequest<ConsentLog> = ConsentLog.fetchRequest()
        
        do {
            let logs = try persistenceController.container.viewContext.fetch(request)
            return logs.map { log in
                ConsentLogExport(
                    id: log.id?.uuidString ?? "",
                    permissionType: log.permissionType ?? "",
                    granted: log.granted,
                    timestamp: log.timestamp ?? Date(),
                    reason: log.reason ?? ""
                )
            }
        } catch {
            throw DataExportError.dataRetrievalFailed
        }
    }
    
    // MARK: - Data Compression
    private func compressData(_ data: Data) throws -> Data {
        return try data.compressed(using: .lzfse)
    }
    
    private func decompressData(_ data: Data) throws -> Data {
        return try data.decompressed(using: .lzfse)
    }
    
    // MARK: - Export Record Management
    private func saveExportRecord(exportData: Data, exportType: DataExportType) async throws {
        let context = persistenceController.container.viewContext
        
        let exportEntity = DataExportEntity(context: context)
        exportEntity.id = UUID()
        exportEntity.exportType = exportType.rawValue
        exportEntity.fileSize = Int32(exportData.count)
        exportEntity.recordCount = Int32(0) // Would calculate actual count
        exportEntity.exportedAt = Date()
        exportEntity.schemaVersion = "1.0"
        exportEntity.isCompressed = exportConfig.compressExports
        exportEntity.checksum = calculateChecksum(exportData)
        exportEntity.createdAt = Date()
        
        try context.save()
        
        // Add to history
        let export = DataExport(
            id: exportEntity.id ?? UUID(),
            exportType: exportType,
            fileSize: Int(exportEntity.fileSize),
            recordCount: Int(exportEntity.recordCount),
            exportedAt: exportEntity.exportedAt ?? Date(),
            schemaVersion: exportEntity.schemaVersion ?? "1.0",
            isCompressed: exportEntity.isCompressed,
            checksum: exportEntity.checksum ?? ""
        )
        
        exportHistory.insert(export, at: 0)
    }
    
    private func calculateChecksum(_ data: Data) -> String {
        return data.sha256
    }
    
    // MARK: - Data Validation
    func validateExportData(_ data: Data) -> ValidationResult {
        do {
            let exportData = try JSONDecoder().decode(CircleExportData.self, from: data)
            return validateExportStructure(exportData)
        } catch {
            return ValidationResult(
                isValid: false,
                errors: ["Invalid JSON format: \(error.localizedDescription)"],
                warnings: []
            )
        }
    }
    
    private func validateExportStructure(_ exportData: CircleExportData) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Validate metadata
        if exportData.metadata.exportVersion.isEmpty {
            errors.append("Missing export version")
        }
        
        if exportData.metadata.schemaVersion.isEmpty {
            errors.append("Missing schema version")
        }
        
        // Validate user data
        if exportData.users.isEmpty {
            warnings.append("No user data found")
        }
        
        // Validate circle data
        if exportData.circles.isEmpty {
            warnings.append("No circle data found")
        }
        
        // Validate challenge data
        if exportData.challenges.isEmpty {
            warnings.append("No challenge data found")
        }
        
        // Validate data consistency
        let challengeIds = Set(exportData.challenges.map { $0.id })
        let resultChallengeIds = Set(exportData.challenges.flatMap { $0.results.map { $0.challengeId } })
        
        if !resultChallengeIds.isSubset(of: challengeIds) {
            errors.append("Challenge results reference non-existent challenges")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Data Import
    func importUserData(_ data: Data) async throws -> ImportResult {
        let exportData = try JSONDecoder().decode(CircleExportData.self, from: data)
        
        // Validate import data
        let validation = validateExportStructure(exportData)
        if !validation.isValid {
            throw DataExportError.invalidImportData
        }
        
        // Import data
        let context = persistenceController.container.viewContext
        
        // Import users
        for userExport in exportData.users {
            let user = User(context: context)
            user.id = UUID(uuidString: userExport.id)
            user.name = userExport.name
            user.email = userExport.email
            user.createdAt = userExport.createdAt
            user.lastActiveAt = userExport.lastActiveAt
            user.isActive = userExport.isActive
            user.notificationsEnabled = userExport.preferences.notificationsEnabled
            user.privacyLevel = userExport.preferences.privacyLevel
            user.theme = userExport.preferences.theme
        }
        
        // Import circles
        for circleExport in exportData.circles {
            let circle = Circle(context: context)
            circle.id = UUID(uuidString: circleExport.id)
            circle.name = circleExport.name
            circle.description = circleExport.description
            circle.createdAt = circleExport.createdAt
            circle.isActive = circleExport.isActive
            circle.memberCount = Int32(circleExport.memberCount)
            circle.isPublic = circleExport.settings.isPublic
            circle.allowInvites = circleExport.settings.allowInvites
            circle.requireApproval = circleExport.settings.requireApproval
        }
        
        // Import challenges
        for challengeExport in exportData.challenges {
            let challenge = Challenge(context: context)
            challenge.id = UUID(uuidString: challengeExport.id)
            challenge.name = challengeExport.name
            challenge.description = challengeExport.description
            challenge.category = challengeExport.category
            challenge.targetValue = challengeExport.targetValue
            challenge.targetUnit = challengeExport.targetUnit
            challenge.startDate = challengeExport.startDate
            challenge.endDate = challengeExport.endDate
            challenge.isActive = challengeExport.isActive
            challenge.verificationMethod = challengeExport.verificationMethod
        }
        
        // Import challenge results
        for challengeExport in exportData.challenges {
            for resultExport in challengeExport.results {
                let result = ChallengeResult(context: context)
                result.id = UUID(uuidString: resultExport.id)
                result.isCompleted = resultExport.isCompleted
                result.completedAt = resultExport.completedAt
                result.pointsEarned = Int32(resultExport.pointsEarned)
                result.verificationMethod = resultExport.verificationMethod
                result.confidence = resultExport.confidence
            }
        }
        
        // Import hangouts
        for hangoutExport in exportData.hangouts {
            let hangout = HangoutSession(context: context)
            hangout.id = UUID(uuidString: hangoutExport.id)
            hangout.startTime = hangoutExport.startTime
            hangout.endTime = hangoutExport.endTime
            hangout.duration = hangoutExport.duration
            hangout.latitude = hangoutExport.location.latitude
            hangout.longitude = hangoutExport.location.longitude
            hangout.accuracy = hangoutExport.location.accuracy
            hangout.pointsEarned = Int32(hangoutExport.pointsEarned)
        }
        
        // Import points
        for pointsExport in exportData.points {
            let points = PointsLedger(context: context)
            points.id = UUID(uuidString: pointsExport.id)
            points.points = Int32(pointsExport.points)
            points.category = pointsExport.category
            points.reason = pointsExport.reason
            points.timestamp = pointsExport.timestamp
            points.metadata = pointsExport.metadata
        }
        
        try context.save()
        
        return ImportResult(
            success: true,
            importedRecords: exportData.metadata.recordCount,
            errors: [],
            warnings: validation.warnings
        )
    }
    
    // MARK: - Helper Methods
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model) \(device.systemName) \(device.systemVersion)"
    }
    
    private func logExport(_ message: String) {
        print("[DataExport] \(message)")
    }
    
    // MARK: - Analytics
    func getExportStats() -> DataExportStats {
        return DataExportStats(
            totalExports: exportHistory.count,
            totalFileSize: exportHistory.reduce(0) { $0 + $1.fileSize },
            averageFileSize: calculateAverageFileSize(),
            mostRecentExport: exportHistory.first?.exportedAt,
            exportTrend: getExportTrend(),
            compressionRatio: calculateCompressionRatio()
        )
    }
    
    private func calculateAverageFileSize() -> Int {
        guard !exportHistory.isEmpty else { return 0 }
        return exportHistory.reduce(0) { $0 + $1.fileSize } / exportHistory.count
    }
    
    private func getExportTrend() -> ExportTrend {
        let recentExports = exportHistory.filter { $0.exportedAt.timeIntervalSinceNow > -7 * 24 * 3600 }
        let olderExports = exportHistory.filter { $0.exportedAt.timeIntervalSinceNow <= -7 * 24 * 3600 }
        
        if recentExports.count > olderExports.count {
            return .increasing
        } else if recentExports.count < olderExports.count {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateCompressionRatio() -> Double {
        let compressedExports = exportHistory.filter { $0.isCompressed }
        guard !compressedExports.isEmpty else { return 0 }
        
        // This would calculate actual compression ratio
        return 0.7 // Placeholder
    }
}

// MARK: - Supporting Types
struct CircleExportData: Codable {
    let metadata: ExportMetadata
    let users: [UserExport]
    let circles: [CircleExport]
    let challenges: [ChallengeExport]
    let hangouts: [HangoutExport]
    let points: [PointsExport]
    let privacySettings: PrivacySettingsExport
    let consentLogs: [ConsentLogExport]
}

struct ExportMetadata: Codable {
    let exportVersion: String
    let exportDate: Date
    let exportType: DataExportType
    let recordCount: Int
    let schemaVersion: String
    let appVersion: String
    let deviceInfo: String
}

enum DataExportType: String, CaseIterable, Codable {
    case full = "full"
    case partial = "partial"
    case privacy = "privacy"
    case analytics = "analytics"
    
    var displayName: String {
        switch self {
        case .full: return "Full Export"
        case .partial: return "Partial Export"
        case .privacy: return "Privacy Export"
        case .analytics: return "Analytics Export"
        }
    }
}

struct UserExport: Codable {
    let id: String
    let name: String
    let email: String
    let createdAt: Date
    let lastActiveAt: Date
    let isActive: Bool
    let preferences: UserPreferencesExport
}

struct UserPreferencesExport: Codable {
    let notificationsEnabled: Bool
    let privacyLevel: String
    let theme: String
}

struct CircleExport: Codable {
    let id: String
    let name: String
    let description: String
    let createdAt: Date
    let isActive: Bool
    let memberCount: Int
    let settings: CircleSettingsExport
}

struct CircleSettingsExport: Codable {
    let isPublic: Bool
    let allowInvites: Bool
    let requireApproval: Bool
}

struct ChallengeExport: Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let targetValue: Double
    let targetUnit: String
    let startDate: Date
    let endDate: Date
    let isActive: Bool
    let verificationMethod: String
    let results: [ChallengeResultExport]
}

struct ChallengeResultExport: Codable {
    let id: String
    let challengeId: String
    let userId: String
    let isCompleted: Bool
    let completedAt: Date?
    let pointsEarned: Int
    let verificationMethod: String
    let confidence: Double
}

struct HangoutExport: Codable {
    let id: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let location: HangoutLocationExport
    let participants: [HangoutParticipantExport]
    let pointsEarned: Int
}

struct HangoutLocationExport: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
}

struct HangoutParticipantExport: Codable {
    let id: String
    let userId: String
    let joinedAt: Date
    let leftAt: Date?
    let duration: TimeInterval
}

struct PointsExport: Codable {
    let id: String
    let userId: String
    let points: Int
    let category: String
    let reason: String
    let timestamp: Date
    let metadata: [String: String]?
}

struct PrivacySettingsExport: Codable {
    let preciseLocationEnabled: Bool
    let analyticsEnabled: Bool
    let crashReportingEnabled: Bool
    let dataRetentionDays: Int
}

struct ConsentLogExport: Codable {
    let id: String
    let permissionType: String
    let granted: Bool
    let timestamp: Date
    let reason: String
}

struct DataExport: Codable {
    let id: UUID
    let exportType: DataExportType
    let fileSize: Int
    let recordCount: Int
    let exportedAt: Date
    let schemaVersion: String
    let isCompressed: Bool
    let checksum: String
}

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
}

struct ImportResult {
    let success: Bool
    let importedRecords: Int
    let errors: [String]
    let warnings: [String]
}

enum ExportTrend: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }
}

struct DataExportConfiguration {
    let compressExports = true
    let maxFileSize = 100 * 1024 * 1024 // 100MB
    let maxExportsPerDay = 5
    let schemaVersion = "1.0"
    let exportFormat = "JSON"
}

struct DataExportStats {
    let totalExports: Int
    let totalFileSize: Int
    let averageFileSize: Int
    let mostRecentExport: Date?
    let exportTrend: ExportTrend
    let compressionRatio: Double
}

enum DataExportError: LocalizedError {
    case dataRetrievalFailed
    case invalidImportData
    case compressionFailed
    case validationFailed
    case exportLimitReached
    
    var errorDescription: String? {
        switch self {
        case .dataRetrievalFailed:
            return "Failed to retrieve data for export"
        case .invalidImportData:
            return "Invalid import data format"
        case .compressionFailed:
            return "Failed to compress export data"
        case .validationFailed:
            return "Export data validation failed"
        case .exportLimitReached:
            return "Daily export limit reached"
        }
    }
}

// MARK: - Core Data Extensions
extension DataExportEntity {
    static func fetchRequest() -> NSFetchRequest<DataExportEntity> {
        return NSFetchRequest<DataExportEntity>(entityName: "DataExportEntity")
    }
}

// MARK: - Data Extensions
extension Data {
    var sha256: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
