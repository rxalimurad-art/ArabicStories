//
//  LoginView.swift
//  Arabicly
//  Enhanced authentication screen with AppIcon logo
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var authService = AuthService.shared
    @State private var showError = false
    @State private var contentOffset: CGFloat = 30
    
    // Theme colors
    private let primaryTeal = Color(red: 0.18, green: 0.55, blue: 0.55)
    private let darkTeal = Color(red: 0.12, green: 0.42, blue: 0.42)
    private let lightTeal = Color(red: 0.28, green: 0.65, blue: 0.65)
    
    var body: some View {
        ZStack {
            // Teal theme background
            backgroundGradient
            
            // Decorative elements
            decorativeCircles
            
            VStack(spacing: 0) {
                // Logo and title
                headerSection
                
                Spacer()
                
                // Login options
                authSection
                .padding(.bottom, 20)
                
                // Anonymous option
                anonymousSection
                .padding(.bottom, 24)
                
                // Terms
                termsSection
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 28)
            .offset(y: contentOffset)
            .opacity(contentOffset == 0 ? 1 : 0)
        }
        .loadingOverlay(isLoading: authService.isLoading)
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOffset = 0
            }
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                darkTeal,
                primaryTeal,
                lightTeal
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Decorative Circles
    private var decorativeCircles: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.03))
                .frame(width: 350, height: 350)
                .offset(x: 150, y: -150)
            
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 200, height: 200)
                .offset(x: -120, y: 50)
            
            Circle()
                .fill(Color.white.opacity(0.03))
                .frame(width: 280, height: 280)
                .offset(x: 100, y: 350)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon with glow
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(
                    color: Color.black.opacity(0.3),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
            
            // App name
            VStack(spacing: 6) {
                Text("Arabicly")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                
                Text("Learn Arabic through stories")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Auth Section (Apple + Google)
    private var authSection: some View {
        VStack(spacing: 16) {
            Text("Sign in to save your progress")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.bottom, 4)
            
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
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .disabled(authService.isLoading)
            
            // Divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Google Sign In
            Button {
                signInWithGoogle()
            } label: {
                HStack(spacing: 12) {
                    Image("google_logo")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.red)
                    
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .disabled(authService.isLoading)
        }
    }
    
    // MARK: - Anonymous Section
    private var anonymousSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 4)
            
            Button {
                Task {
                    do {
                        try await authService.signInAnonymously()
                    } catch {
                        // Error handled by auth service
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                    
                    Text("Continue as Guest")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
            }
            .disabled(authService.isLoading)
            
            Text("You can link your account later in Settings")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 6) {
            Text("By continuing, you agree to our")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.6))
            
            HStack(spacing: 4) {
                Link("Terms of Service", destination: URL(string: "https://hikaya.app/terms")!)
                Text("and")
                Link("Privacy Policy", destination: URL(string: "https://hikaya.app/privacy")!)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.white.opacity(0.9))
        }
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
    
    // MARK: - Google Sign In Handler
    private func signInWithGoogle() {
        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    return
                }
                try await authService.signInWithGoogle(presenting: rootViewController)
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
