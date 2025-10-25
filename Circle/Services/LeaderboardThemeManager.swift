//
//  LeaderboardThemeManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import Foundation
import CoreData
import Combine

@MainActor
class LeaderboardThemeManager: ObservableObject {
    static let shared = LeaderboardThemeManager()
    
    @Published var currentTheme: LeaderboardTheme = .default
    @Published var availableThemes: [LeaderboardTheme] = []
    @Published var crownAnimations: [CrownAnimation] = []
    @Published var leaderboardStyles: [LeaderboardStyle] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    
    // Theme configuration
    private let themeConfig = LeaderboardThemeConfiguration()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupThemes()
        setupCrownAnimations()
        setupLeaderboardStyles()
        loadCurrentTheme()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupThemes() {
        availableThemes = [
            LeaderboardTheme(
                id: "default",
                name: "Classic",
                displayName: "Classic",
                description: "Clean and minimal design",
                isPremium: false,
                colors: LeaderboardColors(
                    background: .white,
                    surface: .gray.opacity(0.1),
                    text: .primary,
                    secondaryText: .secondary,
                    accent: .blue,
                    success: .green,
                    warning: .orange,
                    error: .red
                ),
                crownStyle: .classic,
                animationStyle: .subtle,
                isDefault: true
            ),
            LeaderboardTheme(
                id: "dark",
                name: "Dark Mode",
                displayName: "Dark Mode",
                description: "Elegant dark theme",
                isPremium: false,
                colors: LeaderboardColors(
                    background: .black,
                    surface: .gray.opacity(0.2),
                    text: .white,
                    secondaryText: .gray,
                    accent: .blue,
                    success: .green,
                    warning: .orange,
                    error: .red
                ),
                crownStyle: .glow,
                animationStyle: .smooth,
                isDefault: false
            ),
            LeaderboardTheme(
                id: "neon",
                name: "Neon",
                displayName: "Neon",
                description: "Vibrant neon colors",
                isPremium: true,
                colors: LeaderboardColors(
                    background: .black,
                    surface: .purple.opacity(0.1),
                    text: .white,
                    secondaryText: .gray,
                    accent: .cyan,
                    success: .green,
                    warning: .yellow,
                    error: .pink
                ),
                crownStyle: .neon,
                animationStyle: .energetic,
                isDefault: false
            ),
            LeaderboardTheme(
                id: "gold",
                name: "Gold",
                displayName: "Gold",
                description: "Luxurious gold theme",
                isPremium: true,
                colors: LeaderboardColors(
                    background: .black,
                    surface: .yellow.opacity(0.1),
                    text: .white,
                    secondaryText: .gray,
                    accent: .yellow,
                    success: .green,
                    warning: .orange,
                    error: .red
                ),
                crownStyle: .royal,
                animationStyle: .elegant,
                isDefault: false
            ),
            LeaderboardTheme(
                id: "minimal",
                name: "Minimal",
                displayName: "Minimal",
                description: "Ultra-minimal design",
                isPremium: false,
                colors: LeaderboardColors(
                    background: .white,
                    surface: .clear,
                    text: .primary,
                    secondaryText: .secondary,
                    accent: .gray,
                    success: .green,
                    warning: .orange,
                    error: .red
                ),
                crownStyle: .minimal,
                animationStyle: .none,
                isDefault: false
            )
        ]
    }
    
    private func setupCrownAnimations() {
        crownAnimations = [
            CrownAnimation(
                id: "sparkle",
                name: "Sparkle",
                displayName: "Sparkle",
                description: "Sparkling crown animation",
                duration: 2.0,
                isPremium: false,
                animationType: .sparkle
            ),
            CrownAnimation(
                id: "glow",
                name: "Glow",
                displayName: "Glow",
                description: "Glowing crown effect",
                duration: 1.5,
                isPremium: false,
                animationType: .glow
            ),
            CrownAnimation(
                id: "pulse",
                name: "Pulse",
                displayName: "Pulse",
                description: "Pulsing crown animation",
                duration: 1.0,
                isPremium: false,
                animationType: .pulse
            ),
            CrownAnimation(
                id: "rainbow",
                name: "Rainbow",
                displayName: "Rainbow",
                description: "Rainbow crown animation",
                duration: 3.0,
                isPremium: true,
                animationType: .rainbow
            ),
            CrownAnimation(
                id: "fire",
                name: "Fire",
                displayName: "Fire",
                description: "Fire crown animation",
                duration: 2.5,
                isPremium: true,
                animationType: .fire
            ),
            CrownAnimation(
                id: "ice",
                name: "Ice",
                displayName: "Ice",
                description: "Ice crown animation",
                duration: 2.0,
                isPremium: true,
                animationType: .ice
            )
        ]
    }
    
    private func setupLeaderboardStyles() {
        leaderboardStyles = [
            LeaderboardStyle(
                id: "card",
                name: "Card",
                displayName: "Card Style",
                description: "Card-based leaderboard",
                isPremium: false,
                styleType: .card,
                cornerRadius: 12,
                shadowRadius: 4,
                padding: 16
            ),
            LeaderboardStyle(
                id: "list",
                name: "List",
                displayName: "List Style",
                description: "Simple list leaderboard",
                isPremium: false,
                styleType: .list,
                cornerRadius: 8,
                shadowRadius: 2,
                padding: 12
            ),
            LeaderboardStyle(
                id: "glass",
                name: "Glass",
                displayName: "Glass Style",
                description: "Glass morphism effect",
                isPremium: true,
                styleType: .glass,
                cornerRadius: 16,
                shadowRadius: 8,
                padding: 20
            ),
            LeaderboardStyle(
                id: "neon",
                name: "Neon",
                displayName: "Neon Style",
                description: "Neon border effect",
                isPremium: true,
                styleType: .neon,
                cornerRadius: 12,
                shadowRadius: 6,
                padding: 16
            )
        ]
    }
    
    private func loadCurrentTheme() {
        if let savedThemeId = UserDefaults.standard.string(forKey: "leaderboard_theme"),
           let theme = availableThemes.first(where: { $0.id == savedThemeId }) {
            currentTheme = theme
        } else {
            currentTheme = availableThemes.first { $0.isDefault } ?? availableThemes[0]
        }
    }
    
    // MARK: - Theme Management
    func setTheme(_ theme: LeaderboardTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.id, forKey: "leaderboard_theme")
        
        // Apply theme to leaderboard
        applyTheme(theme)
        
        logTheme("Theme changed to: \(theme.displayName)")
    }
    
    private func applyTheme(_ theme: LeaderboardTheme) {
        // Apply theme colors and styles
        // This would integrate with actual leaderboard UI
        print("Applying leaderboard theme: \(theme.displayName)")
    }
    
    // MARK: - Crown Management
    func getCrownForRank(_ rank: Int, theme: LeaderboardTheme) -> Crown {
        let crownStyle = theme.crownStyle
        
        switch rank {
        case 1:
            return Crown(
                id: "first",
                rank: 1,
                style: crownStyle,
                color: .yellow,
                size: .large,
                animation: getCrownAnimation(for: rank, theme: theme),
                isAnimated: true
            )
        case 2:
            return Crown(
                id: "second",
                rank: 2,
                style: crownStyle,
                color: .gray,
                size: .medium,
                animation: getCrownAnimation(for: rank, theme: theme),
                isAnimated: true
            )
        case 3:
            return Crown(
                id: "third",
                rank: 3,
                style: crownStyle,
                color: .brown,
                size: .small,
                animation: getCrownAnimation(for: rank, theme: theme),
                isAnimated: true
            )
        default:
            return Crown(
                id: "default",
                rank: rank,
                style: .minimal,
                color: .gray,
                size: .small,
                animation: nil,
                isAnimated: false
            )
        }
    }
    
    private func getCrownAnimation(for rank: Int, theme: LeaderboardTheme) -> CrownAnimation? {
        switch rank {
        case 1:
            return crownAnimations.first { $0.id == "sparkle" }
        case 2:
            return crownAnimations.first { $0.id == "glow" }
        case 3:
            return crownAnimations.first { $0.id == "pulse" }
        default:
            return nil
        }
    }
    
    // MARK: - Leaderboard Styling
    func getLeaderboardStyle(_ styleId: String) -> LeaderboardStyle {
        return leaderboardStyles.first { $0.id == styleId } ?? leaderboardStyles[0]
    }
    
    func applyLeaderboardStyle(_ style: LeaderboardStyle, to view: some View) -> some View {
        switch style.styleType {
        case .card:
            return AnyView(
                view
                    .background(style.colors.surface)
                    .cornerRadius(style.cornerRadius)
                    .shadow(radius: style.shadowRadius)
                    .padding(style.padding)
            )
        case .list:
            return AnyView(
                view
                    .background(style.colors.surface)
                    .cornerRadius(style.cornerRadius)
                    .padding(style.padding)
            )
        case .glass:
            return AnyView(
                view
                    .background(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .fill(style.colors.surface.opacity(0.3))
                            .background(
                                RoundedRectangle(cornerRadius: style.cornerRadius)
                                    .stroke(style.colors.accent.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(radius: style.shadowRadius)
                    .padding(style.padding)
            )
        case .neon:
            return AnyView(
                view
                    .background(style.colors.surface)
                    .cornerRadius(style.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .stroke(style.colors.accent, lineWidth: 2)
                            .shadow(color: style.colors.accent, radius: 4)
                    )
                    .padding(style.padding)
            )
        }
    }
    
    // MARK: - Crown Animations
    func createCrownAnimation(_ animation: CrownAnimation) -> some View {
        switch animation.animationType {
        case .sparkle:
            return AnyView(SparkleCrownAnimation(duration: animation.duration))
        case .glow:
            return AnyView(GlowCrownAnimation(duration: animation.duration))
        case .pulse:
            return AnyView(PulseCrownAnimation(duration: animation.duration))
        case .rainbow:
            return AnyView(RainbowCrownAnimation(duration: animation.duration))
        case .fire:
            return AnyView(FireCrownAnimation(duration: animation.duration))
        case .ice:
            return AnyView(IceCrownAnimation(duration: animation.duration))
        }
    }
    
    // MARK: - Theme Customization
    func createCustomTheme(name: String, colors: LeaderboardColors) -> LeaderboardTheme {
        let customTheme = LeaderboardTheme(
            id: UUID().uuidString,
            name: name,
            displayName: name,
            description: "Custom theme",
            isPremium: false,
            colors: colors,
            crownStyle: .classic,
            animationStyle: .subtle,
            isDefault: false
        )
        
        // Save custom theme
        saveCustomTheme(customTheme)
        
        return customTheme
    }
    
    private func saveCustomTheme(_ theme: LeaderboardTheme) {
        // Save custom theme to UserDefaults
        if let data = try? JSONEncoder().encode(theme) {
            UserDefaults.standard.set(data, forKey: "custom_theme_\(theme.id)")
        }
    }
    
    // MARK: - Analytics
    func getThemeStats() -> LeaderboardThemeStats {
        return LeaderboardThemeStats(
            currentTheme: currentTheme,
            availableThemesCount: availableThemes.count,
            premiumThemesCount: availableThemes.filter { $0.isPremium }.count,
            crownAnimationsCount: crownAnimations.count,
            leaderboardStylesCount: leaderboardStyles.count,
            themeUsage: getThemeUsage()
        )
    }
    
    private func getThemeUsage() -> [String: Int] {
        // This would track theme usage statistics
        return [
            "default": 10,
            "dark": 8,
            "neon": 5,
            "gold": 3,
            "minimal": 2
        ]
    }
    
    // MARK: - Helper Methods
    private func logTheme(_ message: String) {
        print("[LeaderboardTheme] \(message)")
    }
}

// MARK: - Supporting Types
struct LeaderboardTheme: Codable {
    let id: String
    let name: String
    let displayName: String
    let description: String
    let isPremium: Bool
    let colors: LeaderboardColors
    let crownStyle: CrownStyle
    let animationStyle: AnimationStyle
    let isDefault: Bool
}

struct LeaderboardColors: Codable {
    let background: Color
    let surface: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let success: Color
    let warning: Color
    let error: Color
}

enum CrownStyle: String, CaseIterable, Codable {
    case classic = "classic"
    case glow = "glow"
    case neon = "neon"
    case royal = "royal"
    case minimal = "minimal"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .glow: return "Glow"
        case .neon: return "Neon"
        case .royal: return "Royal"
        case .minimal: return "Minimal"
        }
    }
}

enum AnimationStyle: String, CaseIterable, Codable {
    case none = "none"
    case subtle = "subtle"
    case smooth = "smooth"
    case energetic = "energetic"
    case elegant = "elegant"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .subtle: return "Subtle"
        case .smooth: return "Smooth"
        case .energetic: return "Energetic"
        case .elegant: return "Elegant"
        }
    }
}

struct Crown {
    let id: String
    let rank: Int
    let style: CrownStyle
    let color: Color
    let size: CrownSize
    let animation: CrownAnimation?
    let isAnimated: Bool
}

enum CrownSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    var value: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 30
        case .large: return 40
        }
    }
}

struct CrownAnimation {
    let id: String
    let name: String
    let displayName: String
    let description: String
    let duration: Double
    let isPremium: Bool
    let animationType: CrownAnimationType
}

enum CrownAnimationType: String, CaseIterable {
    case sparkle = "sparkle"
    case glow = "glow"
    case pulse = "pulse"
    case rainbow = "rainbow"
    case fire = "fire"
    case ice = "ice"
    
    var displayName: String {
        switch self {
        case .sparkle: return "Sparkle"
        case .glow: return "Glow"
        case .pulse: return "Pulse"
        case .rainbow: return "Rainbow"
        case .fire: return "Fire"
        case .ice: return "Ice"
        }
    }
}

struct LeaderboardStyle {
    let id: String
    let name: String
    let displayName: String
    let description: String
    let isPremium: Bool
    let styleType: LeaderboardStyleType
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let padding: CGFloat
    
    var colors: LeaderboardColors {
        return LeaderboardThemeManager.shared.currentTheme.colors
    }
}

enum LeaderboardStyleType: String, CaseIterable {
    case card = "card"
    case list = "list"
    case glass = "glass"
    case neon = "neon"
    
    var displayName: String {
        switch self {
        case .card: return "Card"
        case .list: return "List"
        case .glass: return "Glass"
        case .neon: return "Neon"
        }
    }
}

struct LeaderboardThemeConfiguration {
    let defaultThemeId = "default"
    let premiumThemeIds = ["neon", "gold"]
    let maxCustomThemes = 5
    let themeChangeCooldown: TimeInterval = 300 // 5 minutes
}

struct LeaderboardThemeStats {
    let currentTheme: LeaderboardTheme
    let availableThemesCount: Int
    let premiumThemesCount: Int
    let crownAnimationsCount: Int
    let leaderboardStylesCount: Int
    let themeUsage: [String: Int]
}

// MARK: - Crown Animation Views
struct SparkleCrownAnimation: View {
    let duration: Double
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "crown.fill")
            .foregroundColor(.yellow)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.8 : 1.0)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct GlowCrownAnimation: View {
    let duration: Double
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "crown.fill")
            .foregroundColor(.yellow)
            .shadow(color: .yellow, radius: isAnimating ? 10 : 5)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct PulseCrownAnimation: View {
    let duration: Double
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "crown.fill")
            .foregroundColor(.yellow)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct RainbowCrownAnimation: View {
    let duration: Double
    @State private var hue: Double = 0
    
    var body: some View {
        Image(systemName: "crown.fill")
            .foregroundColor(Color(hue: hue, saturation: 1, brightness: 1))
            .animation(
                Animation.linear(duration: duration)
                    .repeatForever(autoreverses: false),
                value: hue
            )
            .onAppear {
                hue = 1.0
            }
    }
}

struct FireCrownAnimation: View {
    let duration: Double
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "crown.fill")
            .foregroundColor(.orange)
            .shadow(color: .red, radius: isAnimating ? 8 : 4)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct IceCrownAnimation: View {
    let duration: Double
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "crown.fill")
            .foregroundColor(.cyan)
            .shadow(color: .blue, radius: isAnimating ? 6 : 3)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
