//
//  LoginView.swift
//  Hikaya
//  Authentication screen with multiple login options
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var authService = AuthService.shared
    @State private var showPhoneAuth = false
    @State private var showError = false
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and title
                    headerSection
                    
                    // Login options
                    loginOptionsSection
                    
                    // Anonymous option
                    anonymousSection
                    
                    // Terms
                    termsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 32)
            }
        }
        .loadingOverlay(isLoading: authService.isLoading)
        .sheet(isPresented: $showPhoneAuth) {
            PhoneAuthView()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.authError ?? "An error occurred")
        }
        .onChange(of: authService.authError) { _, error in
            if error != nil {
                showError = true
            }
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.hikayaCream,
                Color.hikayaSand.opacity(0.5),
                Color.hikayaCream
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            ZStack {
                Circle()
                    .fill(Color.hikayaTeal.gradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.hikayaTeal.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            
            Text("Hikaya")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(Color.hikayaDeepTeal)
            
            Text("Learn Arabic through stories")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Login Options Section
    private var loginOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Sign in to save your progress")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            
            // Sign in with Apple
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    handleAppleSignIn(result)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(authService.isLoading)
            
            // Google Sign In
            Button {
                Task {
                    do {
                        // Get the root view controller
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let rootViewController = windowScene.windows.first?.rootViewController else {
                            return
                        }
                        try await authService.signInWithGoogle(presenting: rootViewController)
                    } catch {
                        // Handle error
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(authService.isLoading)
            
            // Phone Sign In
            Button {
                showPhoneAuth = true
            } label: {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundStyle(Color.hikayaTeal)
                    
                    Text("Continue with Phone")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(authService.isLoading)
        }
    }
    
    // MARK: - Anonymous Section
    private var anonymousSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)
            
            Button {
                Task {
                    do {
                        try await authService.signInAnonymously()
                    } catch {
                        // Error handled by auth service
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "person.fill.questionmark")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Text("Continue as Guest")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .disabled(authService.isLoading)
            
            Text("You can link your account later in Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Link("Terms of Service", destination: URL(string: "https://hikaya.app/terms")!)
                Text("and")
                Link("Privacy Policy", destination: URL(string: "https://hikaya.app/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(Color.hikayaTeal)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Apple Sign In Handler
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                switch result {
                case .success:
                    try await authService.signInWithApple()
                case .failure(let error):
                    print("Apple sign in error: \(error.localizedDescription)")
                }
            } catch {
                // Error handled by auth service
            }
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: ViewModifier {
    var isLoading: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Please wait...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading))
    }
}

// MARK: - Preview
#Preview {
    LoginView()
}
