import Foundation
import OSLog

struct LocalAccountSession {
    let service: ServiceKind
    let label: String
    let bearerToken: String?
    let cookies: [HTTPCookie]
    let organizationID: String?

    func makeRequest(url: URL, userAgent: String? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let matchingCookies = cookies.filter { $0.applies(to: url) }
        if !matchingCookies.isEmpty {
            let headers = HTTPCookie.requestHeaderFields(with: matchingCookies)
            for (field, value) in headers {
                request.setValue(value, forHTTPHeaderField: field)
            }
        }

        if let userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        return request
    }
}

extension HTTPCookie {
    func applies(to url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let domain = self.domain.lowercased()
        let normalizedDomain = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
        let matchesHost = host == normalizedDomain || (domain.hasPrefix(".") && host.hasSuffix("." + normalizedDomain))
        guard matchesHost, !isSecure || url.scheme?.lowercased() == "https" else { return false }
        guard expiresDate.map({ $0 > Date() }) ?? true else { return false }

        let cookiePath = path.isEmpty ? "/" : path
        let encodedPath = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        let requestPath = encodedPath.isEmpty ? "/" : encodedPath
        return requestPath == cookiePath || (requestPath.hasPrefix(cookiePath) &&
            (cookiePath.hasSuffix("/") || requestPath.dropFirst(cookiePath.count).hasPrefix("/")))
    }

    static func isWithinDomain(_ cookieDomain: String, domains: [String]) -> Bool {
        let normalized = cookieDomain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return domains.contains { normalized == $0 || normalized.hasSuffix("." + $0) }
    }
}

struct LocalAccountSessionDetector: Sendable {
    static let shared = LocalAccountSessionDetector()

    private let logger = Logger(subsystem: "CuotaBar", category: "LocalAccountSessionDetector")

    func hasSession(for service: ServiceKind) -> Bool {
        (try? detectSession(for: service)) != nil
    }

    func detectSession(for service: ServiceKind) throws -> LocalAccountSession {
        switch service {
        case .codex:
            try detectCodexSession()
        case .claudeCode:
            try detectClaudeSession()
        }
    }

    private func detectCodexSession() throws -> LocalAccountSession {
        do {
            return try CodexDesktopSessionService.shared.detectSession()
        } catch {
            logger.error("Codex desktop session detection failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    private func detectClaudeSession() throws -> LocalAccountSession {
        if let storedSession = try? ClaudeWebSessionStore.shared.loadSession()?.localSession {
            return storedSession
        }

        do {
            return try BrowserClaudeSessionDetector.shared.detectSession()
        } catch UsageProviderError.missingLocalSession(.claudeCode) {
            logger.info("Claude browser session was not found")
        } catch UsageProviderError.browserDataAccessDenied(.claudeCode, let browserName) {
            logger.error("Claude browser session detection was denied for \(browserName, privacy: .public)")
            throw UsageProviderError.browserDataAccessDenied(.claudeCode, browserName: browserName)
        } catch {
            logger.error("Claude browser session detection failed: \(String(describing: error), privacy: .public)")
        }

        // The Claude desktop app's cookie store is scanned (and decrypted) by BrowserClaudeSessionDetector.
        throw UsageProviderError.missingLocalSession(.claudeCode)
    }

    static func decodeJWTProfile(from token: String?) -> JWTProfile? {
        guard let token else { return nil }
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard
            let data = Data(base64Encoded: payload),
            let profile = try? JSONDecoder().decode(JWTProfile.self, from: data)
        else {
            return nil
        }

        return profile
    }

    static func chromeDate(from rawValue: Int64) -> Date? {
        guard rawValue > 0 else { return nil }
        let seconds = TimeInterval(rawValue) / 1_000_000 - 11_644_473_600
        return Date(timeIntervalSince1970: seconds)
    }
}

struct CodexAuthFile: Decodable {
    /// `nil` when Codex is signed in with an API key instead of a ChatGPT account.
    let tokens: Tokens?

    struct Tokens: Decodable {
        let accessToken: String?
        let idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case idToken = "id_token"
        }
    }
}

struct JWTProfile: Decodable {
    let email: String?
    let auth: JWTAuthPayload?

    enum CodingKeys: String, CodingKey {
        case email
        case auth = "https://api.openai.com/auth"
    }

    var planType: String? {
        auth?.chatgptPlanType
    }
}

struct JWTAuthPayload: Decodable {
    let chatgptPlanType: String?

    enum CodingKeys: String, CodingKey {
        case chatgptPlanType = "chatgpt_plan_type"
    }
}
