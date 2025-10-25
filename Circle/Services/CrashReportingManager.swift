//
//  CrashReportingManager.swift
//  Circle
//
//  Created by Circle Team on 202-01-15.
//

import Foundation
import os.log
import CoreData
import Combine

@MainActor
class CrashReportingManager: ObservableObject {
    static let shared = CrashReportingManager()
    
    @Published var isCrashReportingEnabled = true
    @Published var crashReports: [CrashReport] = []
    @Published var logEntries: [LogEntry] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    // Logging categories
    private let logger = Logger(subsystem: "com.circle.app", category: "CrashReporting")
    private let authLogger = Logger(subsystem: "com.circle.app", category: "Authentication")
    private let locationLogger = Logger(subsystem: "com.circle.app", category: "Location")
    private let challengeLogger = Logger(subsystem: "com.circle.app", category: "Challenges")
    private let hangoutLogger = Logger(subsystem: "com.circle.app", category: "Hangouts")
    private let cameraLogger = Logger(subsystem: "com.circle.app", category: "Camera")
    private let privacyLogger = Logger(subsystem: "com.circle.app", category: "Privacy")
    private let performanceLogger = Logger(subsystem: "com.circle.app", category: "Performance")
    
    // Crash reporting configuration
    private let crashReportingConfig = CrashReportingConfig()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupCrashReporting()
        setupLogging()
        loadCrashReports()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupCrashReporting() {
        // Set up crash reporting
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                await CrashReportingManager.shared.handleUncaughtException(exception)
            }
        }
        
        // Set up signal handlers
        setupSignalHandlers()
        
        // Set up crash detection
        setupCrashDetection()
    }
    
    private func setupSignalHandlers() {
        // Handle SIGABRT
        signal(SIGABRT) { signal in
            Task { @MainActor in
                await CrashReportingManager.shared.handleSignal(signal, name: "SIGABRT")
            }
        }
        
        // Handle SIGSEGV
        signal(SIGSEGV) { signal in
            Task { @MainActor in
                await CrashReportingManager.shared.handleSignal(signal, name: "SIGSEGV")
            }
        }
        
        // Handle SIGBUS
        signal(SIGBUS) { signal in
            Task { @MainActor in
                await CrashReportingManager.shared.handleSignal(signal, name: "SIGBUS")
            }
        }
        
        // Handle SIGILL
        signal(SIGILL) { signal in
            Task { @MainActor in
                await CrashReportingManager.shared.handleSignal(signal, name: "SIGILL")
            }
        }
    }
    
    private func setupCrashDetection() {
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    private func setupLogging() {
        // Set up logging configuration
        // This would integrate with actual logging setup
        print("Logging system initialized")
    }
    
    // MARK: - Crash Handling
    private func handleUncaughtException(_ exception: NSException) async {
        let crashReport = CrashReport(
            id: UUID(),
            type: .uncaughtException,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown reason",
            callStack: exception.callStackSymbols,
            timestamp: Date(),
            appVersion: getAppVersion(),
            deviceInfo: getDeviceInfo(),
            userInfo: getUserInfo(),
            isResolved: false
        )
        
        await saveCrashReport(crashReport)
        logCrash(crashReport)
    }
    
    private func handleSignal(_ signal: Int32, name: String) async {
        let crashReport = CrashReport(
            id: UUID(),
            type: .signal,
            name: name,
            reason: "Signal \(signal) received",
            callStack: Thread.callStackSymbols,
            timestamp: Date(),
            appVersion: getAppVersion(),
            deviceInfo: getDeviceInfo(),
            userInfo: getUserInfo(),
            isResolved: false
        )
        
        await saveCrashReport(crashReport)
        logCrash(crashReport)
    }
    
    // MARK: - Logging Methods
    func logInfo(_ message: String, category: LogCategory = .general) {
        let logEntry = LogEntry(
            id: UUID(),
            level: .info,
            category: category,
            message: message,
            timestamp: Date(),
            thread: Thread.current.name ?? "Unknown",
            file: #file,
            function: #function,
            line: #line
        )
        
        saveLogEntry(logEntry)
        logToOSLog(logEntry)
    }
    
    func logWarning(_ message: String, category: LogCategory = .general) {
        let logEntry = LogEntry(
            id: UUID(),
            level: .warning,
            category: category,
            message: message,
            timestamp: Date(),
            thread: Thread.current.name ?? "Unknown",
            file: #file,
            function: #function,
            line: #line
        )
        
        saveLogEntry(logEntry)
        logToOSLog(logEntry)
    }
    
    func logError(_ message: String, category: LogCategory = .general, error: Error? = nil) {
        let logEntry = LogEntry(
            id: UUID(),
            level: .error,
            category: category,
            message: message,
            timestamp: Date(),
            thread: Thread.current.name ?? "Unknown",
            file: #file,
            function: #function,
            line: #line,
            error: error?.localizedDescription
        )
        
        saveLogEntry(logEntry)
        logToOSLog(logEntry)
    }
    
    func logDebug(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        let logEntry = LogEntry(
            id: UUID(),
            level: .debug,
            category: category,
            message: message,
            timestamp: Date(),
            thread: Thread.current.name ?? "Unknown",
            file: #file,
            function: #function,
            line: #line
        )
        
        saveLogEntry(logEntry)
        logToOSLog(logEntry)
        #endif
    }
    
    // MARK: - Category-Specific Logging
    func logAuthentication(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info: logInfo(message, category: .authentication)
        case .warning: logWarning(message, category: .authentication)
        case .error: logError(message, category: .authentication)
        case .debug: logDebug(message, category: .authentication)
        }
    }
    
    func logLocation(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info: logInfo(message, category: .location)
        case .warning: logWarning(message, category: .location)
        case .error: logError(message, category: .location)
        case .debug: logDebug(message, category: .location)
        }
    }
    
    func logChallenge(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info: logInfo(message, category: .challenges)
        case .warning: logWarning(message, category: .challenges)
        case .error: logError(message, category: .challenges)
        case .debug: logDebug(message, category: .challenges)
        }
    }
    
    func logHangout(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info: logInfo(message, category: .hangouts)
        case .warning: logWarning(message, category: .hangouts)
        case .error: logError(message, category: .hangouts)
        case .debug: logDebug(message, category: .hangouts)
        }
    }
    
    func logCamera(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info: logInfo(message, category: .camera)
        case .warning: logWarning(message, category: .camera)
        case .error: logError(message, category: .camera)
        case .debug: logDebug(message, category: .camera)
        }
    }
    
    func logPrivacy(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info: logInfo(message, category: .privacy)
        case .warning: logWarning(message, category: .privacy)
        case .error: logError(message, category: .privacy)
        case .debug: logDebug(message, category: .privacy)
        }
    }
    
    func logPerformance(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info: logInfo(message, category: .performance)
        case .warning: logWarning(message, category: .performance)
        case .error: logError(message, category: .performance)
        case .debug: logDebug(message, category: .performance)
        }
    }
    
    // MARK: - OSLog Integration
    private func logToOSLog(_ logEntry: LogEntry) {
        let logger = getLogger(for: logEntry.category)
        
        switch logEntry.level {
        case .info:
            logger.info("\(logEntry.message)")
        case .warning:
            logger.warning("\(logEntry.message)")
        case .error:
            logger.error("\(logEntry.message)")
        case .debug:
            logger.debug("\(logEntry.message)")
        }
    }
    
    private func getLogger(for category: LogCategory) -> Logger {
        switch category {
        case .general:
            return logger
        case .authentication:
            return authLogger
        case .location:
            return locationLogger
        case .challenges:
            return challengeLogger
        case .hangouts:
            return hangoutLogger
        case .camera:
            return cameraLogger
        case .privacy:
            return privacyLogger
        case .performance:
            return performanceLogger
        }
    }
    
    // MARK: - Data Persistence
    private func saveCrashReport(_ crashReport: CrashReport) async {
        let context = persistenceController.container.viewContext
        
        let crashReportEntity = CrashReportEntity(context: context)
        crashReportEntity.id = crashReport.id
        crashReportEntity.type = crashReport.type.rawValue
        crashReportEntity.name = crashReport.name
        crashReportEntity.reason = crashReport.reason
        crashReportEntity.callStack = crashReport.callStack.joined(separator: "\n")
        crashReportEntity.timestamp = crashReport.timestamp
        crashReportEntity.appVersion = crashReport.appVersion
        crashReportEntity.deviceInfo = crashReport.deviceInfo
        crashReportEntity.userInfo = crashReport.userInfo
        crashReportEntity.isResolved = crashReport.isResolved
        crashReportEntity.createdAt = Date()
        
        try? context.save()
        
        // Add to array
        crashReports.append(crashReportEntity)
    }
    
    private func saveLogEntry(_ logEntry: LogEntry) async {
        let context = persistenceController.container.viewContext
        
        let logEntryEntity = LogEntryEntity(context: context)
        logEntryEntity.id = logEntry.id
        logEntryEntity.level = logEntry.level.rawValue
        logEntryEntity.category = logEntry.category.rawValue
        logEntryEntity.message = logEntry.message
        logEntryEntity.timestamp = logEntry.timestamp
        logEntryEntity.thread = logEntry.thread
        logEntryEntity.file = logEntry.file
        logEntryEntity.function = logEntry.function
        logEntryEntity.line = Int32(logEntry.line)
        logEntryEntity.error = logEntry.error
        logEntryEntity.createdAt = Date()
        
        try? context.save()
        
        // Add to array
        logEntries.append(logEntryEntity)
    }
    
    private func loadCrashReports() {
        let request: NSFetchRequest<CrashReportEntity> = CrashReportEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CrashReportEntity.createdAt, ascending: false)]
        request.fetchLimit = 100
        
        do {
            crashReports = try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Error loading crash reports: \(error)")
        }
    }
    
    // MARK: - Crash Analysis
    func analyzeCrashes() -> CrashAnalysis {
        let totalCrashes = crashReports.count
        let unresolvedCrashes = crashReports.filter { !$0.isResolved }.count
        let crashTypes = Dictionary(grouping: crashReports) { $0.type }
        let recentCrashes = crashReports.filter { $0.timestamp.timeIntervalSinceNow > -86400 } // Last 24 hours
        
        return CrashAnalysis(
            totalCrashes: totalCrashes,
            unresolvedCrashes: unresolvedCrashes,
            recentCrashes: recentCrashes.count,
            crashTypes: crashTypes.mapValues { $0.count },
            mostCommonCrash: findMostCommonCrash(),
            crashTrend: calculateCrashTrend(),
            recommendations: generateCrashRecommendations()
        )
    }
    
    private func findMostCommonCrash() -> String? {
        let crashTypes = Dictionary(grouping: crashReports) { $0.type }
        return crashTypes.max(by: { $0.value.count < $1.value.count })?.key.rawValue
    }
    
    private func calculateCrashTrend() -> CrashTrend {
        let recentCrashes = crashReports.filter { $0.timestamp.timeIntervalSinceNow > -86400 }
        let olderCrashes = crashReports.filter { $0.timestamp.timeIntervalSinceNow <= -86400 }
        
        if recentCrashes.count > olderCrashes.count {
            return .increasing
        } else if recentCrashes.count < olderCrashes.count {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func generateCrashRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let unresolvedCrashes = crashReports.filter { !$0.isResolved }
        if unresolvedCrashes.count > 0 {
            recommendations.append("Address \(unresolvedCrashes.count) unresolved crashes")
        }
        
        let recentCrashes = crashReports.filter { $0.timestamp.timeIntervalSinceNow > -86400 }
        if recentCrashes.count > 5 {
            recommendations.append("High crash rate detected - investigate immediately")
        }
        
        let signalCrashes = crashReports.filter { $0.type == .signal }
        if signalCrashes.count > 0 {
            recommendations.append("Address signal crashes - potential memory issues")
        }
        
        return recommendations
    }
    
    // MARK: - Log Analysis
    func analyzeLogs() -> LogAnalysis {
        let totalLogs = logEntries.count
        let errorLogs = logEntries.filter { $0.level == .error }.count
        let warningLogs = logEntries.filter { $0.level == .warning }.count
        let logCategories = Dictionary(grouping: logEntries) { $0.category }
        let recentLogs = logEntries.filter { $0.timestamp.timeIntervalSinceNow > -3600 } // Last hour
        
        return LogAnalysis(
            totalLogs: totalLogs,
            errorLogs: errorLogs,
            warningLogs: warningLogs,
            recentLogs: recentLogs.count,
            logCategories: logCategories.mapValues { $0.count },
            mostCommonError: findMostCommonError(),
            logTrend: calculateLogTrend(),
            recommendations: generateLogRecommendations()
        )
    }
    
    private func findMostCommonError() -> String? {
        let errorLogs = logEntries.filter { $0.level == .error }
        let errorMessages = Dictionary(grouping: errorLogs) { $0.message }
        return errorMessages.max(by: { $0.value.count < $1.value.count })?.key
    }
    
    private func calculateLogTrend() -> LogTrend {
        let recentLogs = logEntries.filter { $0.timestamp.timeIntervalSinceNow > -3600 }
        let olderLogs = logEntries.filter { $0.timestamp.timeIntervalSinceNow <= -3600 }
        
        if recentLogs.count > olderLogs.count {
            return .increasing
        } else if recentLogs.count < olderLogs.count {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func generateLogRecommendations() -> [String] {
        var recommendations: [String] = []
        
        let errorLogs = logEntries.filter { $0.level == .error }
        if errorLogs.count > 0 {
            recommendations.append("Address \(errorLogs.count) error logs")
        }
        
        let warningLogs = logEntries.filter { $0.level == .warning }
        if warningLogs.count > 0 {
            recommendations.append("Review \(warningLogs.count) warning logs")
        }
        
        let recentErrors = logEntries.filter { $0.level == .error && $0.timestamp.timeIntervalSinceNow > -3600 }
        if recentErrors.count > 5 {
            recommendations.append("High error rate detected - investigate immediately")
        }
        
        return recommendations
    }
    
    // MARK: - Notification Handlers
    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        logInfo("App became active", category: .general)
    }
    
    @objc private func handleAppWillTerminate(_ notification: Notification) {
        logInfo("App will terminate", category: .general)
    }
    
    @objc private func handleAppDidEnterBackground(_ notification: Notification) {
        logInfo("App entered background", category: .general)
    }
    
    // MARK: - Helper Methods
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model) \(device.systemName) \(device.systemVersion)"
    }
    
    private func getUserInfo() -> String {
        // This would return user-specific information for crash context
        return "User ID: \(UUID().uuidString)"
    }
    
    private func logCrash(_ crashReport: CrashReport) {
        logError("Crash occurred: \(crashReport.name) - \(crashReport.reason)", category: .general)
    }
    
    // MARK: - Export
    func exportCrashReports() -> Data? {
        let exportData = CrashReportExportData(
            crashes: crashReports.map { crash in
                CrashReportExport(
                    id: crash.id?.uuidString ?? "",
                    type: crash.type ?? "",
                    name: crash.name ?? "",
                    reason: crash.reason ?? "",
                    timestamp: crash.timestamp ?? Date(),
                    appVersion: crash.appVersion ?? "",
                    deviceInfo: crash.deviceInfo ?? "",
                    userInfo: crash.userInfo ?? "",
                    isResolved: crash.isResolved
                )
            },
            exportedAt: Date()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    func exportLogs() -> Data? {
        let exportData = LogExportData(
            logs: logEntries.map { log in
                LogExport(
                    id: log.id?.uuidString ?? "",
                    level: log.level ?? "",
                    category: log.category ?? "",
                    message: log.message ?? "",
                    timestamp: log.timestamp ?? Date(),
                    thread: log.thread ?? "",
                    file: log.file ?? "",
                    function: log.function ?? "",
                    line: Int(log.line),
                    error: log.error
                )
            },
            exportedAt: Date()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
}

// MARK: - Supporting Types
enum CrashType: String, CaseIterable {
    case uncaughtException = "uncaught_exception"
    case signal = "signal"
    case memoryWarning = "memory_warning"
    case outOfMemory = "out_of_memory"
    
    var displayName: String {
        switch self {
        case .uncaughtException: return "Uncaught Exception"
        case .signal: return "Signal"
        case .memoryWarning: return "Memory Warning"
        case .outOfMemory: return "Out of Memory"
        }
    }
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

enum LogCategory: String, CaseIterable {
    case general = "general"
    case authentication = "authentication"
    case location = "location"
    case challenges = "challenges"
    case hangouts = "hangouts"
    case camera = "camera"
    case privacy = "privacy"
    case performance = "performance"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .authentication: return "Authentication"
        case .location: return "Location"
        case .challenges: return "Challenges"
        case .hangouts: return "Hangouts"
        case .camera: return "Camera"
        case .privacy: return "Privacy"
        case .performance: return "Performance"
        }
    }
}

struct CrashReport {
    let id: UUID
    let type: CrashType
    let name: String
    let reason: String
    let callStack: [String]
    let timestamp: Date
    let appVersion: String
    let deviceInfo: String
    let userInfo: String
    let isResolved: Bool
}

struct LogEntry {
    let id: UUID
    let level: LogLevel
    let category: LogCategory
    let message: String
    let timestamp: Date
    let thread: String
    let file: String
    let function: String
    let line: Int
    let error: String?
}

struct CrashAnalysis {
    let totalCrashes: Int
    let unresolvedCrashes: Int
    let recentCrashes: Int
    let crashTypes: [String: Int]
    let mostCommonCrash: String?
    let crashTrend: CrashTrend
    let recommendations: [String]
}

enum CrashTrend: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

struct LogAnalysis {
    let totalLogs: Int
    let errorLogs: Int
    let warningLogs: Int
    let recentLogs: Int
    let logCategories: [String: Int]
    let mostCommonError: String?
    let logTrend: LogTrend
    let recommendations: [String]
}

enum LogTrend: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

struct CrashReportingConfig {
    let maxCrashReports = 100
    let maxLogEntries = 1000
    let logRetentionDays = 30
    let crashRetentionDays = 90
}

struct CrashReportExportData: Codable {
    let crashes: [CrashReportExport]
    let exportedAt: Date
}

struct CrashReportExport: Codable {
    let id: String
    let type: String
    let name: String
    let reason: String
    let timestamp: Date
    let appVersion: String
    let deviceInfo: String
    let userInfo: String
    let isResolved: Bool
}

struct LogExportData: Codable {
    let logs: [LogExport]
    let exportedAt: Date
}

struct LogExport: Codable {
    let id: String
    let level: String
    let category: String
    let message: String
    let timestamp: Date
    let thread: String
    let file: String
    let function: String
    let line: Int
    let error: String?
}

// MARK: - Core Data Extensions
extension CrashReportEntity {
    static func fetchRequest() -> NSFetchRequest<CrashReportEntity> {
        return NSFetchRequest<CrashReportEntity>(entityName: "CrashReportEntity")
    }
}

extension LogEntryEntity {
    static func fetchRequest() -> NSFetchRequest<LogEntryEntity> {
        return NSFetchRequest<LogEntryEntity>(entityName: "LogEntryEntity")
    }
}
