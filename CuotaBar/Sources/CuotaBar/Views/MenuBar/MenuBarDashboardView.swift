import SwiftUI
import AppKit

struct MenuBarDashboardView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var usageStore: UsageStore
    var showReport: () -> Void = {}
    var showSettings: () -> Void = {}

    private var strings: AppStrings {
        AppStrings(language: settings.appLanguage)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CuotaBarTheme.canvasTop, CuotaBarTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(strings.appTitle)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(CuotaBarTheme.strongText)
                        Text(settings.displayMode == .minimal ? strings.minimalMode : strings.usagePulseDescription)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(CuotaBarTheme.muted)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            Task { await usageStore.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CuotaBarTheme.strongText)
                        .rotationEffect(.degrees(usageStore.isRefreshing ? 180 : 0))
                        .animation(.easeInOut(duration: 0.5), value: usageStore.isRefreshing)
                        .accessibilityLabel(strings.refreshNow)

                        Button {
                            showReport()
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CuotaBarTheme.strongText)
                        .accessibilityLabel(strings.openReport)

                        Button(action: showSettings) {
                            Image(systemName: "gearshape")
                        }
                        .keyboardShortcut(",", modifiers: .command)
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CuotaBarTheme.strongText)
                        .accessibilityLabel(strings.settings)
                    }
                }

                if usageStore.snapshots.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(strings.connectService)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(CuotaBarTheme.strongText)
                            Text(strings.connectServiceDescription)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(CuotaBarTheme.muted)
                        }
                    }
                } else {
                    ForEach(usageStore.snapshots) { snapshot in
                        ServiceUsageCard(snapshot: snapshot, displayMode: settings.displayMode, strings: strings)
                    }
                }

                if let error = usageStore.lastRefreshError {
                    Text(error)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(CuotaBarTheme.danger)
                }

                Divider()

                Button(strings.quitApp) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CuotaBarTheme.muted)
            }
            .padding(18)
        }
        .frame(width: 360)
    }
}

#if DEBUG
private struct MenuBarDashboardViewPreview: PreviewProvider {
    static var previews: some View {
        MenuBarDashboardView(settings: PreviewSupport.settings, usageStore: PreviewSupport.usageStore)
            .previewDisplayName("Menu Bar Dashboard")
    }
}
#endif
