//
//  HapticFeedbackManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import UIKit
import SwiftUI
import Combine

@MainActor
class HapticFeedbackManager: ObservableObject {
    static let shared = HapticFeedbackManager()
    
    @Published var isHapticsEnabled = true
    @Published var hapticIntensity: HapticIntensity = .medium
    @Published var animationSpeed: AnimationSpeed = .normal
    @Published var isReducedMotionEnabled = false
    @Published var errorMessage: String?
    
    // Haptic feedback generators
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    // Animation configuration
    private let animationConfig = AnimationConfig()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupHaptics()
        setupAccessibility()
        loadHapticSettings()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupHaptics() {
        // Prepare haptic generators
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        
        // Check if haptics are available
        isHapticsEnabled = UIDevice.current.userInterfaceIdiom == .phone
    }
    
    private func setupAccessibility() {
        // Check for reduced motion preference
        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
        
        // Observe accessibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccessibilityChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    private func loadHapticSettings() {
        // Load saved haptic settings
        isHapticsEnabled = UserDefaults.standard.bool(forKey: "haptics_enabled")
        
        if let savedIntensity = UserDefaults.standard.string(forKey: "haptic_intensity"),
           let intensity = HapticIntensity(rawValue: savedIntensity) {
            hapticIntensity = intensity
        }
        
        if let savedSpeed = UserDefaults.standard.string(forKey: "animation_speed"),
           let speed = AnimationSpeed(rawValue: savedSpeed) {
            animationSpeed = speed
        }
    }
    
    // MARK: - Haptic Feedback
    func triggerHaptic(_ hapticType: HapticType) {
        guard isHapticsEnabled else { return }
        
        switch hapticType {
        case .light:
            triggerLightHaptic()
        case .medium:
            triggerMediumHaptic()
        case .heavy:
            triggerHeavyHaptic()
        case .selection:
            triggerSelectionHaptic()
        case .success:
            triggerSuccessHaptic()
        case .warning:
            triggerWarningHaptic()
        case .error:
            triggerErrorHaptic()
        case .custom(let intensity, let pattern):
            triggerCustomHaptic(intensity: intensity, pattern: pattern)
        }
    }
    
    private func triggerLightHaptic() {
        lightImpactGenerator.impactOccurred()
    }
    
    private func triggerMediumHaptic() {
        mediumImpactGenerator.impactOccurred()
    }
    
    private func triggerHeavyHaptic() {
        heavyImpactGenerator.impactOccurred()
    }
    
    private func triggerSelectionHaptic() {
        selectionGenerator.selectionChanged()
    }
    
    private func triggerSuccessHaptic() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    private func triggerWarningHaptic() {
        notificationGenerator.notificationOccurred(.warning)
    }
    
    private func triggerErrorHaptic() {
        notificationGenerator.notificationOccurred(.error)
    }
    
    private func triggerCustomHaptic(intensity: HapticIntensity, pattern: HapticPattern) {
        // Implement custom haptic patterns
        switch pattern {
        case .single:
            triggerHaptic(intensity.hapticType)
        case .double:
            triggerHaptic(intensity.hapticType)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.triggerHaptic(intensity.hapticType)
            }
        case .triple:
            triggerHaptic(intensity.hapticType)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.triggerHaptic(intensity.hapticType)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.triggerHaptic(intensity.hapticType)
            }
        case .pulse(let count):
            for i in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    self.triggerHaptic(intensity.hapticType)
                }
            }
        }
    }
    
    // MARK: - Context-Specific Haptics
    func triggerChallengeHaptic(_ event: ChallengeEvent) {
        switch event {
        case .created:
            triggerHaptic(.medium)
        case .completed:
            triggerHaptic(.success)
        case .failed:
            triggerHaptic(.warning)
        case .expired:
            triggerHaptic(.error)
        }
    }
    
    func triggerHangoutHaptic(_ event: HangoutEvent) {
        switch event {
        case .started:
            triggerHaptic(.medium)
        case .ended:
            triggerHaptic(.light)
        case .pointsEarned:
            triggerHaptic(.success)
        }
    }
    
    func triggerCameraHaptic(_ event: CameraEvent) {
        switch event {
        case .captureStarted:
            triggerHaptic(.light)
        case .captureCompleted:
            triggerHaptic(.success)
        case .captureFailed:
            triggerHaptic(.error)
        case .livenessDetected:
            triggerHaptic(.medium)
        }
    }
    
    func triggerLeaderboardHaptic(_ event: LeaderboardEvent) {
        switch event {
        case .rankUp:
            triggerHaptic(.success)
        case .rankDown:
            triggerHaptic(.warning)
        case .newRecord:
            triggerHaptic(.heavy)
        case .weeklyReset:
            triggerHaptic(.medium)
        }
    }
    
    func triggerForfeitHaptic(_ event: ForfeitEvent) {
        switch event {
        case .assigned:
            triggerHaptic(.warning)
        case .completed:
            triggerHaptic(.success)
        case .skipped:
            triggerHaptic(.error)
        }
    }
    
    // MARK: - Animation Management
    func animateWithHaptic<T: View>(_ view: T, animation: Animation, haptic: HapticType) -> some View {
        return view
            .animation(animation, value: animation)
            .onAppear {
                self.triggerHaptic(haptic)
            }
    }
    
    func getAnimationDuration(for type: AnimationType) -> Double {
        let baseDuration = animationConfig.baseDuration
        
        switch animationSpeed {
        case .slow:
            return baseDuration * 1.5
        case .normal:
            return baseDuration
        case .fast:
            return baseDuration * 0.7
        case .instant:
            return 0.1
        }
    }
    
    func getAnimationEasing(for type: AnimationType) -> Animation {
        if isReducedMotionEnabled {
            return .linear(duration: 0.1)
        }
        
        switch type {
        case .bounce:
            return .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
        case .smooth:
            return .easeInOut(duration: getAnimationDuration(for: type))
        case .sharp:
            return .easeOut(duration: getAnimationDuration(for: type))
        case .gentle:
            return .easeIn(duration: getAnimationDuration(for: type))
        }
    }
    
    // MARK: - Micro-animations
    func createMicroAnimation(for action: MicroAnimationAction) -> MicroAnimation {
        return MicroAnimation(
            action: action,
            duration: getAnimationDuration(for: action.animationType),
            easing: getAnimationEasing(for: action.animationType),
            haptic: action.hapticType,
            isEnabled: !isReducedMotionEnabled
        )
    }
    
    // MARK: - Settings Management
    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "haptics_enabled")
    }
    
    func setHapticIntensity(_ intensity: HapticIntensity) {
        hapticIntensity = intensity
        UserDefaults.standard.set(intensity.rawValue, forKey: "haptic_intensity")
    }
    
    func setAnimationSpeed(_ speed: AnimationSpeed) {
        animationSpeed = speed
        UserDefaults.standard.set(speed.rawValue, forKey: "animation_speed")
    }
    
    // MARK: - Accessibility
    @objc private func handleAccessibilityChanged() {
        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
    
    func isAccessibilityFeatureEnabled(_ feature: AccessibilityFeature) -> Bool {
        switch feature {
        case .reduceMotion:
            return UIAccessibility.isReduceMotionEnabled
        case .reduceTransparency:
            return UIAccessibility.isReduceTransparencyEnabled
        case .increaseContrast:
            return UIAccessibility.isDarkerSystemColorsEnabled
        case .largerText:
            return UIAccessibility.isBoldTextEnabled
        }
    }
    
    // MARK: - Performance Optimization
    func optimizeForPerformance() {
        // Reduce haptic intensity for better performance
        if hapticIntensity == .heavy {
            hapticIntensity = .medium
        }
        
        // Reduce animation speed for better performance
        if animationSpeed == .slow {
            animationSpeed = .normal
        }
        
        print("Haptics optimized for performance")
    }
    
    func restoreNormalSettings() {
        // Restore normal haptic settings
        hapticIntensity = .medium
        animationSpeed = .normal
        
        print("Haptics restored to normal settings")
    }
    
    // MARK: - Analytics
    func getHapticStats() -> HapticStats {
        return HapticStats(
            isHapticsEnabled: isHapticsEnabled,
            hapticIntensity: hapticIntensity,
            animationSpeed: animationSpeed,
            isReducedMotionEnabled: isReducedMotionEnabled,
            totalHapticsTriggered: getTotalHapticsTriggered(),
            mostUsedHaptic: getMostUsedHaptic(),
            hapticUsageByContext: getHapticUsageByContext()
        )
    }
    
    private func getTotalHapticsTriggered() -> Int {
        // This would track actual haptic usage
        return 0
    }
    
    private func getMostUsedHaptic() -> HapticType {
        // This would track actual haptic usage
        return .medium
    }
    
    private func getHapticUsageByContext() -> [String: Int] {
        // This would track actual haptic usage by context
        return [
            "challenge": 10,
            "hangout": 5,
            "camera": 8,
            "leaderboard": 3,
            "forfeit": 2
        ]
    }
    
    // MARK: - Testing
    func testHaptics() {
        // Test all haptic types
        let hapticTypes: [HapticType] = [.light, .medium, .heavy, .selection, .success, .warning, .error]
        
        for (index, hapticType) in hapticTypes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                self.triggerHaptic(hapticType)
            }
        }
    }
    
    func testAnimations() {
        // Test all animation types
        let animationTypes: [AnimationType] = [.bounce, .smooth, .sharp, .gentle]
        
        for (index, animationType) in animationTypes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                let duration = self.getAnimationDuration(for: animationType)
                let easing = self.getAnimationEasing(for: animationType)
                print("Testing \(animationType.rawValue) animation: duration=\(duration), easing=\(easing)")
            }
        }
    }
}

// MARK: - Supporting Types
enum HapticType {
    case light
    case medium
    case heavy
    case selection
    case success
    case warning
    case error
    case custom(intensity: HapticIntensity, pattern: HapticPattern)
}

enum HapticIntensity: String, CaseIterable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }
    
    var hapticType: HapticType {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }
}

enum HapticPattern: String, CaseIterable {
    case single = "single"
    case double = "double"
    case triple = "triple"
    case pulse(count: Int) = "pulse"
    
    var displayName: String {
        switch self {
        case .single: return "Single"
        case .double: return "Double"
        case .triple: return "Triple"
        case .pulse(let count): return "Pulse (\(count))"
        }
    }
}

enum AnimationSpeed: String, CaseIterable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"
    case instant = "instant"
    
    var displayName: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        case .instant: return "Instant"
        }
    }
}

enum AnimationType: String, CaseIterable {
    case bounce = "bounce"
    case smooth = "smooth"
    case sharp = "sharp"
    case gentle = "gentle"
    
    var displayName: String {
        switch self {
        case .bounce: return "Bounce"
        case .smooth: return "Smooth"
        case .sharp: return "Sharp"
        case .gentle: return "Gentle"
        }
    }
}

enum MicroAnimationAction {
    case buttonPress
    case cardFlip
    case listItemAppear
    case progressUpdate
    case successCelebration
    case errorShake
    case loadingSpinner
    case pageTransition
    
    var animationType: AnimationType {
        switch self {
        case .buttonPress: return .sharp
        case .cardFlip: return .smooth
        case .listItemAppear: return .gentle
        case .progressUpdate: return .smooth
        case .successCelebration: return .bounce
        case .errorShake: return .sharp
        case .loadingSpinner: return .smooth
        case .pageTransition: return .smooth
        }
    }
    
    var hapticType: HapticType {
        switch self {
        case .buttonPress: return .light
        case .cardFlip: return .medium
        case .listItemAppear: return .light
        case .progressUpdate: return .light
        case .successCelebration: return .success
        case .errorShake: return .error
        case .loadingSpinner: return .light
        case .pageTransition: return .selection
        }
    }
}

enum AccessibilityFeature: String, CaseIterable {
    case reduceMotion = "reduce_motion"
    case reduceTransparency = "reduce_transparency"
    case increaseContrast = "increase_contrast"
    case largerText = "larger_text"
    
    var displayName: String {
        switch self {
        case .reduceMotion: return "Reduce Motion"
        case .reduceTransparency: return "Reduce Transparency"
        case .increaseContrast: return "Increase Contrast"
        case .largerText: return "Larger Text"
        }
    }
}

// MARK: - Event Types
enum ChallengeEvent {
    case created
    case completed
    case failed
    case expired
}

enum HangoutEvent {
    case started
    case ended
    case pointsEarned
}

enum CameraEvent {
    case captureStarted
    case captureCompleted
    case captureFailed
    case livenessDetected
}

enum LeaderboardEvent {
    case rankUp
    case rankDown
    case newRecord
    case weeklyReset
}

enum ForfeitEvent {
    case assigned
    case completed
    case skipped
}

// MARK: - Supporting Structures
struct AnimationConfig {
    let baseDuration: Double = 0.3
    let bounceResponse: Double = 0.6
    let bounceDamping: Double = 0.8
}

struct MicroAnimation {
    let action: MicroAnimationAction
    let duration: Double
    let easing: Animation
    let haptic: HapticType
    let isEnabled: Bool
}

struct HapticStats {
    let isHapticsEnabled: Bool
    let hapticIntensity: HapticIntensity
    let animationSpeed: AnimationSpeed
    let isReducedMotionEnabled: Bool
    let totalHapticsTriggered: Int
    let mostUsedHaptic: HapticType
    let hapticUsageByContext: [String: Int]
}
