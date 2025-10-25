//
//  CameraManager.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import Foundation
import AVFoundation
import UIKit
import Combine

@MainActor
class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    @Published var isSessionActive = false
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var livenessScore: Double = 0.0
    @Published var errorMessage: String?
    
    // Camera session
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Liveness detection
    private var livenessDetector: LivenessDetector
    private var frameAnalyzer: FrameAnalyzer
    private var livenessTimer: Timer?
    
    // Recording
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentSession: CameraSession?
    
    // Permissions
    private var permissionStatus: AVAuthorizationStatus = .notDetermined
    
    private override init() {
        self.livenessDetector = LivenessDetector()
        self.frameAnalyzer = FrameAnalyzer()
        super.init()
        setupCamera()
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        // Configure session
        captureSession.sessionPreset = .medium
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            errorMessage = "Failed to create video input"
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Add video output for recording
        videoOutput = AVCaptureMovieFileOutput()
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Add photo output for still images
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Configure outputs
        configureOutputs()
    }
    
    private func configureOutputs() {
        guard let videoOutput = videoOutput,
              let photoOutput = photoOutput else { return }
        
        // Configure video output
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
        
        // Configure photo output
        photoOutput.isHighResolutionCaptureEnabled = true
    }
    
    // MARK: - Session Management
    func startSession(for purpose: CameraPurpose, duration: TimeInterval = 10.0) async throws -> CameraSession {
        // Check permissions
        try await requestCameraPermission()
        
        guard let captureSession = captureSession else {
            throw CameraError.sessionNotAvailable
        }
        
        // Create session
        let session = CameraSession(
            id: UUID(),
            purpose: purpose,
            duration: duration,
            startTime: Date(),
            endTime: nil,
            isCompleted: false
        )
        
        currentSession = session
        
        // Start capture session
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
        
        isSessionActive = true
        
        // Start liveness detection
        startLivenessDetection()
        
        // Start recording timer
        startRecordingTimer(duration: duration)
        
        return session
    }
    
    func stopSession() {
        guard let captureSession = captureSession else { return }
        
        // Stop recording
        if isRecording {
            videoOutput?.stopRecording()
        }
        
        // Stop timers
        livenessTimer?.invalidate()
        livenessTimer = nil
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Stop capture session
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        isSessionActive = false
        isRecording = false
        recordingDuration = 0
        livenessScore = 0.0
        
        currentSession = nil
    }
    
    // MARK: - Recording
    func startRecording() async throws {
        guard let videoOutput = videoOutput,
              let captureSession = captureSession,
              captureSession.isRunning else {
            throw CameraError.sessionNotActive
        }
        
        // Create output URL
        let outputURL = createOutputURL()
        
        // Start recording
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        isRecording = true
        recordingStartTime = Date()
        
        print("Recording started: \(outputURL)")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        videoOutput?.stopRecording()
        isRecording = false
        recordingStartTime = nil
    }
    
    private func createOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "proof_\(UUID().uuidString).mov"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    // MARK: - Photo Capture
    func capturePhoto() async throws -> URL {
        guard let photoOutput = photoOutput,
              let captureSession = captureSession,
              captureSession.isRunning else {
            throw CameraError.sessionNotActive
        }
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        
        return try await withCheckedThrowingContinuation { continuation in
            photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate { result in
                continuation.resume(with: result)
            })
        }
    }
    
    // MARK: - Liveness Detection
    private func startLivenessDetection() {
        livenessTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateLivenessScore()
            }
        }
    }
    
    private func updateLivenessScore() async {
        // Simulate liveness detection
        // In a real implementation, this would analyze camera frames
        let newScore = await livenessDetector.analyzeFrame()
        livenessScore = newScore
    }
    
    // MARK: - Recording Timer
    private func startRecordingTimer(duration: TimeInterval) {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let startTime = self.recordingStartTime {
                    self.recordingDuration = Date().timeIntervalSince(startTime)
                    
                    // Auto-stop if duration exceeded
                    if self.recordingDuration >= duration {
                        self.stopRecording()
                        timer.invalidate()
                    }
                }
            }
        }
    }
    
    // MARK: - Session Verification
    func verifySession(_ session: CameraSession) async throws -> CameraVerification {
        guard let currentSession = currentSession,
              currentSession.id == session.id else {
            throw CameraError.invalidSession
        }
        
        // Check liveness score
        let livenessPassed = livenessScore >= 0.7
        
        // Check recording duration
        let durationPassed = recordingDuration >= session.duration * 0.8 // 80% of required duration
        
        // Check for suspicious activity
        let suspiciousActivity = await detectSuspiciousActivity()
        
        let isVerified = livenessPassed && durationPassed && !suspiciousActivity
        let confidenceScore = calculateConfidenceScore(
            liveness: livenessScore,
            duration: recordingDuration,
            requiredDuration: session.duration,
            suspiciousActivity: suspiciousActivity
        )
        
        return CameraVerification(
            isVerified: isVerified,
            confidenceScore: confidenceScore,
            livenessScore: livenessScore,
            duration: recordingDuration,
            suspiciousActivity: suspiciousActivity,
            timestamp: Date()
        )
    }
    
    private func detectSuspiciousActivity() async -> Bool {
        // Check for rapid movements, static images, etc.
        // This would be implemented with computer vision
        return false
    }
    
    private func calculateConfidenceScore(
        liveness: Double,
        duration: TimeInterval,
        requiredDuration: TimeInterval,
        suspiciousActivity: Bool
    ) -> Double {
        var score: Double = 0.0
        
        // Liveness factor (40% weight)
        score += liveness * 0.4
        
        // Duration factor (30% weight)
        let durationFactor = min(duration / requiredDuration, 1.0)
        score += durationFactor * 0.3
        
        // Suspicious activity factor (30% weight)
        let activityFactor = suspiciousActivity ? 0.0 : 1.0
        score += activityFactor * 0.3
        
        return min(score, 1.0)
    }
    
    // MARK: - Permissions
    private func requestCameraPermission() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            permissionStatus = .authorized
            return
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                permissionStatus = .authorized
            } else {
                permissionStatus = .denied
                throw CameraError.permissionDenied
            }
            
        case .denied, .restricted:
            permissionStatus = status
            throw CameraError.permissionDenied
            
        @unknown default:
            throw CameraError.permissionDenied
        }
    }
    
    // MARK: - Preview Layer
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let captureSession = captureSession else { return nil }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        self.previewLayer = previewLayer
        return previewLayer
    }
    
    // MARK: - Cleanup
    func cleanupSession() {
        // Delete temporary files
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let proofFiles = files.filter { $0.lastPathComponent.hasPrefix("proof_") }
            
            for file in proofFiles {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Error cleaning up proof files: \(error)")
        }
    }
    
    // MARK: - Analytics
    func getLivenessScore() -> Double {
        return livenessScore
    }
    
    func getSessionStats() -> CameraSessionStats {
        return CameraSessionStats(
            totalSessions: 1, // This would be tracked over time
            averageLivenessScore: livenessScore,
            averageDuration: recordingDuration,
            successRate: livenessScore >= 0.7 ? 1.0 : 0.0
        )
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
            errorMessage = "Recording failed: \(error.localizedDescription)"
        } else {
            print("Recording completed: \(outputFileURL)")
        }
        
        isRecording = false
        recordingStartTime = nil
    }
}

// MARK: - Supporting Types
enum CameraPurpose: String, CaseIterable {
    case challenge = "challenge"
    case forfeit = "forfeit"
    case hangout = "hangout"
    case antiCheat = "anti_cheat"
    
    var displayName: String {
        switch self {
        case .challenge: return "Challenge Proof"
        case .forfeit: return "Forfeit Proof"
        case .hangout: return "Hangout Proof"
        case .antiCheat: return "Anti-Cheat Verification"
        }
    }
}

struct CameraSession {
    let id: UUID
    let purpose: CameraPurpose
    let duration: TimeInterval
    let startTime: Date
    var endTime: Date?
    var isCompleted: Bool
}

struct CameraVerification {
    let isVerified: Bool
    let confidenceScore: Double
    let livenessScore: Double
    let duration: TimeInterval
    let suspiciousActivity: Bool
    let timestamp: Date
}

struct CameraSessionStats {
    let totalSessions: Int
    let averageLivenessScore: Double
    let averageDuration: TimeInterval
    let successRate: Double
}

enum CameraError: LocalizedError {
    case sessionNotAvailable
    case sessionNotActive
    case invalidSession
    case permissionDenied
    case recordingFailed(String)
    case photoCaptureFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "Camera session not available"
        case .sessionNotActive:
            return "Camera session not active"
        case .invalidSession:
            return "Invalid camera session"
        case .permissionDenied:
            return "Camera permission denied"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .photoCaptureFailed(let message):
            return "Photo capture failed: \(message)"
        }
    }
}

// MARK: - Liveness Detection
class LivenessDetector {
    func analyzeFrame() async -> Double {
        // Simulate liveness detection
        // In a real implementation, this would use computer vision
        // to detect eye blinks, head movements, etc.
        
        let randomScore = Double.random(in: 0.6...1.0)
        return randomScore
    }
}

// MARK: - Frame Analysis
class FrameAnalyzer {
    func analyzeFrame(_ frame: CVPixelBuffer) -> FrameAnalysis {
        // Simulate frame analysis
        // In a real implementation, this would analyze the frame
        // for faces, movements, etc.
        
        return FrameAnalysis(
            hasFace: true,
            isMoving: true,
            brightness: 0.8,
            quality: 0.9
        )
    }
}

struct FrameAnalysis {
    let hasFace: Bool
    let isMoving: Bool
    let brightness: Double
    let quality: Double
}

// MARK: - Photo Capture Delegate
class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<URL, Error>) -> Void
    
    init(completion: @escaping (Result<URL, Error>) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.photoCaptureFailed("No image data")))
            return
        }
        
        // Save to temporary file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "proof_\(UUID().uuidString).jpg"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            completion(.success(fileURL))
        } catch {
            completion(.failure(error))
        }
    }
}
