import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case spanish
    case english
    case japanese

    var id: String { rawValue }

    func displayName(in language: AppLanguage) -> String {
        switch self {
        case .system: language.text(english: "System language", spanish: "Idioma del sistema", japanese: "システムの言語")
        case .spanish: "Español"
        case .english: "English"
        case .japanese: "日本語"
        }
    }

    var locale: Locale {
        Locale(identifier: text(english: "en", spanish: "es", japanese: "ja"))
    }

    static func fromSystemLocale(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        let preferred = Locale(identifier: preferredLanguages.first ?? "")
        return switch preferred.language.languageCode?.identifier {
        case "es": .spanish
        case "ja": .japanese
        default: .english
        }
    }

    func text(english: String, spanish: String, japanese: String) -> String {
        switch self {
        case .system: Self.fromSystemLocale().text(english: english, spanish: spanish, japanese: japanese)
        case .english: english
        case .spanish: spanish
        case .japanese: japanese
        }
    }
}

struct AppStrings {
    let language: AppLanguage

    var appTitle: String { "CuotaBar" }
    var settings: String { language.text(english: "Settings", spanish: "Ajustes", japanese: "設定") }
    var setup: String { language.text(english: "Setup", spanish: "Configurar", japanese: "設定") }
    var minimalMode: String { language.text(english: "Minimal mode", spanish: "Modo minimalista", japanese: "ミニマルモード") }
    var usagePulseDescription: String {
        language.text(
            english: "Usage pulse for Codex and Claude Code",
            spanish: "Uso de Codex y Claude Code",
            japanese: "Codex と Claude Code の使用状況を表示"
        )
    }
    var connectService: String { language.text(english: "Connect a service", spanish: "Conecta un servicio", japanese: "サービスを接続") }
    var connectServiceDescription: String {
        language.text(
            english: "Open Settings to link your Codex or Claude Code account.",
            spanish: "Abre Ajustes para vincular tu cuenta de Codex o Claude Code.",
            japanese: "設定画面から Codex または Claude Code のアカウントを連携してください。"
        )
    }
    var connectServicesWidget: String {
        language.text(
            english: "Connect Codex or Claude Code in Settings",
            spanish: "Vincula Codex o Claude Code en Ajustes",
            japanese: "設定で Codex または Claude Code を接続"
        )
    }
    var weeklyLabel: String { language.text(english: "Weekly", spanish: "Semanal", japanese: "週間") }
    var weeklyShortLabel: String { language.text(english: "W", spanish: "S", japanese: "週") }
    var widgetUsageUnavailable: String {
        language.text(english: "Usage unavailable", spanish: "Uso no disponible", japanese: "使用状況を取得できません")
    }
    var quitApp: String { language.text(english: "Quit App", spanish: "Salir", japanese: "アプリを終了する") }
    var updatedPrefix: String { language.text(english: "Updated", spanish: "Actualizado a las", japanese: "更新") }
    var openReport: String { language.text(english: "Usage Report", spanish: "Informe de uso", japanese: "使用量レポート") }
    var refreshNow: String { language.text(english: "Refresh now", spanish: "Actualizar ahora", japanese: "今すぐ更新") }
    var safariAccessAlertTitle: String {
        language.text(
            english: "Safari login needs Full Disk Access",
            spanish: "La sesión de Safari requiere acceso total al disco",
            japanese: "Safari ログインにはフルディスクアクセスが必要です"
        )
    }
    var safariAccessAlertMessage: String {
        language.text(
            english: "Safari is your default browser on this Mac. To let CuotaBar read Safari login state, grant Full Disk Access in System Settings.",
            spanish: "Safari es el navegador predeterminado de este Mac. Dale a CuotaBar acceso total al disco en Ajustes del Sistema para que pueda leer la sesión de Safari.",
            japanese: "この Mac の既定ブラウザは Safari です。CuotaBar が Safari のログイン状態を確認するには、システム設定でフルディスクアクセスを許可してください。"
        )
    }
    var openSystemSettings: String {
        language.text(english: "Open System Settings", spanish: "Abrir Ajustes del Sistema", japanese: "システム設定を開く")
    }
    var later: String { language.text(english: "Later", spanish: "Más tarde", japanese: "あとで") }
    var installAlertTitle: String {
        language.text(
            english: "Move CuotaBar to the Applications folder",
            spanish: "Mueve CuotaBar a la carpeta Aplicaciones",
            japanese: "CuotaBar を Applications フォルダに移動してください"
        )
    }
    var installAlertMessage: String {
        language.text(
            english: "macOS is running CuotaBar from a temporary folder because it was opened directly from a disk image. Copy CuotaBar.app to Applications, then open it again.",
            spanish: "macOS ejecuta CuotaBar desde una carpeta temporal porque lo abriste directamente desde una imagen de disco. Copia CuotaBar.app a Aplicaciones y vuelve a abrirlo.",
            japanese: "DMG から直接起動しているため、macOS のセキュリティ機能により一時フォルダから実行されています。このままでは数分後にクラッシュする可能性があります。\n\nCuotaBar.app を /Applications フォルダにコピーしてから再度起動してください。"
        )
    }

    func statusLabel(_ status: UsageStatus) -> String {
        switch status {
        case .normal: language.text(english: status.label, spanish: "normal", japanese: "通常")
        case .warning: language.text(english: status.label, spanish: "aviso", japanese: "注意")
        case .high: language.text(english: status.label, spanish: "alto", japanese: "高い")
        case .limitNear: language.text(english: status.label, spanish: "cerca del límite", japanese: "上限間近")
        case .resetDetected: language.text(english: status.label, spanish: "límite restablecido", japanese: "リセット済み")
        }
    }

    func resetTime(_ time: String) -> String {
        language.text(english: "Resets \(time)", spanish: "Se restablece el \(time)", japanese: "リセット \(time)")
    }

    func resetCountdown(_ duration: String) -> String {
        language.text(english: "resets in \(duration)", spanish: "se restablece en \(duration)", japanese: "リセットまで \(duration)")
    }

    func weeklyUsage(_ percent: Int) -> String {
        language.text(english: "weekly \(percent)%", spanish: "semanal \(percent)%", japanese: "週間 \(percent)%")
    }
}
