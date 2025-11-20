//
//  PermissionsFlowView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI

struct PermissionsFlowView: View {
    @StateObject private var permissionsManager = StartupPermissionsManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text("Welcome to Circle")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Let's set up your permissions to get started")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Current Permission Card
                if let currentPermission = permissionsManager.getCurrentPermission() {
                    PermissionCard(
                        permission: currentPermission,
                        status: permissionsManager.getPermissionStatus(currentPermission),
                        onAllow: {
                            Task {
                                await permissionsManager.requestPermission(currentPermission)
                                permissionsManager.nextPermissionStep()
                            }
                        },
                        onSkip: {
                            permissionsManager.nextPermissionStep()
                        }
                    )
                }
                
                // Progress Indicator
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<StartupPermissionsManager.PermissionType.allCases.count, id: \.self) { index in
                            Circle()
                                .fill(index <= permissionsManager.currentPermissionStep ? Color.blue : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text("Step \(permissionsManager.currentPermissionStep + 1) of \(StartupPermissionsManager.PermissionType.allCases.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Skip All Button
                Button("Skip All Permissions") {
                    permissionsManager.skipPermissionsFlow()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct PermissionCard: View {
    let permission: StartupPermissionsManager.PermissionType
    let status: StartupPermissionsManager.PermissionStatus
    let onAllow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Permission Icon
            Image(systemName: permission.icon)
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            // Permission Title
            Text(permission.rawValue)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Permission Description
            Text(permission.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Status Indicator
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(statusColor.opacity(0.1))
            )
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Allow") {
                    onAllow()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(status == .authorized)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }
    
    private var statusIcon: String {
        switch status {
        case .notRequested: return "questionmark.circle"
        case .denied: return "xmark.circle"
        case .authorized: return "checkmark.circle.fill"
        case .restricted: return "exclamationmark.triangle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .notRequested: return .orange
        case .denied: return .red
        case .authorized: return .green
        case .restricted: return .orange
        }
    }
    
    private var statusText: String {
        switch status {
        case .notRequested: return "Not Requested"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .restricted: return "Restricted"
        }
    }
}

struct PermissionsFlowView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsFlowView()
    }
}





