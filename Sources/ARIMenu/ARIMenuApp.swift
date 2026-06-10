import SwiftUI

@main
struct ARIMenuApp: App {
    @StateObject private var controller = ARIController()
    @StateObject private var settings = AppSettings.shared
    @Environment(\.openWindow) private var openWindow

    init() {
        if AppSettings.shared.launchAtLogin {
            // Re-register on every launch in case the user moved the .app
            // bundle since last time. Failures here are silent (no UI yet);
            // a subsequent toggle from the menu will surface any error.
            try? LaunchAtLogin.enable()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(controller)
                .environmentObject(settings)
        } label: {
            Image(systemName: controller.state.symbolName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(controller.state.tint)
        }
        .menuBarExtraStyle(.menu)

        Window("ARI Logs", id: WindowID.logs) {
            LogsWindow()
                .environmentObject(controller)
        }
        .defaultSize(width: 720, height: 420)

        Window("ARI Menu Settings", id: WindowID.settings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(controller)
        }
        .defaultSize(width: 560, height: 640)
        .windowResizability(.contentSize)
    }
}
