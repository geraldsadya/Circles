//
//  AuthenticationManagerTests.swift
//  CircleTests
//
//  Created by Circle Team on 2024-01-15.
//

import XCTest
import CoreData
@testable import Circle

final class AuthenticationManagerTests: XCTestCase {
    var authenticationManager: AuthenticationManager!
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
        authenticationManager = AuthenticationManager.shared
    }
    
    override func tearDownWithError() throws {
        authenticationManager = nil
        mockContext = nil
    }
    
    // MARK: - User Creation Tests
    
    func testCreateUserFromSubjectID() throws {
        // Given
        let subjectID = "test-subject-123"
        
        // When
        let user = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user.appleUserID, subjectID)
        XCTAssertNotNil(user.id)
        XCTAssertNotNil(user.createdAt)
        XCTAssertNotNil(user.lastActiveAt)
        XCTAssertEqual(user.totalPoints, 0)
        XCTAssertEqual(user.weeklyPoints, 0)
    }
    
    func testCreateUserWithDisplayName() throws {
        // Given
        let subjectID = "test-subject-456"
        let displayName = "Test User"
        
        // When
        let user = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
        user.displayName = displayName
        
        // Then
        XCTAssertEqual(user.displayName, displayName)
    }
    
    // MARK: - User Persistence Tests
    
    func testSaveUserToCoreData() throws {
        // Given
        let subjectID = "test-subject-789"
        let user = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
        
        // When
        try mockContext.save()
        
        // Then
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "appleUserID == %@", subjectID)
        let savedUsers = try mockContext.fetch(request)
        
        XCTAssertEqual(savedUsers.count, 1)
        XCTAssertEqual(savedUsers.first?.appleUserID, subjectID)
    }
    
    func testLoadUserFromCoreData() throws {
        // Given
        let subjectID = "test-subject-load"
        let user = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
        try mockContext.save()
        
        // When
        let loadedUser = authenticationManager.loadUserFromCoreData(subjectID: subjectID, in: mockContext)
        
        // Then
        XCTAssertNotNil(loadedUser)
        XCTAssertEqual(loadedUser?.appleUserID, subjectID)
    }
    
    // MARK: - Authentication State Tests
    
    func testAuthenticationStateInitialization() throws {
        // Given/When
        let isAuthenticated = authenticationManager.isAuthenticated
        
        // Then
        XCTAssertFalse(isAuthenticated)
        XCTAssertNil(authenticationManager.currentUser)
    }
    
    func testSetCurrentUser() throws {
        // Given
        let subjectID = "test-subject-current"
        let user = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
        
        // When
        authenticationManager.currentUser = user
        
        // Then
        XCTAssertTrue(authenticationManager.isAuthenticated)
        XCTAssertEqual(authenticationManager.currentUser, user)
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOutClearsUser() throws {
        // Given
        let subjectID = "test-subject-signout"
        let user = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
        authenticationManager.currentUser = user
        
        // When
        authenticationManager.signOut()
        
        // Then
        XCTAssertFalse(authenticationManager.isAuthenticated)
        XCTAssertNil(authenticationManager.currentUser)
    }
    
    // MARK: - Keychain Tests
    
    func testStoreSubjectIDInKeychain() throws {
        // Given
        let subjectID = "test-subject-keychain"
        
        // When
        let success = KeychainManager.store(subjectID, forKey: "test_key")
        
        // Then
        XCTAssertTrue(success)
        
        // Clean up
        KeychainManager.delete(forKey: "test_key")
    }
    
    func testRetrieveSubjectIDFromKeychain() throws {
        // Given
        let subjectID = "test-subject-retrieve"
        KeychainManager.store(subjectID, forKey: "test_key")
        
        // When
        let retrievedID = KeychainManager.retrieve(forKey: "test_key")
        
        // Then
        XCTAssertEqual(retrievedID, subjectID)
        
        // Clean up
        KeychainManager.delete(forKey: "test_key")
    }
    
    func testDeleteFromKeychain() throws {
        // Given
        let subjectID = "test-subject-delete"
        KeychainManager.store(subjectID, forKey: "test_key")
        
        // When
        let deleteSuccess = KeychainManager.delete(forKey: "test_key")
        
        // Then
        XCTAssertTrue(deleteSuccess)
        
        let retrievedID = KeychainManager.retrieve(forKey: "test_key")
        XCTAssertNil(retrievedID)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleAuthenticationError() throws {
        // Given
        let error = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        authenticationManager.handleAuthenticationError(error)
        
        // Then
        XCTAssertNotNil(authenticationManager.errorMessage)
        XCTAssertEqual(authenticationManager.errorMessage, "Test error")
    }
    
    // MARK: - Performance Tests
    
    func testUserCreationPerformance() throws {
        measure {
            for i in 0..<100 {
                let subjectID = "perf-test-\(i)"
                _ = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
            }
        }
    }
    
    func testUserFetchPerformance() throws {
        // Given - Create test data
        for i in 0..<1000 {
            let subjectID = "perf-fetch-\(i)"
            _ = authenticationManager.createUserFromSubjectID(subjectID, in: mockContext)
        }
        try mockContext.save()
        
        // When/Then
        measure {
            let request: NSFetchRequest<User> = User.fetchRequest()
            _ = try? mockContext.fetch(request)
        }
    }
}

// MARK: - Mock KeychainManager for Testing
class MockKeychainManager {
    private static var storage: [String: String] = [:]
    
    static func store(_ value: String, forKey key: String) -> Bool {
        storage[key] = value
        return true
    }
    
    static func retrieve(forKey key: String) -> String? {
        return storage[key]
    }
    
    static func delete(forKey key: String) -> Bool {
        storage.removeValue(forKey: key)
        return true
    }
    
    static func clear() {
        storage.removeAll()
    }
}
