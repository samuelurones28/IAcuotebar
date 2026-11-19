import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore
    var onCheckForUpdates: (() -> Void)?
    @State private var disconnectConfirmationService: ServiceKind?
    @State private var connectionErrorMessage: String?

    private var strings: SettingsStrings {
        SettingsStrings(appLanguage: settings.appLanguage)
    }

    private var widgetOrderBinding: Binding<Bool> {
        Binding(
            get: { settings.widgetServiceOrder.first == ServiceKind.codex.rawValue },
            set: { codexFirst in
                settings.widgetServiceOrder = codexFirst
                    ? [ServiceKind.codex.rawValue, ServiceKind.claudeCode.rawValue]
                    : [ServiceKind.claudeCode.rawValue, ServiceKind.codex.rawValue]
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { settings.notificationsEnabled },
            set: { settings.setNotificationsEnabled($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
        )
    }

    private var connectionErrorBinding: Binding<Bool> {
        Binding(
            get: { connectionErrorMessage != nil },
            set: { if !$0 { connectionErrorMessage = nil } }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker(strings.language, selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.displayName(in: settings.appLanguage)).tag(language)
                    }
                }
            }

            // MARK: アカウント
            Section {
                VStack(spacing: 12) {
                    ForEach(ServiceKind.allCases) { service in
                        AccountIntegrationRow(
                            service: service,
                            isConnected: settings.isConnected(service),
                            accountLabel: settings.accountLabel(for: service),
                            strings: strings,
                            action: { toggleConnection(for: service) }
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label(strings.accounts, systemImage: "person.2")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(strings.accountsFooter)
                    HStack(spacing: 0) {
                        Text(strings.fullDiskAccessHint + " ")
                        Button(strings.openSystemSettings) {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                            )
                        }
                        .buttonStyle(.link)
                    }
                }
            }

            // MARK: 表示モード
            Section {
                Picker(strings.displayMode, selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(strings.displayModeLabel(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.displayMode == .minimal ? strings.minimalDescription : strings.normalDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Label(strings.displayModeSection, systemImage: "rectangle.on.rectangle")
            }

            // MARK: ウィジェット
            Section {
                Toggle(strings.floatingWidget, isOn: $settings.widgetEnabled)

                Picker(strings.widgetStyle, selection: $settings.widgetStyle) {
                    Text(strings.edgeWidgetStyle).tag(WidgetStyle.edge)
                    Text(strings.cardWidgetStyle).tag(WidgetStyle.card)
                }
                .pickerStyle(.segmented)
                .disabled(!settings.widgetEnabled)

                Picker(strings.widgetSize, selection: $settings.widgetSize) {
                    Text("S").tag(WidgetSize.small)
                    Text("M").tag(WidgetSize.medium)
                }
                .pickerStyle(.segmented)
                .disabled(!settings.widgetEnabled)

                Picker(strings.widgetPosition, selection: $settings.widgetPosition) {
                    ForEach(WidgetPosition.allCases) { position in
                        Text(strings.widgetPositionLabel(position)).tag(position)
                    }
                }
                .disabled(!settings.widgetEnabled)

                Toggle(strings.alwaysOnTop, isOn: $settings.widgetAlwaysOnTop)
                    .disabled(!settings.widgetEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(strings.widgetOpacity)
                        Spacer()
                        Text("\(Int(settings.widgetOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.widgetOpacity, in: 0.3...1.0, step: 0.05)
                }
                .disabled(!settings.widgetEnabled)

                Picker(strings.widgetOrder, selection: widgetOrderBinding) {
                    Text(strings.widgetOrderCodexFirst).tag(true)
                    Text(strings.widgetOrderClaudeFirst).tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(!settings.widgetEnabled)

                Toggle(strings.showClaudeWeeklyLimitInWidget, isOn: $settings.showClaudeWeeklyLimitInWidget)
                    .disabled(!settings.widgetEnabled)

                Toggle(strings.showCodexWeeklyLimitInWidget, isOn: $settings.showCodexWeeklyLimitInWidget)
                    .disabled(!settings.widgetEnabled)
            } header: {
                Label(strings.widgetSection, systemImage: "macwindow.on.rectangle")
            } footer: {
                Text(strings.widgetFooter)
            }

            // MARK: 通知・更新
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(strings.notificationThreshold)
                        Spacer()
                        Text("\(Int(settings.thresholdPercent))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.thresholdPercent, in: 50...100, step: 1)
                    Text(strings.notificationThresholdDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker(strings.autoRefresh, selection: $settings.refreshInterval) {
                    Text(strings.minutes(1)).tag(TimeInterval(60))
                    Text(strings.minutes(5)).tag(TimeInterval(300))
                    Text(strings.minutes(10)).tag(TimeInterval(600))
                    Text(strings.minutes(15)).tag(TimeInterval(900))
                    Text(strings.minutes(30)).tag(TimeInterval(1800))
                }
                .onChange(of: settings.refreshInterval) { _, _ in
                    usageStore.rescheduleTimer()
                }

                HStack {
                    Toggle(strings.notifications, isOn: notificationsBinding)
                    .disabled(!AppEnvironment.supportsUserNotifications)

                    Spacer()

                    Button(strings.testNotification) {
                        usageStore.sendTestNotification()
                    }
                    .disabled(!settings.notificationsEnabled || !AppEnvironment.supportsUserNotifications)
                }

                Text(strings.notificationsDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !AppEnvironment.supportsUserNotifications {
                    Text(strings.notificationsAppOnly)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(strings.monitoring, systemImage: "bell.badge")
            }

            // MARK: システム
            Section {
                Toggle(strings.menuBarItem, isOn: $settings.menuBarEnabled)

                Toggle(strings.launchAtLogin, isOn: launchAtLoginBinding)
                .disabled(!AppEnvironment.supportsLaunchAtLogin)

                if !AppEnvironment.supportsLaunchAtLogin {
                    Text(strings.launchAtLoginAppOnly)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(strings.refreshNow) {
                    Task { await usageStore.refresh() }
                }

                if AppEnvironment.supportsUpdates, let onCheckForUpdates {
                    Button(strings.checkForUpdates) {
                        onCheckForUpdates()
                    }
                }

                HStack {
                    Text(strings.version)
                    Spacer()
                    Text(AppVersion.current.displayString)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                // The only way to quit when the menu bar item is hidden.
                Button(strings.quitApp, role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            } header: {
                Label(strings.system, systemImage: "gearshape")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 540)
        .background(WindowLevelReader(level: .floating))
        .alert(strings.connectionErrorTitle, isPresented: connectionErrorBinding) {
            Button(strings.ok, role: .cancel) {}
        } message: {
            Text(connectionErrorMessage ?? "")
        }
        .alert(item: $disconnectConfirmationService) { service in
            Alert(
                title: Text(strings.disconnectTitle(service.displayName)),
                message: Text(strings.disconnectMessage(service.displayName)),
                primaryButton: .destructive(Text(strings.disconnect)) {
                    settings.disconnect(service)
                    usageStore.disconnect(service)
                },
                secondaryButton: .cancel(Text(strings.cancel))
            )
        }
    }

    private func toggleConnection(for service: ServiceKind) {
        if settings.isConnected(service) {
            disconnectConfirmationService = service
        } else {
            do {
                try settings.connect(service)
                connectionErrorMessage = nil
                refreshUsage()
            } catch UsageProviderError.browserDataAccessDenied(let deniedService, let browserName) {
                connectionErrorMessage = strings.browserAccessDenied(serviceName: deniedService.displayName, browserName: browserName)
            } catch let providerError as UsageProviderError {
                connectionErrorMessage = connectionMessage(for: providerError)
            } catch {
                connectionErrorMessage = error.localizedDescription
            }
        }
    }

    private func refreshUsage() {
        Task { await usageStore.refresh() }
    }

    private func openClaudeLoginPage() -> BrowserLaunchTarget {
        BrowserLaunchService.shared.openDefaultBrowser(for: ServiceKind.claudeCode.loginURL)
    }

    private func connectionMessage(for error: UsageProviderError) -> String {
        switch error {
        case .localClientNotInstalled(.codex, _):
            strings.codexInstallPrompt
        case .missingLocalSession(.codex):
            strings.codexLoginPrompt
        case .missingLocalSession(.claudeCode):
            browserPrompt(for: openClaudeLoginPage(), service: .claudeCode)
        default:
            error.description(in: settings.appLanguage)
        }
    }

    private func browserPrompt(for browser: BrowserLaunchTarget, service: ServiceKind) -> String {
        switch browser.family {
        case .safari:
            if BrowserCookieStore.shared.safariCookieAccessState() == .permissionDenied {
                strings.safariFullDiskAccessPrompt(service.displayName, browserName: browser.displayName)
            } else {
                strings.browserLoginPrompt(service.displayName, browserName: browser.displayName)
            }
        case .chromium, .other:
            strings.browserLoginPrompt(service.displayName, browserName: browser.displayName)
        }
    }
}

#if DEBUG
private struct SettingsViewPreview: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: PreviewSupport.settings, usageStore: PreviewSupport.usageStore)
            .previewDisplayName("Settings")
    }
}
#endif

private struct AccountIntegrationRow: View {
    let service: ServiceKind
    let isConnected: Bool
    let accountLabel: String?
    let strings: SettingsStrings
    let action: () -> Void

    private var displayAccountLabel: String {
        if let accountLabel, accountLabel != service.accountLabel {
            return accountLabel
        }
        return strings.accountLabel(for: service)
    }

    var body: some View {
        HStack(spacing: 14) {
            ServiceLogoMark(service: service, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(service.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(isConnected ? strings.connected : strings.notConnected)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isConnected ? CuotaBarTheme.success : CuotaBarTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill((isConnected ? CuotaBarTheme.success : CuotaBarTheme.warning).opacity(0.14))
                        )
                }

                Text(isConnected ? displayAccountLabel : strings.linkAccount(service.displayName))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isConnected ? strings.disconnect : strings.connect) {
                action()
            }
            .buttonStyle(.borderedProminent)
            .tint(isConnected ? CuotaBarTheme.warning : CuotaBarTheme.accent)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsStrings {
    let appLanguage: AppLanguage

    var language: String { appLanguage.text(english: "Language", spanish: "Idioma", japanese: "言語") }

    // セクションヘッダー
    var accounts: String { appLanguage.text(english: "Accounts", spanish: "Cuentas", japanese: "アカウント") }
    var displayModeSection: String { appLanguage.text(english: "Display Mode", spanish: "Modo de visualización", japanese: "表示モード") }
    var widgetSection: String { appLanguage.text(english: "Widget", spanish: "Widget", japanese: "ウィジェット") }
    var monitoring: String { appLanguage.text(english: "Notifications & Updates", spanish: "Notificaciones y actualizaciones", japanese: "通知・更新") }
    var system: String { appLanguage.text(english: "System", spanish: "Sistema", japanese: "システム") }

    // フッター・説明文
    var accountsFooter: String {
        appLanguage.text(
            english: "Usage is fetched using your local login session.",
            spanish: "CuotaBar consulta el uso a través de tu sesión local.",
            japanese: "ローカルのログインセッションを使って使用状況を取得します。"
        )
    }
    var fullDiskAccessHint: String {
        appLanguage.text(
            english: "Full Disk Access may be required to read browser login data.",
            spanish: "Puede que CuotaBar necesite acceso total al disco para leer tu sesión del navegador.",
            japanese: "ブラウザのログイン情報を読み取るにはフルディスクアクセスが必要な場合があります。"
        )
    }
    var openSystemSettings: String {
        appLanguage.text(english: "Open System Settings →", spanish: "Abrir Ajustes del Sistema →", japanese: "システム設定を開く →")
    }
    var widgetFooter: String {
        appLanguage.text(
            english: "When the widget is off, all settings below are disabled.",
            spanish: "Al desactivar el widget, también se desactivan sus opciones.",
            japanese: "ウィジェットをオフにすると、以下の設定はすべて無効になります。"
        )
    }
    var notificationThresholdDescription: String {
        appLanguage.text(
            english: "You will be notified when usage exceeds this level.",
            spanish: "Recibirás un aviso cuando el uso supere este nivel.",
            japanese: "この使用率を超えたときに通知します。"
        )
    }

    // 表示モード
    var displayMode: String { appLanguage.text(english: "Mode", spanish: "Modo", japanese: "モード") }
    var minimalDescription: String { appLanguage.text(english: "Shows only the logo and usage percentage.", spanish: "Muestra solo el logotipo y el porcentaje de uso.", japanese: "ロゴと使用率のみをコンパクトに表示します。") }
    var normalDescription: String { appLanguage.text(english: "Shows logo, status, and account details.", spanish: "Muestra el logotipo, el estado y los datos de la cuenta.", japanese: "ロゴ・ステータス・アカウント情報を表示します。") }

    // ウィジェット
    var floatingWidget: String { appLanguage.text(english: "Floating widget", spanish: "Widget flotante", japanese: "フローティングウィジェット") }
    var widgetStyle: String { appLanguage.text(english: "Style", spanish: "Estilo", japanese: "スタイル") }
    var edgeWidgetStyle: String { appLanguage.text(english: "Edge bar", spanish: "Barra lateral", japanese: "サイドバー") }
    var cardWidgetStyle: String { appLanguage.text(english: "Card", spanish: "Tarjeta", japanese: "カード") }
    var alwaysOnTop: String { appLanguage.text(english: "Always on top", spanish: "Siempre visible", japanese: "常に手前に表示") }
    var widgetSize: String { appLanguage.text(english: "Size", spanish: "Tamaño", japanese: "サイズ") }
    var widgetPosition: String { appLanguage.text(english: "Position", spanish: "Posición", japanese: "位置") }
    var widgetOpacity: String { appLanguage.text(english: "Background opacity", spanish: "Opacidad del fondo", japanese: "背景の透明度") }
    var widgetOrder: String { appLanguage.text(english: "Display order", spanish: "Orden de visualización", japanese: "表示順") }
    var widgetOrderCodexFirst: String { appLanguage.text(english: "Codex first", spanish: "Codex primero", japanese: "Codex を先に表示") }
    var widgetOrderClaudeFirst: String { appLanguage.text(english: "Claude Code first", spanish: "Claude Code primero", japanese: "Claude Code を先に表示") }
    var showClaudeWeeklyLimitInWidget: String { appLanguage.text(english: "Show Weekly Limits (Claude Code)", spanish: "Mostrar el límite semanal de Claude Code", japanese: "Weekly Limits 表示(Claude Code)") }
    var showCodexWeeklyLimitInWidget: String { appLanguage.text(english: "Show Weekly Limits (Codex)", spanish: "Mostrar el límite semanal de Codex", japanese: "Weekly Limits 表示(Codex)") }

    // 通知・更新
    var notificationThreshold: String { appLanguage.text(english: "Notification threshold", spanish: "Umbral de notificación", japanese: "通知しきい値") }
    var autoRefresh: String { appLanguage.text(english: "Auto refresh interval", spanish: "Intervalo de actualización automática", japanese: "自動更新の間隔") }
    var notifications: String { appLanguage.text(english: "Enable notifications", spanish: "Activar notificaciones", japanese: "通知を有効にする") }
    var testNotification: String { appLanguage.text(english: "Send test", spanish: "Enviar prueba", japanese: "テスト送信") }
    var notificationsDescription: String {
        appLanguage.text(
            english: "Notifies when usage exceeds the threshold or resets.",
            spanish: "Avisa cuando el uso supera el umbral o se restablece.",
            japanese: "使用率がしきい値を超えたとき、または使用量がリセットされたときに通知します。"
        )
    }
    var notificationsAppOnly: String {
        appLanguage.text(
            english: "Notifications are available when run from a bundled .app.",
            spanish: "Las notificaciones están disponibles al abrir CuotaBar como archivo .app.",
            japanese: "通知は .app として実行したときのみ利用できます。"
        )
    }

    // システム
    var menuBarItem: String { appLanguage.text(english: "Show in menu bar", spanish: "Mostrar en la barra de menús", japanese: "メニューバーに表示") }
    var launchAtLogin: String { appLanguage.text(english: "Launch at login", spanish: "Abrir al iniciar sesión", japanese: "ログイン時に自動起動") }
    var launchAtLoginAppOnly: String {
        appLanguage.text(
            english: "Launch at login is available when run from a bundled .app.",
            spanish: "El inicio automático está disponible al abrir CuotaBar como archivo .app.",
            japanese: "自動起動は .app として実行したときのみ利用できます。"
        )
    }
    var refreshNow: String { AppStrings(language: appLanguage).refreshNow }
    var quitApp: String { appLanguage.text(english: "Quit CuotaBar", spanish: "Salir de CuotaBar", japanese: "CuotaBar を終了") }
    var checkForUpdates: String { appLanguage.text(english: "Check for Updates", spanish: "Buscar actualizaciones", japanese: "アップデートを確認") }
    var version: String { appLanguage.text(english: "Version", spanish: "Versión", japanese: "バージョン") }

    // アカウント関連
    var connected: String { appLanguage.text(english: "Connected", spanish: "Conectado", japanese: "接続済み") }
    var notConnected: String { appLanguage.text(english: "Not connected", spanish: "Sin conectar", japanese: "未接続") }
    var connect: String { appLanguage.text(english: "Connect", spanish: "Conectar", japanese: "接続") }
    var disconnect: String { appLanguage.text(english: "Disconnect", spanish: "Desconectar", japanese: "解除") }
    var cancel: String { appLanguage.text(english: "Cancel", spanish: "Cancelar", japanese: "キャンセル") }
    var ok: String { "OK" }
    var connectionErrorTitle: String { appLanguage.text(english: "Connection failed", spanish: "No se pudo conectar", japanese: "接続に失敗しました") }
    var codexInstallPrompt: String {
        appLanguage.text(
            english: "To fetch Codex usage, install the Codex app or CLI on this Mac. After installing, sign in to Codex and then connect again.",
            spanish: "Para consultar el uso, instala la app o la CLI de Codex en este Mac. Luego inicia sesión en Codex y vuelve a conectar.",
            japanese: "Codex の使用量を取得するには、Codex アプリまたは CLI をこの Mac にインストールしてください。インストール後、Codex 側でログインしてから再度接続してください。"
        )
    }
    var codexLoginPrompt: String {
        appLanguage.text(
            english: "To fetch Codex usage, sign in through the Codex app or CLI. Then return to CuotaBar and connect again.",
            spanish: "Para consultar el uso, inicia sesión en la app o la CLI de Codex. Después, vuelve a CuotaBar y conecta de nuevo.",
            japanese: "Codex の使用量を取得するには、Codex アプリまたは CLI でログインしてください。ログイン後に CuotaBar へ戻って再度接続してください。"
        )
    }

    func browserLoginPrompt(_ serviceName: String, browserName: String) -> String {
        appLanguage.text(
            english: "No local \(serviceName) login was found, so \(browserName) was opened. Sign in, then return and connect again.",
            spanish: "CuotaBar abrió \(browserName) porque no encontró una sesión local de \(serviceName). Inicia sesión, vuelve a CuotaBar y conecta de nuevo.",
            japanese: "\(serviceName) のローカルログインが見つからなかったため、\(browserName) を開きました。ログイン後にアプリへ戻って再度接続してください。"
        )
    }

    func safariFullDiskAccessPrompt(_ serviceName: String, browserName: String) -> String {
        appLanguage.text(
            english: "No local \(serviceName) login was found, so \(browserName) was opened. To use a Safari login, grant CuotaBar Full Disk Access, then sign in and return to connect again.",
            spanish: "CuotaBar abrió \(browserName) porque no encontró una sesión local de \(serviceName). Para usar tu sesión de Safari, dale a CuotaBar acceso total al disco. Después, inicia sesión y vuelve a conectar.",
            japanese: "\(serviceName) のローカルログインが見つからなかったため、\(browserName) を開きました。Safari ログインを使うには CuotaBar にフルディスクアクセスを許可してください。その後、ログインしてアプリへ戻り、もう一度接続してください。"
        )
    }

    func browserAccessDenied(serviceName: String, browserName: String) -> String {
        appLanguage.text(
            english: "\(serviceName) could not access \(browserName) login data. Grant CuotaBar Full Disk Access in System Settings → Privacy & Security → Full Disk Access, then try connecting again.",
            spanish: "No se pudo leer la sesión de \(serviceName) en \(browserName). Dale a CuotaBar acceso total al disco en Ajustes del Sistema → Privacidad y seguridad → Acceso total al disco. Después, vuelve a intentar la conexión.",
            japanese: "\(serviceName) は \(browserName) のログイン情報にアクセスできませんでした。CuotaBar にフルディスクアクセスを付与してください（システム設定 → プライバシーとセキュリティ → フルディスクアクセス）。その後、もう一度接続してください。"
        )
    }

    func minutes(_ value: Int) -> String {
        appLanguage.text(english: "Every \(value) min", spanish: "Cada \(value) min", japanese: "\(value)分ごと")
    }

    func displayModeLabel(_ mode: DisplayMode) -> String {
        switch mode {
        case .minimal: appLanguage.text(english: "Minimal", spanish: "Minimalista", japanese: "ミニマル")
        case .normal: appLanguage.text(english: "Normal", spanish: "Normal", japanese: "通常")
        }
    }

    func widgetPositionLabel(_ position: WidgetPosition) -> String {
        switch position {
        case .topLeft: appLanguage.text(english: "Top Left", spanish: "Arriba a la izquierda", japanese: "左上")
        case .topRight: appLanguage.text(english: "Top Right", spanish: "Arriba a la derecha", japanese: "右上")
        case .centerLeft: appLanguage.text(english: "Center Left", spanish: "Centro a la izquierda", japanese: "左中央")
        case .centerRight: appLanguage.text(english: "Center Right", spanish: "Centro a la derecha", japanese: "右中央")
        case .bottomLeft: appLanguage.text(english: "Bottom Left", spanish: "Abajo a la izquierda", japanese: "左下")
        case .bottomRight: appLanguage.text(english: "Bottom Right", spanish: "Abajo a la derecha", japanese: "右下")
        }
    }

    func accountLabel(for service: ServiceKind) -> String {
        switch service {
        case .codex: appLanguage.text(english: "OpenAI account", spanish: "Cuenta de OpenAI", japanese: "OpenAI アカウント")
        case .claudeCode: appLanguage.text(english: "Anthropic account", spanish: "Cuenta de Anthropic", japanese: "Anthropic アカウント")
        }
    }

    func linkAccount(_ serviceName: String) -> String {
        appLanguage.text(
            english: "Monitors using the signed-in \(serviceName) desktop session.",
            spanish: "Consulta el uso mediante tu sesión de \(serviceName).",
            japanese: "\(serviceName) のデスクトップセッションを使って監視します。"
        )
    }

    func disconnectTitle(_ serviceName: String) -> String {
        appLanguage.text(english: "Disconnect \(serviceName)?", spanish: "¿Desconectar \(serviceName)?", japanese: "\(serviceName) の接続を解除しますか？")
    }

    func disconnectMessage(_ serviceName: String) -> String {
        appLanguage.text(
            english: "This stops monitoring for \(serviceName). Your desktop session remains intact.",
            spanish: "CuotaBar dejará de consultar el uso de \(serviceName). Tu sesión seguirá abierta.",
            japanese: "\(serviceName) の監視を停止します。デスクトップのログイン状態はそのまま残ります。"
        )
    }
}
