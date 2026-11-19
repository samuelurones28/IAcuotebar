import SwiftUI

struct FloatingWidgetView: View {
    @ObservedObject var usageStore: UsageStore
    @ObservedObject var settings: SettingsStore
    var onOpenSettings: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme

    private struct WidgetUsageRow: Identifiable {
        let id: String
        let service: ServiceKind
        let title: String
        let percent: Double
        let status: UsageStatus
        let isWeekly: Bool
        let resetAt: Date?

        var barTint: Color {
            isWeekly ? service.weeklyColor : CuotaBarTheme.progressColor(for: percent, service: service)
        }

        var percentageTint: Color {
            isWeekly ? CuotaBarTheme.weeklyText : CuotaBarTheme.severityColor(for: percent)
        }

        func resetLabel(in locale: Locale) -> String? {
            guard let date = resetAt else { return nil }
            let remaining = date.timeIntervalSinceNow
            guard remaining > 0 else { return nil }

            if isWeekly {
                return date.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated).hour().minute().locale(locale))
            } else {
                return UsageSnapshot.resetDescription(after: Int(remaining))
            }
        }
    }

    private var strings: AppStrings {
        AppStrings(language: settings.appLanguage)
    }

    private var layout: WidgetLayout {
        WidgetLayout(
            style: .card,
            displayMode: settings.displayMode,
            widgetSize: settings.widgetSize
        )
    }

    var body: some View {
        if settings.widgetStyle == .edge {
            EdgeWidgetView(
                usageStore: usageStore,
                settings: settings,
                onOpenSettings: onOpenSettings
            )
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: layout.cardRowSpacing) {
            if settings.displayMode == .normal {
                HStack {
                    Text(strings.appTitle)
                        .font(.system(size: settings.widgetSize == .small ? 12 : 13, weight: .medium))
                        .foregroundStyle(CuotaBarTheme.muted)
                    Spacer()
                    Image(systemName: "capsule.lefthalf.filled")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CuotaBarTheme.accent)
                }
            }

            if usageStore.snapshots.isEmpty {
                Text(strings.connectServicesWidget)
                    .font(.system(size: settings.widgetSize == .small ? 11 : 12, weight: .medium))
                    .foregroundStyle(CuotaBarTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(widgetRows) { row in
                    if settings.displayMode == .minimal {
                        MinimalWidgetRow(row: row, widgetSize: settings.widgetSize, strings: strings)
                    } else {
                        NormalWidgetRow(row: row, widgetSize: settings.widgetSize, locale: strings.language.locale)
                    }
                }
            }
        }
        .padding(layout.cardPadding)
        .frame(width: layout.width)
        .background(
            widgetBackground
        )
        .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
        .onTapGesture(count: 2, perform: onOpenSettings)
    }

    private var widgetRows: [WidgetUsageRow] {
        orderedSnapshots.flatMap { snapshot in
            var rows = [
                WidgetUsageRow(
                    id: "\(snapshot.service.rawValue)-primary",
                    service: snapshot.service,
                    title: snapshot.service.displayName,
                    percent: snapshot.clampedPercent,
                    status: snapshot.status,
                    isWeekly: false,
                    resetAt: snapshot.resetAt
                )
            ]

            if settings.showsWeeklyLimitInWidget(for: snapshot.service),
               let weeklyPercent = snapshot.clampedWeeklyPercent {
                rows.append(
                    WidgetUsageRow(
                        id: "\(snapshot.service.rawValue)-weekly",
                        service: snapshot.service,
                        title: strings.weeklyLabel,
                        percent: weeklyPercent,
                        status: UsageSnapshot.status(for: weeklyPercent),
                        isWeekly: true,
                        resetAt: snapshot.weeklyResetAt
                    )
                )
            }

            return rows
        }
    }

    private var orderedSnapshots: [UsageSnapshot] {
        settings.orderedWidgetServices.compactMap { service in
            usageStore.snapshots.first { $0.service == service }
        }
    }

    private struct NormalWidgetRow: View {
        let row: WidgetUsageRow
        let widgetSize: WidgetSize
        let locale: Locale
        @State private var isHovered = false

        private var logoSize: CGFloat { widgetSize == .small ? 18 : 20 }
        private var fontSize: CGFloat { widgetSize == .small ? 12 : 13 }
        private var percentFontSize: CGFloat { widgetSize == .small ? 14 : 16 }
        private var rowHeight: CGFloat { widgetSize == .small ? 18 : 22 }

        var body: some View {
            let resetLabel = isHovered ? row.resetLabel(in: locale) : nil

            HStack(spacing: 10) {
                ServiceLogoMark(service: row.service, size: logoSize)

                Text(row.title)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(CuotaBarTheme.strongText)
                    .frame(width: 84, alignment: .leading)

                ZStack {
                    ProgressPill(percent: row.percent, tint: row.barTint)
                        .frame(height: 6)
                        .opacity(resetLabel == nil ? 1 : 0)

                    if let label = resetLabel {
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CuotaBarTheme.strongText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 4)
                    }
                }

                Text("\(Int(row.percent))%")
                    .font(.system(size: percentFontSize, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(row.percentageTint)
                    .frame(width: 42, alignment: .trailing)
            }
            .frame(height: rowHeight)
            .onHover { isHovered = $0 }
        }
    }

    private struct MinimalWidgetRow: View {
        let row: WidgetUsageRow
        let widgetSize: WidgetSize
        let strings: AppStrings
        @State private var isHovered = false

        private var logoSize: CGFloat { widgetSize == .small ? 18 : 20 }
        private var percentFontSize: CGFloat { widgetSize == .small ? 20 : 24 }
        private var percentWidth: CGFloat { widgetSize == .small ? 58 : 70 }
        private var rowHeight: CGFloat { widgetSize == .small ? 22 : 26 }

        var body: some View {
            HStack(spacing: 10) {
                ServiceLogoMark(service: row.service, size: logoSize)

                if isHovered, let label = row.resetLabel(in: strings.language.locale) {
                    Text(label)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CuotaBarTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Spacer(minLength: 0)

                    if row.isWeekly {
                        Text(strings.weeklyShortLabel)
                            .font(.system(size: widgetSize == .small ? 10 : 11, weight: .semibold))
                            .foregroundStyle(CuotaBarTheme.muted)
                    }

                    Text("\(Int(row.percent))%")
                        .font(.system(size: percentFontSize, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(row.percentageTint)
                        .frame(width: percentWidth, alignment: .trailing)
                }
            }
            .frame(height: rowHeight)
            .onHover { isHovered = $0 }
        }
    }

    private var widgetBackground: some View {
        let shape = RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)

        return ZStack {
            shape
                .fill(Color.black.opacity(colorScheme == .light ? 0.55 : 0.34))

            shape
                .fill(.ultraThinMaterial)

            shape
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .compositingGroup()
        .opacity(settings.widgetOpacity)
        .shadow(color: .black.opacity(0.22 * settings.widgetOpacity), radius: 24, y: 8)
    }
}

#if DEBUG
private struct FloatingWidgetViewPreview: PreviewProvider {
    static var previews: some View {
        FloatingWidgetView(usageStore: PreviewSupport.usageStore, settings: PreviewSupport.settings)
            .padding()
            .background(Color.black)
            .previewDisplayName("Floating Widget")
    }
}
#endif
