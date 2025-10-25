//
//  IntegrationTests.swift
//  CircleTests
//
//  Created by Circle Team on 2024-01-15.
//

import XCTest
import CoreData
import CoreLocation
@testable import Circle

final class IntegrationTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var authenticationManager: AuthenticationManager!
    var locationManager: LocationManager!
    var challengeEngine: ChallengeEngine!
    var hangoutEngine: HangoutEngine!
    var antiCheatEngine: AntiCheatEngine!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        container = NSPersistentContainer(name: "Circle")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        context = container.viewContext
        
        // Initialize managers
        authenticationManager = AuthenticationManager.shared
        locationManager = LocationManager.shared
        challengeEngine = ChallengeEngine.shared
        hangoutEngine = HangoutEngine.shared
        antiCheatEngine = AntiCheatEngine.shared
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        authenticationManager = nil
        locationManager = nil
        challengeEngine = nil
        hangoutEngine = nil
        antiCheatEngine = nil
    }
    
    // MARK: - User Onboarding Integration Tests
    
    func testCompleteUserOnboardingFlow() throws {
        // Given
        let appleUserID = "integration-test-user"
        let displayName = "Integration Test User"
        
        // When - Complete onboarding flow
        let user = authenticationManager.createUserFromSubjectID(appleUserID, in: context)
        user.displayName = displayName
        
        // Create user's first circle
        let circle = Circle.create(in: context, name: "Test Circle")
        let membership = Membership.create(in: context, role: "owner")
        membership.user = user
        membership.circle = circle
        
        try context.save()
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user.displayName, displayName)
        XCTAssertNotNil(circle)
        XCTAssertEqual(membership.role, "owner")
        XCTAssertEqual(membership.user, user)
        XCTAssertEqual(membership.circle, circle)
    }
    
    // MARK: - Challenge Creation and Verification Integration Tests
    
    func testChallengeCreationAndVerificationFlow() throws {
        // Given
        let user = User.create(in: context, appleUserID: "challenge-user", displayName: "Challenge User")
        let circle = Circle.create(in: context, name: "Challenge Circle")
        let membership = Membership.create(in: context, role: "owner")
        membership.user = user
        membership.circle = circle
        
        // When - Create challenge
        let challenge = Challenge.create(
            in: context,
            title: "Daily Steps",
            category: "fitness",
            verificationMethod: "motion"
        )
        challenge.circle = circle
        challenge.createdBy = user
        challenge.targetValue = 5000
        challenge.targetUnit = "steps"
        challenge.pointsReward = 10
        challenge.pointsPenalty = -5
        
        try context.save()
        
        // Create proof for challenge
        let proof = Proof.create(
            in: context,
            isVerified: true,
            confidenceScore: 0.95,
            verificationMethod: "motion"
        )
        proof.challenge = challenge
        proof.user = user
        proof.pointsAwarded = challenge.pointsReward
        
        try context.save()
        
        // Then
        XCTAssertNotNil(challenge)
        XCTAssertEqual(challenge.circle, circle)
        XCTAssertEqual(challenge.createdBy, user)
        XCTAssertEqual(challenge.targetValue, 5000)
        XCTAssertEqual(challenge.targetUnit, "steps")
        
        XCTAssertNotNil(proof)
        XCTAssertEqual(proof.challenge, challenge)
        XCTAssertEqual(proof.user, user)
        XCTAssertEqual(proof.pointsAwarded, 10)
        XCTAssertTrue(proof.isVerified)
    }
    
    // MARK: - Hangout Detection Integration Tests
    
    func testHangoutDetectionFlow() throws {
        // Given
        let user1 = User.create(in: context, appleUserID: "user1", displayName: "User 1")
        let user2 = User.create(in: context, appleUserID: "user2", displayName: "User 2")
        let circle = Circle.create(in: context, name: "Hangout Circle")
        
        // Create memberships
        let membership1 = Membership.create(in: context, role: "member")
        membership1.user = user1
        membership1.circle = circle
        
        let membership2 = Membership.create(in: context, role: "member")
        membership2.user = user2
        membership2.circle = circle
        
        // When - Create hangout session
        let startTime = Date()
        let session = HangoutSession.create(in: context, startTime: startTime)
        session.circle = circle
        
        // Create participants
        let participant1 = HangoutParticipant.create(in: context, user: user1, session: session)
        let participant2 = HangoutParticipant.create(in: context, user: user2, session: session)
        
        // End session after 30 minutes
        let endTime = startTime.addingTimeInterval(1800)
        session.endTime = endTime
        session.duration = 1800
        session.pointsAwarded = 15
        
        participant1.leftAt = endTime
        participant1.durationSec = 1800
        
        participant2.leftAt = endTime
        participant2.durationSec = 1800
        
        try context.save()
        
        // Then
        XCTAssertNotNil(session)
        XCTAssertEqual(session.circle, circle)
        XCTAssertEqual(session.duration, 1800)
        XCTAssertEqual(session.pointsAwarded, 15)
        
        XCTAssertNotNil(participant1)
        XCTAssertEqual(participant1.user, user1)
        XCTAssertEqual(participant1.session, session)
        XCTAssertEqual(participant1.durationSec, 1800)
        
        XCTAssertNotNil(participant2)
        XCTAssertEqual(participant2.user, user2)
        XCTAssertEqual(participant2.session, session)
        XCTAssertEqual(participant2.durationSec, 1800)
    }
    
    // MARK: - Points System Integration Tests
    
    func testPointsSystemFlow() throws {
        // Given
        let user = User.create(in: context, appleUserID: "points-user", displayName: "Points User")
        let circle = Circle.create(in: context, name: "Points Circle")
        let membership = Membership.create(in: context, role: "member")
        membership.user = user
        membership.circle = circle
        
        // When - Award points for challenge completion
        let challenge = Challenge.create(
            in: context,
            title: "Test Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        challenge.circle = circle
        challenge.pointsReward = 10
        
        let proof = Proof.create(
            in: context,
            isVerified: true,
            confidenceScore: 0.95,
            verificationMethod: "motion"
        )
        proof.challenge = challenge
        proof.user = user
        proof.pointsAwarded = 10
        
        // Create points ledger entry
        let ledger = PointsLedger.create(in: context, points: 10, reason: "Challenge completed")
        ledger.user = user
        ledger.challenge = challenge
        
        // Update user points
        user.totalPoints += 10
        user.weeklyPoints += 10
        
        try context.save()
        
        // Then
        XCTAssertEqual(user.totalPoints, 10)
        XCTAssertEqual(user.weeklyPoints, 10)
        XCTAssertEqual(proof.pointsAwarded, 10)
        XCTAssertEqual(ledger.points, 10)
        XCTAssertEqual(ledger.user, user)
        XCTAssertEqual(ledger.challenge, challenge)
    }
    
    // MARK: - Leaderboard Integration Tests
    
    func testLeaderboardGenerationFlow() throws {
        // Given
        let circle = Circle.create(in: context, name: "Leaderboard Circle")
        let users = [
            User.create(in: context, appleUserID: "user1", displayName: "User 1"),
            User.create(in: context, appleUserID: "user2", displayName: "User 2"),
            User.create(in: context, appleUserID: "user3", displayName: "User 3")
        ]
        
        // Set different point totals
        users[0].weeklyPoints = 100
        users[1].weeklyPoints = 150
        users[2].weeklyPoints = 75
        
        // Create memberships
        for (index, user) in users.enumerated() {
            let membership = Membership.create(in: context, role: "member")
            membership.user = user
            membership.circle = circle
        }
        
        // When - Create leaderboard entries
        let weekStarting = Date()
        let weekEnding = weekStarting.addingTimeInterval(604800) // 7 days
        
        let entries = [
            LeaderboardEntry.create(in: context, points: 150, rank: 1, weekStarting: weekStarting, weekEnding: weekEnding),
            LeaderboardEntry.create(in: context, points: 100, rank: 2, weekStarting: weekStarting, weekEnding: weekEnding),
            LeaderboardEntry.create(in: context, points: 75, rank: 3, weekStarting: weekStarting, weekEnding: weekEnding)
        ]
        
        for (index, entry) in entries.enumerated() {
            entry.user = users[index]
            entry.circle = circle
        }
        
        try context.save()
        
        // Then
        XCTAssertEqual(entries[0].rank, 1)
        XCTAssertEqual(entries[0].points, 150)
        XCTAssertEqual(entries[0].user, users[1])
        
        XCTAssertEqual(entries[1].rank, 2)
        XCTAssertEqual(entries[1].points, 100)
        XCTAssertEqual(entries[1].user, users[0])
        
        XCTAssertEqual(entries[2].rank, 3)
        XCTAssertEqual(entries[2].points, 75)
        XCTAssertEqual(entries[2].user, users[2])
    }
    
    // MARK: - Anti-Cheat Integration Tests
    
    func testAntiCheatIntegrationFlow() throws {
        // Given
        let user = User.create(in: context, appleUserID: "anti-cheat-user", displayName: "Anti-Cheat User")
        let challenge = Challenge.create(
            in: context,
            title: "Test Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        
        // When - Record suspicious activity
        let suspiciousActivity = SuspiciousActivityEntity.create(
            in: context,
            type: "rapid_movement",
            severity: "high",
            description: "Detected rapid movement"
        )
        suspiciousActivity.user = user
        
        // Update integrity score
        antiCheatEngine.recordSuspiciousActivity(suspiciousActivity)
        antiCheatEngine.updateIntegrityScore()
        
        // Verify challenge integrity
        let isIntegrityValid = antiCheatEngine.verifyChallengeIntegrity(challenge)
        
        try context.save()
        
        // Then
        XCTAssertNotNil(suspiciousActivity)
        XCTAssertEqual(suspiciousActivity.user, user)
        XCTAssertEqual(suspiciousActivity.type, "rapid_movement")
        XCTAssertEqual(suspiciousActivity.severity, "high")
        
        XCTAssertLessThan(antiCheatEngine.integrityScore, 1.0)
        XCTAssertFalse(isIntegrityValid) // Should fail due to suspicious activity
    }
    
    // MARK: - Data Export Integration Tests
    
    func testDataExportFlow() throws {
        // Given - Create comprehensive test data
        let user = User.create(in: context, appleUserID: "export-user", displayName: "Export User")
        let circle = Circle.create(in: context, name: "Export Circle")
        let membership = Membership.create(in: context, role: "owner")
        membership.user = user
        membership.circle = circle
        
        let challenge = Challenge.create(
            in: context,
            title: "Export Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        challenge.circle = circle
        challenge.createdBy = user
        
        let proof = Proof.create(
            in: context,
            isVerified: true,
            confidenceScore: 0.95,
            verificationMethod: "motion"
        )
        proof.challenge = challenge
        proof.user = user
        
        let session = HangoutSession.create(in: context, startTime: Date())
        session.circle = circle
        
        let participant = HangoutParticipant.create(in: context, user: user, session: session)
        
        let ledger = PointsLedger.create(in: context, points: 10, reason: "Challenge completed")
        ledger.user = user
        ledger.challenge = challenge
        
        try context.save()
        
        // When - Export data
        let exportData = try DataExportManager.shared.exportUserData()
        
        // Then
        XCTAssertNotNil(exportData)
        // Note: In a real implementation, this would return structured data
        // For testing, we verify the method completes without error
    }
    
    // MARK: - Data Deletion Integration Tests
    
    func testDataDeletionFlow() throws {
        // Given - Create test data
        let user = User.create(in: context, appleUserID: "delete-user", displayName: "Delete User")
        let circle = Circle.create(in: context, name: "Delete Circle")
        let membership = Membership.create(in: context, role: "owner")
        membership.user = user
        membership.circle = circle
        
        let challenge = Challenge.create(
            in: context,
            title: "Delete Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        challenge.circle = circle
        challenge.createdBy = user
        
        try context.save()
        
        // When - Delete user data
        try DataExportManager.shared.deleteAllUserData()
        
        // Then - All user-related data should be deleted
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try context.fetch(userRequest)
        XCTAssertEqual(users.count, 0)
        
        let challengeRequest: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        let challenges = try context.fetch(challengeRequest)
        XCTAssertEqual(challenges.count, 0)
        
        let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
        let circles = try context.fetch(circleRequest)
        XCTAssertEqual(circles.count, 0)
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeDataSetPerformance() throws {
        // Given - Create large dataset
        let startTime = Date()
        
        // Create 1000 users
        for i in 0..<1000 {
            let user = User.create(in: context, appleUserID: "perf-user-\(i)", displayName: "User \(i)")
            
            // Create circle for each user
            let circle = Circle.create(in: context, name: "Circle \(i)")
            let membership = Membership.create(in: context, role: "owner")
            membership.user = user
            membership.circle = circle
            
            // Create challenge for each user
            let challenge = Challenge.create(
                in: context,
                title: "Challenge \(i)",
                category: "fitness",
                verificationMethod: "motion"
            )
            challenge.circle = circle
            challenge.createdBy = user
            
            // Create proof for each challenge
            let proof = Proof.create(
                in: context,
                isVerified: true,
                confidenceScore: 0.95,
                verificationMethod: "motion"
            )
            proof.challenge = challenge
            proof.user = user
        }
        
        // When - Save all data
        try context.save()
        
        // Then - Should complete within reasonable time
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 10.0) // Should complete within 10 seconds
    }
    
    func testComplexQueryPerformance() throws {
        // Given - Create test data
        for i in 0..<100 {
            let user = User.create(in: context, appleUserID: "query-user-\(i)", displayName: "User \(i)")
            let circle = Circle.create(in: context, name: "Circle \(i)")
            let membership = Membership.create(in: context, role: "member")
            membership.user = user
            membership.circle = circle
            
            for j in 0..<10 {
                let challenge = Challenge.create(
                    in: context,
                    title: "Challenge \(i)-\(j)",
                    category: "fitness",
                    verificationMethod: "motion"
                )
                challenge.circle = circle
                challenge.createdBy = user
                
                let proof = Proof.create(
                    in: context,
                    isVerified: true,
                    confidenceScore: 0.95,
                    verificationMethod: "motion"
                )
                proof.challenge = challenge
                proof.user = user
            }
        }
        
        try context.save()
        
        // When - Perform complex query
        let startTime = Date()
        
        let request: NSFetchRequest<Proof> = Proof.fetchRequest()
        request.predicate = NSPredicate(format: "isVerified == YES AND confidenceScore > 0.9")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 100
        
        let proofs = try context.fetch(request)
        
        // Then - Should complete within reasonable time
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0) // Should complete within 1 second
        XCTAssertEqual(proofs.count, 100)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testErrorHandlingFlow() throws {
        // Given - Create invalid data
        let user = User(context: context)
        // Don't set required fields
        
        // When/Then - Should handle error gracefully
        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertTrue(error is NSError)
        }
        
        // Context should still be usable after error
        let validUser = User.create(in: context, appleUserID: "valid-user", displayName: "Valid User")
        try context.save()
        
        let request: NSFetchRequest<User> = User.fetchRequest()
        let users = try context.fetch(request)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.appleUserID, "valid-user")
    }
}
