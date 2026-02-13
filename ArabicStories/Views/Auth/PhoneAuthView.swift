//
//  PhoneAuthView.swift
//  Arabicly
//  Phone number authentication view
//

import SwiftUI

struct PhoneAuthView: View {
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var verificationID: String?
    @State private var showCodeEntry = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var countdown = 60
    @State private var canResend = false
    @State private var timer: Timer?
    
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
            .navigationTitle(showCodeEntry ? "Verify Code" : "Phone Number")
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
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    // MARK: - Phone Entry Section
    private var phoneEntrySection: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "phone.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.hikayaTeal)
                .symbolEffect(.pulse)
            
            // Description
            VStack(spacing: 8) {
                Text("Enter your phone number")
                    .font(.title2.bold())
                    .foregroundStyle(Color.hikayaDeepTeal)
                
                Text("We'll send you a verification code")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Phone input
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    // Country code placeholder
                    Text("+1")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
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
            }
            
            Spacer()
            
            // Continue button
            Button {
                sendVerificationCode()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send Code")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isValidPhoneNumber 
                        ? Color.hikayaTeal 
                        : Color.gray.opacity(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValidPhoneNumber || isLoading)
        }
    }
    
    // MARK: - Code Entry Section
    private var codeEntrySection: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.hikayaOrange)
                .symbolEffect(.pulse)
            
            // Description
            VStack(spacing: 8) {
                Text("Enter verification code")
                    .font(.title2.bold())
                    .foregroundStyle(Color.hikayaDeepTeal)
                
                Text("Code sent to \(formatPhoneNumber(phoneNumber))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Code input
            VStack(spacing: 16) {
                TextField("000000", text: $verificationCode)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .frame(height: 60)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.hikayaTeal.opacity(0.3), lineWidth: 2)
                    )
                    .onChange(of: verificationCode) { _, newValue in
                        // Auto-submit when 6 digits entered
                        if newValue.count == 6 {
                            verifyCode()
                        }
                    }
                
                // Resend code
                HStack {
                    if canResend {
                        Button("Resend Code") {
                            sendVerificationCode()
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.hikayaTeal)
                    } else {
                        Text("Resend code in \(countdown)s")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Verify button
            Button {
                verifyCode()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Verify")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isValidCode 
                        ? Color.hikayaTeal 
                        : Color.gray.opacity(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValidCode || isLoading)
            
            // Change number button
            Button("Change phone number") {
                withAnimation {
                    showCodeEntry = false
                    verificationCode = ""
                    timer?.invalidate()
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.hikayaTeal)
        }
    }
    
    // MARK: - Validation
    private var isValidPhoneNumber: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        return digits.count >= 10
    }
    
    private var isValidCode: Bool {
        verificationCode.count == 6
    }
    
    // MARK: - Formatting
    private func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }
        if digits.count >= 10 {
            let area = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            let line = digits.dropFirst(6).prefix(4)
            return "+1 (\(area)) \(prefix)-\(line)"
        }
        return number
    }
    
    // MARK: - Actions
    private func sendVerificationCode() {
        isLoading = true
        
        Task {
            do {
                let id = try await authService.sendPhoneVerificationCode(
                    phoneNumber: "+1\(phoneNumber.filter { $0.isNumber })"
                )
                
                await MainActor.run {
                    verificationID = id
                    showCodeEntry = true
                    isLoading = false
                    startCountdown()
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
                try await authService.verifyPhoneCode(
                    verificationID: verificationID,
                    verificationCode: verificationCode
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                    verificationCode = ""
                }
            }
        }
    }
    
    private func startCountdown() {
        countdown = 60
        canResend = false
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                canResend = true
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PhoneAuthView()
}
