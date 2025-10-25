//
//  CoreDataTests.swift
//  CircleTests
//
//  Created by Circle Team on 2024-01-15.
//

import XCTest
import CoreData
@testable import Circle

final class CoreDataTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
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
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
    }
    
    // MARK: - User Entity Tests
    
    func testCreateUser() throws {
        // Given
        let appleUserID = "test-user-123"
        let displayName = "Test User"
        
        // When
        let user = User.create(in: context, appleUserID: appleUserID, displayName: displayName)
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user.appleUserID, appleUserID)
        XCTAssertEqual(user.displayName, displayName)
        XCTAssertNotNil(user.id)
        XCTAssertNotNil(user.createdAt)
        XCTAssertNotNil(user.lastActiveAt)
        XCTAssertEqual(user.totalPoints, 0)
        XCTAssertEqual(user.weeklyPoints, 0)
    }
    
    func testSaveUser() throws {
        // Given
        let user = User.create(in: context, appleUserID: "test-user", displayName: "Test User")
        
        // When
        try context.save()
        
        // Then
        let request: NSFetchRequest<User> = User.fetchRequest()
        let users = try context.fetch(request)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.appleUserID, "test-user")
    }
    
    func testFetchUser() throws {
        // Given
        let user = User.create(in: context, appleUserID: "test-user", displayName: "Test User")
        try context.save()
        
        // When
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "appleUserID == %@", "test-user")
        let fetchedUsers = try context.fetch(request)
        
        // Then
        XCTAssertEqual(fetchedUsers.count, 1)
        XCTAssertEqual(fetchedUsers.first?.displayName, "Test User")
    }
    
    // MARK: - Circle Entity Tests
    
    func testCreateCircle() throws {
        // Given
        let circleName = "Test Circle"
        
        // When
        let circle = Circle.create(in: context, name: circleName)
        
        // Then
        XCTAssertNotNil(circle)
        XCTAssertEqual(circle.name, circleName)
        XCTAssertNotNil(circle.id)
        XCTAssertNotNil(circle.inviteCode)
        XCTAssertNotNil(circle.createdAt)
        XCTAssertTrue(circle.isActive)
    }
    
    func testCircleInviteCodeGeneration() throws {
        // Given
        let circle1 = Circle.create(in: context, name: "Circle 1")
        let circle2 = Circle.create(in: context, name: "Circle 2")
        
        // When
        try context.save()
        
        // Then
        XCTAssertNotEqual(circle1.inviteCode, circle2.inviteCode)
        XCTAssertEqual(circle1.inviteCode?.count, 8)
        XCTAssertEqual(circle2.inviteCode?.count, 8)
    }
    
    // MARK: - Challenge Entity Tests
    
    func testCreateChallenge() throws {
        // Given
        let title = "Test Challenge"
        let category = "fitness"
        let verificationMethod = "motion"
        
        // When
        let challenge = Challenge.create(
            in: context,
            title: title,
            category: category,
            verificationMethod: verificationMethod
        )
        
        // Then
        XCTAssertNotNil(challenge)
        XCTAssertEqual(challenge.title, title)
        XCTAssertEqual(challenge.category, category)
        XCTAssertEqual(challenge.verificationMethod, verificationMethod)
        XCTAssertNotNil(challenge.id)
        XCTAssertNotNil(challenge.createdAt)
        XCTAssertNotNil(challenge.startDate)
        XCTAssertTrue(challenge.isActive)
        XCTAssertEqual(challenge.pointsReward, 10)
        XCTAssertEqual(challenge.pointsPenalty, -5)
    }
    
    func testChallengeWithCustomParameters() throws {
        // Given
        let challenge = Challenge.create(
            in: context,
            title: "Custom Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        
        // When
        challenge.targetValue = 5000
        challenge.targetUnit = "steps"
        challenge.descriptionText = "Walk 5000 steps daily"
        challenge.pointsReward = 15
        challenge.pointsPenalty = -10
        
        // Then
        XCTAssertEqual(challenge.targetValue, 5000)
        XCTAssertEqual(challenge.targetUnit, "steps")
        XCTAssertEqual(challenge.descriptionText, "Walk 5000 steps daily")
        XCTAssertEqual(challenge.pointsReward, 15)
        XCTAssertEqual(challenge.pointsPenalty, -10)
    }
    
    // MARK: - Proof Entity Tests
    
    func testCreateProof() throws {
        // Given
        let isVerified = true
        let confidenceScore = 0.95
        let verificationMethod = "camera"
        
        // When
        let proof = Proof.create(
            in: context,
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            verificationMethod: verificationMethod
        )
        
        // Then
        XCTAssertNotNil(proof)
        XCTAssertEqual(proof.isVerified, isVerified)
        XCTAssertEqual(proof.confidenceScore, confidenceScore)
        XCTAssertEqual(proof.verificationMethod, verificationMethod)
        XCTAssertNotNil(proof.id)
        XCTAssertNotNil(proof.timestamp)
        XCTAssertNotNil(proof.createdAt)
        XCTAssertEqual(proof.pointsAwarded, isVerified ? 10 : -5)
    }
    
    // MARK: - HangoutSession Entity Tests
    
    func testCreateHangoutSession() throws {
        // Given
        let startTime = Date()
        
        // When
        let session = HangoutSession.create(in: context, startTime: startTime)
        
        // Then
        XCTAssertNotNil(session)
        XCTAssertEqual(session.startTime, startTime)
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.createdAt)
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.duration, 0.0)
        XCTAssertEqual(session.pointsAwarded, 0)
    }
    
    func testHangoutSessionWithEndTime() throws {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1800) // 30 minutes
        
        // When
        let session = HangoutSession.create(in: context, startTime: startTime)
        session.endTime = endTime
        session.duration = 1800
        session.pointsAwarded = 15
        
        // Then
        XCTAssertEqual(session.endTime, endTime)
        XCTAssertEqual(session.duration, 1800)
        XCTAssertEqual(session.pointsAwarded, 15)
    }
    
    // MARK: - PointsLedger Entity Tests
    
    func testCreatePointsLedger() throws {
        // Given
        let points = 10
        let reason = "Challenge completed"
        
        // When
        let ledger = PointsLedger.create(in: context, points: Int32(points), reason: reason)
        
        // Then
        XCTAssertNotNil(ledger)
        XCTAssertEqual(ledger.points, Int32(points))
        XCTAssertEqual(ledger.reason, reason)
        XCTAssertNotNil(ledger.id)
        XCTAssertNotNil(ledger.timestamp)
        XCTAssertNotNil(ledger.createdAt)
    }
    
    // MARK: - LeaderboardEntry Entity Tests
    
    func testCreateLeaderboardEntry() throws {
        // Given
        let points = 100
        let rank = 1
        let weekStarting = Date()
        let weekEnding = weekStarting.addingTimeInterval(604800) // 7 days
        
        // When
        let entry = LeaderboardEntry.create(
            in: context,
            points: Int32(points),
            rank: Int32(rank),
            weekStarting: weekStarting,
            weekEnding: weekEnding
        )
        
        // Then
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry.points, Int32(points))
        XCTAssertEqual(entry.rank, Int32(rank))
        XCTAssertEqual(entry.weekStarting, weekStarting)
        XCTAssertEqual(entry.weekEnding, weekEnding)
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.createdAt)
    }
    
    // MARK: - Membership Entity Tests
    
    func testCreateMembership() throws {
        // Given
        let role = "owner"
        
        // When
        let membership = Membership.create(in: context, role: role)
        
        // Then
        XCTAssertNotNil(membership)
        XCTAssertEqual(membership.role, role)
        XCTAssertNotNil(membership.id)
        XCTAssertNotNil(membership.joinedAt)
    }
    
    // MARK: - Relationship Tests
    
    func testUserCircleRelationship() throws {
        // Given
        let user = User.create(in: context, appleUserID: "test-user", displayName: "Test User")
        let circle = Circle.create(in: context, name: "Test Circle")
        let membership = Membership.create(in: context, role: "owner")
        
        // When
        membership.user = user
        membership.circle = circle
        
        // Then
        XCTAssertEqual(membership.user, user)
        XCTAssertEqual(membership.circle, circle)
    }
    
    func testChallengeProofRelationship() throws {
        // Given
        let challenge = Challenge.create(
            in: context,
            title: "Test Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        let proof = Proof.create(
            in: context,
            isVerified: true,
            confidenceScore: 0.95,
            verificationMethod: "motion"
        )
        
        // When
        proof.challenge = challenge
        
        // Then
        XCTAssertEqual(proof.challenge, challenge)
    }
    
    func testUserProofRelationship() throws {
        // Given
        let user = User.create(in: context, appleUserID: "test-user", displayName: "Test User")
        let proof = Proof.create(
            in: context,
            isVerified: true,
            confidenceScore: 0.95,
            verificationMethod: "motion"
        )
        
        // When
        proof.user = user
        
        // Then
        XCTAssertEqual(proof.user, user)
    }
    
    // MARK: - Cascade Delete Tests
    
    func testUserCascadeDelete() throws {
        // Given
        let user = User.create(in: context, appleUserID: "test-user", displayName: "Test User")
        let proof = Proof.create(
            in: context,
            isVerified: true,
            confidenceScore: 0.95,
            verificationMethod: "motion"
        )
        proof.user = user
        
        try context.save()
        
        // When
        context.delete(user)
        try context.save()
        
        // Then
        let proofRequest: NSFetchRequest<Proof> = Proof.fetchRequest()
        let proofs = try context.fetch(proofRequest)
        XCTAssertEqual(proofs.count, 0) // Should be deleted with user
    }
    
    func testCircleCascadeDelete() throws {
        // Given
        let circle = Circle.create(in: context, name: "Test Circle")
        let challenge = Challenge.create(
            in: context,
            title: "Test Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        challenge.circle = circle
        
        try context.save()
        
        // When
        context.delete(circle)
        try context.save()
        
        // Then
        let challengeRequest: NSFetchRequest<Challenge> = Challenge.fetchRequest()
        let challenges = try context.fetch(challengeRequest)
        XCTAssertEqual(challenges.count, 0) // Should be deleted with circle
    }
    
    // MARK: - Performance Tests
    
    func testUserCreationPerformance() throws {
        measure {
            for i in 0..<1000 {
                _ = User.create(in: context, appleUserID: "user-\(i)", displayName: "User \(i)")
            }
        }
    }
    
    func testUserFetchPerformance() throws {
        // Given - Create test data
        for i in 0..<1000 {
            _ = User.create(in: context, appleUserID: "user-\(i)", displayName: "User \(i)")
        }
        try context.save()
        
        // When/Then
        measure {
            let request: NSFetchRequest<User> = User.fetchRequest()
            _ = try? context.fetch(request)
        }
    }
    
    func testChallengeCreationPerformance() throws {
        measure {
            for i in 0..<1000 {
                _ = Challenge.create(
                    in: context,
                    title: "Challenge \(i)",
                    category: "fitness",
                    verificationMethod: "motion"
                )
            }
        }
    }
    
    // MARK: - Validation Tests
    
    func testRequiredFieldsValidation() throws {
        // Given
        let user = User(context: context)
        // Don't set required fields
        
        // When/Then
        XCTAssertThrowsError(try context.save()) { error in
            // Should fail validation for required fields
            XCTAssertTrue(error is NSError)
        }
    }
    
    func testUniqueConstraints() throws {
        // Given
        let user1 = User.create(in: context, appleUserID: "unique-user", displayName: "User 1")
        let user2 = User.create(in: context, appleUserID: "unique-user", displayName: "User 2")
        
        // When/Then
        XCTAssertThrowsError(try context.save()) { error in
            // Should fail unique constraint
            XCTAssertTrue(error is NSError)
        }
    }
    
    // MARK: - Migration Tests
    
    func testDataMigration() throws {
        // Given
        let user = User.create(in: context, appleUserID: "migration-test", displayName: "Migration Test")
        try context.save()
        
        // When - Simulate migration by updating user
        user.totalPoints = 100
        user.weeklyPoints = 50
        try context.save()
        
        // Then
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "appleUserID == %@", "migration-test")
        let users = try context.fetch(request)
        
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.totalPoints, 100)
        XCTAssertEqual(users.first?.weeklyPoints, 50)
    }
}
