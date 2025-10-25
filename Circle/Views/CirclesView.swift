//
//  CirclesView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData

struct CirclesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var circleShareManager = CircleShareManager.shared
    
    @State private var showingCreateCircle = false
    @State private var showingJoinCircle = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Circles List
                if filteredCircles.isEmpty {
                    emptyState
                } else {
                    circlesList
                }
            }
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreateCircle = true }) {
                            Label("Create Circle", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingJoinCircle = true }) {
                            Label("Join Circle", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingCreateCircle) {
                CreateCircleView()
            }
            .sheet(isPresented: $showingJoinCircle) {
                JoinCircleView()
            }
        }
        .onAppear {
            loadCircles()
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search circles...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Circles List
    private var circlesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredCircles, id: \.id) { circle in
                    CircleCard(circle: circle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.3")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Circles Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Create your first circle or join one with friends to start proving it together")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Button(action: { showingCreateCircle = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create Circle")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                    )
                }
                
                Button(action: { showingJoinCircle = true }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join Circle")
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    private var userCircles: [Circle] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.createdAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching circles: \(error)")
            return []
        }
    }
    
    private var filteredCircles: [Circle] {
        if searchText.isEmpty {
            return userCircles
        } else {
            return userCircles.filter { circle in
                circle.name?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    // MARK: - Methods
    private func loadCircles() {
        // Load circles from Core Data
    }
}

// MARK: - Circle Card
struct CircleCard: View {
    let circle: Circle
    @State private var showingCircleDetails = false
    
    var body: some View {
        Button(action: { showingCircleDetails = true }) {
            HStack(spacing: 16) {
                // Circle Avatar - Minimalist
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .overlay(
                        Text(circle.name?.prefix(1).uppercased() ?? "C")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(circle.name ?? "Untitled Circle")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(circle.memberships?.count ?? 0) members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Created \(circle.createdAt, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if circle.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 8, height: 8)
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingCircleDetails) {
            CircleDetailView(circle: circle)
        }
    }
}

// MARK: - Create Circle View
struct CreateCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var circleName = ""
    @State private var circleDescription = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Circle Name", text: $circleName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description (Optional)", text: $circleDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                } header: {
                    Text("Circle Details")
                } footer: {
                    Text("Choose a name that represents your group's goals")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What happens next?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You become the owner")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("You can invite friends and manage the circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Share invite code")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Friends can join using the invite code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start proving it")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Create challenges and track progress together")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Create Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createCircle()
                    }
                    .disabled(circleName.isEmpty || isCreating)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func createCircle() {
        guard !circleName.isEmpty else { return }
        
        isCreating = true
        
        // Create circle in Core Data
        let newCircle = Circle.create(in: viewContext, name: circleName)
        newCircle.inviteCode = generateInviteCode()
        
        // Create membership for current user
        let membership = Membership.create(in: viewContext, role: "owner")
        membership.user = authManager.currentUser
        membership.circle = newCircle
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error creating circle: \(error)")
            isCreating = false
        }
    }
    
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
}

// MARK: - Join Circle View
struct JoinCircleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Invite Code", text: $inviteCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                } header: {
                    Text("Enter Invite Code")
                } footer: {
                    Text("Ask a friend for their circle's invite code")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to get an invite code?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("• Ask a friend who's already in a circle")
                            .font(.subheadline)
                        Text("• They can find it in their circle settings")
                            .font(.subheadline)
                        Text("• Invite codes are 8 characters long")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Join") {
                        joinCircle()
                    }
                    .disabled(inviteCode.isEmpty || isJoining)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func joinCircle() {
        guard !inviteCode.isEmpty else { return }
        
        isJoining = true
        errorMessage = nil
        
        // Find circle by invite code
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        
        do {
            let circles = try viewContext.fetch(request)
            
            if let circle = circles.first {
                // Create membership for current user
                let membership = Membership.create(in: viewContext, role: "member")
                membership.user = authManager.currentUser
                membership.circle = circle
                
                try viewContext.save()
                dismiss()
            } else {
                errorMessage = "Invalid invite code. Please check and try again."
            }
        } catch {
            errorMessage = "Error joining circle: \(error.localizedDescription)"
        }
        
        isJoining = false
    }
}

// MARK: - Circle Detail View
struct CircleDetailView: View {
    let circle: Circle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Circle Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(circle.name?.prefix(1).uppercased() ?? "C")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(circle.name ?? "Untitled Circle")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("\(circle.memberships?.count ?? 0) members")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        if let inviteCode = circle.inviteCode {
                            HStack {
                                Text("Invite Code:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(inviteCode)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Button("Copy") {
                                    UIPasteboard.general.string = inviteCode
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    
                    // Members Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Members")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Member list would go here
                        Text("Member list coming soon...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Challenges Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Challenges")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Challenge list would go here
                        Text("Challenge list coming soon...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Circle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CirclesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
