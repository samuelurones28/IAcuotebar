import AppKit
import SwiftUI

@MainActor
final class WidgetWindowController {
    private var panel: NSPanel?
    private var lastAppliedSize: NSSize?
    private var lastAppliedPosition: WidgetPosition?
    private var lastAppliedLevel: NSWindow.Level?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func update(using usageStore: UsageStore, settings: SettingsStore, onOpenSettings: @escaping () -> Void) {
        // AppKit can lay out the hosting view synchronously when the panel changes size.
        DispatchQueue.main.async { [weak self] in
            self?.applyUpdate(using: usageStore, settings: settings, onOpenSettings: onOpenSettings)
        }
    }

    private func applyUpdate(using usageStore: UsageStore, settings: SettingsStore, onOpenSettings: @escaping () -> Void) {
        guard settings.widgetEnabled else {
            panel?.orderOut(nil)
            return
        }

        let layout = WidgetLayout(
            style: settings.widgetStyle,
            displayMode: settings.displayMode,
            widgetSize: settings.widgetSize
        )

        if panel == nil {
            panel = makePanel(usageStore: usageStore, settings: settings, onOpenSettings: onOpenSettings)
        }
        guard let panel else { return }

        let rowCount = layout.rowCount(for: usageStore.snapshots, showsWeekly: settings.showsWeeklyLimitInWidget)
        let newSize = NSSize(width: layout.width, height: layout.height(forRowCount: rowCount))
        let newLevel: NSWindow.Level = settings.widgetAlwaysOnTop ? .floating : .normal
        let shouldApplySize = lastAppliedSize != newSize

        panel.isMovableByWindowBackground = settings.widgetStyle == .card
        if shouldApplySize {
            panel.setContentSize(newSize)
            lastAppliedSize = newSize
        }
        if lastAppliedLevel != newLevel {
            panel.level = newLevel
            lastAppliedLevel = newLevel
        }
        if lastAppliedPosition != settings.widgetPosition || shouldApplySize {
            updatePanelOrigin(for: panel, position: settings.widgetPosition, style: settings.widgetStyle)
            lastAppliedPosition = settings.widgetPosition
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func makePanel(usageStore: UsageStore, settings: SettingsStore, onOpenSettings: @escaping () -> Void) -> NSPanel {
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = NSPanel(
            contentRect: NSRect(x: 40, y: 120, width: 210, height: 84),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .normal
        panel.contentViewController = NSHostingController(
            rootView: FloatingWidgetView(usageStore: usageStore, settings: settings, onOpenSettings: onOpenSettings)
        )
        return panel
    }

    private func updatePanelOrigin(for panel: NSPanel, position: WidgetPosition, style: WidgetStyle) {
        guard let screen = targetScreen(for: panel) else { return }

        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 20
        let horizontalFrame = style == .edge ? screen.frame : visibleFrame
        let sideMargin: CGFloat = style == .edge ? 0 : margin
        let size = panel.frame.size

        let x = position.isRight ? horizontalFrame.maxX - size.width - sideMargin : horizontalFrame.minX + sideMargin
        let y = switch position {
        case .topLeft, .topRight:
            visibleFrame.maxY - size.height - margin
        case .centerLeft, .centerRight:
            visibleFrame.midY - size.height / 2
        case .bottomLeft, .bottomRight:
            visibleFrame.minY + margin
        }
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }

    @objc private func screenParametersDidChange() {
        guard let panel, !panel.isMovableByWindowBackground, let position = lastAppliedPosition else { return }
        updatePanelOrigin(for: panel, position: position, style: .edge)
    }

    private func targetScreen(for panel: NSPanel) -> NSScreen? {
        let panelFrame = panel.frame

        if let matchingScreen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panelFrame) }) {
            return matchingScreen
        }

        return panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    }
}
