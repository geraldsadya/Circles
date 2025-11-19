//
//  SignInView.swift
//  Circle
//
//  Sign in with Apple and profile setup
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var profileManager = UserProfileManager.shared
    @State private var showingProfileSetup = false
    @State private var appleUserID: String?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App logo/icon
                VStack(spacing: 16) {
                    Text("⭕️")
                        .font(.system(size: 100))
                    
                    Text("Circle")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Social life, verified")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Sign in button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                
                Text("Sign in to connect with friends")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                    .frame(height: 100)
            }
        }
        .sheet(isPresented: $showingProfileSetup) {
            if let userID = appleUserID {
                ProfileSetupView(appleUserID: userID)
            }
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }
    
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ Invalid credential type")
                return
            }
            
            let userID = credential.user
            print("✅ Signed in with Apple ID: \(userID)")
            
            isLoading = true
            
            Task {
                do {
                    // Check if user profile already exists
                    let existingProfile = try await profileManager.fetchUserProfile(appleUserID: userID)
                    
                    if existingProfile != nil {
                        print("✅ User profile found - signing in")
                        isLoading = false
                        // User already has profile, sign in complete
                    } else {
                        print("ℹ️ New user - needs profile setup")
                        appleUserID = userID
                        isLoading = false
                        showingProfileSetup = true
                    }
                } catch {
                    print("❌ Error checking user profile: \(error.localizedDescription)")
                    isLoading = false
                    // Show error to user
                }
            }
            
        case .failure(let error):
            print("❌ Sign in failed: \(error.localizedDescription)")
            // Show error to user
        }
    }
}

// MARK: - Profile Setup View
struct ProfileSetupView: View {
    let appleUserID: String
    
    @StateObject private var profileManager = UserProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var selectedEmoji = "👤"
    @State private var isCreating = false
    
    let emojis = ["👤", "😎", "🤠", "🚀", "⚡️", "🔥", "💪", "🎯", "🏆", "⭐️", "💫", "✨"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Create Your Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                // Emoji selector
                VStack(spacing: 16) {
                    Text(selectedEmoji)
                        .font(.system(size: 80))
                        .frame(width: 120, height: 120)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                            }) {
                                Text(emoji)
                                    .font(.system(size: 40))
                                    .frame(width: 60, height: 60)
                                    .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.headline)
                    
                    TextField("Enter your name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Create button
                Button(action: createProfile) {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Profile")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(displayName.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .disabled(displayName.isEmpty || isCreating)
                
                Spacer()
                    .frame(height: 40)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func createProfile() {
        guard !displayName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                let profile = try await profileManager.createUserProfile(
                    appleUserID: appleUserID,
                    displayName: displayName,
                    profileEmoji: selectedEmoji
                )
                
                print("✅ Profile created: \(profile.displayName)")
                
                // Start location sharing
                await LocationSharingManager.shared.startSharing()
                
                isCreating = false
                dismiss()
            } catch {
                print("❌ Failed to create profile: \(error.localizedDescription)")
                isCreating = false
                // Show error to user
            }
        }
    }
}

#Preview {
    SignInView()
}

