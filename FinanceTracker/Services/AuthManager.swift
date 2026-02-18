import Foundation

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
                isAuthenticated = true
            } else {
                print("Session invalid — no user, showing login")
                logout()
            }
        } catch {
            print("Session validation failed: \(error), showing login")
            logout()
        }
    }
}
