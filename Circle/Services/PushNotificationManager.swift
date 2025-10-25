//
//  PushNotificationManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import UserNotifications
import CloudKit
import Combine

@MainActor
class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var isAuthorized: Bool = false
    @Published var notificationSettings: NotificationSettings = NotificationSettings()
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Notification categories
    private let notificationCategories: Set<UNNotificationCategory> = [
        UNNotificationCategory(
            identifier: "HANGOUT_NOTIFICATION",
            actions: [
                UNNotificationAction(identifier: "JOIN_HANGOUT", title: "Join", options: [.foreground]),
                UNNotificationAction(identifier: "DECLINE_HANGOUT", title: "Decline", options: [])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        ),
        UNNotificationCategory(
            identifier: "CHALLENGE_NOTIFICATION",
            actions: [
                UNNotificationAction(identifier: "ACCEPT_CHALLENGE", title: "Accept", options: [.foreground]),
                UNNotificationAction(identifier: "DECLINE_CHALLENGE", title: "Decline", options: [])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        ),
        UNNotificationCategory(
            identifier: "PHOTO_STORY_NOTIFICATION",
            actions: [
                UNNotificationAction(identifier: "APPROVE_PHOTO", title: "Approve", options: [.foreground]),
                UNNotificationAction(identifier: "DECLINE_PHOTO", title: "Decline", options: [])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        ),
        UNNotificationCategory(
            identifier: "CIRCLE_INVITATION",
            actions: [
                UNNotificationAction(identifier: "ACCEPT_INVITATION", title: "Accept", options: [.foreground]),
                UNNotificationAction(identifier: "DECLINE_INVITATION", title: "Decline", options: [])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    ]
    
    init() {
        setupNotificationCenter()
        setupNotifications()
        checkAuthorizationStatus()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func setupNotificationCenter() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // Set notification categories
        center.setNotificationCategories(notificationCategories)
    }
    
    private func setupNotifications() {
        // Listen for app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppEnteredBackground()
            }
            .store(in: &cancellables)
        
        // Listen for CloudKit notifications
        NotificationCenter.default.publisher(for: .CKDatabaseChanged)
            .sink { [weak self] notification in
                self?.handleCloudKitNotification(notification)
            }
            .store(in: &cancellables)
        
        // Listen for local events
        NotificationCenter.default.publisher(for: .hangoutStarted)
            .sink { [weak self] notification in
                self?.handleHangoutStarted(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .hangoutEnded)
            .sink { [weak self] notification in
                self?.handleHangoutEnded(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .challengeCreated)
            .sink { [weak self] notification in
                self?.handleChallengeCreated(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .photoStoryApproved)
            .sink { [weak self] notification in
                self?.handlePhotoStoryApproved(notification)
            }
            .store(in: &cancellables)
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Authorization
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
            
            if granted {
                await registerForRemoteNotifications()
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to request notification permission: \(error.localizedDescription)"
            }
        }
    }
    
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - Local Notifications
    func scheduleHangoutReminder(for hangoutSession: HangoutSession, in timeInterval: TimeInterval) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Hangout Reminder"
        content.body = "You have a hangout starting in \(Int(timeInterval / 60)) minutes"
        content.sound = .default
        content.categoryIdentifier = "HANGOUT_NOTIFICATION"
        content.userInfo = [
            "hangoutID": hangoutSession.id.uuidString,
            "type": "hangout_reminder"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "hangout_reminder_\(hangoutSession.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule hangout reminder: \(error.localizedDescription)")
            } else {
                print("✅ Hangout reminder scheduled")
            }
        }
    }
    
    func scheduleChallengeReminder(for challenge: Challenge, in timeInterval: TimeInterval) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Reminder"
        content.body = "Don't forget about your challenge: \(challenge.title)"
        content.sound = .default
        content.categoryIdentifier = "CHALLENGE_NOTIFICATION"
        content.userInfo = [
            "challengeID": challenge.id.uuidString,
            "type": "challenge_reminder"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "challenge_reminder_\(challenge.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule challenge reminder: \(error.localizedDescription)")
            } else {
                print("✅ Challenge reminder scheduled")
            }
        }
    }
    
    func sendPhotoTagRequest(for photoStory: PhotoStory, to user: User) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Photo Tag Request"
        content.body = "\(photoStory.takenBy.name) tagged you in a photo story"
        content.sound = .default
        content.categoryIdentifier = "PHOTO_STORY_NOTIFICATION"
        content.userInfo = [
            "photoStoryID": photoStory.id.uuidString,
            "taggedUserID": user.id.uuidString,
            "type": "photo_tag_request"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "photo_tag_\(photoStory.id.uuidString)_\(user.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send photo tag request: \(error.localizedDescription)")
            } else {
                print("✅ Photo tag request sent")
            }
        }
    }
    
    func sendCircleInvitation(to user: User, for circle: Circle) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Circle Invitation"
        content.body = "You've been invited to join '\(circle.name)' circle"
        content.sound = .default
        content.categoryIdentifier = "CIRCLE_INVITATION"
        content.userInfo = [
            "circleID": circle.id.uuidString,
            "invitedUserID": user.id.uuidString,
            "type": "circle_invitation"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "circle_invitation_\(circle.id.uuidString)_\(user.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send circle invitation: \(error.localizedDescription)")
            } else {
                print("✅ Circle invitation sent")
            }
        }
    }
    
    // MARK: - Daily/Weekly Notifications
    func scheduleDailyMotivationNotification() {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Motivation"
        content.body = "Ready to crush your challenges today? 💪"
        content.sound = .default
        content.userInfo = ["type": "daily_motivation"]
        
        // Schedule for 9 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_motivation",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily motivation: \(error.localizedDescription)")
            } else {
                print("✅ Daily motivation notification scheduled")
            }
        }
    }
    
    func scheduleWeeklySummaryNotification() {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body = "Check out your weekly achievements! 🏆"
        content.sound = .default
        content.userInfo = ["type": "weekly_summary"]
        
        // Schedule for Sunday 6 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly_summary",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule weekly summary: \(error.localizedDescription)")
            } else {
                print("✅ Weekly summary notification scheduled")
            }
        }
    }
    
    // MARK: - Event Handlers
    private func handleAppBecameActive() {
        // Clear badge count
        UNUserNotificationCenter.current().setBadgeCount(0)
        
        // Check for pending notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            print("📱 \(notifications.count) delivered notifications")
        }
    }
    
    private func handleAppEnteredBackground() {
        // App entered background - notifications will continue to work
    }
    
    private func handleCloudKitNotification(_ notification: Notification) {
        // Handle CloudKit push notifications
        guard let userInfo = notification.userInfo,
              let ckNotification = userInfo[CKNotification.NotificationUserInfoKey] as? CKNotification else {
            return
        }
        
        // Process CloudKit notification
        processCloudKitNotification(ckNotification)
    }
    
    private func handleHangoutStarted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hangoutSession = userInfo["hangoutSession"] as? HangoutSession else {
            return
        }
        
        // Send notification to friends about hangout starting
        let content = UNMutableNotificationContent()
        content.title = "Hangout Started"
        content.body = "Your friends are hanging out nearby!"
        content.sound = .default
        content.userInfo = [
            "hangoutID": hangoutSession.id.uuidString,
            "type": "hangout_started"
        ]
        
        let request = UNNotificationRequest(
            identifier: "hangout_started_\(hangoutSession.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func handleHangoutEnded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hangoutSession = userInfo["hangoutSession"] as? HangoutSession else {
            return
        }
        
        // Send notification about hangout ending
        let content = UNMutableNotificationContent()
        content.title = "Hangout Ended"
        content.body = "Great hangout! You earned \(hangoutSession.pointsAwarded) points"
        content.sound = .default
        content.userInfo = [
            "hangoutID": hangoutSession.id.uuidString,
            "type": "hangout_ended"
        ]
        
        let request = UNNotificationRequest(
            identifier: "hangout_ended_\(hangoutSession.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func handleChallengeCreated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let challenge = userInfo["challenge"] as? Challenge else {
            return
        }
        
        // Send notification about new challenge
        let content = UNMutableNotificationContent()
        content.title = "New Challenge"
        content.body = "\(challenge.title) - \(challenge.points) points available!"
        content.sound = .default
        content.categoryIdentifier = "CHALLENGE_NOTIFICATION"
        content.userInfo = [
            "challengeID": challenge.id.uuidString,
            "type": "challenge_created"
        ]
        
        let request = UNNotificationRequest(
            identifier: "challenge_created_\(challenge.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func handlePhotoStoryApproved(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let photoStoryID = userInfo["photoStoryID"] as? UUID else {
            return
        }
        
        // Send notification about photo story approval
        let content = UNMutableNotificationContent()
        content.title = "Photo Story Approved"
        content.body = "Your photo story is now live!"
        content.sound = .default
        content.userInfo = [
            "photoStoryID": photoStoryID.uuidString,
            "type": "photo_story_approved"
        ]
        
        let request = UNNotificationRequest(
            identifier: "photo_story_approved_\(photoStoryID.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - CloudKit Notification Processing
    private func processCloudKitNotification(_ notification: CKNotification) {
        switch notification.notificationType {
        case .query:
            if let queryNotification = notification as? CKQueryNotification {
                processQueryNotification(queryNotification)
            }
        case .database:
            if let databaseNotification = notification as? CKDatabaseNotification {
                processDatabaseNotification(databaseNotification)
            }
        default:
            break
        }
    }
    
    private func processQueryNotification(_ notification: CKQueryNotification) {
        // Process CloudKit query notifications
        let recordID = notification.recordID
        
        switch notification.querySubscriptionID {
        case "CircleUpdates":
            sendCircleUpdateNotification(recordID: recordID)
        case "ChallengeUpdates":
            sendChallengeUpdateNotification(recordID: recordID)
        case "HangoutUpdates":
            sendHangoutUpdateNotification(recordID: recordID)
        case "PhotoStoryUpdates":
            sendPhotoStoryUpdateNotification(recordID: recordID)
        default:
            break
        }
    }
    
    private func processDatabaseNotification(_ notification: CKDatabaseNotification) {
        // Process database-level notifications
        print("Database notification received")
    }
    
    // MARK: - Specific Notification Senders
    private func sendCircleUpdateNotification(recordID: CKRecord.ID) {
        let content = UNMutableNotificationContent()
        content.title = "Circle Update"
        content.body = "Your circle has been updated"
        content.sound = .default
        content.userInfo = [
            "recordID": recordID.recordName,
            "type": "circle_update"
        ]
        
        let request = UNNotificationRequest(
            identifier: "circle_update_\(recordID.recordName)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendChallengeUpdateNotification(recordID: CKRecord.ID) {
        let content = UNMutableNotificationContent()
        content.title = "Challenge Update"
        content.body = "A challenge has been updated"
        content.sound = .default
        content.userInfo = [
            "recordID": recordID.recordName,
            "type": "challenge_update"
        ]
        
        let request = UNNotificationRequest(
            identifier: "challenge_update_\(recordID.recordName)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendHangoutUpdateNotification(recordID: CKRecord.ID) {
        let content = UNMutableNotificationContent()
        content.title = "Hangout Update"
        content.body = "Hangout activity detected"
        content.sound = .default
        content.userInfo = [
            "recordID": recordID.recordName,
            "type": "hangout_update"
        ]
        
        let request = UNNotificationRequest(
            identifier: "hangout_update_\(recordID.recordName)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendPhotoStoryUpdateNotification(recordID: CKRecord.ID) {
        let content = UNMutableNotificationContent()
        content.title = "Photo Story Update"
        content.body = "New photo story available"
        content.sound = .default
        content.userInfo = [
            "recordID": recordID.recordName,
            "type": "photo_story_update"
        ]
        
        let request = UNNotificationRequest(
            identifier: "photo_story_update_\(recordID.recordName)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Notification Management
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return await UNUserNotificationCenter.current().deliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "JOIN_HANGOUT":
            handleJoinHangoutAction(userInfo: userInfo)
        case "DECLINE_HANGOUT":
            handleDeclineHangoutAction(userInfo: userInfo)
        case "ACCEPT_CHALLENGE":
            handleAcceptChallengeAction(userInfo: userInfo)
        case "DECLINE_CHALLENGE":
            handleDeclineChallengeAction(userInfo: userInfo)
        case "APPROVE_PHOTO":
            handleApprovePhotoAction(userInfo: userInfo)
        case "DECLINE_PHOTO":
            handleDeclinePhotoAction(userInfo: userInfo)
        case "ACCEPT_INVITATION":
            handleAcceptInvitationAction(userInfo: userInfo)
        case "DECLINE_INVITATION":
            handleDeclineInvitationAction(userInfo: userInfo)
        default:
            // Default action (user tapped notification)
            handleDefaultAction(userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
    
    // MARK: - Action Handlers
    private func handleJoinHangoutAction(userInfo: [AnyHashable: Any]) {
        // Handle join hangout action
        print("User chose to join hangout")
    }
    
    private func handleDeclineHangoutAction(userInfo: [AnyHashable: Any]) {
        // Handle decline hangout action
        print("User chose to decline hangout")
    }
    
    private func handleAcceptChallengeAction(userInfo: [AnyHashable: Any]) {
        // Handle accept challenge action
        print("User chose to accept challenge")
    }
    
    private func handleDeclineChallengeAction(userInfo: [AnyHashable: Any]) {
        // Handle decline challenge action
        print("User chose to decline challenge")
    }
    
    private func handleApprovePhotoAction(userInfo: [AnyHashable: Any]) {
        // Handle approve photo action
        print("User chose to approve photo")
    }
    
    private func handleDeclinePhotoAction(userInfo: [AnyHashable: Any]) {
        // Handle decline photo action
        print("User chose to decline photo")
    }
    
    private func handleAcceptInvitationAction(userInfo: [AnyHashable: Any]) {
        // Handle accept invitation action
        print("User chose to accept invitation")
    }
    
    private func handleDeclineInvitationAction(userInfo: [AnyHashable: Any]) {
        // Handle decline invitation action
        print("User chose to decline invitation")
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        // Handle default tap action
        print("User tapped notification")
    }
}

// MARK: - Supporting Types
struct NotificationSettings {
    var hangoutNotifications: Bool = true
    var challengeNotifications: Bool = true
    var photoStoryNotifications: Bool = true
    var circleInvitationNotifications: Bool = true
    var dailyMotivation: Bool = true
    var weeklySummary: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
}

// MARK: - Notifications
extension Notification.Name {
    static let challengeCreated = Notification.Name("challengeCreated")
    static let challengeCompleted = Notification.Name("challengeCompleted")
    static let challengeFailed = Notification.Name("challengeFailed")
}
