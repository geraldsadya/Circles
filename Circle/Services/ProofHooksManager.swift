//
//  ProofHooksManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import CoreData
import Combine

@MainActor
class ProofHooksManager: ObservableObject {
    static let shared = ProofHooksManager()
    
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private let challengeEngine = ChallengeEngine.shared
    private let hangoutEngine = HangoutEngine.shared
    private let forfeitEngine = ForfeitEngine.shared
    private let antiCheatEngine = AntiCheatEngine.shared
    private let cameraManager = CameraManager.shared
    private let pointsEngine = PointsEngine.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCameraVerificationRequired),
            name: .cameraVerificationRequired,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSuspiciousActivityDetected),
            name: .suspiciousActivityDetected,
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
            selector: #selector(handleHangoutEnded),
            name: .hangoutEnded,
            object: nil
        )
    }
    
    // MARK: - Challenge Proof Hooks
    func requestChallengeProof(for challenge: Challenge, user: User) async throws -> Proof {
        // Check if camera verification is required
        let integrityResult = antiCheatEngine.verifyChallengeIntegrity(challenge, user: user)
        
        if !integrityResult.isVerified {
            // Request camera proof
            let cameraProof = try await requestCameraProof(
                purpose: .challenge,
                reason: integrityResult.notes ?? "Challenge integrity verification required",
                user: user,
                challenge: challenge
            )
            
            return cameraProof
        }
        
        // Regular challenge verification
        return challengeEngine.verifyChallenge(challenge, for: user)
    }
    
    func completeChallengeProof(_ proof: Proof, user: User, challenge: Challenge) async throws {
        // Award points
        try await pointsEngine.awardChallengePoints(
            for: proof,
            user: user,
            challenge: challenge
        )
        
        // Update leaderboard
        if let circle = challenge.circle {
            await LeaderboardManager.shared.updateLeaderboard(for: circle)
        }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .challengeProofCompleted,
            object: nil,
            userInfo: [
                "proof": proof,
                "user": user,
                "challenge": challenge
            ]
        )
    }
    
    // MARK: - Hangout Proof Hooks
    func requestHangoutProof(for hangoutSession: HangoutSession, user: User) async throws -> Proof? {
        // Check if hangout verification is required
        let suspiciousMotion = antiCheatEngine.detectSuspiciousMotion()
        
        if let suspiciousActivity = suspiciousMotion {
            // Request camera proof for hangout
            let cameraProof = try await requestCameraProof(
                purpose: .hangout,
                reason: suspiciousActivity.description,
                user: user,
                hangoutSession: hangoutSession
            )
            
            return cameraProof
        }
        
        // Regular hangout verification (automatic)
        return nil
    }
    
    func completeHangoutProof(_ proof: Proof, user: User, hangoutSession: HangoutSession) async throws {
        // Award hangout points
        try await pointsEngine.awardHangoutPoints(
            proof.pointsAwarded,
            user: user,
            hangoutSession: hangoutSession
        )
        
        // Update leaderboard
        if let circle = hangoutSession.circle {
            await LeaderboardManager.shared.updateLeaderboard(for: circle)
        }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .hangoutProofCompleted,
            object: nil,
            userInfo: [
                "proof": proof,
                "user": user,
                "hangoutSession": hangoutSession
            ]
        )
    }
    
    // MARK: - Forfeit Proof Hooks
    func requestForfeitProof(for forfeit: Forfeit, user: User) async throws -> Proof {
        // All forfeits require camera proof
        let cameraProof = try await requestCameraProof(
            purpose: .forfeit,
            reason: "Forfeit completion verification",
            user: user,
            forfeit: forfeit
        )
        
        return cameraProof
    }
    
    func completeForfeitProof(_ proof: Proof, user: User, forfeit: Forfeit) async throws {
        // Complete forfeit
        try await forfeitEngine.completeForfeit(forfeit, proof: proof)
        
        // Update leaderboard
        if let circle = forfeit.circle {
            await LeaderboardManager.shared.updateLeaderboard(for: circle)
        }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .forfeitProofCompleted,
            object: nil,
            userInfo: [
                "proof": proof,
                "user": user,
                "forfeit": forfeit
            ]
        )
    }
    
    // MARK: - Anti-Cheat Proof Hooks
    func requestAntiCheatProof(reason: String, user: User) async throws -> Proof {
        let cameraProof = try await requestCameraProof(
            purpose: .antiCheat,
            reason: reason,
            user: user
        )
        
        return cameraProof
    }
    
    func completeAntiCheatProof(_ proof: Proof, user: User) async throws {
        // Update anti-cheat engine
        if proof.isVerified {
            // Clear suspicious activities
            antiCheatEngine.cleanupOldActivities()
        }
        
        // Notify other systems
        NotificationCenter.default.post(
            name: .antiCheatProofCompleted,
            object: nil,
            userInfo: [
                "proof": proof,
                "user": user
            ]
        )
    }
    
    // MARK: - Camera Proof Request
    private func requestCameraProof(
        purpose: CameraPurpose,
        reason: String,
        user: User,
        challenge: Challenge? = nil,
        hangoutSession: HangoutSession? = nil,
        forfeit: Forfeit? = nil
    ) async throws -> Proof {
        isProcessing = true
        errorMessage = nil
        
        // Start camera session
        let session = try await cameraManager.startSession(for: purpose, duration: 10.0)
        
        // Show proof UI
        let verification = try await showProofUI(
            purpose: purpose,
            reason: reason,
            session: session
        )
        
        // Create proof
        let proof = Proof(context: persistenceController.container.viewContext)
        proof.id = UUID()
        proof.user = user
        proof.challenge = challenge
        proof.hangoutSession = hangoutSession
        proof.forfeit = forfeit
        proof.timestamp = Date()
        proof.isVerified = verification.isVerified
        proof.confidenceScore = verification.confidenceScore
        proof.verificationMethod = VerificationMethod.camera.rawValue
        proof.sensorData = try JSONEncoder().encode(verification.sensorData)
        proof.notes = reason
        
        // Save context
        try persistenceController.container.viewContext.save()
        
        isProcessing = false
        
        return proof
    }
    
    // MARK: - Proof UI Integration
    private func showProofUI(
        purpose: CameraPurpose,
        reason: String,
        session: CameraSession
    ) async throws -> CameraVerification {
        return try await withCheckedThrowingContinuation { continuation in
            // This would show the ProofView in a modal
            // For now, we'll simulate the verification
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let verification = CameraVerification(
                    isVerified: true,
                    confidenceScore: 0.9,
                    livenessScore: 0.8,
                    duration: 10.0,
                    suspiciousActivity: false,
                    timestamp: Date()
                )
                continuation.resume(returning: verification)
            }
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handleCameraVerificationRequired(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo["reason"] as? String else { return }
        
        Task {
            do {
                // Get current user
                guard let currentUser = getCurrentUser() else { return }
                
                // Request anti-cheat proof
                let proof = try await requestAntiCheatProof(reason: reason, user: currentUser)
                
                // Complete proof
                try await completeAntiCheatProof(proof, user: currentUser)
                
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    @objc private func handleSuspiciousActivityDetected(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let activity = userInfo["activity"] as? SuspiciousActivity else { return }
        
        Task {
            do {
                // Get current user
                guard let currentUser = getCurrentUser() else { return }
                
                // Request anti-cheat proof
                let proof = try await requestAntiCheatProof(
                    reason: activity.description,
                    user: currentUser
                )
                
                // Complete proof
                try await completeAntiCheatProof(proof, user: currentUser)
                
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    @objc private func handleHangoutStarted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hangout = userInfo["hangout"] as? HangoutSession else { return }
        
        Task {
            do {
                // Get current user
                guard let currentUser = getCurrentUser() else { return }
                
                // Check if hangout proof is required
                if let proof = try await requestHangoutProof(for: hangout, user: currentUser) {
                    try await completeHangoutProof(proof, user: currentUser, hangoutSession: hangout)
                }
                
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    @objc private func handleHangoutEnded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let hangout = userInfo["hangout"] as? HangoutSession else { return }
        
        Task {
            do {
                // Get current user
                guard let currentUser = getCurrentUser() else { return }
                
                // Check if hangout proof is required
                if let proof = try await requestHangoutProof(for: hangout, user: currentUser) {
                    try await completeHangoutProof(proof, user: currentUser, hangoutSession: hangout)
                }
                
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentUser() -> User? {
        // This would be implemented to get the current authenticated user
        // For now, return nil
        return nil
    }
    
    // MARK: - Proof Validation
    func validateProof(_ proof: Proof) -> ValidationResult {
        var errors: [String] = []
        
        // Validate proof data
        if proof.timestamp == nil {
            errors.append("Proof timestamp is required")
        }
        
        if proof.confidenceScore < 0 || proof.confidenceScore > 1 {
            errors.append("Invalid confidence score")
        }
        
        // Validate verification method
        if proof.verificationMethod?.isEmpty ?? true {
            errors.append("Verification method is required")
        }
        
        // Validate sensor data
        if proof.sensorData == nil {
            errors.append("Sensor data is required")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    // MARK: - Analytics
    func getProofStats(for user: User) -> ProofStats {
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        
        do {
            let proofs = try persistenceController.container.viewContext.fetch(request)
            
            let totalProofs = proofs.count
            let verifiedProofs = proofs.filter { $0.isVerified }.count
            let cameraProofs = proofs.filter { $0.verificationMethod == VerificationMethod.camera.rawValue }.count
            
            let averageConfidence = proofs.isEmpty ? 0.0 : 
                proofs.reduce(0) { $0 + $1.confidenceScore } / Double(proofs.count)
            
            let verificationMethods = Dictionary(grouping: proofs, by: { $0.verificationMethod ?? "unknown" })
                .mapValues { $0.count }
            
            return ProofStats(
                totalProofs: totalProofs,
                verifiedProofs: verifiedProofs,
                cameraProofs: cameraProofs,
                averageConfidence: averageConfidence,
                verificationMethods: verificationMethods
            )
            
        } catch {
            print("Error getting proof stats: \(error)")
            return ProofStats(
                totalProofs: 0,
                verifiedProofs: 0,
                cameraProofs: 0,
                averageConfidence: 0.0,
                verificationMethods: [:]
            )
        }
    }
    
    // MARK: - Cleanup
    func cleanupOldProofs() {
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        
        do {
            let oldProofs = try persistenceController.container.viewContext.fetch(request)
            
            for proof in oldProofs {
                persistenceController.container.viewContext.delete(proof)
            }
            
            try persistenceController.container.viewContext.save()
            
            print("Cleaned up \(oldProofs.count) old proofs")
            
        } catch {
            print("Error cleaning up old proofs: \(error)")
        }
    }
}

// MARK: - Supporting Types
struct ProofStats {
    let totalProofs: Int
    let verifiedProofs: Int
    let cameraProofs: Int
    let averageConfidence: Double
    let verificationMethods: [String: Int]
}

// MARK: - Notifications
extension Notification.Name {
    static let challengeProofCompleted = Notification.Name("challengeProofCompleted")
    static let hangoutProofCompleted = Notification.Name("hangoutProofCompleted")
    static let forfeitProofCompleted = Notification.Name("forfeitProofCompleted")
    static let antiCheatProofCompleted = Notification.Name("antiCheatProofCompleted")
}
