//
//  ErrorStatesView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import Network

struct ErrorStatesView: View {
    // This is a collection of reusable error states
    // Individual views can use these components as needed
}

// MARK: - Network Error States
struct NetworkErrorView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Internet Connection")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Check your internet connection and try again")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
        }
        .padding(.vertical, 40)
    }
}

// MARK: - CloudKit Error States
struct CloudKitErrorView: View {
    let error: CloudKitError
    let onRetry: () -> Void
    
    enum CloudKitError {
        case notSignedIn
        case quotaExceeded
        case serviceUnavailable
        case unknown
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: errorIcon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(errorTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(errorActionTitle) {
                onRetry()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
        }
        .padding(.vertical, 40)
    }
    
    private var errorIcon: String {
        switch error {
        case .notSignedIn: return "person.crop.circle.badge.exclamationmark"
        case .quotaExceeded: return "externaldrive.fill.trianglebadge.exclamationmark"
        case .serviceUnavailable: return "cloud.slash"
        case .unknown: return "exclamationmark.triangle"
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .notSignedIn: return "Not Signed In to iCloud"
        case .quotaExceeded: return "Storage Quota Exceeded"
        case .serviceUnavailable: return "iCloud Service Unavailable"
        case .unknown: return "Sync Error"
        }
    }
    
    private var errorMessage: String {
        switch error {
        case .notSignedIn: return "Please sign in to iCloud in Settings to sync your data across devices"
        case .quotaExceeded: return "Your iCloud storage is full. Please free up space or upgrade your storage plan"
        case .serviceUnavailable: return "iCloud services are temporarily unavailable. Please try again later"
        case .unknown: return "An error occurred while syncing your data. Please try again"
        }
    }
    
    private var errorActionTitle: String {
        switch error {
        case .notSignedIn: return "Open Settings"
        case .quotaExceeded: return "Manage Storage"
        case .serviceUnavailable: return "Try Again"
        case .unknown: return "Retry"
        }
    }
}

// MARK: - Permission Error States
struct PermissionErrorView: View {
    let permission: PermissionType
    let onOpenSettings: () -> Void
    let onSkip: () -> Void
    
    enum PermissionType {
        case location
        case camera
        case motion
        case notifications
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: permissionIcon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(permissionTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(permissionMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Button("Open Settings") {
                    onOpenSettings()
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
                
                Button("Skip for Now") {
                    onSkip()
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
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
    
    private var permissionIcon: String {
        switch permission {
        case .location: return "location.slash"
        case .camera: return "camera.fill"
        case .motion: return "figure.walk"
        case .notifications: return "bell.slash"
        }
    }
    
    private var permissionTitle: String {
        switch permission {
        case .location: return "Location Permission Denied"
        case .camera: return "Camera Permission Denied"
        case .motion: return "Motion Permission Denied"
        case .notifications: return "Notification Permission Denied"
        }
    }
    
    private var permissionMessage: String {
        switch permission {
        case .location: return "Circle needs location access to detect hangouts and verify location-based challenges. You can enable it in Settings."
        case .camera: return "Circle needs camera access to verify challenges with photos. You can enable it in Settings."
        case .motion: return "Circle needs motion access to track steps and verify fitness challenges. You can enable it in Settings."
        case .notifications: return "Circle needs notification access to remind you about challenges. You can enable it in Settings."
        }
    }
}

// MARK: - Empty States
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Loading States
struct LoadingStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Low Power Mode Warning
struct LowPowerModeWarning: View {
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "battery.25")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Low Power Mode Active")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Location tracking reduced to save battery")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Background Refresh Warning
struct BackgroundRefreshWarning: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Background Refresh Disabled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Enable in Settings for automatic challenge verification")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Settings") {
                onOpenSettings()
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Approximate Location Warning
struct ApproximateLocationWarning: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.circle")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Using Approximate Location")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Enable precise location for better hangout detection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Settings") {
                onOpenSettings()
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        NetworkErrorView(onRetry: {})
        CloudKitErrorView(error: .notSignedIn, onRetry: {})
        PermissionErrorView(permission: .location, onOpenSettings: {}, onSkip: {})
        EmptyStateView(
            icon: "target",
            title: "No Challenges",
            subtitle: "Create your first challenge to get started",
            actionTitle: "Create Challenge",
            action: {}
        )
    }
    .padding()
}
