//
//  OnboardingFlow.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreLocation

struct OnboardingFlow: View {
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var currentStep = 0
    @State private var showingPermissionAlert = false
    @State private var permissionDenied = false
    
    private let totalSteps = 4
    
    var body: some View {
        ZStack {
            // Apple-style background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep()
                        .tag(0)
                    
                    ValuePropositionStep()
                        .tag(1)
                    
                    PermissionsStep()
                        .tag(2)
                    
                    CompleteStep()
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Navigation
                navigationButtons
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Skip", role: .cancel) {
                handlePermissionSkip()
            }
        } message: {
            Text("Circle needs this permission to verify your challenges. You can enable it later in Settings.")
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.blue : Color(.systemGray5))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button(currentStep == totalSteps - 1 ? "Get Started" : "Continue") {
                handleNextStep()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Step Handlers
    private func handleNextStep() {
        if currentStep == 2 { // Permissions step
            requestPermissions()
        } else if currentStep == totalSteps - 1 {
            completeOnboarding()
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    private func requestPermissions() {
        Task {
            let granted = await onboardingManager.requestPermission(.location)
            if granted {
                // Try to upgrade to Always
                let alwaysGranted = await onboardingManager.requestAlwaysLocationPermission()
                if !alwaysGranted {
                    permissionDenied = true
                }
            } else {
                permissionDenied = true
            }
            
            await MainActor.run {
                withAnimation {
                    currentStep += 1
                }
            }
        }
    }
    
    private func handlePermissionSkip() {
        withAnimation {
            currentStep += 1
        }
    }
    
    private func completeOnboarding() {
        onboardingManager.completeOnboarding()
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Icon
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 120, height: 120)
                .overlay(
                    Text("C")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 16) {
                Text("Welcome to Circle")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Social life, verified.")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Value Proposition Step
struct ValuePropositionStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                FeatureCard(
                    icon: "target",
                    title: "Prove It",
                    description: "Turn what you say you'll do into verified proof using your iPhone's sensors"
                )
                
                FeatureCard(
                    icon: "person.3.fill",
                    title: "Stay Accountable",
                    description: "Create circles with friends and compete on weekly leaderboards"
                )
                
                FeatureCard(
                    icon: "location.fill",
                    title: "Real Hangouts",
                    description: "Automatically detect when you're actually hanging out with friends"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Permissions Step
struct PermissionsStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Text("Enable Permissions")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Circle needs a few permissions to verify your challenges and detect hangouts with friends.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 20) {
                PermissionCard(
                    icon: "location.fill",
                    title: "Location",
                    description: "Detect hangouts and verify location-based challenges",
                    isRequired: true
                )
                
                PermissionCard(
                    icon: "figure.walk",
                    title: "Motion & Fitness",
                    description: "Track steps and verify fitness challenges",
                    isRequired: true
                )
                
                PermissionCard(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Remind you about challenges and forfeits",
                    isRequired: false
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Complete Step
struct CompleteStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Start creating circles, setting challenges, and proving it with your friends.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Supporting Views
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isRequired: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if isRequired {
                        Text("Required")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    OnboardingFlow()
        .environmentObject(OnboardingManager.shared)
        .environmentObject(AuthenticationManager.shared)
}
