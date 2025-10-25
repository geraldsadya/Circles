//
//  PhotoStoriesManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import UIKit
import Photos
import Combine
import CoreData

@MainActor
class PhotoStoriesManager: ObservableObject {
    static let shared = PhotoStoriesManager()
    
    @Published var isAuthorized: Bool = false
    @Published var photoStories: [PhotoStory] = []
    @Published var pendingTagRequests: [TagRequest] = []
    @Published var errorMessage: String?
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Photo library access
    private let photoLibrary = PHPhotoLibrary.shared()
    
    init() {
        checkPhotoLibraryAuthorization()
        setupNotifications()
        loadPhotoStories()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    private func checkPhotoLibraryAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        isAuthorized = (status == .authorized || status == .limited)
    }
    
    private func setupNotifications() {
        // Listen for new hangout sessions to suggest photo stories
        NotificationCenter.default.publisher(for: .hangoutStarted)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let hangoutSession = userInfo["hangoutSession"] as? HangoutSession {
                    self?.suggestPhotoStory(for: hangoutSession)
                }
            }
            .store(in: &cancellables)
        
        // Listen for hangout endings to prompt for photo sharing
        NotificationCenter.default.publisher(for: .hangoutEnded)
            .sink { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let hangoutSession = userInfo["hangoutSession"] as? HangoutSession {
                    self?.promptForPhotoStory(after: hangoutSession)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authorization
    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized || status == .limited)
        }
        
        if isAuthorized {
            await loadPhotoStories()
        }
    }
    
    // MARK: - Photo Story Creation
    func createPhotoStory(
        hangoutSession: HangoutSession,
        selectedPhotos: [UIImage],
        taggedUsers: [User]
    ) async -> PhotoStory? {
        guard isAuthorized else {
            errorMessage = "Photo library access required"
            return nil
        }
        
        // Create tag requests for all tagged users
        let tagRequests = taggedUsers.map { user in
            TagRequest(
                id: UUID(),
                photoStoryID: UUID(),
                taggedUser: user,
                requestedBy: getCurrentUser(),
                status: .pending,
                createdAt: Date()
            )
        }
        
        // Create the photo story
        let photoStory = PhotoStory(
            id: UUID(),
            hangoutSession: hangoutSession,
            photos: selectedPhotos,
            taggedUsers: taggedUsers,
            tagRequests: tagRequests,
            takenBy: getCurrentUser(),
            createdAt: Date(),
            isApproved: false // Will be true when all tags are approved
        )
        
        // Save to Core Data
        await savePhotoStoryToCoreData(photoStory)
        
        // Send tag requests to friends
        await sendTagRequests(tagRequests)
        
        // Add to local collection
        photoStories.append(photoStory)
        
        return photoStory
    }
    
    // MARK: - Tag Request Management
    func respondToTagRequest(_ request: TagRequest, approved: Bool) async {
        // Update the tag request status
        await updateTagRequestStatus(request, approved: approved)
        
        // If all tags are approved, approve the entire photo story
        if approved {
            await checkAndApprovePhotoStory(request.photoStoryID)
        }
        
        // Remove from pending requests
        pendingTagRequests.removeAll { $0.id == request.id }
    }
    
    private func updateTagRequestStatus(_ request: TagRequest, approved: Bool) async {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TagRequestEntity> = TagRequestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", request.id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                entity.status = approved ? "approved" : "declined"
                entity.respondedAt = Date()
                try context.save()
            }
        } catch {
            print("Error updating tag request: \(error)")
        }
    }
    
    private func checkAndApprovePhotoStory(_ photoStoryID: UUID) async {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<PhotoStoryEntity> = PhotoStoryEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", photoStoryID as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                // Check if all tag requests are approved
                let tagRequestFetch: NSFetchRequest<TagRequestEntity> = TagRequestEntity.fetchRequest()
                tagRequestFetch.predicate = NSPredicate(format: "photoStoryID == %@", photoStoryID as CVarArg)
                
                let tagRequests = try context.fetch(tagRequestFetch)
                let allApproved = tagRequests.allSatisfy { $0.status == "approved" }
                
                if allApproved {
                    entity.isApproved = true
                    entity.approvedAt = Date()
                    try context.save()
                    
                    // Update local collection
                    if let index = photoStories.firstIndex(where: { $0.id == photoStoryID }) {
                        photoStories[index] = PhotoStory(
                            id: photoStoryID,
                            hangoutSession: entity.hangoutSession!,
                            photos: [], // Would load from storage
                            taggedUsers: [], // Would load from relationships
                            tagRequests: [], // Would load from relationships
                            takenBy: entity.takenBy!,
                            createdAt: entity.createdAt!,
                            isApproved: true
                        )
                    }
                    
                    // Notify that photo story is now public
                    NotificationCenter.default.post(
                        name: .photoStoryApproved,
                        object: nil,
                        userInfo: ["photoStoryID": photoStoryID]
                    )
                }
            }
        } catch {
            print("Error checking photo story approval: \(error)")
        }
    }
    
    // MARK: - Photo Selection
    func selectPhotosFromLibrary() async -> [UIImage] {
        guard isAuthorized else { return [] }
        
        // This would present a photo picker
        // For now, return empty array
        return []
    }
    
    func takePhotoWithCamera() async -> UIImage? {
        // This would present camera interface
        // For now, return nil
        return nil
    }
    
    // MARK: - Hangout Integration
    private func suggestPhotoStory(for hangoutSession: HangoutSession) {
        // Show suggestion to take photos during hangout
        print("📸 Suggesting photo story for hangout with \(hangoutSession.participants.count) participants")
    }
    
    private func promptForPhotoStory(after hangoutSession: HangoutSession) {
        // Show prompt to share photos after hangout ends
        print("📸 Prompting for photo story after hangout ended")
    }
    
    // MARK: - Data Management
    private func loadPhotoStories() async {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<PhotoStoryEntity> = PhotoStoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isApproved == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PhotoStoryEntity.createdAt, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            photoStories = entities.compactMap { entity in
                // Convert entity to PhotoStory model
                // This would include loading photos from storage
                return PhotoStory(
                    id: entity.id!,
                    hangoutSession: entity.hangoutSession!,
                    photos: [], // Would load from storage
                    taggedUsers: [], // Would load from relationships
                    tagRequests: [], // Would load from relationships
                    takenBy: entity.takenBy!,
                    createdAt: entity.createdAt!,
                    isApproved: entity.isApproved
                )
            }
        } catch {
            print("Error loading photo stories: \(error)")
        }
    }
    
    private func savePhotoStoryToCoreData(_ photoStory: PhotoStory) async {
        let context = persistenceController.container.viewContext
        
        // Save photo story
        let entity = PhotoStoryEntity(context: context)
        entity.id = photoStory.id
        entity.hangoutSession = photoStory.hangoutSession
        entity.takenBy = photoStory.takenBy
        entity.createdAt = photoStory.createdAt
        entity.isApproved = photoStory.isApproved
        
        // Save tag requests
        for tagRequest in photoStory.tagRequests {
            let tagEntity = TagRequestEntity(context: context)
            tagEntity.id = tagRequest.id
            tagEntity.photoStoryID = photoStory.id
            tagEntity.taggedUser = tagRequest.taggedUser
            tagEntity.requestedBy = tagRequest.requestedBy
            tagEntity.status = tagRequest.status.rawValue
            tagEntity.createdAt = tagRequest.createdAt
        }
        
        do {
            try context.save()
            print("✅ Photo story saved to Core Data")
        } catch {
            print("❌ Failed to save photo story: \(error)")
        }
    }
    
    private func sendTagRequests(_ requests: [TagRequest]) async {
        // This would integrate with CloudKit to send push notifications
        // For now, just add to pending requests
        pendingTagRequests.append(contentsOf: requests)
        
        print("📤 Sent \(requests.count) tag requests")
    }
    
    // MARK: - Helper Methods
    private func getCurrentUser() -> User {
        // This would get the current authenticated user
        // For now, return a placeholder
        return User(name: "Current User", location: nil, profileEmoji: "👤")
    }
    
    // MARK: - Public Methods
    func getPhotoStoriesForHangout(_ hangoutSession: HangoutSession) -> [PhotoStory] {
        return photoStories.filter { $0.hangoutSession.id == hangoutSession.id }
    }
    
    func getPhotoStoriesWithUser(_ user: User) -> [PhotoStory] {
        return photoStories.filter { story in
            story.taggedUsers.contains { $0.id == user.id } ||
            story.takenBy.id == user.id
        }
    }
    
    func getPendingTagRequestsForUser(_ user: User) -> [TagRequest] {
        return pendingTagRequests.filter { $0.taggedUser.id == user.id }
    }
}

// MARK: - Supporting Types
struct PhotoStory: Identifiable, Hashable {
    let id: UUID
    let hangoutSession: HangoutSession
    let photos: [UIImage]
    let taggedUsers: [User]
    let tagRequests: [TagRequest]
    let takenBy: User
    let createdAt: Date
    let isApproved: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoStory, rhs: PhotoStory) -> Bool {
        return lhs.id == rhs.id
    }
}

struct TagRequest: Identifiable, Hashable {
    let id: UUID
    let photoStoryID: UUID
    let taggedUser: User
    let requestedBy: User
    let status: TagRequestStatus
    let createdAt: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TagRequest, rhs: TagRequest) -> Bool {
        return lhs.id == rhs.id
    }
}

enum TagRequestStatus: String, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case declined = "declined"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .declined: return "Declined"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .approved: return "green"
        case .declined: return "red"
        }
    }
}

// MARK: - Core Data Entities (Placeholders)
class PhotoStoryEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var hangoutSession: HangoutSession?
    @NSManaged var takenBy: User?
    @NSManaged var createdAt: Date?
    @NSManaged var isApproved: Bool
    @NSManaged var approvedAt: Date?
}

class TagRequestEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var photoStoryID: UUID?
    @NSManaged var taggedUser: User?
    @NSManaged var requestedBy: User?
    @NSManaged var status: String?
    @NSManaged var createdAt: Date?
    @NSManaged var respondedAt: Date?
}

// MARK: - Notifications
extension Notification.Name {
    static let photoStoryApproved = Notification.Name("photoStoryApproved")
    static let tagRequestReceived = Notification.Name("tagRequestReceived")
}
