//
//  TestConfiguration.swift
//  CircleTests
//
//  Created by Circle Team on 2024-01-15.
//

import XCTest
import CoreData
@testable import Circle

/// Test configuration and utilities for Circle app testing
final class TestConfiguration {
    
    // MARK: - Test Data Factory
    
    static func createTestUser(in context: NSManagedObjectContext, appleUserID: String = "test-user", displayName: String = "Test User") -> User {
        return User.create(in: context, appleUserID: appleUserID, displayName: displayName)
    }
    
    static func createTestCircle(in context: NSManagedObjectContext, name: String = "Test Circle") -> Circle {
        return Circle.create(in: context, name: name)
    }
    
    static func createTestChallenge(in context: NSManagedObjectContext, title: String = "Test Challenge", category: String = "fitness", verificationMethod: String = "motion") -> Challenge {
        return Challenge.create(in: context, title: title, category: category, verificationMethod: verificationMethod)
    }
    
    static func createTestProof(in context: NSManagedObjectContext, isVerified: Bool = true, confidenceScore: Double = 0.95, verificationMethod: String = "motion") -> Proof {
        return Proof.create(in: context, isVerified: isVerified, confidenceScore: confidenceScore, verificationMethod: verificationMethod)
    }
    
    static func createTestHangoutSession(in context: NSManagedObjectContext, startTime: Date = Date()) -> HangoutSession {
        return HangoutSession.create(in: context, startTime: startTime)
    }
    
    static func createTestMembership(in context: NSManagedObjectContext, role: String = "member") -> Membership {
        return Membership.create(in: context, role: role)
    }
    
    static func createTestPointsLedger(in context: NSManagedObjectContext, points: Int32 = 10, reason: String = "Test reason") -> PointsLedger {
        return PointsLedger.create(in: context, points: points, reason: reason)
    }
    
    static func createTestLeaderboardEntry(in context: NSManagedObjectContext, points: Int32 = 100, rank: Int32 = 1, weekStarting: Date = Date(), weekEnding: Date = Date().addingTimeInterval(604800)) -> LeaderboardEntry {
        return LeaderboardEntry.create(in: context, points: points, rank: rank, weekStarting: weekStarting, weekEnding: weekEnding)
    }
    
    static func createTestSuspiciousActivity(in context: NSManagedObjectContext, type: String = "test_activity", severity: String = "medium", description: String = "Test suspicious activity") -> SuspiciousActivityEntity {
        return SuspiciousActivityEntity.create(in: context, type: type, severity: severity, description: description)
    }
    
    // MARK: - Test Relationships
    
    static func createUserCircleRelationship(in context: NSManagedObjectContext, user: User, circle: Circle, role: String = "member") -> Membership {
        let membership = createTestMembership(in: context, role: role)
        membership.user = user
        membership.circle = circle
        return membership
    }
    
    static func createChallengeProofRelationship(in context: NSManagedObjectContext, challenge: Challenge, proof: Proof) {
        proof.challenge = challenge
    }
    
    static func createUserProofRelationship(in context: NSManagedObjectContext, user: User, proof: Proof) {
        proof.user = user
    }
    
    static func createCircleChallengeRelationship(in context: NSManagedObjectContext, circle: Circle, challenge: Challenge, createdBy: User) {
        challenge.circle = circle
        challenge.createdBy = createdBy
    }
    
    // MARK: - Test Scenarios
    
    static func createCompleteUserScenario(in context: NSManagedObjectContext) -> (user: User, circle: Circle, challenge: Challenge, proof: Proof) {
        let user = createTestUser(in: context)
        let circle = createTestCircle(in: context)
        let membership = createUserCircleRelationship(in: context, user: user, circle: circle, role: "owner")
        
        let challenge = createTestChallenge(in: context)
        createCircleChallengeRelationship(in: context, circle: circle, challenge: challenge, createdBy: user)
        
        let proof = createTestProof(in: context)
        createChallengeProofRelationship(in: context, challenge: challenge, proof: proof)
        createUserProofRelationship(in: context, user: user, proof: proof)
        
        return (user, circle, challenge, proof)
    }
    
    static func createHangoutScenario(in context: NSManagedObjectContext) -> (user1: User, user2: User, circle: Circle, session: HangoutSession) {
        let user1 = createTestUser(in: context, appleUserID: "user1", displayName: "User 1")
        let user2 = createTestUser(in: context, appleUserID: "user2", displayName: "User 2")
        let circle = createTestCircle(in: context)
        
        let membership1 = createUserCircleRelationship(in: context, user: user1, circle: circle)
        let membership2 = createUserCircleRelationship(in: context, user: user2, circle: circle)
        
        let session = createTestHangoutSession(in: context)
        session.circle = circle
        
        let participant1 = HangoutParticipant.create(in: context, user: user1, session: session)
        let participant2 = HangoutParticipant.create(in: context, user: user2, session: session)
        
        return (user1, user2, circle, session)
    }
    
    static func createLeaderboardScenario(in context: NSManagedObjectContext) -> (users: [User], circle: Circle, entries: [LeaderboardEntry]) {
        let users = [
            createTestUser(in: context, appleUserID: "leader1", displayName: "Leader 1"),
            createTestUser(in: context, appleUserID: "leader2", displayName: "Leader 2"),
            createTestUser(in: context, appleUserID: "leader3", displayName: "Leader 3")
        ]
        
        let circle = createTestCircle(in: context)
        
        for user in users {
            _ = createUserCircleRelationship(in: context, user: user, circle: circle)
        }
        
        let weekStarting = Date()
        let weekEnding = weekStarting.addingTimeInterval(604800)
        
        let entries = [
            createTestLeaderboardEntry(in: context, points: 150, rank: 1, weekStarting: weekStarting, weekEnding: weekEnding),
            createTestLeaderboardEntry(in: context, points: 100, rank: 2, weekStarting: weekStarting, weekEnding: weekEnding),
            createTestLeaderboardEntry(in: context, points: 75, rank: 3, weekStarting: weekStarting, weekEnding: weekEnding)
        ]
        
        for (index, entry) in entries.enumerated() {
            entry.user = users[index]
            entry.circle = circle
        }
        
        return (users, circle, entries)
    }
    
    // MARK: - Test Data Cleanup
    
    static func cleanupTestData(in context: NSManagedObjectContext) throws {
        // Delete all test data
        let entities = [
            "User", "Circle", "Challenge", "Proof", "HangoutSession", "HangoutParticipant",
            "PointsLedger", "LeaderboardEntry", "Membership", "SuspiciousActivityEntity",
            "AnalyticsEventEntity", "ConsentLogEntity", "Device", "ChallengeTemplate"
        ]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
        
        try context.save()
    }
    
    // MARK: - Test Assertions
    
    static func assertUserProperties(_ user: User, appleUserID: String, displayName: String) {
        XCTAssertEqual(user.appleUserID, appleUserID)
        XCTAssertEqual(user.displayName, displayName)
        XCTAssertNotNil(user.id)
        XCTAssertNotNil(user.createdAt)
        XCTAssertNotNil(user.lastActiveAt)
        XCTAssertEqual(user.totalPoints, 0)
        XCTAssertEqual(user.weeklyPoints, 0)
    }
    
    static func assertCircleProperties(_ circle: Circle, name: String) {
        XCTAssertEqual(circle.name, name)
        XCTAssertNotNil(circle.id)
        XCTAssertNotNil(circle.inviteCode)
        XCTAssertNotNil(circle.createdAt)
        XCTAssertTrue(circle.isActive)
    }
    
    static func assertChallengeProperties(_ challenge: Challenge, title: String, category: String, verificationMethod: String) {
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
    
    static func assertProofProperties(_ proof: Proof, isVerified: Bool, confidenceScore: Double, verificationMethod: String) {
        XCTAssertEqual(proof.isVerified, isVerified)
        XCTAssertEqual(proof.confidenceScore, confidenceScore)
        XCTAssertEqual(proof.verificationMethod, verificationMethod)
        XCTAssertNotNil(proof.id)
        XCTAssertNotNil(proof.timestamp)
        XCTAssertNotNil(proof.createdAt)
        XCTAssertEqual(proof.pointsAwarded, isVerified ? 10 : -5)
    }
    
    // MARK: - Test Performance
    
    static func measurePerformance<T>(_ block: () throws -> T) throws -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try block()
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        return (result, duration)
    }
    
    static func assertPerformance(_ duration: TimeInterval, maxDuration: TimeInterval, message: String = "Performance test failed") {
        XCTAssertLessThan(duration, maxDuration, message)
    }
    
    // MARK: - Test Mock Data
    
    static func createMockLocation(coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), accuracy: CLLocationAccuracy = 10) -> CLLocation {
        return CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            timestamp: Date()
        )
    }
    
    static func createMockMotionData(steps: Int = 1000, distance: Double = 1000) -> CMPedometerData {
        // Note: CMPedometerData is not directly creatable
        // This would require mocking or using test data
        fatalError("Mock motion data creation not implemented")
    }
    
    // MARK: - Test Environment
    
    static func setupTestEnvironment() {
        // Configure test environment
        // This could include setting up mock services, test data, etc.
    }
    
    static func teardownTestEnvironment() {
        // Clean up test environment
        // This could include cleaning up mock services, test data, etc.
    }
}

// MARK: - Test Extensions

extension XCTestCase {
    
    func createTestContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "Circle")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        return container.viewContext
    }
    
    func cleanupTestContext(_ context: NSManagedObjectContext) throws {
        try TestConfiguration.cleanupTestData(in: context)
    }
    
    func assertNoMemoryLeaks<T: AnyObject>(_ object: T, file: StaticString = #file, line: UInt = #line) {
        weak var weakObject = object
        XCTAssertNil(weakObject, "Object should be deallocated", file: file, line: line)
    }
    
    func assertPerformance<T>(_ block: () throws -> T, maxDuration: TimeInterval, message: String = "Performance test failed") throws {
        let (_, duration) = try TestConfiguration.measurePerformance(block)
        TestConfiguration.assertPerformance(duration, maxDuration: maxDuration, message: message)
    }
}
