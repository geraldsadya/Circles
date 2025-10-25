//
//  PrivacyLabelsManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class PrivacyLabelsManager: ObservableObject {
    static let shared = PrivacyLabelsManager()
    
    @Published var privacyLabels: AppPrivacyLabels = AppPrivacyLabels()
    @Published var dataCollectionSummary: DataCollectionSummary = DataCollectionSummary()
    @Published var isCompliant = true
    @Published var complianceIssues: [ComplianceIssue] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    // Privacy label configuration
    private let privacyLabelConfig = PrivacyLabelConfiguration()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        generatePrivacyLabels()
        validateCompliance()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Privacy Labels Generation
    private func generatePrivacyLabels() {
        privacyLabels = AppPrivacyLabels(
            // Data Collection
            dataCollection: generateDataCollectionLabels(),
            
            // Data Usage
            dataUsage: generateDataUsageLabels(),
            
            // Data Sharing
            dataSharing: generateDataSharingLabels(),
            
            // Data Security
            dataSecurity: generateDataSecurityLabels(),
            
            // User Rights
            userRights: generateUserRightsLabels(),
            
            // Contact Information
            contactInfo: ContactInfo(
                privacyEmail: "privacy@circle.app",
                privacyWebsite: "https://circle.app/privacy",
                supportEmail: "support@circle.app"
            )
        )
        
        // Generate data collection summary
        dataCollectionSummary = generateDataCollectionSummary()
    }
    
    // MARK: - Data Collection Labels
    private func generateDataCollectionLabels() -> DataCollectionLabels {
        return DataCollectionLabels(
            // Location Data
            locationData: LocationDataLabel(
                isCollected: true,
                isLinkedToUser: false,
                isUsedForTracking: false,
                purposes: [
                    .hangoutDetection,
                    .challengeVerification,
                    .geofenceMonitoring
                ],
                retentionPeriod: .automaticDeletion,
                description: "Location data is used to detect hangouts with friends and verify location-based challenges. Data is processed on-device and only verification results are shared."
            ),
            
            // Motion Data
            motionData: MotionDataLabel(
                isCollected: true,
                isLinkedToUser: false,
                isUsedForTracking: false,
                purposes: [
                    .challengeVerification,
                    .activityTracking,
                    .stepCounting
                ],
                retentionPeriod: .automaticDeletion,
                description: "Motion data is used to verify fitness challenges and track physical activity. Data is processed on-device and only verification results are shared."
            ),
            
            // Camera Data
            cameraData: CameraDataLabel(
                isCollected: true,
                isLinkedToUser: false,
                isUsedForTracking: false,
                purposes: [
                    .proofVerification,
                    .forfeitCompletion,
                    .antiCheatVerification
                ],
                retentionPeriod: .immediateDeletion,
                description: "Camera data is used for live proof verification and forfeit completion. Images are processed on-device and immediately deleted after verification."
            ),
            
            // Health Data
            healthData: HealthDataLabel(
                isCollected: false,
                isLinkedToUser: false,
                isUsedForTracking: false,
                purposes: [],
                retentionPeriod: .notCollected,
                description: "Health data is not collected by Circle. Users may optionally connect HealthKit for sleep tracking challenges."
            ),
            
            // Screen Time Data
            screenTimeData: ScreenTimeDataLabel(
                isCollected: false,
                isLinkedToUser: false,
                isUsedForTracking: false,
                purposes: [],
                retentionPeriod: .notCollected,
                description: "Screen Time data is not collected by Circle. Users may optionally use Screen Time API for focus challenges."
            ),
            
            // Usage Data
            usageData: UsageDataLabel(
                isCollected: true,
                isLinkedToUser: false,
                isUsedForTracking: false,
                purposes: [
                    .appFunctionality,
                    .analytics,
                    .personalization
                ],
                retentionPeriod: .automaticDeletion,
                description: "Usage data includes app interactions, challenge completions, and points earned. Data is processed on-device and only aggregated results are shared."
            ),
            
            // Identifiers
            identifiers: IdentifiersLabel(
                isCollected: true,
                isLinkedToUser: true,
                isUsedForTracking: false,
                purposes: [
                    .appFunctionality,
                    .userAccount
                ],
                retentionPeriod: .automaticDeletion,
                description: "User identifiers are used for account management and app functionality. Data is stored securely and automatically deleted when account is closed."
            )
        )
    }
    
    // MARK: - Data Usage Labels
    private func generateDataUsageLabels() -> DataUsageLabels {
        return DataUsageLabels(
            // Primary Uses
            primaryUses: [
                .hangoutDetection,
                .challengeVerification,
                .pointsCalculation,
                .leaderboardRanking,
                .socialFeatures
            ],
            
            // Secondary Uses
            secondaryUses: [
                .analytics,
                .appImprovement,
                .personalization
            ],
            
            // Data Processing
            dataProcessing: DataProcessingLabel(
                isProcessedOnDevice: true,
                isProcessedOnServer: false,
                isProcessedByThirdParties: false,
                processingDescription: "All data processing occurs on the user's device. No personal data is uploaded to servers or shared with third parties."
            ),
            
            // Data Aggregation
            dataAggregation: DataAggregationLabel(
                isAggregated: true,
                aggregationLevel: .anonymous,
                aggregationDescription: "Only aggregated, anonymous data is shared between users (e.g., challenge completion status, points earned)."
            )
        )
    }
    
    // MARK: - Data Sharing Labels
    private func generateDataSharingLabels() -> DataSharingLabels {
        return DataSharingLabels(
            // Shared Data Types
            sharedDataTypes: [
                .challengeResults,
                .pointsData,
                .leaderboardRankings,
                .hangoutDetections
            ],
            
            // Sharing Recipients
            sharingRecipients: [
                .circleMembers,
                .appUsers
            ],
            
            // Sharing Purposes
            sharingPurposes: [
                .socialFeatures,
                .competition,
                .accountability
            ],
            
            // Data Minimization
            dataMinimization: DataMinimizationLabel(
                isMinimized: true,
                minimizationDescription: "Only necessary data is shared. Personal information, exact locations, and raw sensor data are never shared."
            ),
            
            // User Control
            userControl: UserControlLabel(
                canControlSharing: true,
                controlOptions: [
                    .leaveCircle,
                    .disableFeatures,
                    .deleteAccount
                ],
                controlDescription: "Users can control data sharing by leaving circles, disabling features, or deleting their account."
            )
        )
    }
    
    // MARK: - Data Security Labels
    private func generateDataSecurityLabels() -> DataSecurityLabels {
        return DataSecurityLabels(
            // Encryption
            encryption: EncryptionLabel(
                isEncryptedInTransit: true,
                isEncryptedAtRest: true,
                encryptionDescription: "All data is encrypted using industry-standard encryption protocols."
            ),
            
            // Access Controls
            accessControls: AccessControlsLabel(
                hasAccessControls: true,
                accessLevel: .userOnly,
                accessDescription: "Only the user and their circle members can access shared data."
            ),
            
            // Data Retention
            dataRetention: DataRetentionLabel(
                retentionPolicy: .automaticDeletion,
                retentionPeriod: .oneYear,
                retentionDescription: "Data is automatically deleted after one year or when the user deletes their account."
            ),
            
            // Security Measures
            securityMeasures: SecurityMeasuresLabel(
                measures: [
                    .onDeviceProcessing,
                    .secureEnclave,
                    .keychainStorage,
                    .automaticDeletion
                ],
                securityDescription: "Multiple security measures protect user data, including on-device processing and secure storage."
            )
        )
    }
    
    // MARK: - User Rights Labels
    private func generateUserRightsLabels() -> UserRightsLabels {
        return UserRightsLabels(
            // Data Access
            dataAccess: DataAccessLabel(
                canAccessData: true,
                accessMethod: .inAppExport,
                accessDescription: "Users can export their data through the app's privacy settings."
            ),
            
            // Data Correction
            dataCorrection: DataCorrectionLabel(
                canCorrectData: true,
                correctionMethod: .inAppEditing,
                correctionDescription: "Users can correct their data through the app's settings and profile management."
            ),
            
            // Data Deletion
            dataDeletion: DataDeletionLabel(
                canDeleteData: true,
                deletionMethod: .inAppDeletion,
                deletionDescription: "Users can delete their data through the app's privacy settings or by deleting their account."
            ),
            
            // Data Portability
            dataPortability: DataPortabilityLabel(
                canExportData: true,
                exportFormat: .json,
                exportDescription: "Users can export their data in JSON format for portability to other services."
            ),
            
            // Consent Withdrawal
            consentWithdrawal: ConsentWithdrawalLabel(
                canWithdrawConsent: true,
                withdrawalMethod: .inAppSettings,
                withdrawalDescription: "Users can withdraw consent for data processing through the app's privacy settings."
            )
        )
    }
    
    // MARK: - Data Collection Summary
    private func generateDataCollectionSummary() -> DataCollectionSummary {
        let totalDataTypes = 7
        let collectedDataTypes = 5 // Location, Motion, Camera, Usage, Identifiers
        let notCollectedDataTypes = 2 // Health, Screen Time
        
        return DataCollectionSummary(
            totalDataTypes: totalDataTypes,
            collectedDataTypes: collectedDataTypes,
            notCollectedDataTypes: notCollectedDataTypes,
            collectionPercentage: Double(collectedDataTypes) / Double(totalDataTypes),
            isMinimalCollection: true,
            collectionRationale: "Circle collects only the minimum data necessary for core functionality. All processing occurs on-device."
        )
    }
    
    // MARK: - Compliance Validation
    private func validateCompliance() {
        complianceIssues.removeAll()
        
        // Check data minimization
        if !privacyLabels.dataCollection.usageData.isCollected {
            complianceIssues.append(ComplianceIssue(
                type: .dataMinimization,
                severity: .warning,
                description: "Usage data collection is disabled",
                recommendation: "Enable usage data collection for app functionality"
            ))
        }
        
        // Check data sharing
        if privacyLabels.dataSharing.sharedDataTypes.isEmpty {
            complianceIssues.append(ComplianceIssue(
                type: .dataSharing,
                severity: .error,
                description: "No data sharing types defined",
                recommendation: "Define data sharing types for social features"
            ))
        }
        
        // Check user rights
        if !privacyLabels.userRights.dataDeletion.canDeleteData {
            complianceIssues.append(ComplianceIssue(
                type: .userRights,
                severity: .error,
                description: "Data deletion not available",
                recommendation: "Enable data deletion for user rights compliance"
            ))
        }
        
        // Check security measures
        if !privacyLabels.dataSecurity.encryption.isEncryptedAtRest {
            complianceIssues.append(ComplianceIssue(
                type: .dataSecurity,
                severity: .error,
                description: "Data not encrypted at rest",
                recommendation: "Implement data encryption at rest"
            ))
        }
        
        // Determine overall compliance
        isCompliant = complianceIssues.filter { $0.severity == .error }.isEmpty
    }
    
    // MARK: - App Store Labels
    func generateAppStoreLabels() -> AppStorePrivacyLabels {
        return AppStorePrivacyLabels(
            // Data Types
            dataTypes: [
                AppStoreDataType(
                    type: "Location",
                    isCollected: true,
                    isLinkedToUser: false,
                    isUsedForTracking: false,
                    purposes: ["App Functionality", "Analytics"]
                ),
                AppStoreDataType(
                    type: "Motion & Fitness",
                    isCollected: true,
                    isLinkedToUser: false,
                    isUsedForTracking: false,
                    purposes: ["App Functionality", "Analytics"]
                ),
                AppStoreDataType(
                    type: "Photos or Videos",
                    isCollected: true,
                    isLinkedToUser: false,
                    isUsedForTracking: false,
                    purposes: ["App Functionality"]
                ),
                AppStoreDataType(
                    type: "Usage Data",
                    isCollected: true,
                    isLinkedToUser: false,
                    isUsedForTracking: false,
                    purposes: ["App Functionality", "Analytics", "Personalization"]
                ),
                AppStoreDataType(
                    type: "Identifiers",
                    isCollected: true,
                    isLinkedToUser: true,
                    isUsedForTracking: false,
                    purposes: ["App Functionality"]
                )
            ],
            
            // Data Not Collected
            dataNotCollected: [
                "Health & Fitness",
                "Sensitive Info",
                "Financial Info",
                "Contact Info",
                "User Content",
                "Browsing History",
                "Search History",
                "Device ID",
                "Advertising Data"
            ],
            
            // Data Use
            dataUse: AppStoreDataUse(
                isUsedForTracking: false,
                isUsedForThirdPartyAdvertising: false,
                isUsedForDeveloperAdvertising: false,
                isUsedForAnalytics: true,
                isUsedForProductPersonalization: true,
                isUsedForAppFunctionality: true
            ),
            
            // Data Sharing
            dataSharing: AppStoreDataSharing(
                isSharedWithThirdParties: false,
                isUsedForThirdPartyAdvertising: false,
                isUsedForDeveloperAdvertising: false,
                isUsedForAnalytics: false,
                isUsedForProductPersonalization: false,
                isUsedForAppFunctionality: true
            )
        )
    }
    
    // MARK: - Privacy Policy Generation
    func generatePrivacyPolicy() -> PrivacyPolicy {
        return PrivacyPolicy(
            lastUpdated: Date(),
            version: "1.0",
            sections: [
                PrivacyPolicySection(
                    title: "Information We Collect",
                    content: generateInformationCollectionContent()
                ),
                PrivacyPolicySection(
                    title: "How We Use Information",
                    content: generateInformationUsageContent()
                ),
                PrivacyPolicySection(
                    title: "Information Sharing",
                    content: generateInformationSharingContent()
                ),
                PrivacyPolicySection(
                    title: "Data Security",
                    content: generateDataSecurityContent()
                ),
                PrivacyPolicySection(
                    title: "Your Rights",
                    content: generateUserRightsContent()
                ),
                PrivacyPolicySection(
                    title: "Contact Us",
                    content: generateContactContent()
                )
            ]
        )
    }
    
    // MARK: - Privacy Policy Content
    private func generateInformationCollectionContent() -> String {
        return """
        Circle collects the following types of information:
        
        • Location Data: Used to detect hangouts with friends and verify location-based challenges
        • Motion Data: Used to verify fitness challenges and track physical activity
        • Camera Data: Used for live proof verification and forfeit completion
        • Usage Data: Includes app interactions, challenge completions, and points earned
        • Identifiers: Used for account management and app functionality
        
        All data is processed on your device and only verification results are shared with your friends.
        """
    }
    
    private func generateInformationUsageContent() -> String {
        return """
        We use the information we collect to:
        
        • Provide app functionality and features
        • Detect hangouts with friends
        • Verify challenge completions
        • Calculate points and rankings
        • Improve app performance and user experience
        
        All processing occurs on your device to protect your privacy.
        """
    }
    
    private func generateInformationSharingContent() -> String {
        return """
        We share information only with:
        
        • Your circle members (challenge results, points, rankings)
        • Other app users (anonymous leaderboard data)
        
        We do not share personal information with third parties or use data for advertising.
        """
    }
    
    private func generateDataSecurityContent() -> String {
        return """
        We protect your information through:
        
        • On-device processing and storage
        • Industry-standard encryption
        • Secure Enclave for sensitive data
        • Automatic data deletion
        • User-controlled data sharing
        
        Your data is never uploaded to our servers.
        """
    }
    
    private func generateUserRightsContent() -> String {
        return """
        You have the right to:
        
        • Access your data through the app
        • Correct inaccurate information
        • Delete your data at any time
        • Export your data in JSON format
        • Withdraw consent for data processing
        
        Contact us at privacy@circle.app for assistance.
        """
    }
    
    private func generateContactContent() -> String {
        return """
        If you have questions about this privacy policy, please contact us:
        
        • Email: privacy@circle.app
        • Website: https://circle.app/privacy
        • Support: support@circle.app
        
        We will respond to your inquiry within 30 days.
        """
    }
    
    // MARK: - Compliance Reporting
    func generateComplianceReport() -> ComplianceReport {
        return ComplianceReport(
            generatedAt: Date(),
            isCompliant: isCompliant,
            complianceScore: calculateComplianceScore(),
            issues: complianceIssues,
            recommendations: generateComplianceRecommendations(),
            nextReviewDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())
        )
    }
    
    private func calculateComplianceScore() -> Double {
        let totalChecks = 10
        let passedChecks = totalChecks - complianceIssues.filter { $0.severity == .error }.count
        return Double(passedChecks) / Double(totalChecks)
    }
    
    private func generateComplianceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        for issue in complianceIssues {
            recommendations.append(issue.recommendation)
        }
        
        if isCompliant {
            recommendations.append("Maintain current privacy practices")
            recommendations.append("Regularly review and update privacy labels")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types
struct AppPrivacyLabels {
    let dataCollection: DataCollectionLabels
    let dataUsage: DataUsageLabels
    let dataSharing: DataSharingLabels
    let dataSecurity: DataSecurityLabels
    let userRights: UserRightsLabels
    let contactInfo: ContactInfo
}

struct DataCollectionLabels {
    let locationData: LocationDataLabel
    let motionData: MotionDataLabel
    let cameraData: CameraDataLabel
    let healthData: HealthDataLabel
    let screenTimeData: ScreenTimeDataLabel
    let usageData: UsageDataLabel
    let identifiers: IdentifiersLabel
}

struct LocationDataLabel {
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [DataPurpose]
    let retentionPeriod: RetentionPeriod
    let description: String
}

struct MotionDataLabel {
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [DataPurpose]
    let retentionPeriod: RetentionPeriod
    let description: String
}

struct CameraDataLabel {
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [DataPurpose]
    let retentionPeriod: RetentionPeriod
    let description: String
}

struct HealthDataLabel {
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [DataPurpose]
    let retentionPeriod: RetentionPeriod
    let description: String
}

struct ScreenTimeDataLabel {
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [DataPurpose]
    let retentionPeriod: RetentionPeriod
    let description: String
}

struct UsageDataLabel {
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [DataPurpose]
    let retentionPeriod: RetentionPeriod
    let description: String
}

struct IdentifiersLabel {
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [DataPurpose]
    let retentionPeriod: RetentionPeriod
    let description: String
}

enum DataPurpose: String, CaseIterable {
    case hangoutDetection = "hangout_detection"
    case challengeVerification = "challenge_verification"
    case geofenceMonitoring = "geofence_monitoring"
    case activityTracking = "activity_tracking"
    case stepCounting = "step_counting"
    case proofVerification = "proof_verification"
    case forfeitCompletion = "forfeit_completion"
    case antiCheatVerification = "anti_cheat_verification"
    case appFunctionality = "app_functionality"
    case analytics = "analytics"
    case personalization = "personalization"
    case userAccount = "user_account"
}

enum RetentionPeriod: String, CaseIterable {
    case immediateDeletion = "immediate_deletion"
    case automaticDeletion = "automatic_deletion"
    case oneYear = "one_year"
    case notCollected = "not_collected"
}

struct DataUsageLabels {
    let primaryUses: [DataPurpose]
    let secondaryUses: [DataPurpose]
    let dataProcessing: DataProcessingLabel
    let dataAggregation: DataAggregationLabel
}

struct DataProcessingLabel {
    let isProcessedOnDevice: Bool
    let isProcessedOnServer: Bool
    let isProcessedByThirdParties: Bool
    let processingDescription: String
}

struct DataAggregationLabel {
    let isAggregated: Bool
    let aggregationLevel: AggregationLevel
    let aggregationDescription: String
}

enum AggregationLevel: String, CaseIterable {
    case anonymous = "anonymous"
    case pseudonymous = "pseudonymous"
    case identifiable = "identifiable"
}

struct DataSharingLabels {
    let sharedDataTypes: [SharedDataType]
    let sharingRecipients: [SharingRecipient]
    let sharingPurposes: [SharingPurpose]
    let dataMinimization: DataMinimizationLabel
    let userControl: UserControlLabel
}

enum SharedDataType: String, CaseIterable {
    case challengeResults = "challenge_results"
    case pointsData = "points_data"
    case leaderboardRankings = "leaderboard_rankings"
    case hangoutDetections = "hangout_detections"
}

enum SharingRecipient: String, CaseIterable {
    case circleMembers = "circle_members"
    case appUsers = "app_users"
    case thirdParties = "third_parties"
}

enum SharingPurpose: String, CaseIterable {
    case socialFeatures = "social_features"
    case competition = "competition"
    case accountability = "accountability"
}

struct DataMinimizationLabel {
    let isMinimized: Bool
    let minimizationDescription: String
}

struct UserControlLabel {
    let canControlSharing: Bool
    let controlOptions: [ControlOption]
    let controlDescription: String
}

enum ControlOption: String, CaseIterable {
    case leaveCircle = "leave_circle"
    case disableFeatures = "disable_features"
    case deleteAccount = "delete_account"
}

struct DataSecurityLabels {
    let encryption: EncryptionLabel
    let accessControls: AccessControlsLabel
    let dataRetention: DataRetentionLabel
    let securityMeasures: SecurityMeasuresLabel
}

struct EncryptionLabel {
    let isEncryptedInTransit: Bool
    let isEncryptedAtRest: Bool
    let encryptionDescription: String
}

struct AccessControlsLabel {
    let hasAccessControls: Bool
    let accessLevel: AccessLevel
    let accessDescription: String
}

enum AccessLevel: String, CaseIterable {
    case userOnly = "user_only"
    case circleMembers = "circle_members"
    case appUsers = "app_users"
    case public = "public"
}

struct DataRetentionLabel {
    let retentionPolicy: RetentionPolicy
    let retentionPeriod: RetentionPeriod
    let retentionDescription: String
}

enum RetentionPolicy: String, CaseIterable {
    case automaticDeletion = "automatic_deletion"
    case userControlled = "user_controlled"
    case indefinite = "indefinite"
}

struct SecurityMeasuresLabel {
    let measures: [SecurityMeasure]
    let securityDescription: String
}

enum SecurityMeasure: String, CaseIterable {
    case onDeviceProcessing = "on_device_processing"
    case secureEnclave = "secure_enclave"
    case keychainStorage = "keychain_storage"
    case automaticDeletion = "automatic_deletion"
}

struct UserRightsLabels {
    let dataAccess: DataAccessLabel
    let dataCorrection: DataCorrectionLabel
    let dataDeletion: DataDeletionLabel
    let dataPortability: DataPortabilityLabel
    let consentWithdrawal: ConsentWithdrawalLabel
}

struct DataAccessLabel {
    let canAccessData: Bool
    let accessMethod: AccessMethod
    let accessDescription: String
}

struct DataCorrectionLabel {
    let canCorrectData: Bool
    let correctionMethod: CorrectionMethod
    let correctionDescription: String
}

struct DataDeletionLabel {
    let canDeleteData: Bool
    let deletionMethod: DeletionMethod
    let deletionDescription: String
}

struct DataPortabilityLabel {
    let canExportData: Bool
    let exportFormat: ExportFormat
    let exportDescription: String
}

struct ConsentWithdrawalLabel {
    let canWithdrawConsent: Bool
    let withdrawalMethod: WithdrawalMethod
    let withdrawalDescription: String
}

enum AccessMethod: String, CaseIterable {
    case inAppExport = "in_app_export"
    case emailRequest = "email_request"
    case webPortal = "web_portal"
}

enum CorrectionMethod: String, CaseIterable {
    case inAppEditing = "in_app_editing"
    case emailRequest = "email_request"
    case webPortal = "web_portal"
}

enum DeletionMethod: String, CaseIterable {
    case inAppDeletion = "in_app_deletion"
    case emailRequest = "email_request"
    case webPortal = "web_portal"
}

enum ExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case pdf = "pdf"
}

enum WithdrawalMethod: String, CaseIterable {
    case inAppSettings = "in_app_settings"
    case emailRequest = "email_request"
    case webPortal = "web_portal"
}

struct ContactInfo {
    let privacyEmail: String
    let privacyWebsite: String
    let supportEmail: String
}

struct DataCollectionSummary {
    let totalDataTypes: Int
    let collectedDataTypes: Int
    let notCollectedDataTypes: Int
    let collectionPercentage: Double
    let isMinimalCollection: Bool
    let collectionRationale: String
}

struct ComplianceIssue {
    let type: ComplianceIssueType
    let severity: ComplianceSeverity
    let description: String
    let recommendation: String
}

enum ComplianceIssueType: String, CaseIterable {
    case dataMinimization = "data_minimization"
    case dataSharing = "data_sharing"
    case userRights = "user_rights"
    case dataSecurity = "data_security"
    case consent = "consent"
}

enum ComplianceSeverity: String, CaseIterable {
    case error = "error"
    case warning = "warning"
    case info = "info"
}

struct AppStorePrivacyLabels {
    let dataTypes: [AppStoreDataType]
    let dataNotCollected: [String]
    let dataUse: AppStoreDataUse
    let dataSharing: AppStoreDataSharing
}

struct AppStoreDataType {
    let type: String
    let isCollected: Bool
    let isLinkedToUser: Bool
    let isUsedForTracking: Bool
    let purposes: [String]
}

struct AppStoreDataUse {
    let isUsedForTracking: Bool
    let isUsedForThirdPartyAdvertising: Bool
    let isUsedForDeveloperAdvertising: Bool
    let isUsedForAnalytics: Bool
    let isUsedForProductPersonalization: Bool
    let isUsedForAppFunctionality: Bool
}

struct AppStoreDataSharing {
    let isSharedWithThirdParties: Bool
    let isUsedForThirdPartyAdvertising: Bool
    let isUsedForDeveloperAdvertising: Bool
    let isUsedForAnalytics: Bool
    let isUsedForProductPersonalization: Bool
    let isUsedForAppFunctionality: Bool
}

struct PrivacyPolicy {
    let lastUpdated: Date
    let version: String
    let sections: [PrivacyPolicySection]
}

struct PrivacyPolicySection {
    let title: String
    let content: String
}

struct ComplianceReport {
    let generatedAt: Date
    let isCompliant: Bool
    let complianceScore: Double
    let issues: [ComplianceIssue]
    let recommendations: [String]
    let nextReviewDate: Date
}

struct PrivacyLabelConfiguration {
    let appName = "Circle"
    let appVersion = "1.0"
    let privacyPolicyVersion = "1.0"
    let lastUpdated = Date()
}
