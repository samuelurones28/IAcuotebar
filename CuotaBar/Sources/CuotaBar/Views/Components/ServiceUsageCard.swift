import SwiftUI

struct ServiceUsageCard: View {
    let snapshot: UsageSnapshot
    let displayMode: DisplayMode
    let strings: AppStrings

    private var timeText: String {
        snapshot.lastUpdated.formatted(.dateTime.hour().minute().locale(strings.language.locale))
    }

    private var details: String? {
        if let details = snapshot.details { return details }

        var labels: [String] = []
        if let resetAt = snapshot.resetAt {
            let duration = UsageSnapshot.resetDescription(after: Int(resetAt.timeIntervalSince(snapshot.lastUpdated).rounded()))
            labels.append(strings.resetCountdown(duration))
        }
        if snapshot.service == .claudeCode, let percent = snapshot.weeklyPercent {
            labels.append(strings.weeklyUsage(Int(percent)))
        }
        return labels.isEmpty ? nil : labels.joined(separator: " • ")
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: displayMode == .minimal ? 10 : 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        ServiceLogoMark(service: snapshot.service, size: displayMode == .minimal ? 28 : 32)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(snapshot.service.displayName)
                                .font(.system(size: displayMode == .minimal ? 13 : 14, weight: .semibold))
                                .foregroundStyle(CuotaBarTheme.strongText)

                            if displayMode == .normal {
                                Text(strings.statusLabel(snapshot.status))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(snapshot.tint)
                                    .textCase(.lowercase)
                            }
                        }
                    }

                    Spacer()

                    Text("\(Int(snapshot.clampedPercent))%")
                        .font(.system(size: displayMode == .minimal ? 24 : 28, weight: .thin, design: .rounded))
                        .foregroundStyle(CuotaBarTheme.severityColor(for: snapshot.clampedPercent))
                        .contentTransition(.numericText())
                }

                ProgressPill(
                    percent: snapshot.clampedPercent,
                    tint: CuotaBarTheme.progressColor(for: snapshot.clampedPercent, service: snapshot.service)
                )

                if displayMode == .normal {
                    HStack {
                        Text("\(strings.updatedPrefix) \(timeText)")
                            .foregroundStyle(CuotaBarTheme.muted)
                        Spacer()
                        if let details {
                            Text(details)
                                .foregroundStyle(CuotaBarTheme.muted)
                        }
                    }
                    .font(.system(size: 11, weight: .regular))
                }
            }
        }
    }
}
