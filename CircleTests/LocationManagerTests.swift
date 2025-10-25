//
//  LocationManagerTests.swift
//  CircleTests
//
//  Created by Circle Team on 2024-01-15.
//

import XCTest
import CoreLocation
@testable import Circle

final class LocationManagerTests: XCTestCase {
    var locationManager: LocationManager!
    var mockCLLocationManager: MockCLLocationManager!
    
    override func setUpWithError() throws {
        mockCLLocationManager = MockCLLocationManager()
        locationManager = LocationManager.shared
        locationManager.locationManager = mockCLLocationManager
    }
    
    override func tearDownWithError() throws {
        locationManager = nil
        mockCLLocationManager = nil
    }
    
    // MARK: - Location Permission Tests
    
    func testRequestLocationPermission() throws {
        // Given
        XCTAssertFalse(mockCLLocationManager.requestWhenInUseLocationCalled)
        
        // When
        locationManager.requestLocationPermission()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.requestWhenInUseLocationCalled)
    }
    
    func testRequestAlwaysLocationPermission() throws {
        // Given
        XCTAssertFalse(mockCLLocationManager.requestAlwaysLocationCalled)
        
        // When
        locationManager.requestAlwaysLocationPermission()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.requestAlwaysLocationCalled)
    }
    
    // MARK: - Location Tracking Tests
    
    func testStartLocationTracking() throws {
        // Given
        XCTAssertFalse(mockCLLocationManager.startUpdatingLocationCalled)
        
        // When
        locationManager.startLocationTracking()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.startUpdatingLocationCalled)
    }
    
    func testStopLocationTracking() throws {
        // Given
        locationManager.startLocationTracking()
        XCTAssertTrue(mockCLLocationManager.startUpdatingLocationCalled)
        
        // When
        locationManager.stopLocationTracking()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.stopUpdatingLocationCalled)
    }
    
    // MARK: - Location Accuracy Tests
    
    func testLocationAccuracyEscalation() throws {
        // Given
        let initialAccuracy = locationManager.locationAccuracy
        
        // When - Simulate candidate hangout
        locationManager.updateLocationAccuracy(for: .candidateHangout)
        
        // Then
        XCTAssertNotEqual(locationManager.locationAccuracy, initialAccuracy)
    }
    
    func testLocationAccuracyReduction() throws {
        // Given
        locationManager.updateLocationAccuracy(for: .activeHangout)
        let activeAccuracy = locationManager.locationAccuracy
        
        // When - Return to idle
        locationManager.updateLocationAccuracy(for: .idle)
        
        // Then
        XCTAssertNotEqual(locationManager.locationAccuracy, activeAccuracy)
    }
    
    // MARK: - Geofence Tests
    
    func testCreateGeofence() throws {
        // Given
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let radius: CLLocationDistance = 100
        let identifier = "test-geofence"
        
        // When
        let success = locationManager.createGeofence(
            center: coordinate,
            radius: radius,
            identifier: identifier
        )
        
        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(mockCLLocationManager.startMonitoringForRegionCalled)
    }
    
    func testRemoveGeofence() throws {
        // Given
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let radius: CLLocationDistance = 100
        let identifier = "test-geofence"
        locationManager.createGeofence(center: coordinate, radius: radius, identifier: identifier)
        
        // When
        locationManager.removeGeofence(identifier: identifier)
        
        // Then
        XCTAssertTrue(mockCLLocationManager.stopMonitoringForRegionCalled)
    }
    
    // MARK: - Location Update Tests
    
    func testProcessLocationUpdate() throws {
        // Given
        let testLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Date()
        )
        
        // When
        locationManager.processLocationUpdate(testLocation)
        
        // Then
        XCTAssertNotNil(locationManager.currentLocation)
        XCTAssertEqual(locationManager.currentLocation?.coordinate.latitude, testLocation.coordinate.latitude)
        XCTAssertEqual(locationManager.currentLocation?.coordinate.longitude, testLocation.coordinate.longitude)
    }
    
    func testLocationHistoryTracking() throws {
        // Given
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Date()
        )
        
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4294),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Date().addingTimeInterval(60)
        )
        
        // When
        locationManager.processLocationUpdate(location1)
        locationManager.processLocationUpdate(location2)
        
        // Then
        XCTAssertGreaterThanOrEqual(locationManager.locationHistory.count, 2)
    }
    
    // MARK: - Power Management Tests
    
    func testLowPowerModeHandling() throws {
        // Given
        let initialAccuracy = locationManager.locationAccuracy
        
        // When - Simulate low power mode
        locationManager.handleLowPowerModeChange(isEnabled: true)
        
        // Then
        XCTAssertNotEqual(locationManager.locationAccuracy, initialAccuracy)
        XCTAssertTrue(locationManager.isLowPowerMode)
    }
    
    func testNormalPowerModeRestoration() throws {
        // Given
        locationManager.handleLowPowerModeChange(isEnabled: true)
        let lowPowerAccuracy = locationManager.locationAccuracy
        
        // When - Restore normal power mode
        locationManager.handleLowPowerModeChange(isEnabled: false)
        
        // Then
        XCTAssertNotEqual(locationManager.locationAccuracy, lowPowerAccuracy)
        XCTAssertFalse(locationManager.isLowPowerMode)
    }
    
    // MARK: - Deferred Updates Tests
    
    func testEnableDeferredLocationUpdates() throws {
        // Given
        XCTAssertFalse(mockCLLocationManager.allowDeferredLocationUpdatesCalled)
        
        // When
        locationManager.enableDeferredLocationUpdates()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.allowDeferredLocationUpdatesCalled)
    }
    
    func testDisableDeferredLocationUpdates() throws {
        // Given
        locationManager.enableDeferredLocationUpdates()
        XCTAssertTrue(mockCLLocationManager.allowDeferredLocationUpdatesCalled)
        
        // When
        locationManager.disableDeferredLocationUpdates()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.disallowDeferredLocationUpdatesCalled)
    }
    
    // MARK: - Stationary Detection Tests
    
    func testStationaryDetection() throws {
        // Given
        let stationaryLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        // When - Process same location multiple times
        for _ in 0..<5 {
            locationManager.processLocationUpdate(stationaryLocation)
        }
        
        // Then
        XCTAssertTrue(locationManager.isStationary)
    }
    
    func testMovementDetection() throws {
        // Given
        let baseLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        let movedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4294),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date().addingTimeInterval(60)
        )
        
        // When
        locationManager.processLocationUpdate(baseLocation)
        locationManager.processLocationUpdate(movedLocation)
        
        // Then
        XCTAssertFalse(locationManager.isStationary)
    }
    
    // MARK: - Performance Tests
    
    func testLocationUpdatePerformance() throws {
        measure {
            for i in 0..<1000 {
                let location = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749 + Double(i) * 0.0001, longitude: -122.4194 + Double(i) * 0.0001),
                    altitude: 0,
                    horizontalAccuracy: 10,
                    verticalAccuracy: 10,
                    timestamp: Date().addingTimeInterval(TimeInterval(i))
                )
                locationManager.processLocationUpdate(location)
            }
        }
    }
}

// MARK: - Mock CLLocationManager
class MockCLLocationManager: CLLocationManager {
    var requestWhenInUseLocationCalled = false
    var requestAlwaysLocationCalled = false
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false
    var startMonitoringForRegionCalled = false
    var stopMonitoringForRegionCalled = false
    var allowDeferredLocationUpdatesCalled = false
    var disallowDeferredLocationUpdatesCalled = false
    
    override func requestWhenInUseAuthorization() {
        requestWhenInUseLocationCalled = true
    }
    
    override func requestAlwaysAuthorization() {
        requestAlwaysLocationCalled = true
    }
    
    override func startUpdatingLocation() {
        startUpdatingLocationCalled = true
    }
    
    override func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
    }
    
    override func startMonitoring(for region: CLRegion) {
        startMonitoringForRegionCalled = true
    }
    
    override func stopMonitoring(for region: CLRegion) {
        stopMonitoringForRegionCalled = true
    }
    
    override func allowDeferredLocationUpdates(untilTraveled distance: CLLocationDistance, timeout: TimeInterval) {
        allowDeferredLocationUpdatesCalled = true
    }
    
    override func disallowDeferredLocationUpdates() {
        disallowDeferredLocationUpdatesCalled = true
    }
}
