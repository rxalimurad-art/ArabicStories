//
//  AuthService.swift
//  Arabicly
//  Authentication service handling all login methods
//

import Foundation
import FirebaseCore
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import GoogleSignIn

@Observable
class AuthService {
    static let shared = AuthService()
    
    // MARK: - Auth State
    var currentUser: User?
    var isAuthenticated = false
    var isAnonymous = false
    var authError: String?
    var isLoading = false
    
    // MARK: - Apple Sign In
    private var currentNonce: String?
    
    private init() {
        // Listen for auth state changes
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
            self?.isAnonymous = user?.isAnonymous ?? false
            
            if let user = user {
                print("🔐 Auth state: \(user.isAnonymous ? "Anonymous" : "Authenticated") - \(user.uid)")
            } else {
                print("🔐 Auth state: Not signed in")
            }
        }
    }
    
    // MARK: - Anonymous Sign In
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("🔐 Anonymous sign in successful: \(result.user.uid)")
        } catch {
            authError = error.localizedDescription
            print("❌ Anonymous sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Apple Sign In
    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Generate nonce for Apple Sign In
        let nonce = randomNonceString()
        currentNonce = nonce
        
        // Create Apple ID Provider request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // Perform the sign in
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            
            // Store delegate to prevent deallocation
            appleSignInDelegate = delegate
            
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
        
        // Handle the result
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        
        // Create Firebase credential
        guard let nonce = currentNonce else {
            throw AuthError.invalidCredentials
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        // Sign in to Firebase
        let authResult = try await Auth.auth().signIn(with: credential)
        
        // Update display name if available
        if let fullName = appleIDCredential.fullName {
            let displayName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            if !displayName.isEmpty {
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
        }
        
        print("🔐 Apple sign in successful: \(authResult.user.uid)")
        currentNonce = nil
        appleSignInDelegate = nil
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle(presenting: UIViewController) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }
        
        // Create Google Sign In configuration
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidCredentials
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Update display name if available
            if let profile = result.user.profile {
                let displayName = [profile.givenName, profile.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !displayName.isEmpty {
                    let changeRequest = authResult.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                }
            }
            
            print("🔐 Google sign in successful: \(authResult.user.uid)")
        } catch {
            authError = error.localizedDescription
            print("❌ Google sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Account Linking
    func linkAppleAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            appleSignInDelegate = delegate
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
        
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.invalidCredentials
        }
        
        // For linking, we don't need the full name
        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: nil
        )
        
        do {
            let result = try await user.link(with: credential)
            print("🔐 Apple account linked: \(result.user.uid)")
            currentNonce = nil
            appleSignInDelegate = nil
        } catch let error as NSError {
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // Handle already linked account
                throw AuthError.alreadyLinked
            }
            throw error
        }
    }
    
    func linkGoogleAccount(presenting: UIViewController) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }
        
        // Create Google Sign In configuration
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidCredentials
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            let linkResult = try await user.link(with: credential)
            print("🔐 Google account linked: \(linkResult.user.uid)")
        } catch let error as NSError {
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                throw AuthError.alreadyLinked
            }
            authError = error.localizedDescription
            print("❌ Google account linking failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Sign Out
    func signOut() async throws {
        do {
            // Clear local cache before signing out
            await LocalCache.shared.switchUser("anonymous")
            
            // Sign out from Firebase
            try Auth.auth().signOut()
            
            // Sign out from Google
            GIDSignIn.sharedInstance.signOut()
            
            print("🔐 Signed out successfully")
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await user.delete()
            print("🔐 Account deleted")
        } catch {
            print("❌ Account deletion failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

// MARK: - Apple Sign In Delegate
private var appleSignInDelegate: AppleSignInDelegate?

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case configurationError
    case notAuthenticated
    case alreadyLinked
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials"
        case .configurationError:
            return "Authentication configuration error"
        case .notAuthenticated:
            return "User not authenticated"
        case .alreadyLinked:
            return "This account is already linked to another user"
        }
    }
}
