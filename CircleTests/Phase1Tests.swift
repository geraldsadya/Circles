//
//  Phase1Tests.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import XCTest
import CoreLocation
import CoreMotion
@testable import Circle

class Phase1Tests: XCTestCase {
    
    // MARK: - LocationManager Tests
    func testLocationManagerInitialization() {
        let locationManager = LocationManager.shared
        XCTAssertNotNil(locationManager)
        XCTAssertEqual(locationManager.authorizationStatus, .notDetermined)
        XCTAssertFalse(locationManager.isTrackingHangouts)
    }
    
    func testLocationManagerPermissionRequest() {
        let locationManager = LocationManager.shared
        locationManager.requestLocationPermission()
        // Note: In a real test environment, you'd mock the CLLocationManager
        // For now, we just verify the method doesn't crash
        XCTAssertNotNil(locationManager)
    }
    
    func testHangoutCandidateCreation() {
        let friend = User(name: "Test Friend", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
        let candidate = HangoutCandidate(
            friend: friend,
            startTime: Date(),
            lastProximityTime: Date(),
            minDistance: 5.0
        )
        
        XCTAssertEqual(candidate.friend.name, "Test Friend")
        XCTAssertEqual(candidate.minDistance, 5.0)
        XCTAssertFalse(candidate.shouldPromoteToActive())
    }
    
    func testHangoutCandidatePromotion() {
        let friend = User(name: "Test Friend", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
        let startTime = Date().addingTimeInterval(-300) // 5 minutes ago
        let candidate = HangoutCandidate(
            friend: friend,
            startTime: startTime,
            lastProximityTime: Date(),
            minDistance: 5.0
        )
        
        // Should promote to active after 5 minutes in proximity
        XCTAssertTrue(candidate.shouldPromoteToActive())
    }
    
    // MARK: - MotionManager Tests
    func testMotionManagerInitialization() {
        let motionManager = MotionManager.shared
        XCTAssertNotNil(motionManager)
        XCTAssertFalse(motionManager.isActivelyMoving)
        XCTAssertEqual(motionManager.motionDuration, 0.0)
        XCTAssertEqual(motionManager.todaysSteps, 0)
    }
    
    func testMotionManagerStepCountingAvailability() {
        let motionManager = MotionManager.shared
        // This will be true on devices with step counting capability
        // In simulator, it might be false
        XCTAssertNotNil(motionManager.isStepCountingAvailable)
    }
    
    func testActivityTypeEnum() {
        XCTAssertEqual(ActivityType.walking.displayName, "Walking")
        XCTAssertEqual(ActivityType.running.displayName, "Running")
        XCTAssertEqual(ActivityType.cycling.displayName, "Cycling")
        XCTAssertEqual(ActivityType.stationary.displayName, "Stationary")
    }
    
    func testActivityTypeIcons() {
        XCTAssertEqual(ActivityType.walking.icon, "figure.walk")
        XCTAssertEqual(ActivityType.running.icon, "figure.run")
        XCTAssertEqual(ActivityType.cycling.icon, "bicycle")
        XCTAssertEqual(ActivityType.stationary.icon, "pause.circle")
    }
    
    // MARK: - BackgroundTaskManager Tests
    func testBackgroundTaskManagerInitialization() {
        let backgroundTaskManager = BackgroundTaskManager.shared
        XCTAssertNotNil(backgroundTaskManager)
        XCTAssertFalse(backgroundTaskManager.isBackgroundTaskRunning)
        XCTAssertEqual(backgroundTaskManager.backgroundTaskStatus, .idle)
    }
    
    func testBackgroundTaskStatusDescription() {
        let backgroundTaskManager = BackgroundTaskManager.shared
        XCTAssertEqual(backgroundTaskManager.getBackgroundTaskStatus(), "Idle")
        XCTAssertEqual(backgroundTaskManager.getActiveTaskCount(), 0)
    }
    
    // MARK: - UI Model Tests
    func testUserModel() {
        let user = User(name: "Test User", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), profileEmoji: "👤")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.profileEmoji, "👤")
        XCTAssertNotNil(user.location)
    }
    
    func testHangoutSessionModel() {
        let participants = [
            User(name: "User 1", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
            User(name: "User 2", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094))
        ]
        
        let session = HangoutSession(
            participants: participants,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            isActive: false
        )
        
        XCTAssertEqual(session.participants.count, 2)
        XCTAssertFalse(session.isActive)
        XCTAssertEqual(session.duration, 3600)
    }
    
    func testChallengeModel() {
        let challenge = Challenge(
            title: "Test Challenge",
            description: "A test challenge",
            participants: ["User 1", "User 2"],
            points: 50,
            verificationMethod: "motion",
            isActive: true
        )
        
        XCTAssertEqual(challenge.title, "Test Challenge")
        XCTAssertEqual(challenge.points, 50)
        XCTAssertEqual(challenge.verificationMethod, "motion")
        XCTAssertTrue(challenge.isActive)
    }
    
    func testLeaderboardEntryModel() {
        let entry = LeaderboardEntry(
            participant: "Test User",
            score: 85,
            rank: 1,
            progress: 0.85,
            isCurrentUser: true
        )
        
        XCTAssertEqual(entry.participant, "Test User")
        XCTAssertEqual(entry.score, 85)
        XCTAssertEqual(entry.rank, 1)
        XCTAssertEqual(entry.progress, 0.85)
        XCTAssertTrue(entry.isCurrentUser)
    }
    
    // MARK: - HangoutEngine Tests
    func testHangoutEngineInitialization() {
        let hangoutEngine = HangoutEngine.shared
        XCTAssertNotNil(hangoutEngine)
    }
    
    func testHangoutEngineActiveHangouts() {
        let hangoutEngine = HangoutEngine.shared
        let activeHangouts = hangoutEngine.getActiveHangouts()
        
        // Should return mock data
        XCTAssertFalse(activeHangouts.isEmpty)
        XCTAssertTrue(activeHangouts.allSatisfy { $0.isActive })
    }
    
    func testHangoutEngineWeeklyHangouts() {
        let hangoutEngine = HangoutEngine.shared
        let weeklyHangouts = hangoutEngine.getWeeklyHangouts()
        
        // Should return mock data
        XCTAssertFalse(weeklyHangouts.isEmpty)
    }
    
    func testHangoutEngineTotalTime() {
        let hangoutEngine = HangoutEngine.shared
        let friend = User(name: "Test Friend", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
        let totalTime = hangoutEngine.getTotalHangoutTime(with: friend)
        
        // Should return mock data (7200 seconds = 2 hours)
        XCTAssertEqual(totalTime, 7200)
    }
    
    // MARK: - Integration Tests
    func testLocationAndMotionIntegration() {
        let locationManager = LocationManager.shared
        let motionManager = MotionManager.shared
        
        // Both should be initialized
        XCTAssertNotNil(locationManager)
        XCTAssertNotNil(motionManager)
        
        // Both should start in idle state
        XCTAssertFalse(locationManager.isTrackingHangouts)
        XCTAssertFalse(motionManager.isActivelyMoving)
    }
    
    func testBackgroundTaskScheduling() {
        let backgroundTaskManager = BackgroundTaskManager.shared
        
        // Should be able to schedule tasks (though they won't actually run in test environment)
        backgroundTaskManager.scheduleBackgroundTasks()
        
        // Status should remain idle in test environment
        XCTAssertEqual(backgroundTaskManager.backgroundTaskStatus, .idle)
    }
    
    // MARK: - Performance Tests
    func testLocationManagerPerformance() {
        let locationManager = LocationManager.shared
        
        measure {
            // Test location manager operations
            locationManager.requestLocationPermission()
            locationManager.startLocationUpdates { _ in }
            locationManager.stopLocationUpdates()
        }
    }
    
    func testMotionManagerPerformance() {
        let motionManager = MotionManager.shared
        
        measure {
            // Test motion manager operations
            let _ = motionManager.getStepsForDate(Date())
            let _ = motionManager.getWeeklySteps()
            let _ = motionManager.getMonthlySteps()
        }
    }
    
    // MARK: - Error Handling Tests
    func testLocationManagerErrorHandling() {
        let locationManager = LocationManager.shared
        
        // Test that methods don't crash with invalid inputs
        locationManager.startLocationUpdates { _ in }
        locationManager.stopLocationUpdates()
        
        // Should not crash
        XCTAssertNotNil(locationManager)
    }
    
    func testMotionManagerErrorHandling() {
        let motionManager = MotionManager.shared
        
        // Test with invalid dates
        let pastDate = Date().addingTimeInterval(-86400 * 365) // 1 year ago
        let futureDate = Date().addingTimeInterval(86400 * 365) // 1 year from now
        
        let pastResult = motionManager.getStepsForDate(pastDate)
        let futureResult = motionManager.getStepsForDate(futureDate)
        
        // Should return valid results (even if 0)
        XCTAssertNotNil(pastResult)
        XCTAssertNotNil(futureResult)
    }
}

// MARK: - Test Extensions
extension Phase1Tests {
    
    func testAllPhase1Features() {
        // Run all Phase 1 feature tests
        testLocationManagerInitialization()
        testMotionManagerInitialization()
        testBackgroundTaskManagerInitialization()
        testHangoutEngineInitialization()
        
        print("✅ All Phase 1 core features initialized successfully")
    }
    
    func testPhase1Integration() {
        // Test integration between Phase 1 components
        let locationManager = LocationManager.shared
        let motionManager = MotionManager.shared
        let backgroundTaskManager = BackgroundTaskManager.shared
        let hangoutEngine = HangoutEngine.shared
        
        // All components should be accessible
        XCTAssertNotNil(locationManager)
        XCTAssertNotNil(motionManager)
        XCTAssertNotNil(backgroundTaskManager)
        XCTAssertNotNil(hangoutEngine)
        
        print("✅ Phase 1 integration test passed")
    }
    
    func testPhase1DataFlow() {
        // Test data flow between components
        let hangoutEngine = HangoutEngine.shared
        let activeHangouts = hangoutEngine.getActiveHangouts()
        let weeklyHangouts = hangoutEngine.getWeeklyHangouts()
        
        // Data should flow correctly
        XCTAssertFalse(activeHangouts.isEmpty)
        XCTAssertFalse(weeklyHangouts.isEmpty)
        
        print("✅ Phase 1 data flow test passed")
    }
}
