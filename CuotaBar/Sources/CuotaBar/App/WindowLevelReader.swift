import AppKit
import SwiftUI

struct WindowLevelReader: NSViewRepresentable {
    let level: NSWindow.Level

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applyLevelIfNeeded(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyLevelIfNeeded(from: nsView)
        }
    }

    /// Only touches the window when something changed; reapplying on every SwiftUI
    /// update causes AppKit layout churn.
    private func applyLevelIfNeeded(from view: NSView) {
        guard let window = view.window else { return }

        if window.level != level {
            window.level = level
        }

        if !window.collectionBehavior.contains(.fullScreenAuxiliary) {
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        }
    }
}
