import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ARIController

    var body: some View {
        Form {
            Section("ARI Repository") {
                HStack {
                    TextField("Path", text: $settings.ariPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") {
                        chooseFolder()
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: controller.ariPathExists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(controller.ariPathExists ? .green : .orange)
                    Text(controller.ariPathExists
                         ? "Found ari script at this path."
                         : "No ari script at this path — pick the folder that contains the ari executable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Network") {
                Toggle("Allow LAN Access", isOn: $settings.allowLanAccess)
                Text("When you start ARI is only available on this computer (localhost). When Allow LAN Access is toggled on, ARI is also accessible from other devices on the same Wi-Fi or LAN.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if controller.state.isRunningOrStarting
                    && settings.allowLanAccess != controller.startedWithLan {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.orange)
                        Text("Stop and start ARI for this change to take effect.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Status Polling") {
                HStack {
                    Slider(value: $settings.pollInterval, in: 2...30, step: 1)
                    Text("\(Int(settings.pollInterval))s")
                        .font(.caption.monospacedDigit())
                        .frame(width: 32, alignment: .trailing)
                }
                Text("How often to check whether ARI is running. Lower = more responsive, slightly more CPU.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                LaunchAtLoginToggle("Launch ARI Menu at login")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 520, minHeight: 600)
        .onChange(of: settings.ariPath) { _ in
            controller.refreshPathExistence()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose ARI Folder"
        if panel.runModal() == .OK, let url = panel.url {
            settings.ariPath = url.path
        }
    }
}
