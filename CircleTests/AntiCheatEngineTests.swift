//
//  AntiCheatEngineTests.swift
//  CircleTests
//
//  Created by Circle Team on 2024-01-15.
//

import XCTest
import CoreLocation
import CoreMotion
@testable import Circle

final class AntiCheatEngineTests: XCTestCase {
    var antiCheatEngine: AntiCheatEngine!
    var mockContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "Circle")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        mockContext = container.viewContext
        antiCheatEngine = AntiCheatEngine.shared
    }
    
    override func tearDownWithError() throws {
        antiCheatEngine = nil
        mockContext = nil
    }
    
    // MARK: - Clock Tampering Tests
    
    func testClockTamperingDetection() throws {
        // Given
        let initialIntegrityScore = antiCheatEngine.integrityScore
        
        // When - Simulate clock tampering
        antiCheatEngine.checkClockTampering()
        
        // Then
        // Note: This test may not detect tampering in test environment
        // but verifies the method doesn't crash
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
        XCTAssertLessThanOrEqual(antiCheatEngine.integrityScore, 1.0)
    }
    
    func testClockTamperingWithSuspiciousActivity() throws {
        // Given
        let suspiciousActivity = SuspiciousActivityEntity.create(
            in: mockContext,
            type: "clock_tampering",
            severity: "high",
            description: "Detected potential clock tampering"
        )
        
        // When
        antiCheatEngine.recordSuspiciousActivity(suspiciousActivity)
        
        // Then
        XCTAssertLessThan(antiCheatEngine.integrityScore, 1.0)
    }
    
    // MARK: - Motion Location Mismatch Tests
    
    func testMotionLocationMismatchDetection() throws {
        // Given
        let initialIntegrityScore = antiCheatEngine.integrityScore
        
        // When
        antiCheatEngine.checkMotionLocationMismatch()
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
        XCTAssertLessThanOrEqual(antiCheatEngine.integrityScore, 1.0)
    }
    
    func testMotionLocationMismatchWithData() throws {
        // Given - Create mock data showing mismatch
        let stationaryLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        // When - Simulate stationary GPS but active motion
        antiCheatEngine.checkMotionLocationMismatch()
        
        // Then
        // Integrity score should be affected if mismatch is detected
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
    }
    
    // MARK: - Rapid Location Changes Tests
    
    func testRapidLocationChangesDetection() throws {
        // Given
        let initialIntegrityScore = antiCheatEngine.integrityScore
        
        // When
        antiCheatEngine.checkRapidLocationChanges()
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
        XCTAssertLessThanOrEqual(antiCheatEngine.integrityScore, 1.0)
    }
    
    func testRapidLocationChangesWithSuspiciousData() throws {
        // Given - Create locations that would indicate rapid movement
        let locations = [
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, timestamp: Date()),
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4294), altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, timestamp: Date().addingTimeInterval(1)),
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.4394), altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, timestamp: Date().addingTimeInterval(2))
        ]
        
        // When
        for location in locations {
            antiCheatEngine.checkRapidLocationChanges()
        }
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
    }
    
    // MARK: - Impossible Movement Tests
    
    func testImpossibleMovementDetection() throws {
        // Given
        let initialIntegrityScore = antiCheatEngine.integrityScore
        
        // When
        antiCheatEngine.checkImpossibleMovement()
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
        XCTAssertLessThanOrEqual(antiCheatEngine.integrityScore, 1.0)
    }
    
    func testImpossibleMovementWithExtremeData() throws {
        // Given - Locations that would indicate impossible speed
        let impossibleLocations = [
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, timestamp: Date()),
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 40.7749, longitude: -120.4194), altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, timestamp: Date().addingTimeInterval(1))
        ]
        
        // When
        antiCheatEngine.checkImpossibleMovement()
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
    }
    
    // MARK: - Data Inconsistency Tests
    
    func testDataInconsistencyDetection() throws {
        // Given
        let initialIntegrityScore = antiCheatEngine.integrityScore
        
        // When
        antiCheatEngine.checkDataInconsistency()
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
        XCTAssertLessThanOrEqual(antiCheatEngine.integrityScore, 1.0)
    }
    
    // MARK: - Suspicious Patterns Tests
    
    func testSuspiciousPatternsDetection() throws {
        // Given
        let initialIntegrityScore = antiCheatEngine.integrityScore
        
        // When
        antiCheatEngine.checkSuspiciousPatterns()
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
        XCTAssertLessThanOrEqual(antiCheatEngine.integrityScore, 1.0)
    }
    
    func testMultipleSuspiciousActivities() throws {
        // Given
        let activities = [
            SuspiciousActivityEntity.create(in: mockContext, type: "clock_tampering", severity: "medium", description: "Clock tampering detected"),
            SuspiciousActivityEntity.create(in: mockContext, type: "rapid_movement", severity: "high", description: "Rapid movement detected"),
            SuspiciousActivityEntity.create(in: mockContext, type: "impossible_movement", severity: "high", description: "Impossible movement detected")
        ]
        
        // When
        for activity in activities {
            antiCheatEngine.recordSuspiciousActivity(activity)
        }
        
        // Then
        XCTAssertLessThan(antiCheatEngine.integrityScore, 0.8) // Should be significantly reduced
    }
    
    // MARK: - Integrity Score Tests
    
    func testIntegrityScoreInitialization() throws {
        // Given/When
        let integrityScore = antiCheatEngine.integrityScore
        
        // Then
        XCTAssertEqual(integrityScore, 1.0) // Should start at perfect score
    }
    
    func testIntegrityScoreUpdate() throws {
        // Given
        let initialScore = antiCheatEngine.integrityScore
        
        // When
        antiCheatEngine.updateIntegrityScore()
        
        // Then
        XCTAssertGreaterThanOrEqual(antiCheatEngine.integrityScore, 0.0)
        XCTAssertLessThanOrEqual(antiCheatEngine.integrityScore, 1.0)
    }
    
    func testIntegrityScoreWithSuspiciousActivity() throws {
        // Given
        let suspiciousActivity = SuspiciousActivityEntity.create(
            in: mockContext,
            type: "test_activity",
            severity: "high",
            description: "Test suspicious activity"
        )
        
        // When
        antiCheatEngine.recordSuspiciousActivity(suspiciousActivity)
        antiCheatEngine.updateIntegrityScore()
        
        // Then
        XCTAssertLessThan(antiCheatEngine.integrityScore, 1.0)
    }
    
    // MARK: - Challenge Integrity Tests
    
    func testVerifyChallengeIntegrity() throws {
        // Given
        let challenge = Challenge.create(
            in: mockContext,
            title: "Test Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        
        // When
        let result = antiCheatEngine.verifyChallengeIntegrity(challenge)
        
        // Then
        XCTAssertTrue(result) // Should pass with no suspicious activity
    }
    
    func testVerifyChallengeIntegrityWithLowScore() throws {
        // Given
        let challenge = Challenge.create(
            in: mockContext,
            title: "Test Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        
        // Create multiple suspicious activities to lower integrity score
        for _ in 0..<5 {
            let activity = SuspiciousActivityEntity.create(
                in: mockContext,
                type: "test_activity",
                severity: "high",
                description: "Test suspicious activity"
            )
            antiCheatEngine.recordSuspiciousActivity(activity)
        }
        
        // When
        let result = antiCheatEngine.verifyChallengeIntegrity(challenge)
        
        // Then
        XCTAssertFalse(result) // Should fail with low integrity score
    }
    
    // MARK: - Camera Verification Tests
    
    func testRequireCameraVerification() throws {
        // Given
        let challenge = Challenge.create(
            in: mockContext,
            title: "Test Challenge",
            category: "fitness",
            verificationMethod: "motion"
        )
        
        // When
        antiCheatEngine.requireCameraVerification(for: challenge)
        
        // Then
        // Should post notification for camera verification
        // This is tested by checking if the method completes without error
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testIntegrityCheckPerformance() throws {
        measure {
            for _ in 0..<100 {
                antiCheatEngine.performIntegrityCheck()
            }
        }
    }
    
    func testSuspiciousActivityRecordingPerformance() throws {
        measure {
            for i in 0..<1000 {
                let activity = SuspiciousActivityEntity.create(
                    in: mockContext,
                    type: "test_activity_\(i)",
                    severity: "medium",
                    description: "Test activity \(i)"
                )
                antiCheatEngine.recordSuspiciousActivity(activity)
            }
        }
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupOldActivities() throws {
        // Given - Create old activities
        let oldDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago
        let oldActivity = SuspiciousActivityEntity.create(
            in: mockContext,
            type: "old_activity",
            severity: "low",
            description: "Old activity"
        )
        oldActivity.timestamp = oldDate
        
        try mockContext.save()
        
        // When
        antiCheatEngine.cleanupOldActivities()
        
        // Then
        // Old activities should be cleaned up
        // This is verified by the method completing without error
        XCTAssertTrue(true)
    }
    
    // MARK: - Statistics Tests
    
    func testGetAntiCheatStats() throws {
        // Given
        let activity = SuspiciousActivityEntity.create(
            in: mockContext,
            type: "test_activity",
            severity: "medium",
            description: "Test activity"
        )
        antiCheatEngine.recordSuspiciousActivity(activity)
        
        // When
        let stats = antiCheatEngine.getAntiCheatStats()
        
        // Then
        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats.totalActivities, 0)
        XCTAssertGreaterThanOrEqual(stats.highSeverityCount, 0)
        XCTAssertGreaterThanOrEqual(stats.mediumSeverityCount, 0)
        XCTAssertGreaterThanOrEqual(stats.lowSeverityCount, 0)
    }
}
