import Foundation
import LocalAuthentication

struct SessionCheck: Decodable {
    let user: SessionUser?
}

struct SessionUser: Decodable {
    let name: String?
}

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isChecking = true
    @Published var isLoading = false
    @Published var error: String?

    init() {
        if let cookie = KeychainHelper.load(key: "session_cookie") {
            APIClient.shared.setSession(cookie)
            // Don't set isAuthenticated yet — validate first
            Task { await validateSession() }
        } else {
            isChecking = false
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let success = try await APIClient.shared.login(username: username, password: password)
            if success {
                isAuthenticated = true
            } else {
                error = "Invalid credentials"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        KeychainHelper.delete(key: "session_cookie")
        APIClient.shared.clearSession()
        isAuthenticated = false
    }

    private func validateSession() async {
        defer { isChecking = false }
        do {
            let session: SessionCheck = try await APIClient.shared.request("/api/auth/session")
            if session.user != nil {
                print("Session valid: \(session.user?.name ?? "unknown")")
                let biometricSuccess = await authenticateWithBiometrics()
                if biometricSuccess {
                    isAuthenticated = true
                } else {
                    // Face ID failed/cancelled — show login screen
                    // Don't clear Keychain — session is still valid
                    isAuthenticated = false
                }
            } else {
                print("Session invalid — no user, showing login")
                logout()
            }
        } catch {
            print("Session validation failed: \(error), showing login")
            logout()
        }
    }

    private func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var nsError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError) else {
            print("Biometrics unavailable: \(nsError?.localizedDescription ?? "unknown")")
            // No biometrics available (simulator, no Face ID) — allow through
            return true
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Canopy"
            )
        } catch {
            print("Biometric auth failed: \(error.localizedDescription)")
            return false
        }
    }
}
