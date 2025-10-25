//
//  ProofView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import AVFoundation

struct ProofView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    
    let purpose: CameraPurpose
    let duration: TimeInterval
    let onCompletion: (CameraVerification) -> Void
    
    @State private var currentStep: ProofStep = .instructions
    @State private var countdown: Int = 3
    @State private var isCountingDown = false
    @State private var recordingProgress: Double = 0.0
    @State private var livenessProgress: Double = 0.0
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content
                contentSection
                
                // Controls
                controlsSection
            }
        }
        .onAppear {
            setupProof()
        }
        .onDisappear {
            cleanupProof()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
                dismiss()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white)
            .font(.headline)
            
            Spacer()
            
            Text(purpose.displayName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for symmetry
            Text("Cancel")
                .font(.headline)
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        Group {
            switch currentStep {
            case .instructions:
                instructionsView
            case .countdown:
                countdownView
            case .recording:
                recordingView
            case .processing:
                processingView
            case .success:
                successView
            case .failure:
                failureView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Instructions View
    private var instructionsView: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: purpose.icon)
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            // Title
            Text("Ready to Prove It?")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Instructions
            VStack(spacing: 16) {
                Text("Follow these steps:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(
                        icon: "1.circle.fill",
                        text: "Hold your phone steady",
                        isCompleted: false
                    )
                    
                    InstructionRow(
                        icon: "2.circle.fill",
                        text: "Look at the camera",
                        isCompleted: false
                    )
                    
                    InstructionRow(
                        icon: "3.circle.fill",
                        text: "Wait for the countdown",
                        isCompleted: false
                    )
                    
                    InstructionRow(
                        icon: "4.circle.fill",
                        text: "Stay in frame for \(Int(duration)) seconds",
                        isCompleted: false
                    )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 40)
    }
    
    // MARK: - Countdown View
    private var countdownView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Countdown Circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(countdown) / 3.0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: countdown)
                
                Text("\(countdown)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Instructions
            Text("Get ready...")
                .font(.title2)
                .foregroundColor(.white)
                .opacity(0.8)
            
            Spacer()
        }
    }
    
    // MARK: - Recording View
    private var recordingView: some View {
        VStack(spacing: 30) {
            // Camera Preview
            if let previewLayer = cameraManager.createPreviewLayer() {
                CameraPreviewView(previewLayer: previewLayer)
                    .frame(height: 400)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
            
            // Progress Indicators
            VStack(spacing: 20) {
                // Recording Progress
                VStack(spacing: 8) {
                    HStack {
                        Text("Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(recordingProgress * duration))s")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    ProgressView(value: recordingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .scaleEffect(y: 2)
                }
                
                // Liveness Progress
                VStack(spacing: 8) {
                    HStack {
                        Text("Liveness")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(livenessProgress * 100))%")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    ProgressView(value: livenessProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(y: 2)
                }
            }
            
            // Instructions
            Text("Stay in frame and look at the camera")
                .font(.title3)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(0.8)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Processing Animation
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(isProcessing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isProcessing)
            }
            
            Text("Processing...")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Verifying your proof")
                .font(.body)
                .foregroundColor(.white)
                .opacity(0.8)
            
            Spacer()
        }
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Proof Verified!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Your proof has been successfully verified")
                .font(.body)
                .foregroundColor(.white)
                .opacity(0.8)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Failure View
    private var failureView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Failure Icon
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "xmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Verification Failed")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Please try again and make sure to follow the instructions")
                .font(.body)
                .foregroundColor(.white)
                .opacity(0.8)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 20) {
            // Action Button
            Button(action: handleActionButtonTap) {
                Text(actionButtonTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(actionButtonColor)
                    .cornerRadius(12)
            }
            .disabled(!isActionButtonEnabled)
            
            // Secondary Button
            if currentStep == .failure {
                Button("Try Again") {
                    resetProof()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Views
    private struct InstructionRow: View {
        let icon: String
        let text: String
        let isCompleted: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isCompleted ? .green : .white)
                    .font(.title2)
                
                Text(text)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
            }
        }
    }
    
    private struct CameraPreviewView: UIViewRepresentable {
        let previewLayer: AVCaptureVideoPreviewLayer
        
        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            return view
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            previewLayer.frame = uiView.bounds
        }
    }
    
    // MARK: - Helper Methods
    private func setupProof() {
        Task {
            do {
                _ = try await cameraManager.startSession(for: purpose, duration: duration)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func cleanupProof() {
        cameraManager.stopSession()
        cameraManager.cleanupSession()
    }
    
    private func handleActionButtonTap() {
        switch currentStep {
        case .instructions:
            startCountdown()
        case .countdown:
            // Countdown is automatic
            break
        case .recording:
            stopRecording()
        case .processing:
            // Processing is automatic
            break
        case .success:
            dismiss()
        case .failure:
            resetProof()
        }
    }
    
    private func startCountdown() {
        currentStep = .countdown
        isCountingDown = true
        countdown = 3
        
        hapticManager.playHaptic(.medium)
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            countdown -= 1
            
            if countdown > 0 {
                hapticManager.playHaptic(.light)
            } else {
                timer.invalidate()
                startRecording()
            }
        }
    }
    
    private func startRecording() {
        currentStep = .recording
        isCountingDown = false
        
        hapticManager.playHaptic(.heavy)
        
        Task {
            do {
                try await cameraManager.startRecording()
                startProgressTracking()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func stopRecording() {
        cameraManager.stopRecording()
        currentStep = .processing
        isProcessing = true
        
        hapticManager.playHaptic(.medium)
        
        Task {
            do {
                let verification = try await cameraManager.verifySession(
                    CameraSession(
                        id: UUID(),
                        purpose: purpose,
                        duration: duration,
                        startTime: Date(),
                        endTime: nil,
                        isCompleted: false
                    )
                )
                
                await MainActor.run {
                    isProcessing = false
                    
                    if verification.isVerified {
                        currentStep = .success
                        hapticManager.playHaptic(.success)
                    } else {
                        currentStep = .failure
                        hapticManager.playHaptic(.error)
                    }
                    
                    onCompletion(verification)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func startProgressTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            recordingProgress = min(cameraManager.recordingDuration / duration, 1.0)
            livenessProgress = cameraManager.livenessScore
            
            if recordingProgress >= 1.0 {
                timer.invalidate()
            }
        }
    }
    
    private func resetProof() {
        currentStep = .instructions
        countdown = 3
        isCountingDown = false
        recordingProgress = 0.0
        livenessProgress = 0.0
        isProcessing = false
        
        hapticManager.playHaptic(.light)
    }
    
    // MARK: - Computed Properties
    private var actionButtonTitle: String {
        switch currentStep {
        case .instructions:
            return "Start Proof"
        case .countdown:
            return "Get Ready..."
        case .recording:
            return "Stop Recording"
        case .processing:
            return "Processing..."
        case .success:
            return "Done"
        case .failure:
            return "Try Again"
        }
    }
    
    private var actionButtonColor: Color {
        switch currentStep {
        case .instructions, .countdown:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .gray
        case .success:
            return .green
        case .failure:
            return .orange
        }
    }
    
    private var isActionButtonEnabled: Bool {
        switch currentStep {
        case .instructions, .recording, .success, .failure:
            return true
        case .countdown, .processing:
            return false
        }
    }
}

// MARK: - Proof Steps
enum ProofStep {
    case instructions
    case countdown
    case recording
    case processing
    case success
    case failure
}

// MARK: - Haptic Manager
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    private init() {}
    
    func playHaptic(_ type: HapticType) {
        switch type {
        case .light:
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        case .medium:
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        case .heavy:
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
        case .success:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
        case .error:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
            
        case .warning:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        }
    }
}

enum HapticType {
    case light
    case medium
    case heavy
    case success
    case error
    case warning
}

// MARK: - Extensions
extension CameraPurpose {
    var icon: String {
        switch self {
        case .challenge: return "checkmark.circle.fill"
        case .forfeit: return "camera.fill"
        case .hangout: return "person.3.fill"
        case .antiCheat: return "shield.fill"
        }
    }
}

#Preview {
    ProofView(
        purpose: .challenge,
        duration: 10.0,
        onCompletion: { _ in }
    )
}
