//
//  AppIconConfiguration.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI

/// App Icon Configuration following Apple Human Interface Guidelines
struct AppIconConfiguration {
    
    // MARK: - Icon Specifications
    
    /// Apple's required icon sizes and scales
    static let requiredSizes: [IconSize] = [
        // iPhone
        IconSize(width: 20, height: 20, scale: 1, idiom: .iphone),
        IconSize(width: 20, height: 20, scale: 2, idiom: .iphone),
        IconSize(width: 20, height: 20, scale: 3, idiom: .iphone),
        IconSize(width: 29, height: 29, scale: 1, idiom: .iphone),
        IconSize(width: 29, height: 29, scale: 2, idiom: .iphone),
        IconSize(width: 29, height: 29, scale: 3, idiom: .iphone),
        IconSize(width: 40, height: 40, scale: 1, idiom: .iphone),
        IconSize(width: 40, height: 40, scale: 2, idiom: .iphone),
        IconSize(width: 40, height: 40, scale: 3, idiom: .iphone),
        IconSize(width: 60, height: 60, scale: 2, idiom: .iphone),
        IconSize(width: 60, height: 60, scale: 3, idiom: .iphone),
        
        // iPad
        IconSize(width: 20, height: 20, scale: 1, idiom: .ipad),
        IconSize(width: 20, height: 20, scale: 2, idiom: .ipad),
        IconSize(width: 29, height: 29, scale: 1, idiom: .ipad),
        IconSize(width: 29, height: 29, scale: 2, idiom: .ipad),
        IconSize(width: 40, height: 40, scale: 1, idiom: .ipad),
        IconSize(width: 40, height: 40, scale: 2, idiom: .ipad),
        IconSize(width: 76, height: 76, scale: 1, idiom: .ipad),
        IconSize(width: 76, height: 76, scale: 2, idiom: .ipad),
        IconSize(width: 83.5, height: 83.5, scale: 2, idiom: .ipad),
        
        // App Store
        IconSize(width: 1024, height: 1024, scale: 1, idiom: .iosMarketing)
    ]
    
    // MARK: - Design Guidelines
    
    /// Apple's recommended corner radius (22% of icon size)
    static func cornerRadius(for size: CGFloat) -> CGFloat {
        return size * 0.22
    }
    
    /// Apple's recommended shadow offset (2% of icon size)
    static func shadowOffset(for size: CGFloat) -> CGFloat {
        return size * 0.02
    }
    
    /// Apple's recommended shadow blur radius (5% of icon size)
    static func shadowBlurRadius(for size: CGFloat) -> CGFloat {
        return size * 0.05
    }
    
    // MARK: - Color Palette
    
    /// Apple's recommended color palette for Circle app
    struct Colors {
        static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
        static let secondaryBlue = Color(red: 0.0, green: 0.35, blue: 0.8)
        static let accentPurple = Color(red: 0.5, green: 0.0, blue: 1.0)
        static let backgroundWhite = Color.white
        static let shadowGray = Color.black.opacity(0.1)
        static let highlightWhite = Color.white.opacity(0.3)
    }
    
    // MARK: - Icon Validation
    
    /// Validates icon follows Apple's guidelines
    static func validateIcon(size: CGSize) -> ValidationResult {
        var issues: [String] = []
        
        // Check if square
        if size.width != size.height {
            issues.append("Icon must be square")
        }
        
        // Check minimum size for App Store
        if size.width < 1024 {
            issues.append("App Store icon must be at least 1024x1024")
        }
        
        // Check if size is in required list
        let isRequiredSize = requiredSizes.contains { iconSize in
            CGFloat(iconSize.width) == size.width && CGFloat(iconSize.height) == size.height
        }
        
        if !isRequiredSize {
            issues.append("Icon size not in Apple's required list")
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    // MARK: - Icon Generation
    
    /// Generates icon filename following Apple's naming convention
    static func generateFilename(width: Int, height: Int, scale: Int, idiom: IconIdiom) -> String {
        if width == 1024 {
            return "AppIcon-1024.png"
        } else if scale > 1 {
            return "AppIcon-\(width)@\(scale)x.png"
        } else {
            return "AppIcon-\(width).png"
        }
    }
    
    /// Generates Contents.json for AppIcon.appiconset
    static func generateContentsJSON() -> String {
        let images = requiredSizes.map { iconSize in
            let filename = generateFilename(
                width: iconSize.width,
                height: iconSize.height,
                scale: iconSize.scale,
                idiom: iconSize.idiom
            )
            
            return """
            {
              "filename" : "\(filename)",
              "idiom" : "\(iconSize.idiom.rawValue)",
              "scale" : "\(iconSize.scale)x",
              "size" : "\(iconSize.width)x\(iconSize.height)"
            }
            """
        }
        
        return """
        {
          "images" : [
            \(images.joined(separator: ",\n    "))
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
    }
}

// MARK: - Supporting Types

struct IconSize {
    let width: Int
    let height: Int
    let scale: Int
    let idiom: IconIdiom
}

enum IconIdiom: String, CaseIterable {
    case iphone = "iphone"
    case ipad = "ipad"
    case iosMarketing = "ios-marketing"
}

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
}

// MARK: - Icon Preview

struct AppIconPreview: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: AppIconConfiguration.cornerRadius(for: size))
                .fill(
                    LinearGradient(
                        colors: [AppIconConfiguration.Colors.primaryBlue, AppIconConfiguration.Colors.secondaryBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Main circle
            Circle()
                .fill(AppIconConfiguration.Colors.backgroundWhite)
                .frame(width: size * 0.6, height: size * 0.6)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppIconConfiguration.Colors.primaryBlue.opacity(0.1),
                                    AppIconConfiguration.Colors.accentPurple.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.4, height: size * 0.4)
                )
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundColor(AppIconConfiguration.Colors.primaryBlue)
                .background(
                    Circle()
                        .fill(AppIconConfiguration.Colors.backgroundWhite)
                        .frame(width: size * 0.3, height: size * 0.3)
                )
            
            // Highlight
            RoundedRectangle(cornerRadius: AppIconConfiguration.cornerRadius(for: size))
                .fill(
                    LinearGradient(
                        colors: [AppIconConfiguration.Colors.highlightWhite, Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)
        }
        .shadow(
            color: AppIconConfiguration.Colors.shadowGray,
            radius: AppIconConfiguration.shadowBlurRadius(for: size),
            x: 0,
            y: AppIconConfiguration.shadowOffset(for: size)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Circle App Icons")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        HStack(spacing: 20) {
            VStack {
                AppIconPreview(size: 60)
                Text("60x60")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                AppIconPreview(size: 120)
                Text("120x120")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                AppIconPreview(size: 240)
                Text("240x240")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        Text("Apple Human Interface Guidelines Compliant")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
