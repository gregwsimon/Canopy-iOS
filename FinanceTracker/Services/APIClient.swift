import Foundation

class APIClient {
    static let shared = APIClient()

    // Change this to your deployed Vercel URL
    var baseURL = "https://canopy-iota.vercel.app"

    private var sessionCookie: String?

    func setSession(_ cookie: String) {
        sessionCookie = cookie
    }

    func clearSession() {
        sessionCookie = nil
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 60
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let cookie = sessionCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return try await executeRequest(request)
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: String = "GET",
        body: B
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let cookie = sessionCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        request.httpBody = try JSONEncoder().encode(body)

        return try await executeRequest(request)
    }

    private func executeRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Capture session cookies
        if let headerFields = httpResponse.allHeaderFields as? [String: String],
           let url = httpResponse.url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
            if !cookies.isEmpty {
                let cookieStr = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                sessionCookie = cookieStr
                // Store in Keychain for persistence
                KeychainHelper.save(key: "session_cookie", value: cookieStr)
            }
        }

        // Detect redirect-to-login (middleware returns HTML login page instead of JSON)
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("text/html") {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(errorBody?.error ?? "Request failed")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func login(username: String, password: String) async throws -> Bool {
        guard let baseUrl = URL(string: baseURL) else {
            throw APIError.invalidURL
        }

        // Use a dedicated cookie storage so login cookies are isolated
        let cookieStorage = HTTPCookieStorage.shared
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = cookieStorage
        let loginSession = URLSession(configuration: config)

        // Step 1: Get CSRF token
        let csrfURL = URL(string: "\(baseURL)/api/auth/csrf")!
        let (csrfData, _) = try await loginSession.data(from: csrfURL)
        let csrf = try JSONDecoder().decode(CSRFResponse.self, from: csrfData)

        // Step 2: POST credentials
        let signInURL = URL(string: "\(baseURL)/api/auth/callback/credentials")!
        var request = URLRequest(url: signInURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "csrfToken=\(csrf.csrfToken)&username=\(username)&password=\(password)"
        request.httpBody = body.data(using: .utf8)

        // Follow all redirects, let URLSession handle cookies automatically
        let (_, _) = try await loginSession.data(for: request)

        // Step 3: Read all cookies from storage for our base URL
        let cookies = cookieStorage.cookies(for: baseUrl) ?? []
        let cookieNames = cookies.map { $0.name }
        print("Login cookies in storage: \(cookieNames.joined(separator: ", "))")

        // Also check localhost since NextAuth may redirect there
        if let localhostURL = URL(string: "http://localhost:3000") {
            let localhostCookies = cookieStorage.cookies(for: localhostURL) ?? []
            if !localhostCookies.isEmpty {
                print("Localhost cookies: \(localhostCookies.map { $0.name }.joined(separator: ", "))")
                // Merge — localhost cookies may have the session token
                for c in localhostCookies {
                    if !cookieNames.contains(c.name) {
                        // Re-create cookie for our base URL domain
                        var properties = c.properties ?? [:]
                        properties[.domain] = baseUrl.host
                        if let newCookie = HTTPCookie(properties: properties) {
                            cookieStorage.setCookie(newCookie)
                        }
                    }
                }
            }
        }

        // Re-read after potential merge
        let allCookies = cookieStorage.cookies(for: baseUrl) ?? []
        let hasSession = allCookies.contains { $0.name == "authjs.session-token" }

        if hasSession {
            let cookieStr = allCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            sessionCookie = cookieStr
            KeychainHelper.save(key: "session_cookie", value: cookieStr)
            print("Login SUCCESS — session token captured")
            return true
        }

        // Fallback: try calling /api/auth/session to verify
        print("No session token in cookie storage, verifying via /api/auth/session...")
        let sessionURL = URL(string: "\(baseURL)/api/auth/session")!
        let (sessionData, _) = try await loginSession.data(from: sessionURL)
        if let sessionStr = String(data: sessionData, encoding: .utf8) {
            print("Session check response: \(sessionStr.prefix(200))")
        }

        // Final attempt: re-read cookies after session check
        let finalCookies = cookieStorage.cookies(for: baseUrl) ?? []
        let cookieStr = finalCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        if !cookieStr.isEmpty {
            sessionCookie = cookieStr
            KeychainHelper.save(key: "session_cookie", value: cookieStr)
            print("Login cookies (final): \(finalCookies.map { $0.name }.joined(separator: ", "))")
            return finalCookies.contains { $0.name == "authjs.session-token" }
        }

        print("WARNING: Login failed — no session cookie captured")
        return false
    }
}

struct CSRFResponse: Decodable {
    let csrfToken: String
}

struct ErrorResponse: Decodable {
    let error: String
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Session expired"
        case .serverError(let msg): return msg
        }
    }
}
