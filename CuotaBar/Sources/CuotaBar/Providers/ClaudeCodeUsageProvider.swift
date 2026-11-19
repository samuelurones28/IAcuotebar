import Foundation

struct ClaudeCodeUsageProvider: UsageProvider {
    let service: ServiceKind = .claudeCode

    func fetchUsage() async throws -> UsageSnapshot {
        let session = try LocalAccountSessionDetector.shared.detectSession(for: service)
        guard let organizationID = session.organizationID else {
            throw UsageProviderError.missingLocalSession(service)
        }

        let request = try session.makeRequest(
            url: URL(string: "https://claude.ai/api/organizations/\(organizationID)/usage")!,
            userAgent: ClaudeWebLoginService.userAgent
        )
        let (data, response) = try await URLSession.cuotaBar.data(for: request)
        try validateClaudeResponse(data: data, response: response)

        let payload = try JSONDecoder().decode(ClaudeUsagePayload.self, from: data)
        guard let percent = payload.fiveHour?.utilization ?? payload.sevenDay?.utilization else {
            throw UsageProviderError.invalidResponse(service)
        }

        return UsageSnapshot(
            service: service,
            usedPercent: percent,
            status: UsageSnapshot.status(for: percent),
            lastUpdated: .now,
            details: nil,
            weeklyPercent: payload.sevenDay?.utilization,
            resetAt: payload.fiveHour?.resetDate,
            weeklyResetAt: payload.sevenDay?.resetDate
        )
    }

    private func validateClaudeResponse(data: Data, response: URLResponse) throws {
        if let text = String(data: data, encoding: .utf8),
           text.localizedCaseInsensitiveContains("Just a moment") {
            throw UsageProviderError.challengeRequired(service)
        }
        try UsageProviderError.validate(response: response, service: service)
    }
}

private struct ClaudeUsagePayload: Decodable {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

private struct ClaudeUsageWindow: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    private nonisolated(unsafe) static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Accepts timestamps with and without fractional seconds.
    var resetDate: Date? {
        guard let resetsAt else { return nil }
        return Self.fractionalFormatter.date(from: resetsAt) ?? Self.plainFormatter.date(from: resetsAt)
    }
}
