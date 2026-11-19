import CoreGraphics

struct WidgetLayout {
    let style: WidgetStyle
    let displayMode: DisplayMode
    let widgetSize: WidgetSize

    var width: CGFloat {
        if style == .edge {
            return widgetSize == .small ? 46 : 52
        }

        return switch (displayMode, widgetSize) {
        case (.minimal, .small):
            152
        case (.minimal, .medium):
            176
        case (.normal, .small):
            240
        case (.normal, .medium):
            290
        }
    }

    var rowHeight: CGFloat {
        if style == .edge {
            return widgetSize == .small ? 46 : 52
        }

        return switch (displayMode, widgetSize) {
        case (.minimal, .small):
            22
        case (.minimal, .medium):
            26
        case (.normal, .small):
            18
        case (.normal, .medium):
            22
        }
    }

    var topAreaHeight: CGFloat {
        displayMode == .minimal ? 0 : 34
    }

    var verticalPadding: CGFloat {
        widgetSize == .small ? 28 : 36
    }

    var cardPadding: CGFloat {
        widgetSize == .small ? 14 : 18
    }

    /// Must match the VStack spacing in FloatingWidgetView.card.
    var cardRowSpacing: CGFloat { 10 }

    var cornerRadius: CGFloat {
        widgetSize == .small ? 20 : 24
    }

    var edgeRowSpacing: CGFloat { widgetSize == .small ? 22 : 26 }
    var edgeTopPadding: CGFloat { widgetSize == .small ? 48 : 54 }
    var edgeBottomPadding: CGFloat { widgetSize == .small ? 40 : 45 }
    var edgeSettingsOverlap: CGFloat { widgetSize == .small ? 10 : 11 }
    var edgeSettingsButtonSize: CGFloat { widgetSize == .small ? 26 : 28 }
    var edgeRingSize: CGFloat { widgetSize == .small ? 28 : 32 }

    func rowCount(for snapshots: [UsageSnapshot], showsWeekly: (ServiceKind) -> Bool) -> Int {
        let primaryCount = style == .edge ? ServiceKind.allCases.count : snapshots.count
        return snapshots.reduce(primaryCount) { count, snapshot in
            count + (showsWeekly(snapshot.service) && snapshot.clampedWeeklyPercent != nil ? 1 : 0)
        }
    }

    func height(forRowCount rowCount: Int) -> CGFloat {
        let count = CGFloat(max(rowCount, 1))
        if style == .edge {
            return count * rowHeight + (count - 1) * edgeRowSpacing
                + edgeTopPadding + edgeBottomPadding + edgeSettingsButtonSize - edgeSettingsOverlap
        }
        return topAreaHeight + count * rowHeight + (count - 1) * cardRowSpacing + verticalPadding
    }
}
