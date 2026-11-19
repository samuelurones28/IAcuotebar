import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [UsageSnapshot] = []
    @Published private(set) var updatedSnapshots: [UsageSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private var lastRefreshErrors: [Error] = []

    var lastRefreshError: String? {
        guard !lastRefreshErrors.isEmpty else { return nil }
        return lastRefreshErrors.map { error in
            (error as? UsageProviderError)?.description(in: settings.appLanguage) ?? error.localizedDescription
        }.joined(separator: "\n")
    }

    private let settings: SettingsStore
    private let notificationManager: NotificationManager
    private let providers: [AnyUsageProvider]
    private var timer: Timer?
    private var didNotifyLimit: [ServiceKind: Bool] = [:]
    private var didNotifyZeroReset: [ServiceKind: Bool] = [:]
    private var previousPercent: [ServiceKind: Double] = [:]
    private var connectionRevisions: [ServiceKind: Int] = [:]
    private var refreshRequested = false

    init(
        settings: SettingsStore,
        providers: [AnyUsageProvider],
        notificationManager: NotificationManager = .shared
    ) {
        self.settings = settings
        self.providers = providers
        self.notificationManager = notificationManager
    }

    func start() {
        scheduleTimer()
        Task {
            await notificationManager.requestAuthorizationIfNeeded()
            await refresh()
        }
    }

    func rescheduleTimer() {
        scheduleTimer()
    }

    func refresh() async {
        guard !isRefreshing else {
            refreshRequested = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        repeat {
            refreshRequested = false
            await refreshOnce()
        } while refreshRequested
    }

    private func refreshOnce() async {
        let activeProviders = providers.filter { settings.isConnected($0.service) }
        guard !activeProviders.isEmpty else {
            lastRefreshErrors = []
            snapshots = []
            return
        }

        let revisions = connectionRevisions
        let results = await withTaskGroup(of: (ServiceKind, Result<UsageSnapshot, Error>).self) { group in
            for provider in activeProviders {
                group.addTask {
                    // UsageProviderError（認証エラー等）はリトライしない
                    // ネットワークエラーのみ最大2回リトライ（1秒、2秒のインターバル）
                    var lastError: Error?
                    for attempt in 0..<3 {
                        do {
                            return (provider.service, .success(try await provider.fetchUsage()))
                        } catch let error as UsageProviderError {
                            return (provider.service, .failure(error))
                        } catch {
                            lastError = error
                            if attempt < 2 {
                                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * (attempt + 1)))
                            }
                        }
                    }
                    return (provider.service, .failure(lastError!))
                }
            }

            var results: [(ServiceKind, Result<UsageSnapshot, Error>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        var refreshedSnapshots: [UsageSnapshot] = []
        var updatedSnapshots: [UsageSnapshot] = []
        var errors: [Error] = []
        for (service, result) in results {
            guard settings.isConnected(service),
                  connectionRevisions[service, default: 0] == revisions[service, default: 0] else {
                continue
            }
            switch result {
            case .success(let snapshot):
                consecutiveSessionFailures[service] = nil
                refreshedSnapshots.append(snapshot)
                updatedSnapshots.append(snapshot)
            case .failure(let error):
                handleConnectionFailure(error)
                if settings.isConnected(service), let previous = snapshots.first(where: { $0.service == service }) {
                    refreshedSnapshots.append(previous)
                }
                errors.append(error)
            }
        }
        let orderedSnapshots = refreshedSnapshots.sorted { $0.service.displayOrder < $1.service.displayOrder }

        snapshots = orderedSnapshots
        handleNotifications(for: updatedSnapshots)
        if !updatedSnapshots.isEmpty {
            self.updatedSnapshots = updatedSnapshots
        }
        lastRefreshErrors = errors
    }

    func disconnect(_ service: ServiceKind) {
        connectionRevisions[service, default: 0] += 1
        snapshots.removeAll { $0.service == service }
        previousPercent[service] = nil
        consecutiveSessionFailures[service] = nil
        didNotifyLimit[service] = nil
        didNotifyZeroReset[service] = nil

        if snapshots.isEmpty {
            lastRefreshErrors = []
        }
    }

    private static let sessionFailuresBeforeDisconnect = 3
    private var consecutiveSessionFailures: [ServiceKind: Int] = [:]

    private func handleConnectionFailure(_ error: Error) {
        guard let providerError = error as? UsageProviderError else { return }

        switch providerError {
        case .missingLocalSession(let service),
             .localClientNotInstalled(let service, _),
             .unauthorized(let service):
            // A single failed poll (expired cookie being refreshed, locked browser DB)
            // shouldn't drop the account; only disconnect after repeated failures.
            let failures = consecutiveSessionFailures[service, default: 0] + 1
            consecutiveSessionFailures[service] = failures
            guard failures >= Self.sessionFailuresBeforeDisconnect else { return }
            settings.disconnect(service)
            disconnect(service)
        case .notImplemented,
             .browserDataAccessDenied,
             .invalidResponse,
             .forbidden,
             .challengeRequired:
            break
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        timer.tolerance = min(max(settings.refreshInterval * 0.2, 5), 60)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func handleNotifications(for snapshots: [UsageSnapshot]) {
        let language = settings.appLanguage
        for snapshot in snapshots {
            let threshold = settings.thresholdPercent
            let previous = previousPercent[snapshot.service]
            let crossedThreshold = (previous ?? 0) < threshold && snapshot.clampedPercent >= threshold
            let zeroResetDetected = if let previous {
                snapshot.clampedPercent == 0 && previous > 0
            } else {
                false
            }
            let lowUsageResetDetected = if let previous {
                snapshot.clampedPercent > 0 && previous > snapshot.clampedPercent && snapshot.clampedPercent < 10
            } else {
                false
            }

            if crossedThreshold, settings.notificationsEnabled, didNotifyLimit[snapshot.service] != true {
                let name = snapshot.service.displayName
                let percent = Int(snapshot.clampedPercent)
                notificationManager.post(
                    title: language.text(
                        english: "\(name) almost full",
                        spanish: "\(name) se acerca al límite",
                        japanese: "\(name) の上限が近づいています"
                    ),
                    body: language.text(english: "\(percent)% used", spanish: "\(percent)% usado", japanese: "\(percent)% 使用済み")
                )
                didNotifyLimit[snapshot.service] = true
            }

            if snapshot.clampedPercent < threshold {
                didNotifyLimit[snapshot.service] = false
            }

            if snapshot.clampedPercent > 0 {
                didNotifyZeroReset[snapshot.service] = false
            }

            if zeroResetDetected, settings.notificationsEnabled, didNotifyZeroReset[snapshot.service] != true {
                postResetNotification(for: snapshot)
                didNotifyZeroReset[snapshot.service] = true
                didNotifyLimit[snapshot.service] = false
            }

            if lowUsageResetDetected, settings.notificationsEnabled {
                postResetNotification(for: snapshot)
                didNotifyLimit[snapshot.service] = false
            }

            previousPercent[snapshot.service] = snapshot.clampedPercent
        }
    }

    private func postResetNotification(for snapshot: UsageSnapshot) {
        let language = settings.appLanguage
        let name = snapshot.service.displayName
        let percent = Int(snapshot.clampedPercent)
        notificationManager.post(
            title: language.text(english: "\(name) reset", spanish: "Límite de \(name) restablecido", japanese: "\(name) の使用量がリセットされました"),
            body: language.text(english: "Usage returned to \(percent)%", spanish: "El uso ha vuelto al \(percent)%", japanese: "使用率は \(percent)% です")
        )
    }

    func sendTestNotification() {
        let language = settings.appLanguage
        notificationManager.post(
            title: language.text(english: "CuotaBar test notification", spanish: "Notificación de prueba de CuotaBar", japanese: "CuotaBar テスト通知"),
            body: language.text(english: "Notifications are working.", spanish: "Las notificaciones funcionan.", japanese: "通知が正常に届いています。")
        )
    }

    #if DEBUG
    func seedForPreview(_ snapshots: [UsageSnapshot]) {
        self.snapshots = snapshots
    }
    #endif
}
