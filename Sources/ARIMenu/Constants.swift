import Foundation

enum AppConstants {
    static let devServerPort: Int = 3000
    static let devServerHost: String = "localhost"
    static let devServerURL: URL = URL(string: "http://localhost:3000")!

    /// Seconds to wait after `./ari stop` finishes before re-spawning during a
    /// restart, giving the OS time to release the dev port. Starting too soon
    /// makes start()'s port probe believe ARI is still up and skip the spawn.
    static let restartCooldownSeconds: Int = 5
}

enum WindowID {
    static let logs = "logs"
    static let settings = "settings"
}
