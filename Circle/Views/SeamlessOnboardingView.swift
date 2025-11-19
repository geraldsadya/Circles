//
//  SeamlessOnboardingView.swift
//  Circle
//
//  One-time setup - just permissions (like Find My)
//

import SwiftUI

struct SeamlessOnboardingView: View {
    @StateObject private var authManager = SeamlessAuthManager.shared
    @StateObject private var contactDiscovery = ContactDiscoveryManager.shared
    @StateObject private var locationManager = SeamlessLocationManager.shared
    
    @State private var currentStep = 0
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App logo
                VStack(spacing: 16) {
                    Text("⭕️")
                        .font(.system(size: 100))
                    
                    Text("Circle")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Step indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Content based on step
                Group {
                    switch currentStep {
                    case 0:
                        step1Welcome
                    case 1:
                        step2Permissions
                    case 2:
                        step3Setup
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Continue button
                Button(action: nextStep) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep == 2 ? "Get Started" : "Continue")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .disabled(isProcessing)
                
                Spacer()
                    .frame(height: 60)
            }
        }
    }
    
    // MARK: - Steps
    private var step1Welcome: some View {
        VStack(spacing: 16) {
            Text("Welcome to Circle")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Stay connected with friends in real-time. See where they are, hang out together, and complete challenges.")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }
    
    private var step2Permissions: some View {
        VStack(spacing: 24) {
            Text("We'll need a few permissions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 16) {
                PermissionRow(
                    icon: "location.fill",
                    title: "Location",
                    description: "Share your location with friends"
                )
                
                PermissionRow(
                    icon: "person.2.fill",
                    title: "Contacts",
                    description: "Find friends who have Circle"
                )
                
                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Get notified about hangouts"
                )
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    private var step3Setup: some View {
        VStack(spacing: 16) {
            if isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                    .padding()
                
                Text("Setting up your account...")
                    .font(.body)
                    .foregroundColor(.white)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You're ready to connect with friends")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Actions
    private func nextStep() {
        if currentStep < 2 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Final step - do setup
            setupApp()
        }
    }
    
    private func setupApp() {
        isProcessing = true
        
        Task {
            // Auto sign in with iCloud
            await authManager.automaticSignIn()
            
            // Request location permission
            await locationManager.autoStart()
            
            // Discover friends from contacts
            try? await contactDiscovery.discoverFriendsFromContacts()
            
            isProcessing = false
            
            // Mark onboarding complete
            UserDefaults.standard.set(true, forKey: "onboarding_complete")
            authManager.isReady = true
        }
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

#Preview {
    SeamlessOnboardingView()
}

