import AppKit
import SwiftUI

@main
struct CuotaBarApp: App {
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        Task { @MainActor in
            model.start()
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { model.menuBarEnabled },
            set: { value in model.setMenuBarEnabledFromUI(value) }
        )) {
            MenuBarDashboardView(
                settings: model.settings,
                usageStore: model.usageStore,
                showReport: model.showReportWindow,
                showSettings: model.showSettingsWindow
            )
        } label: {
            Label {
                Text(model.menuBarTitle)
            } icon: {
                if let menuBarIconImage {
                    Image(nsImage: menuBarIconImage)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIconImage: NSImage? {
        guard
            let url = Bundle.moduleResources.url(
                forResource: "menu-icon-18",
                withExtension: "png",
                subdirectory: "Assets.xcassets/MenuBarIcon.imageset"
            ),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
