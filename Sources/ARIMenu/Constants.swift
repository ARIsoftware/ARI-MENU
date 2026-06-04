import Foundation

enum AppConstants {
    static let devServerPort: Int = 3000
    static let devServerHost: String = "localhost"
    static let devServerURL: URL = URL(string: "http://localhost:3000")!
}

enum WindowID {
    static let logs = "logs"
    static let settings = "settings"
}
