//
//  AuthenticationView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Apple-style gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App Icon and Title
                VStack(spacing: 16) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text("C")
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    VStack(spacing: 8) {
                        Text("Circle")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Social life, verified.")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sign In Button
                VStack(spacing: 16) {
                    SignInWithAppleButton(
                        onRequest: { _ in },
                        onCompletion: { _ in }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .onTapGesture {
                        authManager.signInWithApple()
                    }
                    .disabled(authManager.isLoading)
                    
                    if authManager.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Signing in...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Privacy Notice
                VStack(spacing: 8) {
                    Text("By signing in, you agree to our")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Button("Terms of Service") {
                            // Handle terms
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        
                        Text("and")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Button("Privacy Policy") {
                            // Handle privacy
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
}
