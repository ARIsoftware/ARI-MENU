import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let ariPathDidChange = Notification.Name("ari.software.menu.ariPathDidChange")

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let ariPath = "ariPath"
        static let launchAtLogin = "launchAtLogin"
        static let pollInterval = "pollInterval"
        static let allowLanAccess = "allowLanAccess"
    }

    @Published var ariPath: String {
        didSet {
            defaults.set(ariPath, forKey: Keys.ariPath)
            NotificationCenter.default.post(name: AppSettings.ariPathDidChange, object: nil)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var pollInterval: Double {
        didSet { defaults.set(pollInterval, forKey: Keys.pollInterval) }
    }

    @Published var allowLanAccess: Bool {
        didSet { defaults.set(allowLanAccess, forKey: Keys.allowLanAccess) }
    }

    private init() {
        self.ariPath = defaults.string(forKey: Keys.ariPath) ?? "~/ARI"

        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            defaults.set(true, forKey: Keys.launchAtLogin)
        }
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        let storedInterval = defaults.double(forKey: Keys.pollInterval)
        self.pollInterval = storedInterval > 0 ? storedInterval : 5.0

        self.allowLanAccess = defaults.bool(forKey: Keys.allowLanAccess)
    }
}
