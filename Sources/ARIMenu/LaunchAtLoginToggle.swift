import SwiftUI

struct LaunchAtLoginToggle: View {
    @EnvironmentObject var settings: AppSettings
    let title: String

    init(_ title: String = "Launch at Login") {
        self.title = title
    }

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { settings.launchAtLogin },
            set: { newValue in
                if LaunchAtLogin.apply(newValue) {
                    settings.launchAtLogin = newValue
                }
            }
        ))
    }
}
