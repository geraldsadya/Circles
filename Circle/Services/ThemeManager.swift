//
//  ThemeManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .system
    @Published var isDarkMode: Bool = false
    @Published var accentColor: Color = .blue
    @Published var appIcons: [AppIcon] = []
    @Published var selectedAppIcon: AppIcon?
    
    // Theme colors
    @Published var primaryColor: Color = .blue
    @Published var secondaryColor: Color = .green
    @Published var successColor: Color = .green
    @Published var warningColor: Color = .orange
    @Published var errorColor: Color = .red
    @Published var backgroundColor: Color = .white
    @Published var surfaceColor: Color = .gray.opacity(0.1)
    @Published var textColor: Color = .primary
    @Published var secondaryTextColor: Color = .secondary
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupTheme()
        setupAppIcons()
        observeSystemTheme()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupTheme() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selected_theme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
        
        // Load saved accent color
        if let savedAccentColor = UserDefaults.standard.string(forKey: "accent_color") {
            accentColor = Color(hex: savedAccentColor) ?? .blue
        }
        
        // Apply theme
        applyTheme()
    }
    
    private func setupAppIcons() {
        appIcons = [
            AppIcon(
                id: "default",
                name: "Default",
                iconName: "AppIcon",
                isDefault: true,
                isPremium: false
            ),
            AppIcon(
                id: "dark",
                name: "Dark",
                iconName: "AppIconDark",
                isDefault: false,
                isPremium: false
            ),
            AppIcon(
                id: "light",
                name: "Light",
                iconName: "AppIconLight",
                isDefault: false,
                isPremium: false
            ),
            AppIcon(
                id: "gradient",
                name: "Gradient",
                iconName: "AppIconGradient",
                isDefault: false,
                isPremium: true
            ),
            AppIcon(
                id: "neon",
                name: "Neon",
                iconName: "AppIconNeon",
                isDefault: false,
                isPremium: true
            ),
            AppIcon(
                id: "minimal",
                name: "Minimal",
                iconName: "AppIconMinimal",
                isDefault: false,
                isPremium: true
            )
        ]
        
        // Load selected app icon
        if let savedIconId = UserDefaults.standard.string(forKey: "selected_app_icon") {
            selectedAppIcon = appIcons.first { $0.id == savedIconId }
        } else {
            selectedAppIcon = appIcons.first { $0.isDefault }
        }
    }
    
    private func observeSystemTheme() {
        // Observe system theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemThemeChanged),
            name: .systemThemeChanged,
            object: nil
        )
        
        // Update dark mode status
        updateDarkModeStatus()
    }
    
    @objc private func handleSystemThemeChanged() {
        updateDarkModeStatus()
        
        if currentTheme == .system {
            applyTheme()
        }
    }
    
    private func updateDarkModeStatus() {
        isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    // MARK: - Theme Management
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selected_theme")
        applyTheme()
    }
    
    func setAccentColor(_ color: Color) {
        accentColor = color
        UserDefaults.standard.set(color.toHex(), forKey: "accent_color")
        applyTheme()
    }
    
    private func applyTheme() {
        switch currentTheme {
        case .system:
            applySystemTheme()
        case .light:
            applyLightTheme()
        case .dark:
            applyDarkTheme()
        case .auto:
            applyAutoTheme()
        }
    }
    
    private func applySystemTheme() {
        if isDarkMode {
            applyDarkTheme()
        } else {
            applyLightTheme()
        }
    }
    
    private func applyLightTheme() {
        primaryColor = accentColor
        secondaryColor = accentColor.opacity(0.7)
        successColor = .green
        warningColor = .orange
        errorColor = .red
        backgroundColor = .white
        surfaceColor = .gray.opacity(0.1)
        textColor = .primary
        secondaryTextColor = .secondary
    }
    
    private func applyDarkTheme() {
        primaryColor = accentColor
        secondaryColor = accentColor.opacity(0.7)
        successColor = .green
        warningColor = .orange
        errorColor = .red
        backgroundColor = .black
        surfaceColor = .gray.opacity(0.2)
        textColor = .white
        secondaryTextColor = .gray
    }
    
    private func applyAutoTheme() {
        // Auto theme based on time of day
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 6 && hour < 18 {
            applyLightTheme()
        } else {
            applyDarkTheme()
        }
    }
    
    // MARK: - App Icon Management
    func setAppIcon(_ appIcon: AppIcon) {
        selectedAppIcon = appIcon
        UserDefaults.standard.set(appIcon.id, forKey: "selected_app_icon")
        
        // Apply app icon
        applyAppIcon(appIcon)
    }
    
    private func applyAppIcon(_ appIcon: AppIcon) {
        // This would integrate with actual app icon changing
        // For now, we'll just log the change
        print("App icon changed to: \(appIcon.name)")
    }
    
    // MARK: - Color Schemes
    func getColorScheme() -> ColorScheme {
        switch currentTheme {
        case .system:
            return .none
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return isDarkMode ? .dark : .light
        }
    }
    
    // MARK: - Dynamic Colors
    func getDynamicColor(light: Color, dark: Color) -> Color {
        switch currentTheme {
        case .system:
            return isDarkMode ? dark : light
        case .light:
            return light
        case .dark:
            return dark
        case .auto:
            return isDarkMode ? dark : light
        }
    }
    
    // MARK: - Theme Colors
    func getThemeColors() -> ThemeColors {
        return ThemeColors(
            primary: primaryColor,
            secondary: secondaryColor,
            success: successColor,
            warning: warningColor,
            error: errorColor,
            background: backgroundColor,
            surface: surfaceColor,
            text: textColor,
            secondaryText: secondaryTextColor
        )
    }
    
    // MARK: - Accessibility
    func setAccessibilityTheme(_ accessibilityTheme: AccessibilityTheme) {
        switch accessibilityTheme {
        case .highContrast:
            applyHighContrastTheme()
        case .reducedMotion:
            applyReducedMotionTheme()
        case .largeText:
            applyLargeTextTheme()
        case .none:
            applyTheme()
        }
    }
    
    private func applyHighContrastTheme() {
        // Apply high contrast colors
        primaryColor = .blue
        secondaryColor = .blue
        successColor = .green
        warningColor = .orange
        errorColor = .red
        backgroundColor = isDarkMode ? .black : .white
        surfaceColor = isDarkMode ? .gray.opacity(0.3) : .gray.opacity(0.2)
        textColor = isDarkMode ? .white : .black
        secondaryTextColor = isDarkMode ? .gray : .gray
    }
    
    private func applyReducedMotionTheme() {
        // Apply reduced motion settings
        // This would integrate with actual reduced motion implementation
        print("Reduced motion theme applied")
    }
    
    private func applyLargeTextTheme() {
        // Apply large text settings
        // This would integrate with actual large text implementation
        print("Large text theme applied")
    }
    
    // MARK: - Custom Themes
    func createCustomTheme(name: String, colors: ThemeColors) -> CustomTheme {
        let customTheme = CustomTheme(
            id: UUID().uuidString,
            name: name,
            colors: colors,
            createdAt: Date()
        )
        
        // Save custom theme
        saveCustomTheme(customTheme)
        
        return customTheme
    }
    
    func applyCustomTheme(_ customTheme: CustomTheme) {
        primaryColor = customTheme.colors.primary
        secondaryColor = customTheme.colors.secondary
        successColor = customTheme.colors.success
        warningColor = customTheme.colors.warning
        errorColor = customTheme.colors.error
        backgroundColor = customTheme.colors.background
        surfaceColor = customTheme.colors.surface
        textColor = customTheme.colors.text
        secondaryTextColor = customTheme.colors.secondaryText
    }
    
    private func saveCustomTheme(_ customTheme: CustomTheme) {
        // Save custom theme to UserDefaults
        if let data = try? JSONEncoder().encode(customTheme) {
            UserDefaults.standard.set(data, forKey: "custom_theme_\(customTheme.id)")
        }
    }
    
    // MARK: - Theme Export
    func exportTheme() -> Data? {
        let themeExport = ThemeExport(
            currentTheme: currentTheme,
            accentColor: accentColor.toHex(),
            selectedAppIcon: selectedAppIcon?.id,
            customThemes: getCustomThemes(),
            exportedAt: Date()
        )
        
        return try? JSONEncoder().encode(themeExport)
    }
    
    func importTheme(_ data: Data) -> Bool {
        guard let themeExport = try? JSONDecoder().decode(ThemeExport.self, from: data) else {
            return false
        }
        
        // Apply imported theme
        setTheme(themeExport.currentTheme)
        setAccentColor(Color(hex: themeExport.accentColor) ?? .blue)
        
        if let iconId = themeExport.selectedAppIcon,
           let appIcon = appIcons.first(where: { $0.id == iconId }) {
            setAppIcon(appIcon)
        }
        
        return true
    }
    
    private func getCustomThemes() -> [CustomTheme] {
        // Load custom themes from UserDefaults
        // This would implement actual custom theme loading
        return []
    }
    
    // MARK: - Analytics
    func getThemeStats() -> ThemeStats {
        return ThemeStats(
            currentTheme: currentTheme,
            isDarkMode: isDarkMode,
            accentColor: accentColor.toHex(),
            selectedAppIcon: selectedAppIcon?.id,
            customThemesCount: getCustomThemes().count,
            themeUsage: getThemeUsage()
        )
    }
    
    private func getThemeUsage() -> [String: Int] {
        // This would track theme usage statistics
        return [
            "system": 10,
            "light": 5,
            "dark": 8,
            "auto": 3
        ]
    }
}

// MARK: - Supporting Types
enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "Follows system appearance"
        case .light: return "Always light mode"
        case .dark: return "Always dark mode"
        case .auto: return "Changes based on time of day"
        }
    }
}

enum AccessibilityTheme: String, CaseIterable {
    case none = "none"
    case highContrast = "high_contrast"
    case reducedMotion = "reduced_motion"
    case largeText = "large_text"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .highContrast: return "High Contrast"
        case .reducedMotion: return "Reduced Motion"
        case .largeText: return "Large Text"
        }
    }
}

struct AppIcon {
    let id: String
    let name: String
    let iconName: String
    let isDefault: Bool
    let isPremium: Bool
}

struct ThemeColors {
    let primary: Color
    let secondary: Color
    let success: Color
    let warning: Color
    let error: Color
    let background: Color
    let surface: Color
    let text: Color
    let secondaryText: Color
}

struct CustomTheme: Codable {
    let id: String
    let name: String
    let colors: ThemeColorsCodable
    let createdAt: Date
}

struct ThemeColorsCodable: Codable {
    let primary: String
    let secondary: String
    let success: String
    let warning: String
    let error: String
    let background: String
    let surface: String
    let text: String
    let secondaryText: String
}

struct ThemeExport: Codable {
    let currentTheme: AppTheme
    let accentColor: String
    let selectedAppIcon: String?
    let customThemes: [CustomTheme]
    let exportedAt: Date
}

struct ThemeStats {
    let currentTheme: AppTheme
    let isDarkMode: Bool
    let accentColor: String
    let selectedAppIcon: String?
    let customThemesCount: Int
    let themeUsage: [String: Int]
}

// MARK: - Color Extensions
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let systemThemeChanged = Notification.Name("systemThemeChanged")
    static let themeChanged = Notification.Name("themeChanged")
    static let appIconChanged = Notification.Name("appIconChanged")
}
