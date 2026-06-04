import Foundation
import ServiceManagement

import AppKit

enum LaunchAtLogin {
    static func enable() throws {
        guard #available(macOS 13.0, *) else { return }
        if SMAppService.mainApp.status != .enabled {
            try SMAppService.mainApp.register()
        }
    }

    static func disable() throws {
        guard #available(macOS 13.0, *) else { return }
        if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }

    static var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// Convenience used by the UI toggle: applies the requested state and, on
    /// failure, surfaces a modal alert with the error. Returns whether the
    /// requested state was actually applied so callers can roll back their UI.
    @MainActor
    @discardableResult
    static func apply(_ enabled: Bool) -> Bool {
        do {
            if enabled { try enable() } else { try disable() }
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = enabled
                ? "Couldn't enable Launch at Login"
                : "Couldn't disable Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }
    }
}
