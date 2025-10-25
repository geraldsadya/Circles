//
//  ProofModalView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import AVFoundation
import CoreData

struct ProofModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var cameraManager = CameraManager.shared
    
    let challenge: Challenge
    
    @State private var currentStep: ProofStep = .prompt
    @State private var showingPermissionAlert = false
    @State private var isCapturing = false
    @State private var isVerifying = false
    @State private var verificationResult: ProofResult?
    @State private var errorMessage: String?
    
    enum ProofStep {
        case prompt
        case capture
        case verifying
        case success
        case failure
    }
    
    enum ProofResult {
        case success(Proof)
        case failure(String)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressIndicator
                    
                    // Content
                    Group {
                        switch currentStep {
                        case .prompt:
                            promptStep
                        case .capture:
                            captureStep
                        case .verifying:
                            verifyingStep
                        case .success:
                            successStep
                        case .failure:
                            failureStep
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    // Action buttons
                    actionButtons
                }
            }
            .navigationTitle("Proof Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Circle needs camera access to verify your challenge. Please enable it in Settings.")
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { step in
                Circle()
                    .fill(step <= currentStepIndex ? Color.blue : Color(.systemGray5))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Prompt Step
    private var promptStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 16) {
                    Text("Prove Your Challenge")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(challenge.title ?? "Untitled Challenge")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Take a photo to verify you've completed this challenge")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Capture Step
    private var captureStep: some View {
        VStack(spacing: 20) {
            // Camera preview placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 300)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("Camera Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Camera implementation coming soon...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                )
            
            VStack(spacing: 12) {
                Text("Position yourself in frame")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Make sure you're clearly visible and the photo shows you completing the challenge")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Verifying Step
    private var verifyingStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                VStack(spacing: 16) {
                    Text("Verifying Your Proof")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Analyzing your photo to confirm challenge completion...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Success Step
    private var successStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 16) {
                    Text("Challenge Verified!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Great job! You've successfully completed this challenge.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    if case .success(let proof) = verificationResult {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("+\(proof.pointsAwarded) points earned")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.yellow.opacity(0.1))
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Failure Step
    private var failureStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Verification Failed")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if case .failure(let error) = verificationResult {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case .prompt:
                Button("Start Camera") {
                    startCapture()
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
                
            case .capture:
                Button("Take Photo") {
                    capturePhoto()
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
                .disabled(isCapturing)
                
            case .verifying:
                EmptyView()
                
            case .success:
                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green)
                )
                
            case .failure:
                VStack(spacing: 12) {
                    Button("Try Again") {
                        currentStep = .capture
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
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Computed Properties
    private var currentStepIndex: Int {
        switch currentStep {
        case .prompt: return 0
        case .capture: return 1
        case .verifying: return 2
        case .success, .failure: return 3
        }
    }
    
    // MARK: - Methods
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            showingPermissionAlert = true
        }
    }
    
    private func startCapture() {
        currentStep = .capture
    }
    
    private func capturePhoto() {
        isCapturing = true
        
        // Simulate photo capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isCapturing = false
            currentStep = .verifying
            
            // Simulate verification
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                verifyProof()
            }
        }
    }
    
    private func verifyProof() {
        isVerifying = true
        
        // Simulate verification process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isVerifying = false
            
            // Create proof in Core Data
            let proof = Proof.create(
                in: viewContext,
                isVerified: true,
                confidenceScore: 0.95,
                verificationMethod: "camera"
            )
            
            proof.challenge = challenge
            proof.user = authManager.currentUser
            proof.notes = "Camera verification completed"
            proof.pointsAwarded = challenge.pointsReward
            
            do {
                try viewContext.save()
                verificationResult = .success(proof)
                currentStep = .success
            } catch {
                verificationResult = .failure("Failed to save proof: \(error.localizedDescription)")
                currentStep = .failure
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Preview
#Preview {
    ProofModalView(challenge: Challenge())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
