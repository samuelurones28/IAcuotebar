import AppKit
import Combine
import Foundation
@preconcurrency import Sparkle
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let usageStore: UsageStore
    let historyStore: UsageHistoryStore
    let widgetController: WidgetWindowController
    @Published private(set) var menuBarTitle: String
    @Published var menuBarEnabled: Bool

    private let updaterController: SPUStandardUpdaterController?
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private var hasShownSafariAccessPrompt = false
    private var reportWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private struct WidgetUpdateState: Equatable {
        let isEnabled: Bool
        let alwaysOnTop: Bool
        let widgetStyle: WidgetStyle
        let widgetSize: WidgetSize
        let widgetPosition: WidgetPosition
        let displayMode: DisplayMode
        let rowCount: Int
    }

    init() {
        let settings = SettingsStore()
        self.settings = settings
        self.historyStore = UsageHistoryStore()
        self.widgetController = WidgetWindowController()
        self.updaterController = AppEnvironment.supportsUpdates
            ? SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        self.usageStore = UsageStore(
            settings: settings,
            providers: [
                AnyUsageProvider(CodexUsageProvider()),
                AnyUsageProvider(ClaudeCodeUsageProvider())
            ]
        )
        self.menuBarTitle = AppModel.makeMenuBarTitle(
            snapshots: [],
            settings: settings
        )
        self.menuBarEnabled = settings.menuBarEnabled
        bindMenuBarTitle()
        bindWindowTitles()
        bindWidgetUpdates()
        bindHistoryRecording()
        bindMenuBarEnabled()
    }

    private func bindMenuBarTitle() {
        Publishers.CombineLatest4(
            usageStore.$snapshots,
            settings.$codexConnected,
            settings.$claudeConnected,
            settings.$appLanguage
        )
        .receive(on: RunLoop.main)
        .map { [weak settings] snapshots, _, _, _ in
            guard let settings else { return "" }
            return AppModel.makeMenuBarTitle(snapshots: snapshots, settings: settings)
        }
        .removeDuplicates()
        .sink { [weak self] title in
            self?.menuBarTitle = title
        }
        .store(in: &cancellables)
    }

    private func bindWindowTitles() {
        settings.$appLanguage
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] language in
                let strings = AppStrings(language: language)
                self?.settingsWindow?.title = strings.settings
                self?.reportWindow?.title = strings.openReport
            }
            .store(in: &cancellables)
    }

    private func bindWidgetUpdates() {
        let widgetSettings = Publishers.CombineLatest4(
            settings.$widgetEnabled,
            settings.$widgetAlwaysOnTop,
            settings.$widgetSize,
            settings.$widgetPosition
        )
        .combineLatest(
            Publishers.CombineLatest4(
                settings.$displayMode,
                settings.$widgetStyle,
                settings.$showClaudeWeeklyLimitInWidget,
                settings.$showCodexWeeklyLimitInWidget
            )
        )

        let widgetStatePublisher = Publishers.CombineLatest(
            usageStore.$snapshots,
            widgetSettings
        )
            .map { combined -> WidgetUpdateState in
                let (snapshots, widgetSettings) = combined
                let ((isEnabled, alwaysOnTop, widgetSize, widgetPosition), (displayMode, style, showClaudeWeeklyLimit, showCodexWeeklyLimit)) = widgetSettings
                let layout = WidgetLayout(style: style, displayMode: displayMode, widgetSize: widgetSize)
                let rowCount = layout.rowCount(for: snapshots) { service in
                    service == .claudeCode ? showClaudeWeeklyLimit : showCodexWeeklyLimit
                }

                return WidgetUpdateState(
                    isEnabled: isEnabled,
                    alwaysOnTop: alwaysOnTop,
                    widgetStyle: style,
                    widgetSize: widgetSize,
                    widgetPosition: widgetPosition,
                    displayMode: displayMode,
                    rowCount: rowCount
                )
            }
            .removeDuplicates()

        widgetStatePublisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] (_: WidgetUpdateState) in
                self?.updateWidget()
            })
            .store(in: &cancellables)
    }

    private func bindHistoryRecording() {
        usageStore.$updatedSnapshots
            .filter { !$0.isEmpty }
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshots in
                self?.historyStore.record(snapshots: snapshots)
            }
            .store(in: &cancellables)
    }

    private func bindMenuBarEnabled() {
        settings.$menuBarEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self, self.menuBarEnabled != value else { return }
                self.menuBarEnabled = value
            }
            .store(in: &cancellables)

    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        if AppEnvironment.isTranslocated {
            showTranslocationAlert()
            return
        }

        promptForSafariFullDiskAccessIfNeeded()
        usageStore.start()
        updateWidget()
        // アプリ起動完了後に Sparkle を開始
        if let updater = updaterController?.updater {
            try? updater.start()
        }
    }

    func setMenuBarEnabledFromUI(_ value: Bool) {
        guard settings.menuBarEnabled != value else { return }
        settings.menuBarEnabled = value
        menuBarEnabled = value
    }

    private func showTranslocationAlert() {
        let strings = AppStrings(language: settings.appLanguage)
        let alert = NSAlert()
        alert.messageText = strings.installAlertTitle
        alert.informativeText = strings.installAlertMessage
        alert.addButton(withTitle: strings.quitApp)
        alert.alertStyle = .critical
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func promptForSafariFullDiskAccessIfNeeded() {
        guard !hasShownSafariAccessPrompt else { return }

        let defaultBrowser = BrowserLaunchService.shared.defaultBrowser(for: ServiceKind.claudeCode.loginURL)
        guard defaultBrowser.family == .safari else { return }
        guard BrowserCookieStore.shared.safariCookieAccessState() == .permissionDenied else { return }

        hasShownSafariAccessPrompt = true

        let strings = AppStrings(language: settings.appLanguage)
        let alert = NSAlert()
        alert.messageText = strings.safariAccessAlertTitle
        alert.informativeText = strings.safariAccessAlertMessage
        alert.addButton(withTitle: strings.openSystemSettings)
        alert.addButton(withTitle: strings.later)
        alert.alertStyle = .warning

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = BrowserLaunchService.shared.openFullDiskAccessSettings()
        }
    }

    func checkForUpdates() {
        updaterController?.updater.checkForUpdates()
    }

    private func updateWidget() {
        widgetController.update(using: usageStore, settings: settings) { [weak self] in
            self?.showSettingsWindow()
        }
    }

    func showSettingsWindow() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, usageStore: usageStore) { [weak self] in
                self?.checkForUpdates()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = AppStrings(language: settings.appLanguage).settings
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 540, height: 560))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showReportWindow() {
        if let w = reportWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = makeReportWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reportWindow = window
    }

    private func makeReportWindow() -> NSWindow {
        let view = UsageReportView(historyStore: historyStore, settings: settings)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = AppStrings(language: settings.appLanguage).openReport
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        return window
    }

    private static func makeMenuBarTitle(snapshots: [UsageSnapshot], settings: SettingsStore) -> String {
        let values = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.service, Int($0.clampedPercent)) })
        let labels = settings.connectedServices.compactMap { service -> String? in
            guard let value = values[service] else { return nil }
            return "\(service.shortLabel) \(value)%"
        }
        return labels.isEmpty ? AppStrings(language: settings.appLanguage).setup : labels.joined(separator: " / ")
    }
}
