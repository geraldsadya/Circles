//
//  WrappedExportManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import Foundation
import CoreData
import Combine

@MainActor
class WrappedExportManager: ObservableObject {
    static let shared = WrappedExportManager()
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportedImages: [ExportedImage] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let weeklySummaryManager = WeeklySummaryManager.shared
    
    // Export configuration
    private let exportConfig = WrappedExportConfiguration()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupExportTemplates()
        loadExportedImages()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupExportTemplates() {
        // Initialize export templates
        print("Export templates initialized")
    }
    
    private func loadExportedImages() {
        // Load previously exported images
        let request: NSFetchRequest<ExportedImageEntity> = ExportedImageEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExportedImageEntity.createdAt, ascending: false)]
        request.fetchLimit = 50
        
        do {
            let entities = try persistenceController.container.viewContext.fetch(request)
            exportedImages = entities.map { entity in
                ExportedImage(
                    id: entity.id ?? UUID(),
                    imageData: entity.imageData ?? Data(),
                    templateId: entity.templateId ?? "",
                    summaryData: entity.summaryData ?? Data(),
                    exportedAt: entity.exportedAt ?? Date(),
                    fileSize: Int(entity.fileSize),
                    dimensions: CGSize(width: CGFloat(entity.width), height: CGFloat(entity.height))
                )
            }
        } catch {
            logExport("Error loading exported images: \(error)")
        }
    }
    
    // MARK: - Export Functions
    func exportWrappedSummary(_ summary: WeeklySummary, template: WrappedTemplate) async -> ExportedImage? {
        guard !isExporting else { return nil }
        
        isExporting = true
        exportProgress = 0.0
        
        do {
            // Create export view
            let exportView = createExportView(summary: summary, template: template)
            
            // Render to image
            let image = try await renderViewToImage(exportView)
            
            // Save image
            let exportedImage = try await saveExportedImage(image, summary: summary, template: template)
            
            // Update progress
            exportProgress = 1.0
            
            // Add to exported images
            exportedImages.insert(exportedImage, at: 0)
            
            isExporting = false
            
            logExport("Successfully exported wrapped summary")
            return exportedImage
            
        } catch {
            isExporting = false
            errorMessage = "Export failed: \(error.localizedDescription)"
            logExport("Export failed: \(error)")
            return nil
        }
    }
    
    func exportMultipleSummaries(_ summaries: [WeeklySummary], template: WrappedTemplate) async -> [ExportedImage] {
        var exportedImages: [ExportedImage] = []
        
        for (index, summary) in summaries.enumerated() {
            exportProgress = Double(index) / Double(summaries.count)
            
            if let exportedImage = await exportWrappedSummary(summary, template: template) {
                exportedImages.append(exportedImage)
            }
        }
        
        exportProgress = 1.0
        return exportedImages
    }
    
    // MARK: - Export View Creation
    private func createExportView(summary: WeeklySummary, template: WrappedTemplate) -> some View {
        return WrappedExportView(summary: summary, template: template)
            .frame(width: template.dimensions.width, height: template.dimensions.height)
    }
    
    // MARK: - Image Rendering
    private func renderViewToImage<Content: View>(_ view: Content) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let renderer = ImageRenderer(content: view)
            renderer.scale = UIScreen.main.scale
            
            DispatchQueue.main.async {
                do {
                    let image = renderer.uiImage ?? UIImage()
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Image Saving
    private func saveExportedImage(_ image: UIImage, summary: WeeklySummary, template: WrappedTemplate) async throws -> ExportedImage {
        // Convert to PNG data
        guard let imageData = image.pngData() else {
            throw WrappedExportError.imageConversionFailed
        }
        
        // Create exported image
        let exportedImage = ExportedImage(
            id: UUID(),
            imageData: imageData,
            templateId: template.id,
            summaryData: try JSONEncoder().encode(summary),
            exportedAt: Date(),
            fileSize: imageData.count,
            dimensions: template.dimensions
        )
        
        // Save to Core Data
        try await saveExportedImageToCoreData(exportedImage)
        
        // Save to Photos (optional)
        if template.saveToPhotos {
            try await saveToPhotos(image)
        }
        
        return exportedImage
    }
    
    private func saveExportedImageToCoreData(_ exportedImage: ExportedImage) async throws {
        let context = persistenceController.container.viewContext
        
        let entity = ExportedImageEntity(context: context)
        entity.id = exportedImage.id
        entity.imageData = exportedImage.imageData
        entity.templateId = exportedImage.templateId
        entity.summaryData = exportedImage.summaryData
        entity.exportedAt = exportedImage.exportedAt
        entity.fileSize = Int32(exportedImage.fileSize)
        entity.width = Float(exportedImage.dimensions.width)
        entity.height = Float(exportedImage.dimensions.height)
        entity.createdAt = Date()
        
        try context.save()
    }
    
    private func saveToPhotos(_ image: UIImage) async throws {
        try await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
    
    // MARK: - Template Management
    func getAvailableTemplates() -> [WrappedTemplate] {
        return [
            WrappedTemplate(
                id: "classic",
                name: "Classic",
                displayName: "Classic",
                description: "Clean and minimal design",
                dimensions: CGSize(width: 1080, height: 1920),
                isPremium: false,
                saveToPhotos: true,
                templateType: .classic
            ),
            WrappedTemplate(
                id: "neon",
                name: "Neon",
                displayName: "Neon",
                description: "Vibrant neon colors",
                dimensions: CGSize(width: 1080, height: 1920),
                isPremium: true,
                saveToPhotos: true,
                templateType: .neon
            ),
            WrappedTemplate(
                id: "minimal",
                name: "Minimal",
                displayName: "Minimal",
                description: "Ultra-minimal design",
                dimensions: CGSize(width: 1080, height: 1920),
                isPremium: false,
                saveToPhotos: true,
                templateType: .minimal
            ),
            WrappedTemplate(
                id: "story",
                name: "Story",
                displayName: "Story",
                description: "Instagram story format",
                dimensions: CGSize(width: 1080, height: 1920),
                isPremium: false,
                saveToPhotos: true,
                templateType: .story
            ),
            WrappedTemplate(
                id: "post",
                name: "Post",
                displayName: "Post",
                description: "Instagram post format",
                dimensions: CGSize(width: 1080, height: 1080),
                isPremium: false,
                saveToPhotos: true,
                templateType: .post
            )
        ]
    }
    
    // MARK: - Share Functionality
    func shareExportedImage(_ exportedImage: ExportedImage) -> UIActivityViewController {
        let image = UIImage(data: exportedImage.imageData) ?? UIImage()
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return activityViewController
    }
    
    func shareMultipleImages(_ exportedImages: [ExportedImage]) -> UIActivityViewController {
        let images = exportedImages.compactMap { UIImage(data: $0.imageData) }
        let activityViewController = UIActivityViewController(activityItems: images, applicationActivities: nil)
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return activityViewController
    }
    
    // MARK: - Image Management
    func deleteExportedImage(_ exportedImage: ExportedImage) async {
        // Remove from Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<ExportedImageEntity> = ExportedImageEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", exportedImage.id as CVarArg)
        
        if let entity = try? context.fetch(request).first {
            context.delete(entity)
            try? context.save()
        }
        
        // Remove from array
        exportedImages.removeAll { $0.id == exportedImage.id }
        
        logExport("Deleted exported image: \(exportedImage.id)")
    }
    
    func clearAllExportedImages() async {
        // Clear Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<ExportedImageEntity> = ExportedImageEntity.fetchRequest()
        
        if let entities = try? context.fetch(request) {
            for entity in entities {
                context.delete(entity)
            }
            try? context.save()
        }
        
        // Clear array
        exportedImages.removeAll()
        
        logExport("Cleared all exported images")
    }
    
    // MARK: - Analytics
    func getExportStats() -> WrappedExportStats {
        return WrappedExportStats(
            totalExports: exportedImages.count,
            totalFileSize: exportedImages.reduce(0) { $0 + $1.fileSize },
            averageFileSize: calculateAverageFileSize(),
            mostUsedTemplate: getMostUsedTemplate(),
            exportTrend: getExportTrend(),
            premiumExports: exportedImages.filter { getTemplateById($0.templateId)?.isPremium == true }.count
        )
    }
    
    private func calculateAverageFileSize() -> Int {
        guard !exportedImages.isEmpty else { return 0 }
        return exportedImages.reduce(0) { $0 + $1.fileSize } / exportedImages.count
    }
    
    private func getMostUsedTemplate() -> String? {
        let templateCounts = Dictionary(grouping: exportedImages) { $0.templateId }
        return templateCounts.max(by: { $0.value.count < $1.value.count })?.key
    }
    
    private func getExportTrend() -> ExportTrend {
        let recentExports = exportedImages.filter { $0.exportedAt.timeIntervalSinceNow > -7 * 24 * 3600 }
        let olderExports = exportedImages.filter { $0.exportedAt.timeIntervalSinceNow <= -7 * 24 * 3600 }
        
        if recentExports.count > olderExports.count {
            return .increasing
        } else if recentExports.count < olderExports.count {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func getTemplateById(_ id: String) -> WrappedTemplate? {
        return getAvailableTemplates().first { $0.id == id }
    }
    
    // MARK: - Helper Methods
    private func logExport(_ message: String) {
        print("[WrappedExport] \(message)")
    }
}

// MARK: - Supporting Types
struct ExportedImage {
    let id: UUID
    let imageData: Data
    let templateId: String
    let summaryData: Data
    let exportedAt: Date
    let fileSize: Int
    let dimensions: CGSize
}

struct WrappedTemplate {
    let id: String
    let name: String
    let displayName: String
    let description: String
    let dimensions: CGSize
    let isPremium: Bool
    let saveToPhotos: Bool
    let templateType: WrappedTemplateType
}

enum WrappedTemplateType: String, CaseIterable {
    case classic = "classic"
    case neon = "neon"
    case minimal = "minimal"
    case story = "story"
    case post = "post"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .neon: return "Neon"
        case .minimal: return "Minimal"
        case .story: return "Story"
        case .post: return "Post"
        }
    }
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

struct WrappedExportConfiguration {
    let maxExportsPerDay = 10
    let maxFileSize = 10 * 1024 * 1024 // 10MB
    let defaultImageQuality: CGFloat = 0.9
    let supportedFormats = ["PNG", "JPEG"]
}

struct WrappedExportStats {
    let totalExports: Int
    let totalFileSize: Int
    let averageFileSize: Int
    let mostUsedTemplate: String?
    let exportTrend: ExportTrend
    let premiumExports: Int
}

enum WrappedExportError: LocalizedError {
    case imageConversionFailed
    case templateNotFound
    case exportLimitReached
    case fileSizeExceeded
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to PNG format"
        case .templateNotFound:
            return "Export template not found"
        case .exportLimitReached:
            return "Daily export limit reached"
        case .fileSizeExceeded:
            return "File size exceeds maximum limit"
        case .permissionDenied:
            return "Permission denied to save to Photos"
        }
    }
}

// MARK: - Export View
struct WrappedExportView: View {
    let summary: WeeklySummary
    let template: WrappedTemplate
    
    var body: some View {
        switch template.templateType {
        case .classic:
            ClassicWrappedView(summary: summary)
        case .neon:
            NeonWrappedView(summary: summary)
        case .minimal:
            MinimalWrappedView(summary: summary)
        case .story:
            StoryWrappedView(summary: summary)
        case .post:
            PostWrappedView(summary: summary)
        }
    }
}

// MARK: - Template Views
struct ClassicWrappedView: View {
    let summary: WeeklySummary
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Circle Wrapped")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Week of \(summary.weekStart, formatter: dateFormatter)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                StatCard(title: "Challenges Completed", value: "\(summary.challengesCompleted)", icon: "checkmark.circle.fill", color: .green)
                StatCard(title: "Points Earned", value: "\(summary.pointsEarned)", icon: "star.fill", color: .yellow)
                StatCard(title: "Time with Friends", value: "\(summary.hangoutHours)h", icon: "person.2.fill", color: .blue)
            }
            
            Spacer()
            
            Text("Keep going! 🚀")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(40)
        .background(Color.white)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

struct NeonWrappedView: View {
    let summary: WeeklySummary
    
    var body: some View {
        VStack(spacing: 20) {
            Text("CIRCLE WRAPPED")
                .font(.largeTitle)
                .fontWeight(.black)
                .foregroundColor(.white)
                .shadow(color: .cyan, radius: 10)
            
            Text("WEEK OF \(summary.weekStart, formatter: neonDateFormatter)")
                .font(.headline)
                .foregroundColor(.cyan)
                .shadow(color: .cyan, radius: 5)
            
            VStack(spacing: 16) {
                NeonStatCard(title: "CHALLENGES", value: "\(summary.challengesCompleted)", color: .green)
                NeonStatCard(title: "POINTS", value: "\(summary.pointsEarned)", color: .yellow)
                NeonStatCard(title: "HANGOUTS", value: "\(summary.hangoutHours)h", color: .pink)
            }
            
            Spacer()
            
            Text("YOU'RE ON FIRE! 🔥")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(.white)
                .shadow(color: .orange, radius: 10)
        }
        .padding(40)
        .background(Color.black)
    }
    
    private var neonDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        formatter.uppercase()
        return formatter
    }
}

struct MinimalWrappedView: View {
    let summary: WeeklySummary
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Circle")
                .font(.title)
                .fontWeight(.light)
                .foregroundColor(.primary)
            
            VStack(spacing: 20) {
                MinimalStatRow(title: "Challenges", value: "\(summary.challengesCompleted)")
                MinimalStatRow(title: "Points", value: "\(summary.pointsEarned)")
                MinimalStatRow(title: "Hours", value: "\(summary.hangoutHours)")
            }
            
            Spacer()
        }
        .padding(60)
        .background(Color.white)
    }
}

struct StoryWrappedView: View {
    let summary: WeeklySummary
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("Circle Wrapped")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("This Week")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            VStack(spacing: 20) {
                StoryStatCard(title: "Challenges", value: "\(summary.challengesCompleted)", color: .green)
                StoryStatCard(title: "Points", value: "\(summary.pointsEarned)", color: .blue)
                StoryStatCard(title: "Hours", value: "\(summary.hangoutHours)", color: .orange)
            }
            
            Spacer()
        }
        .padding(40)
        .background(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct PostWrappedView: View {
    let summary: WeeklySummary
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Circle Wrapped")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                PostStatCard(title: "Challenges", value: "\(summary.challengesCompleted)", color: .green)
                PostStatCard(title: "Points", value: "\(summary.pointsEarned)", color: .blue)
            }
            
            HStack(spacing: 20) {
                PostStatCard(title: "Hours", value: "\(summary.hangoutHours)", color: .orange)
                PostStatCard(title: "Rank", value: "#\(summary.rank)", color: .purple)
            }
            
            Spacer()
        }
        .padding(40)
        .background(Color.white)
    }
}

// MARK: - Stat Card Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct NeonStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
                .shadow(color: color, radius: 5)
            
            Spacer()
            
            Text(value)
                .font(.title)
                .fontWeight(.black)
                .foregroundColor(color)
                .shadow(color: color, radius: 10)
        }
        .padding()
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color, lineWidth: 2)
                .shadow(color: color, radius: 5)
        )
    }
}

struct MinimalStatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct StoryStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

struct PostStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Core Data Extensions
extension ExportedImageEntity {
    static func fetchRequest() -> NSFetchRequest<ExportedImageEntity> {
        return NSFetchRequest<ExportedImageEntity>(entityName: "ExportedImageEntity")
    }
}
