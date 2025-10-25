//
//  AuthenticationManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import AuthenticationServices
import Security
import CoreData
import Combine

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let keychain = KeychainManager()
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        checkAuthenticationStatus()
        setupNotificationObservers()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Authentication
    func signInWithApple() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func signOut() {
        guard isAuthenticated else { return }
        
        isLoading = true
        
        // Clear local data
        currentUser = nil
        isAuthenticated = false
        
        // Clear keychain
        keychain.deleteAppleIDSubject()
        
        // Clear Core Data context
        clearUserData()
        
        // Clear UserDefaults
        clearUserDefaults()
        
        // Log sign out event
        AnalyticsManager.shared.logUserAction(.signOut)
        
        isLoading = false
    }
    
    // MARK: - Authentication Status
    private func checkAuthenticationStatus() {
        guard let subjectID = keychain.getAppleIDSubject() else {
            isAuthenticated = false
            return
        }
        
        // Verify with Apple
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: subjectID) { [weak self] state, error in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    self?.loadUserFromCoreData(subjectID: subjectID)
                case .revoked, .notFound:
                    self?.signOut()
                case .notFound:
                    self?.signOut()
                @unknown default:
                    self?.signOut()
                }
            }
        }
    }
    
    private func loadUserFromCoreData(subjectID: String) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "appleIDSubject == %@", subjectID)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            if let user = users.first {
                currentUser = user
                isAuthenticated = true
                
                // Update last active time
                user.lastActiveAt = Date()
                try context.save()
                
                // Log successful authentication
                AnalyticsManager.shared.logUserAction(.signIn)
            } else {
                // User not found in Core Data, need to create
                createUserFromSubjectID(subjectID)
            }
        } catch {
            print("Error loading user from Core Data: \(error)")
            signOut()
        }
    }
    
    // MARK: - User Creation
    private func createUserFromSubjectID(_ subjectID: String) {
        // Create a new user with minimal information
        let context = persistenceController.container.viewContext
        
        let user = User(context: context)
        user.id = UUID()
        user.appleIDSubject = subjectID
        user.displayName = "Circle User"
        user.profileEmoji = "👤"
        user.createdAt = Date()
        user.lastActiveAt = Date()
        user.isActive = true
        user.totalPoints = 0
        user.weeklyPoints = 0
        
        do {
            try context.save()
            currentUser = user
            isAuthenticated = true
            
            // Log user creation
            AnalyticsManager.shared.logUserAction(.signIn)
        } catch {
            print("Error creating user: \(error)")
            signOut()
        }
    }
    
    private func createOrUpdateUser(from credential: ASAuthorizationAppleIDCredential) {
        let subjectID = credential.user
        let context = persistenceController.container.viewContext
        
        // Check if user already exists
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "appleIDSubject == %@", subjectID)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            let user: User
            
            if let existingUser = users.first {
                // Update existing user
                user = existingUser
                user.lastActiveAt = Date()
                
                // Update name if available
                if let fullName = credential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    formatter.style = .long
                    user.displayName = formatter.string(from: fullName)
                }
            } else {
                // Create new user
                user = User(context: context)
                user.id = UUID()
                user.appleIDSubject = subjectID
                user.createdAt = Date()
                user.lastActiveAt = Date()
                user.isActive = true
                user.totalPoints = 0
                user.weeklyPoints = 0
                
                // Set name
                if let fullName = credential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    formatter.style = .long
                    user.displayName = formatter.string(from: fullName)
                } else {
                    user.displayName = "Circle User"
                }
                
                user.profileEmoji = "👤"
            }
            
            // Save user
            try context.save()
            currentUser = user
            isAuthenticated = true
            
            // Log successful authentication
            AnalyticsManager.shared.logUserAction(.signIn)
            
        } catch {
            print("Error creating/updating user: \(error)")
            errorMessage = "Failed to create user account"
        }
    }
    
    // MARK: - Data Management
    private func clearUserData() {
        let context = persistenceController.container.viewContext
        
        // Clear user-specific data
        let entities = ["User", "Circle", "Challenge", "ChallengeResult", "HangoutSession", "PointsLedger"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            do {
                let objects = try context.fetch(request)
                for object in objects {
                    context.delete(object as! NSManagedObject)
                }
            } catch {
                print("Error clearing \(entityName): \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving cleared context: \(error)")
        }
    }
    
    private func clearUserDefaults() {
        let keys = ["current_session_id", "onboarding_complete", "permissions_granted"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        // Observe app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkAuthenticationStatus()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.updateLastActiveTime()
            }
            .store(in: &cancellables)
    }
    
    private func updateLastActiveTime() {
        guard let user = currentUser else { return }
        
        let context = persistenceController.container.viewContext
        user.lastActiveAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Error updating last active time: \(error)")
        }
    }
    
    // MARK: - User Management
    func updateUserProfile(name: String, emoji: String) {
        guard let user = currentUser else { return }
        
        let context = persistenceController.container.viewContext
        user.displayName = name
        user.profileEmoji = emoji
        user.lastActiveAt = Date()
        
        do {
            try context.save()
            
            // Log profile update
            AnalyticsManager.shared.logUserAction(.updateSettings)
        } catch {
            print("Error updating user profile: \(error)")
            errorMessage = "Failed to update profile"
        }
    }
    
    func deleteAccount() async {
        guard let user = currentUser else { return }
        
        isLoading = true
        
        // Delete user data
        clearUserData()
        
        // Sign out
        signOut()
        
        // Log account deletion
        AnalyticsManager.shared.logUserAction(.deleteData)
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    func getCurrentUserId() -> String? {
        return currentUser?.id?.uuidString
    }
    
    func getCurrentUserDisplayName() -> String {
        return currentUser?.displayName ?? "Circle User"
    }
    
    func getCurrentUserEmoji() -> String {
        return currentUser?.profileEmoji ?? "👤"
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            isLoading = false
            errorMessage = "Invalid authorization credential"
            return
        }
        
        // Store the subject ID securely
        let subjectID = appleIDCredential.user
        keychain.storeAppleIDSubject(subjectID)
        
        // Create or update user
        createOrUpdateUser(from: appleIDCredential)
        
        isLoading = false
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = "Sign in was canceled"
            case .failed:
                errorMessage = "Sign in failed"
            case .invalidResponse:
                errorMessage = "Invalid response from Apple"
            case .notHandled:
                errorMessage = "Sign in not handled"
            case .unknown:
                errorMessage = "Unknown sign in error"
            @unknown default:
                errorMessage = "Unknown sign in error"
            }
        } else {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
        
        // Log error
        AnalyticsManager.shared.logError(error, context: "Apple Sign In")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Keychain Manager
class KeychainManager {
    private let service = "com.circle.app"
    private let account = "apple_id_subject"
    
    func storeAppleIDSubject(_ subject: String) {
        let data = subject.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Keychain store error: \(status)")
        }
    }
    
    func getAppleIDSubject() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let subject = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return subject
    }
    
    func deleteAppleIDSubject() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess {
            print("Keychain delete error: \(status)")
        }
    }
}
