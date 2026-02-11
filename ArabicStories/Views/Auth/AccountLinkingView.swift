//
//  AccountLinkingView.swift
//  Hikaya
//  View for linking anonymous accounts to permanent auth methods
//

import SwiftUI
import AuthenticationServices

struct AccountLinkingView: View {
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPhoneLinking = false
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
            .sheet(isPresented: $showPhoneLinking) {
                PhoneLinkingView()
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
            
            // Phone
            Button {
                showPhoneLinking = true
            } label: {
                linkingButtonLabel(
                    icon: "phone.fill",
                    text: "Connect with Phone",
                    color: Color.hikayaTeal
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

// MARK: - Phone Linking View
struct PhoneLinkingView: View {
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var verificationID: String?
    @State private var showCodeEntry = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.hikayaCream.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    if !showCodeEntry {
                        phoneEntrySection
                    } else {
                        codeEntrySection
                    }
                }
                .padding(24)
            }
            .navigationTitle(showCodeEntry ? "Verify" : "Phone Number")
            .navigationBarTitleDisplayMode(.inline)
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
                Text("Your phone number has been linked successfully.")
            }
        }
    }
    
    private var phoneEntrySection: some View {
        VStack(spacing: 24) {
            Text("Enter your phone number to link to your account")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Text("+1")
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                TextField("(555) 555-5555", text: $phoneNumber)
                    .font(.system(size: 17))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Spacer()
            
            Button {
                sendCode()
            } label: {
                Text("Send Code")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValidPhone ? Color.hikayaTeal : Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValidPhone || isLoading)
        }
    }
    
    private var codeEntrySection: some View {
        VStack(spacing: 24) {
            Text("Enter the 6-digit code sent to your phone")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("000000", text: $verificationCode)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .frame(height: 60)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: verificationCode) { _, newValue in
                    if newValue.count == 6 {
                        verifyCode()
                    }
                }
            
            Spacer()
            
            Button {
                verifyCode()
            } label: {
                Text("Link Account")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValidCode ? Color.hikayaTeal : Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValidCode || isLoading)
        }
    }
    
    private var isValidPhone: Bool {
        phoneNumber.filter { $0.isNumber }.count >= 10
    }
    
    private var isValidCode: Bool {
        verificationCode.count == 6
    }
    
    private func sendCode() {
        isLoading = true
        Task {
            do {
                let id = try await authService.linkPhoneNumber(
                    phoneNumber: "+1\(phoneNumber.filter { $0.isNumber })"
                )
                await MainActor.run {
                    verificationID = id
                    showCodeEntry = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func verifyCode() {
        guard let verificationID = verificationID else { return }
        isLoading = true
        Task {
            do {
                try await authService.confirmLinkPhoneNumber(
                    verificationID: verificationID,
                    verificationCode: verificationCode
                )
                await MainActor.run {
                    showSuccess = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AccountLinkingView()
}
