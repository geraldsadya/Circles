//
//  AddFriendView.swift
//  Circle
//
//  Friend invite and connection UI
//

import SwiftUI

struct AddFriendView: View {
    @StateObject private var friendManager = FriendManager.shared
    @StateObject private var profileManager = UserProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteCode = ""
    @State private var isAddingFriend = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // My invite code section
                VStack(spacing: 16) {
                    Text("Your Invite Code")
                        .font(.headline)
                    
                    if let code = friendManager.myInviteCode {
                        // Display code
                        HStack(spacing: 12) {
                            Text(code)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .tracking(4)
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            
                            Button(action: {
                                UIPasteboard.general.string = code
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text("Share this code with friends")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button(action: generateCode) {
                            Text("Generate Invite Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Add friend section
                VStack(spacing: 16) {
                    Text("Add a Friend")
                        .font(.headline)
                    
                    TextField("Enter invite code", text: $inviteCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .tracking(4)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal)
                    
                    Button(action: addFriend) {
                        if isAddingFriend {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Add Friend")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(inviteCode.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(inviteCode.isEmpty || isAddingFriend)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("Friend Added!", isPresented: $showingSuccess) {
                Button("OK") {
                    inviteCode = ""
                }
            } message: {
                Text("Your friend has been added successfully!")
            }
        }
        .onAppear {
            loadInviteCode()
        }
    }
    
    private func generateCode() {
        guard let userProfile = profileManager.currentUserProfile else {
            return
        }
        
        Task {
            do {
                let code = try await friendManager.generateInviteCode(for: userProfile)
                print("✅ Generated invite code: \(code)")
            } catch {
                print("❌ Failed to generate code: \(error.localizedDescription)")
                errorMessage = "Failed to generate invite code"
                showingError = true
            }
        }
    }
    
    private func loadInviteCode() {
        // Try to load existing invite code
        guard let userProfile = profileManager.currentUserProfile else {
            return
        }
        
        // For simplicity, generate a new code if none exists
        if friendManager.myInviteCode == nil {
            generateCode()
        }
    }
    
    private func addFriend() {
        guard let currentUser = profileManager.currentUserProfile else {
            errorMessage = "Please sign in first"
            showingError = true
            return
        }
        
        isAddingFriend = true
        
        Task {
            do {
                try await friendManager.addFriendByCode(inviteCode.uppercased(), currentUser: currentUser)
                print("✅ Friend added successfully")
                showingSuccess = true
            } catch {
                print("❌ Failed to add friend: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showingError = true
            }
            
            isAddingFriend = false
        }
    }
}

#Preview {
    AddFriendView()
}

