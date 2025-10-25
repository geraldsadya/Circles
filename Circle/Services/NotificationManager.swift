//
//  NotificationManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import UserNotifications
import CoreData
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    @Published var notificationSettings: NotificationSettings = NotificationSettings()
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let challengeEngine = ChallengeEngine.shared
    private let forfeitEngine = ForfeitEngine.shared
    private let leaderboardManager = LeaderboardManager.shared
    
    // Notification categories
    private let challengeCategory = "CHALLENGE_CATEGORY"
    private let forfeitCategory = "FORFEIT_CATEGORY"
    private let hangoutCategory = "HANGOUT_CATEGORY"
    private let leaderboardCategory = "LEADERBOARD_CATEGORY"
    private let reminderCategory = "REMINDER_CATEGORY"
    
    // Notification identifiers
    private let challengeReminderPrefix = "challenge_reminder_"
    private let forfeitDeadlinePrefix = "forfeit_deadline_"
    private let hangoutDetectedPrefix = "hangout_detected_"
    private let leaderboardUpdatePrefix = "leaderboard_update_"
    private let weeklyResetPrefix = "weekly_reset_"
    
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupNotifications()
        setupNotificationCategories()
        requestNotificationPermission()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChallengeCreated),
            name: .challengeCreated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForfeitAssigned),
            name: .forfeitsAssigned,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHangoutStarted),
            name: .hangoutStarted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLeaderboardUpdated),
            name: .leaderboardUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWeeklyReset),
            name: .weeklyPointsReset,
            object: nil
        )
    }
    
    private func setupNotificationCategories() {
        // Challenge category
        let challengeAction = UNNotificationAction(
            identifier: "CHALLENGE_ACTION",
            title: "View Challenge",
            options: [.foreground]
        )
        
        let challengeCategory = UNNotificationCategory(
            identifier: challengeCategory,
            actions: [challengeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Forfeit category
        let forfeitAction = UNNotificationAction(
            identifier: "FORFEIT_ACTION",
            title: "Complete Forfeit",
            options: [.foreground]
        )
        
        let forfeitCategory = UNNotificationCategory(
            identifier: forfeitCategory,
            actions: [forfeitAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Hangout category
        let hangoutAction = UNNotificationAction(
            identifier: "HANGOUT_ACTION",
            title: "View Hangout",
            options: [.foreground]
        )
        
        let hangoutCategory = UNNotificationCategory(
            identifier: hangoutCategory,
            actions: [hangoutAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Leaderboard category
        let leaderboardAction = UNNotificationAction(
            identifier: "LEADERBOARD_ACTION",
            title: "View Leaderboard",
            options: [.foreground]
        )
        
        let leaderboardCategory = UNNotificationCategory(
            identifier: leaderboardCategory,
            actions: [leaderboardAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Reminder category
        let reminderAction = UNNotificationAction(
            identifier: "REMINDER_ACTION",
            title: "View Reminder",
            options: [.foreground]
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: reminderCategory,
            actions: [reminderAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            challengeCategory,
            forfeitCategory,
            hangoutCategory,
            leaderboardCategory,
            reminderCategory
        ])
    }
    
    // MARK: - Permission Management
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            
            if granted {
                await MainActor.run {
                    self.setupNotificationSettings()
                }
            }
            
        } catch {
            errorMessage = "Failed to request notification permission: \(error.localizedDescription)"
            print("Error requesting notification permission: \(error)")
        }
    }
    
    private func setupNotificationSettings() {
        // Set up default notification settings
        notificationSettings = NotificationSettings(
            challengeReminders: true,
            forfeitDeadlines: true,
            hangoutDetected: true,
            leaderboardUpdates: true,
            weeklyResets: true,
            reminderTime: DateComponents(hour: 20, minute: 0), // 8:00 PM
            quietHoursStart: DateComponents(hour: 22, minute: 0), // 10:00 PM
            quietHoursEnd: DateComponents(hour: 8, minute: 0) // 8:00 AM
        )
    }
    
    // MARK: - Challenge Notifications
    func scheduleChallengeReminder(for challenge: Challenge, user: User) {
        guard notificationSettings.challengeReminders else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Reminder"
        content.body = "Don't forget about your challenge: \(challenge.title ?? "Unknown")"
        content.sound = .default
        content.categoryIdentifier = challengeCategory
        content.userInfo = [
            "challengeId": challenge.id?.uuidString ?? "",
            "userId": user.id?.uuidString ?? "",
            "type": "challenge_reminder"
        ]
        
        // Schedule reminder for 1 hour before challenge deadline
        let reminderDate = challenge.endDate?.addingTimeInterval(-3600) ?? Date().addingTimeInterval(3600)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(challengeReminderPrefix)\(challenge.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling challenge reminder: \(error)")
            }
        }
    }
    
    func scheduleChallengeDeadline(for challenge: Challenge, user: User) {
        guard notificationSettings.challengeReminders else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Deadline"
        content.body = "Your challenge '\(challenge.title ?? "Unknown")' is due soon!"
        content.sound = .default
        content.categoryIdentifier = challengeCategory
        content.userInfo = [
            "challengeId": challenge.id?.uuidString ?? "",
            "userId": user.id?.uuidString ?? "",
            "type": "challenge_deadline"
        ]
        
        // Schedule deadline notification
        let deadlineDate = challenge.endDate ?? Date().addingTimeInterval(3600)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: deadlineDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(challengeReminderPrefix)deadline_\(challenge.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling challenge deadline: \(error)")
            }
        }
    }
    
    // MARK: - Forfeit Notifications
    func scheduleForfeitDeadline(for forfeit: Forfeit, user: User) {
        guard notificationSettings.forfeitDeadlines else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Forfeit Deadline"
        content.body = "Complete your forfeit: \(forfeit.title ?? "Unknown")"
        content.sound = .default
        content.categoryIdentifier = forfeitCategory
        content.userInfo = [
            "forfeitId": forfeit.id?.uuidString ?? "",
            "userId": user.id?.uuidString ?? "",
            "type": "forfeit_deadline"
        ]
        
        // Schedule deadline notification
        let deadlineDate = forfeit.dueDate ?? Date().addingTimeInterval(24 * 3600) // 24 hours
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: deadlineDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(forfeitDeadlinePrefix)\(forfeit.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling forfeit deadline: \(error)")
            }
        }
    }
    
    func scheduleForfeitReminder(for forfeit: Forfeit, user: User) {
        guard notificationSettings.forfeitDeadlines else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Forfeit Reminder"
        content.body = "Don't forget to complete your forfeit: \(forfeit.title ?? "Unknown")"
        content.sound = .default
        content.categoryIdentifier = forfeitCategory
        content.userInfo = [
            "forfeitId": forfeit.id?.uuidString ?? "",
            "userId": user.id?.uuidString ?? "",
            "type": "forfeit_reminder"
        ]
        
        // Schedule reminder for 2 hours before deadline
        let reminderDate = forfeit.dueDate?.addingTimeInterval(-2 * 3600) ?? Date().addingTimeInterval(22 * 3600)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(forfeitDeadlinePrefix)reminder_\(forfeit.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling forfeit reminder: \(error)")
            }
        }
    }
    
    // MARK: - Hangout Notifications
    func scheduleHangoutDetected(for hangoutSession: HangoutSession, user: User) {
        guard notificationSettings.hangoutDetected else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Hangout Detected"
        content.body = "You're hanging out with friends! Points are being earned automatically."
        content.sound = .default
        content.categoryIdentifier = hangoutCategory
        content.userInfo = [
            "hangoutId": hangoutSession.id?.uuidString ?? "",
            "userId": user.id?.uuidString ?? "",
            "type": "hangout_detected"
        ]
        
        // Schedule immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "\(hangoutDetectedPrefix)\(hangoutSession.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling hangout notification: \(error)")
            }
        }
    }
    
    // MARK: - Leaderboard Notifications
    func scheduleLeaderboardUpdate(for circle: Circle, user: User) {
        guard notificationSettings.leaderboardUpdates else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Leaderboard Updated"
        content.body = "Your ranking in \(circle.name ?? "Circle") has been updated!"
        content.sound = .default
        content.categoryIdentifier = leaderboardCategory
        content.userInfo = [
            "circleId": circle.id?.uuidString ?? "",
            "userId": user.id?.uuidString ?? "",
            "type": "leaderboard_update"
        ]
        
        // Schedule immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "\(leaderboardUpdatePrefix)\(circle.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling leaderboard notification: \(error)")
            }
        }
    }
    
    // MARK: - Weekly Reset Notifications
    func scheduleWeeklyResetNotification(for user: User) {
        guard notificationSettings.weeklyResets else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Reset"
        content.body = "New week, new challenges! Your weekly points have been reset."
        content.sound = .default
        content.categoryIdentifier = reminderCategory
        content.userInfo = [
            "userId": user.id?.uuidString ?? "",
            "type": "weekly_reset"
        ]
        
        // Schedule for Monday at 8:00 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "\(weeklyResetPrefix)\(user.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling weekly reset notification: \(error)")
            }
        }
    }
    
    // MARK: - Custom Reminders
    func scheduleCustomReminder(
        title: String,
        body: String,
        date: Date,
        user: User,
        category: String = reminderCategory
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = [
            "userId": user.id?.uuidString ?? "",
            "type": "custom_reminder"
        ]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "custom_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling custom reminder: \(error)")
            }
        }
    }
    
    // MARK: - Notification Management
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func cancelNotifications(for user: User) {
        // Cancel all notifications for a specific user
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let userRequests = requests.filter { request in
                if let userId = request.content.userInfo["userId"] as? String {
                    return userId == user.id?.uuidString
                }
                return false
            }
            
            let identifiers = userRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    func getPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        
        await MainActor.run {
            pendingNotifications = requests
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleChallengeCreated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let challenge = userInfo["challenge"] as? Challenge,
              let user = userInfo["user"] as? User else { return }
        
        scheduleChallengeReminder(for: challenge, user: user)
        scheduleChallengeDeadline(for: challenge, user: user)
    }
    
    @objc private func handleForfeitAssigned(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let forfeit = userInfo["forfeit"] as? Forfeit,
              let user = userInfo["user"] as? User else { return }
        
        scheduleForfeitDeadline(for: forfeit, user: user)
        scheduleForfeitReminder(for: forfeit, user: user)
    }
    
    @objc private func handleHangoutStarted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hangout = userInfo["hangout"] as? HangoutSession,
              let user = userInfo["user"] as? User else { return }
        
        scheduleHangoutDetected(for: hangout, user: user)
    }
    
    @objc private func handleLeaderboardUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let circle = userInfo["circle"] as? Circle,
              let user = userInfo["user"] as? User else { return }
        
        scheduleLeaderboardUpdate(for: circle, user: user)
    }
    
    @objc private func handleWeeklyReset(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let user = userInfo["user"] as? User else { return }
        
        scheduleWeeklyResetNotification(for: user)
    }
    
    // MARK: - Settings Management
    func updateNotificationSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        
        // Cancel existing notifications if settings changed
        if !settings.challengeReminders {
            cancelNotifications(withPrefix: challengeReminderPrefix)
        }
        
        if !settings.forfeitDeadlines {
            cancelNotifications(withPrefix: forfeitDeadlinePrefix)
        }
        
        if !settings.hangoutDetected {
            cancelNotifications(withPrefix: hangoutDetectedPrefix)
        }
        
        if !settings.leaderboardUpdates {
            cancelNotifications(withPrefix: leaderboardUpdatePrefix)
        }
        
        if !settings.weeklyResets {
            cancelNotifications(withPrefix: weeklyResetPrefix)
        }
    }
    
    private func cancelNotifications(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let matchingRequests = requests.filter { $0.identifier.hasPrefix(prefix) }
            let identifiers = matchingRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    // MARK: - Analytics
    func getNotificationStats() -> NotificationStats {
        let totalPending = pendingNotifications.count
        
        let challengeNotifications = pendingNotifications.filter { $0.identifier.hasPrefix(challengeReminderPrefix) }.count
        let forfeitNotifications = pendingNotifications.filter { $0.identifier.hasPrefix(forfeitDeadlinePrefix) }.count
        let hangoutNotifications = pendingNotifications.filter { $0.identifier.hasPrefix(hangoutDetectedPrefix) }.count
        let leaderboardNotifications = pendingNotifications.filter { $0.identifier.hasPrefix(leaderboardUpdatePrefix) }.count
        
        return NotificationStats(
            totalPending: totalPending,
            challengeNotifications: challengeNotifications,
            forfeitNotifications: forfeitNotifications,
            hangoutNotifications: hangoutNotifications,
            leaderboardNotifications: leaderboardNotifications,
            isAuthorized: isAuthorized
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification actions
        switch response.actionIdentifier {
        case "CHALLENGE_ACTION":
            handleChallengeAction(userInfo: userInfo)
        case "FORFEIT_ACTION":
            handleForfeitAction(userInfo: userInfo)
        case "HANGOUT_ACTION":
            handleHangoutAction(userInfo: userInfo)
        case "LEADERBOARD_ACTION":
            handleLeaderboardAction(userInfo: userInfo)
        case "REMINDER_ACTION":
            handleReminderAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleChallengeAction(userInfo: [AnyHashable: Any]) {
        // Navigate to challenge
        if let challengeId = userInfo["challengeId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToChallenge,
                object: nil,
                userInfo: ["challengeId": challengeId]
            )
        }
    }
    
    private func handleForfeitAction(userInfo: [AnyHashable: Any]) {
        // Navigate to forfeit
        if let forfeitId = userInfo["forfeitId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToForfeit,
                object: nil,
                userInfo: ["forfeitId": forfeitId]
            )
        }
    }
    
    private func handleHangoutAction(userInfo: [AnyHashable: Any]) {
        // Navigate to hangout
        if let hangoutId = userInfo["hangoutId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToHangout,
                object: nil,
                userInfo: ["hangoutId": hangoutId]
            )
        }
    }
    
    private func handleLeaderboardAction(userInfo: [AnyHashable: Any]) {
        // Navigate to leaderboard
        if let circleId = userInfo["circleId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToLeaderboard,
                object: nil,
                userInfo: ["circleId": circleId]
            )
        }
    }
    
    private func handleReminderAction(userInfo: [AnyHashable: Any]) {
        // Navigate to reminders
        NotificationCenter.default.post(
            name: .navigateToReminders,
            object: nil
        )
    }
}

// MARK: - Supporting Types
struct NotificationSettings {
    var challengeReminders: Bool = true
    var forfeitDeadlines: Bool = true
    var hangoutDetected: Bool = true
    var leaderboardUpdates: Bool = true
    var weeklyResets: Bool = true
    var reminderTime: DateComponents = DateComponents(hour: 20, minute: 0)
    var quietHoursStart: DateComponents = DateComponents(hour: 22, minute: 0)
    var quietHoursEnd: DateComponents = DateComponents(hour: 8, minute: 0)
}

struct NotificationStats {
    let totalPending: Int
    let challengeNotifications: Int
    let forfeitNotifications: Int
    let hangoutNotifications: Int
    let leaderboardNotifications: Int
    let isAuthorized: Bool
}

// MARK: - Notifications
extension Notification.Name {
    static let challengeCreated = Notification.Name("challengeCreated")
    static let navigateToChallenge = Notification.Name("navigateToChallenge")
    static let navigateToForfeit = Notification.Name("navigateToForfeit")
    static let navigateToHangout = Notification.Name("navigateToHangout")
    static let navigateToLeaderboard = Notification.Name("navigateToLeaderboard")
    static let navigateToReminders = Notification.Name("navigateToReminders")
}
