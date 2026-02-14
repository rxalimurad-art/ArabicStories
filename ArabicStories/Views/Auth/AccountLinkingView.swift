//
//  AccountLinkingView.swift
//  Arabicly
//  View for linking anonymous accounts to permanent auth methods
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct AccountLinkingView: View {
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaCream.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Linking options
                        linkingOptionsSection
                        
                        // Info card
                        infoSection
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Connect Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.hikayaTeal)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your account has been connected successfully.")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.hikayaTeal.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.hikayaTeal)
            }
            
            Text("Connect Your Account")
                .font(.title2.bold())
                .foregroundStyle(Color.hikayaDeepTeal)
            
            Text("Link your guest account to keep your progress safe and access it across devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Linking Options Section
    private var linkingOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Choose a method")
                .font(.headline)
                .foregroundStyle(Color.hikayaDeepTeal)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Apple
            Button {
                linkAppleAccount()
            } label: {
                linkingButtonLabel(
                    icon: "apple.logo",
                    text: "Connect with Apple",
                    color: .primary
                )
            }
            .disabled(authService.isLoading)
            
            // Google
            Button {
                linkGoogleAccount()
            } label: {
                linkingButtonLabel(
                    icon: "g.circle.fill",
                    text: "Connect with Google",
                    color: .red
                )
            }
            .disabled(authService.isLoading)
        }
    }
    
    // MARK: - Button Label
    private func linkingButtonLabel(icon: String, text: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Your progress will be preserved")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.hikayaTeal)
            }
            
            Label {
                Text("Access your data on any device")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "iphone")
                    .foregroundStyle(Color.hikayaTeal)
            }
            
            Label {
                Text("Secure cloud backup")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "icloud.fill")
                    .foregroundStyle(Color.hikayaTeal)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hikayaTeal.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Actions
    private func linkAppleAccount() {
        Task {
            do {
                try await authService.linkAppleAccount()
                await MainActor.run {
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func linkGoogleAccount() {
        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    return
                }
                try await authService.linkGoogleAccount(presenting: rootViewController)
                await MainActor.run {
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AccountLinkingView()
}
