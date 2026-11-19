import Foundation

struct CodexUsageProvider: UsageProvider {
    let service: ServiceKind = .codex

    static let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"

    func fetchUsage() async throws -> UsageSnapshot {
        let session = try LocalAccountSessionDetector.shared.detectSession(for: service)
        let data = try await fetchUsageWithBearerToken(using: session)

        let payload = try JSONDecoder().decode(CodexUsagePayload.self, from: data)
        let window = payload.rateLimit.primaryWindow ?? payload.rateLimit.secondaryWindow
        guard let percent = window?.usedPercent else {
            throw UsageProviderError.invalidResponse(service)
        }
        let primaryResetAt = payload.rateLimit.primaryWindow.map {
            Date().addingTimeInterval(TimeInterval($0.resetAfterSeconds))
        }
        let weeklyResetAt = payload.rateLimit.secondaryWindow.map {
            Date().addingTimeInterval(TimeInterval($0.resetAfterSeconds))
        }

        return UsageSnapshot(
            service: service,
            usedPercent: percent,
            status: UsageSnapshot.status(for: percent),
            lastUpdated: .now,
            details: nil,
            weeklyPercent: payload.rateLimit.secondaryWindow?.usedPercent,
            resetAt: primaryResetAt,
            weeklyResetAt: weeklyResetAt
        )
    }

    private func fetchUsageWithBearerToken(using session: LocalAccountSession) async throws -> Data {
        let request = try session.makeRequest(
            url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
            userAgent: Self.browserUserAgent
        )
        let (responseData, response) = try await URLSession.cuotaBar.data(for: request)
        try UsageProviderError.validate(response: response, service: service)
        return responseData
    }
}

enum UsageProviderError: LocalizedError {
    case notImplemented(ServiceKind)
    case missingLocalSession(ServiceKind)
    case localClientNotInstalled(ServiceKind, clientName: String)
    case browserDataAccessDenied(ServiceKind, browserName: String)
    case invalidResponse(ServiceKind)
    case unauthorized(ServiceKind)
    case forbidden(ServiceKind)
    case challengeRequired(ServiceKind)

    var errorDescription: String? {
        description(in: .english)
    }

    func description(in language: AppLanguage) -> String {
        switch self {
        case .notImplemented(let service):
            language.text(
                english: "\(service.displayName) provider is not implemented yet.",
                spanish: "La integración con \(service.displayName) aún no está disponible.",
                japanese: "\(service.displayName) のプロバイダーはまだ実装されていません。"
            )
        case .missingLocalSession(let service):
            language.text(
                english: "\(service.displayName) is not logged in locally.",
                spanish: "No hay ninguna sesión local de \(service.displayName).",
                japanese: "\(service.displayName) にローカルでログインしていません。"
            )
        case .localClientNotInstalled(let service, let clientName):
            language.text(
                english: "\(service.displayName) requires \(clientName) to be installed on this Mac.",
                spanish: "Para usar \(service.displayName), instala \(clientName) en este Mac.",
                japanese: "\(service.displayName) を使うには、この Mac に \(clientName) をインストールしてください。"
            )
        case .browserDataAccessDenied(let service, let browserName):
            language.text(
                english: "\(service.displayName) could not read \(browserName) login data on this Mac.",
                spanish: "No se pudo leer la sesión de \(service.displayName) en \(browserName).",
                japanese: "\(browserName) から \(service.displayName) のログイン情報を読み取れませんでした。"
            )
        case .invalidResponse(let service):
            language.text(
                english: "Could not read \(service.displayName) usage.",
                spanish: "No se pudo consultar el uso de \(service.displayName).",
                japanese: "\(service.displayName) の使用状況を取得できませんでした。"
            )
        case .unauthorized(let service):
            language.text(
                english: service == .codex ? "Codex app or CLI login is expired." : "\(service.displayName) local session is expired.",
                spanish: "La sesión local de \(service.displayName) ha caducado.",
                japanese: "\(service.displayName) のローカルセッションの有効期限が切れました。"
            )
        case .forbidden(let service):
            language.text(
                english: "\(service.displayName) denied the usage request. Try again later.",
                spanish: "\(service.displayName) rechazó la consulta de uso. Inténtalo más tarde.",
                japanese: "\(service.displayName) が使用状況のリクエストを拒否しました。しばらくしてからお試しください。"
            )
        case .challengeRequired(let service):
            language.text(
                english: "\(service.displayName) requires reopening the desktop app before usage can be read.",
                spanish: "Vuelve a abrir la app de escritorio de \(service.displayName) para poder consultar su uso.",
                japanese: "使用状況を確認するには、\(service.displayName) のデスクトップアプリを開き直してください。"
            )
        }
    }

    static func validate(response: URLResponse, service: ServiceKind) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageProviderError.invalidResponse(service)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw UsageProviderError.unauthorized(service)
        case 403:
            throw UsageProviderError.forbidden(service)
        default:
            throw UsageProviderError.invalidResponse(service)
        }
    }
}

private struct CodexUsagePayload: Decodable {
    let email: String?
    let planType: String?
    let rateLimit: RateLimit

    enum CodingKeys: String, CodingKey {
        case email
        case rateLimit = "rate_limit"
        case planType = "plan_type"
    }
}

private struct RateLimit: Decodable {
    let primaryWindow: RateLimitWindow?
    let secondaryWindow: RateLimitWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Double
    let resetAfterSeconds: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAfterSeconds = "reset_after_seconds"
    }
}
