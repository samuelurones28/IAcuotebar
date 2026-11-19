import Foundation

enum AppEnvironment {
    static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    // Gatekeeper の App Translocation により一時パスで実行されているか
    // /private/var/folders/.../AppTranslocation/... で動いている場合は true
    static var isTranslocated: Bool {
        Bundle.main.bundlePath.contains("AppTranslocation")
    }

    static var supportsLaunchAtLogin: Bool { isBundledApp }
    static var supportsUserNotifications: Bool { isBundledApp }
    static var supportsUpdates: Bool {
        guard isBundledApp,
              let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return false
        }
        return !feedURL.isEmpty && !publicKey.isEmpty
    }
}
