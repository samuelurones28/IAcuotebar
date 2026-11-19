import SwiftUI

struct EdgeWidgetView: View {
    @ObservedObject var usageStore: UsageStore
    @ObservedObject var settings: SettingsStore
    let onOpenSettings: () -> Void
    @State private var isSettingsHovered = false

    private var strings: AppStrings { AppStrings(language: settings.appLanguage) }

    private var layout: WidgetLayout {
        WidgetLayout(style: .edge, displayMode: settings.displayMode, widgetSize: settings.widgetSize)
    }

    var body: some View {
        let isRight = settings.widgetPosition.isRight
        let barFill = Color(white: 0.02).opacity(settings.widgetOpacity)

        VStack(spacing: -layout.edgeSettingsOverlap) {
            VStack(spacing: layout.edgeRowSpacing) {
                ForEach(settings.orderedWidgetServices) { service in
                    let snapshot = usageStore.snapshots.first { $0.service == service }
                    meter(service, percent: snapshot?.clampedPercent, resetsAt: snapshot?.resetAt)

                    if settings.showsWeeklyLimitInWidget(for: service),
                       let percent = snapshot?.clampedWeeklyPercent {
                        meter(service, percent: percent, resetsAt: snapshot?.weeklyResetAt, weekly: true)
                    }
                }
            }
            .padding(.top, layout.edgeTopPadding)
            .padding(.bottom, layout.edgeBottomPadding)
            .frame(width: layout.width)
            .background {
                EdgeWidgetSilhouette(isRight: isRight).fill(barFill)
            }

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: layout.edgeSettingsButtonSize * 0.48))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: layout.edgeSettingsButtonSize, height: layout.edgeSettingsButtonSize)
                    .background {
                        Circle().fill(isSettingsHovered ? Color(white: 0.12).opacity(settings.widgetOpacity) : barFill)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { isSettingsHovered = $0 }
            .accessibilityLabel(strings.settings)
            .help(strings.settings)
            .offset(x: layout.width * (isRight ? 0.16 : -0.16))
        }
    }

    private func meter(
        _ service: ServiceKind,
        percent: Double?,
        resetsAt: Date?,
        weekly: Bool = false
    ) -> some View {
        let ringSize = layout.edgeRingSize
        let amount = percent.map { "\(Int($0))%" } ?? "—"
        let label = weekly ? "\(service.displayName) · \(strings.weeklyLabel)" : service.displayName
        let value = percent == nil ? strings.widgetUsageUnavailable : amount
        let reset = resetsAt.map { $0.formatted(.dateTime.year().month().day().hour().minute().locale(strings.language.locale)) }
        let tooltip = [label, value, reset.map(strings.resetTime)].compactMap { $0 }
            .joined(separator: "\n")
        let tint: Color = switch (weekly, service) {
        case (true, _): Color(red: 0.90, green: 0.94, blue: 0.31)
        case (false, .codex): Color(red: 0.32, green: 0.82, blue: 0.62)
        case (false, .claudeCode): Color(red: 0.94, green: 0.37, blue: 0.20)
        }

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.17), lineWidth: 2.5)

                if let percent, percent > 0 {
                    Circle()
                        .inset(by: 1.25)
                        .trim(from: 0, to: percent / 100)
                        .stroke(percent > 90 ? CuotaBarTheme.danger : tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                ServiceLogoGlyph(service: service, size: ringSize * 0.43)
                    .opacity(percent == nil ? 0.6 : 1)
            }
            .frame(width: ringSize, height: ringSize)

            HStack(spacing: 2) {
                if weekly {
                    Text(strings.weeklyShortLabel)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(amount)
                    .font(.system(size: settings.widgetSize == .small ? 10 : 12))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(percent == nil ? 0.62 : 0.94))
            }
        }
        .frame(height: layout.rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .help(tooltip)
    }
}

private struct EdgeWidgetSilhouette: Shape {
    let isRight: Bool

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let inflection = CGPoint(x: width * 0.47, y: width * 0.62)
        let curveHeight = width * 1.22

        let outline = Path { path in
            path.move(to: CGPoint(x: width, y: 0))
            path.addCurve(
                to: inflection,
                control1: CGPoint(x: width, y: width * 0.40),
                control2: CGPoint(x: width * 0.76, y: inflection.y)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: curveHeight),
                control1: CGPoint(x: width * 0.16, y: inflection.y),
                control2: CGPoint(x: 0, y: width * 0.85)
            )
            path.addLine(to: CGPoint(x: 0, y: height - curveHeight))
            path.addCurve(
                to: CGPoint(x: inflection.x, y: height - inflection.y),
                control1: CGPoint(x: 0, y: height - width * 0.85),
                control2: CGPoint(x: width * 0.16, y: height - inflection.y)
            )
            path.addCurve(
                to: CGPoint(x: width, y: height),
                control1: CGPoint(x: width * 0.76, y: height - inflection.y),
                control2: CGPoint(x: width, y: height - width * 0.40)
            )
            path.closeSubpath()
        }

        let transform = isRight
            ? CGAffineTransform(translationX: rect.minX, y: rect.minY)
            : CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.maxX, ty: rect.minY)
        return outline.applying(transform)
    }
}
