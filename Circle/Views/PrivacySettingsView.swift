//
//  PrivacySettingsView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var dataExportManager = DataExportManager.shared
    
    @State private var showingDeleteConfirmation = false
    @State private var showingExportConfirmation = false
    @State private var isExporting = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            List {
                // Data Summary Section
                dataSummarySection
                
                // Permissions Section
                permissionsSection
                
                // Location Settings Section
                locationSettingsSection
                
                // Data Management Section
                dataManagementSection
                
                // Privacy Policy Section
                privacyPolicySection
            }
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your data including challenges, proofs, and hangouts. This action cannot be undone.")
            }
            .alert("Export Data", isPresented: $showingExportConfirmation) {
                Button("Export") {
                    exportData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will create a JSON file with all your data that you can download and review.")
            }
        }
    }
    
    // MARK: - Data Summary Section
    private var dataSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("What Data We Collect")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    DataTypeRow(
                        icon: "location.fill",
                        title: "Location Data",
                        description: "Used to verify location-based challenges and detect hangouts with friends",
                        isShared: true
                    )
                    
                    DataTypeRow(
                        icon: "figure.walk",
                        title: "Motion & Fitness",
                        description: "Step count and activity data to verify fitness challenges",
                        isShared: false
                    )
                    
                    DataTypeRow(
                        icon: "camera.fill",
                        title: "Camera Photos",
                        description: "Live photos for challenge verification (deleted immediately after verification)",
                        isShared: false
                    )
                    
                    DataTypeRow(
                        icon: "person.3.fill",
                        title: "Social Data",
                        description: "Challenge results, points, and hangout sessions shared with your circles",
                        isShared: true
                    )
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Data Collection")
        } footer: {
            Text("All data is processed on your device. Only verification results are shared with friends, never raw sensor data.")
        }
    }
    
    // MARK: - Permissions Section
    private var permissionsSection: some View {
        Section {
            VStack(spacing: 12) {
                PermissionStatusRow(
                    title: "Location Services",
                    status: permissionsManager.locationWhenInUse ? "Granted" : "Denied",
                    isGranted: permissionsManager.locationWhenInUse,
                    action: {
                        if permissionsManager.locationWhenInUse {
                            openAppSettings()
                        } else {
                            requestLocationPermission()
                        }
                    }
                )
                
                PermissionStatusRow(
                    title: "Motion & Fitness",
                    status: permissionsManager.motion ? "Granted" : "Denied",
                    isGranted: permissionsManager.motion,
                    action: {
                        if permissionsManager.motion {
                            openAppSettings()
                        } else {
                            requestMotionPermission()
                        }
                    }
                )
                
                PermissionStatusRow(
                    title: "Camera",
                    status: permissionsManager.camera ? "Granted" : "Denied",
                    isGranted: permissionsManager.camera,
                    action: {
                        if permissionsManager.camera {
                            openAppSettings()
                        } else {
                            requestCameraPermission()
                        }
                    }
                )
                
                PermissionStatusRow(
                    title: "Notifications",
                    status: permissionsManager.notifications ? "Granted" : "Denied",
                    isGranted: permissionsManager.notifications,
                    action: {
                        if permissionsManager.notifications {
                            openAppSettings()
                        } else {
                            requestNotificationPermission()
                        }
                    }
                )
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Tap to manage permissions in Settings")
        }
    }
    
    // MARK: - Location Settings Section
    private var locationSettingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Location Accuracy")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Precise location is required for accurate hangout detection and location-based challenges. You can change this per circle.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Toggle("Use Precise Location", isOn: .constant(true))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(.vertical, 8)
        } header: {
            Text("Location Settings")
        } footer: {
            Text("Precise location provides better accuracy for hangout detection and geofence challenges.")
        }
    }
    
    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        Section {
            VStack(spacing: 12) {
                Button(action: { showingExportConfirmation = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        Text("Export My Data")
                            .foregroundColor(.primary)
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isExporting)
                
                Button(action: { showingDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                        Text("Delete All Data")
                            .foregroundColor(.red)
                        Spacer()
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isDeleting)
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Export your data to review what we've collected, or delete everything to start fresh.")
        }
    }
    
    // MARK: - Privacy Policy Section
    private var privacyPolicySection: some View {
        Section {
            VStack(spacing: 12) {
                Button(action: { openPrivacyPolicy() }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        Text("Privacy Policy")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { openTermsOfService() }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        Text("Terms of Service")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { contactSupport() }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Contact Support")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Legal & Support")
        }
    }
    
    // MARK: - Supporting Views
    struct DataTypeRow: View {
        let icon: String
        let title: String
        let description: String
        let isShared: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if isShared {
                            Text("Shared")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange.opacity(0.1))
                                )
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    struct PermissionStatusRow: View {
        let title: String
        let status: String
        let isGranted: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(status)
                            .font(.caption)
                            .foregroundColor(isGranted ? .green : .red)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Methods
    private func requestLocationPermission() {
        Task {
            await permissionsManager.requestPermission(.location)
        }
    }
    
    private func requestMotionPermission() {
        Task {
            await permissionsManager.requestPermission(.motion)
        }
    }
    
    private func requestCameraPermission() {
        Task {
            await permissionsManager.requestPermission(.camera)
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            await permissionsManager.requestPermission(.notifications)
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let exportData = try await dataExportManager.exportUserData()
                // Handle export data (save to file, share, etc.)
                print("Data exported successfully")
            } catch {
                print("Export failed: \(error)")
            }
            
            await MainActor.run {
                isExporting = false
            }
        }
    }
    
    private func deleteAllData() {
        isDeleting = true
        
        Task {
            do {
                try await dataExportManager.deleteAllUserData()
                // Sign out user and return to onboarding
                await MainActor.run {
                    authManager.signOut()
                    dismiss()
                }
            } catch {
                print("Delete failed: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://circle.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: "https://circle.app/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    private func contactSupport() {
        if let url = URL(string: "mailto:support@circle.app") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview
#Preview {
    PrivacySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}