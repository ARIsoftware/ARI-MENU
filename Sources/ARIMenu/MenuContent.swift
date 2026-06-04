import SwiftUI
import AppKit

struct MenuContent: View {
    @EnvironmentObject var controller: ARIController
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(controller.state.label)

        Divider()

        if controller.ariPathExists {
            Button(startStopTitle) {
                if controller.state.isRunningOrStarting {
                    controller.stop()
                } else {
                    controller.start()
                }
            }
            .keyboardShortcut(controller.state.isRunningOrStarting ? "." : "r")
            .disabled(controller.state.isTransitioning)

            Button("Open ARI in Browser") {
                NSWorkspace.shared.open(AppConstants.devServerURL)
            }
            .keyboardShortcut("o")
            .disabled(controller.state != .running)

            Button("Show Logs…") {
                openWindow(id: WindowID.logs)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("l")
        } else {
            Text("ARI folder not found")
                .foregroundStyle(.secondary)
            Text(settings.ariPath)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("Settings…") {
            openWindow(id: WindowID.settings)
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        LaunchAtLoginToggle()

        Divider()

        Button("Quit ARI Menu") {
            controller.shutdownAndQuit()
        }
        .keyboardShortcut("q")
    }

    private var startStopTitle: String {
        switch controller.state {
        case .running:  return "Stop ARI"
        case .starting: return "Starting…"
        case .stopping: return "Stopping…"
        case .stopped, .unknown: return "Start ARI"
        }
    }
}
