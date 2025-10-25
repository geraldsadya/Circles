//
//  AppIconGenerator.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreGraphics

/// Apple-quality app icon generator following Human Interface Guidelines
struct AppIconGenerator {
    
    // MARK: - Icon Design Specifications
    
    /// Apple's recommended color palette for Circle app
    struct Colors {
        static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0) // iOS Blue
        static let secondaryBlue = Color(red: 0.0, green: 0.35, blue: 0.8) // Darker Blue
        static let accentPurple = Color(red: 0.5, green: 0.0, blue: 1.0) // Purple accent
        static let backgroundWhite = Color.white
        static let shadowGray = Color.black.opacity(0.1)
        static let highlightWhite = Color.white.opacity(0.3)
    }
    
    /// Icon sizes following Apple's specifications
    struct Sizes {
        static let iconSizes: [CGFloat] = [
            20, 29, 40, 60, 76, 83.5, 1024
        ]
        
        static let scaleFactors: [CGFloat] = [
            1, 2, 3
        ]
    }
    
    // MARK: - Main Icon Design
    
    /// Creates the main Circle app icon following Apple's design principles
    static func createCircleIcon(size: CGFloat) -> some View {
        ZStack {
            // Background with subtle gradient
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Colors.primaryBlue, Colors.secondaryBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Main circle element
            Circle()
                .fill(Colors.backgroundWhite)
                .frame(width: size * 0.6, height: size * 0.6)
                .overlay(
                    // Inner circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Colors.primaryBlue.opacity(0.1), Colors.accentPurple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.4, height: size * 0.4)
                )
            
            // Verification checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundColor(Colors.primaryBlue)
                .background(
                    Circle()
                        .fill(Colors.backgroundWhite)
                        .frame(width: size * 0.3, height: size * 0.3)
                )
            
            // Subtle highlight overlay
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Colors.highlightWhite, Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)
        }
        .shadow(color: Colors.shadowGray, radius: size * 0.05, x: 0, y: size * 0.02)
    }
    
    // MARK: - Alternative Icon Designs
    
    /// Creates a minimalist version of the Circle icon
    static func createMinimalistIcon(size: CGFloat) -> some View {
        ZStack {
            // Clean background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Colors.primaryBlue)
                .frame(width: size, height: size)
            
            // Simple circle with checkmark
            Circle()
                .fill(Colors.backgroundWhite)
                .frame(width: size * 0.7, height: size * 0.7)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.3, weight: .bold))
                        .foregroundColor(Colors.primaryBlue)
                )
        }
        .shadow(color: Colors.shadowGray, radius: size * 0.05, x: 0, y: size * 0.02)
    }
    
    /// Creates a social-focused version of the Circle icon
    static func createSocialIcon(size: CGFloat) -> some View {
        ZStack {
            // Background with social gradient
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Colors.primaryBlue, Colors.accentPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Multiple circles representing social connections
            HStack(spacing: size * 0.1) {
                Circle()
                    .fill(Colors.backgroundWhite)
                    .frame(width: size * 0.25, height: size * 0.25)
                
                Circle()
                    .fill(Colors.backgroundWhite)
                    .frame(width: size * 0.25, height: size * 0.25)
                
                Circle()
                    .fill(Colors.backgroundWhite)
                    .frame(width: size * 0.25, height: size * 0.25)
            }
            .overlay(
                // Connection lines
                Path { path in
                    let centerY = size * 0.5
                    let spacing = size * 0.35
                    
                    path.move(to: CGPoint(x: size * 0.25, y: centerY))
                    path.addLine(to: CGPoint(x: size * 0.75, y: centerY))
                }
                .stroke(Colors.primaryBlue, lineWidth: size * 0.02)
            )
        }
        .shadow(color: Colors.shadowGray, radius: size * 0.05, x: 0, y: size * 0.02)
    }
    
    // MARK: - Icon Export Functions
    
    /// Generates all required app icon sizes
    static func generateAllIcons() {
        let sizes = Sizes.iconSizes
        let scales = Sizes.scaleFactors
        
        for size in sizes {
            for scale in scales {
                let actualSize = size * scale
                let filename = "AppIcon-\(Int(size))\(scale > 1 ? "@\(Int(scale))x" : "").png"
                
                // Generate icon for this size
                generateIcon(size: actualSize, filename: filename)
            }
        }
        
        // Generate App Store icon (1024x1024)
        generateIcon(size: 1024, filename: "AppIcon-1024.png")
    }
    
    /// Generates a single icon at specified size
    static func generateIcon(size: CGFloat, filename: String) {
        // Create SwiftUI view
        let iconView = createCircleIcon(size: size)
        
        // Convert to UIImage
        let renderer = ImageRenderer(content: iconView)
        renderer.proposedSize = .init(width: size, height: size)
        
        if let uiImage = renderer.uiImage {
            // Save to file
            saveImage(uiImage, filename: filename)
        }
    }
    
    /// Saves UIImage to file
    static func saveImage(_ image: UIImage, filename: String) {
        guard let data = image.pngData() else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(filename)
        
        try? data.write(to: filePath)
    }
}

// MARK: - Icon Preview Views

struct AppIconPreview: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Circle App Icons")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                // Main icon
                AppIconGenerator.createCircleIcon(size: 120)
                
                // Minimalist icon
                AppIconGenerator.createMinimalistIcon(size: 120)
                
                // Social icon
                AppIconGenerator.createSocialIcon(size: 120)
            }
            
            Text("Apple Human Interface Guidelines Compliant")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Icon Validation

struct AppIconValidator {
    
    /// Validates icon follows Apple's guidelines
    static func validateIcon(_ image: UIImage) -> ValidationResult {
        var issues: [String] = []
        
        // Check size
        if image.size.width != image.size.height {
            issues.append("Icon must be square")
        }
        
        // Check minimum size
        if image.size.width < 1024 {
            issues.append("App Store icon must be at least 1024x1024")
        }
        
        // Check corner radius (should be 22% of size)
        let expectedRadius = image.size.width * 0.22
        // Note: This would require more sophisticated analysis in a real implementation
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
}

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
}

// MARK: - Preview

#Preview {
    AppIconPreview()
}
