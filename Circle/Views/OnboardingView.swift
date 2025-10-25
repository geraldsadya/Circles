//
//  OnboardingView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showingPermissionAlert = false
    @State private var currentPermission: PermissionType?
    
    var body: some View {
        ZStack {
            // Apple-style background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(onboardingManager.currentStep), total: 4)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                
                Spacer()
                
                // Content based on current step
                Group {
                    switch onboardingManager.currentStep {
                    case 0:
                        WelcomeStep()
                    case 1:
                        LocationPermissionStep()
                    case 2:
                        MotionPermissionStep()
                    case 3:
                        NotificationPermissionStep()
                    case 4:
                        CompleteStep()
                    default:
                        WelcomeStep()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: onboardingManager.currentStep)
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if onboardingManager.currentStep > 0 {
                        Button("Back") {
                            onboardingManager.currentStep -= 1
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(onboardingManager.currentStep == 4 ? "Get Started" : "Continue") {
                        handleContinue()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue)
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable \(currentPermission?.title ?? "this permission") in Settings to continue.")
        }
    }
    
    private func handleContinue() {
        switch onboardingManager.currentStep {
        case 0:
            onboardingManager.nextStep()
        case 1:
            requestLocationPermission()
        case 2:
            requestMotionPermission()
        case 3:
            requestNotificationPermission()
        case 4:
            onboardingManager.completeOnboarding()
        default:
            break
        }
    }
    
    private func requestLocationPermission() {
        onboardingManager.requestLocationPermission()
        onboardingManager.nextStep()
    }
    
    private func requestMotionPermission() {
        onboardingManager.requestMotionPermission()
        onboardingManager.nextStep()
    }
    
    private func requestNotificationPermission() {
        onboardingManager.requestNotificationPermission()
        onboardingManager.nextStep()
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Onboarding Steps
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text("C")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 12) {
                Text("Welcome to Circle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Turn your goals into proof with friends who actually do things together.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal, 32)
    }
}

struct LocationPermissionStep: View {
    var body: some View {
        PermissionStepView(
            permission: .locationWhenInUse,
            title: "Location Access",
            subtitle: "Verify your gym visits and detect hangouts with friends",
            icon: "location.fill"
        )
    }
}

struct MotionPermissionStep: View {
    var body: some View {
        PermissionStepView(
            permission: .motion,
            title: "Motion & Fitness",
            subtitle: "Track your steps and workouts automatically",
            icon: "figure.walk"
        )
    }
}

struct NotificationPermissionStep: View {
    var body: some View {
        PermissionStepView(
            permission: .notifications,
            title: "Notifications",
            subtitle: "Get reminders for challenges and hangout alerts",
            icon: "bell.fill"
        )
    }
}

struct CompleteStep: View {
    var body: some View {
        VStack(spacing: 24) {
            // Success animation
            Circle()
                .fill(.green)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                )
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: true)
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Circle is ready to help you build better habits with your friends.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }
}

struct PermissionStepView: View {
    let permission: PermissionType
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Permission icon
            Image(systemName: icon)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(.blue.opacity(0.1))
                )
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                Text(permission.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(OnboardingManager())
}
