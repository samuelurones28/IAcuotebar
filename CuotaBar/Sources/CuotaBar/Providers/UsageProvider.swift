import Foundation

extension URLSession {
    /// Shared session for usage requests: 15 s timeout, nothing persisted to disk.
    /// Cookies are sent explicitly per request, so the cookie jar and cache stay off.
    static let cuotaBar: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
}

protocol UsageProvider: Sendable {
    var service: ServiceKind { get }
    func fetchUsage() async throws -> UsageSnapshot
}

struct AnyUsageProvider: UsageProvider {
    let service: ServiceKind
    private let fetcher: @Sendable () async throws -> UsageSnapshot

    init<P: UsageProvider>(_ provider: P) {
        service = provider.service
        fetcher = provider.fetchUsage
    }

    func fetchUsage() async throws -> UsageSnapshot {
        try await fetcher()
    }
}
