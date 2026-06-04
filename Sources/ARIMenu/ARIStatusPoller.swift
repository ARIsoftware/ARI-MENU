import Foundation
import Network

/// Polls whether the ARI dev server is reachable on localhost:3000.
/// Cheap TCP connect check, runs every `AppSettings.shared.pollInterval` seconds.
final class ARIStatusPoller {
    private let onResult: (Bool) -> Void
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "ari.software.menu.poller")

    init(onResult: @escaping (Bool) -> Void) {
        self.onResult = onResult
    }

    func start(interval: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.checkOnce()
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func checkOnce() {
        // Probe by name ("localhost"), not IP literal, so Network.framework
        // tries both 127.0.0.1 and ::1. `pnpm dev -H localhost` binds to ::1
        // only on macOS, so a v4-only probe would never see it.
        let host = NWEndpoint.Host(AppConstants.devServerHost)
        let port = NWEndpoint.Port(integerLiteral: UInt16(AppConstants.devServerPort))
        let conn = NWConnection(host: host, port: port, using: .tcp)
        var settled = false

        let finish: (Bool) -> Void = { [weak self] reachable in
            guard !settled else { return }
            settled = true
            conn.cancel()
            self?.onResult(reachable)
        }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true)
            case .failed, .cancelled:
                finish(false)
            default:
                break
            }
        }
        conn.start(queue: queue)

        // Hard timeout — if the connect hangs (unlikely on localhost), bail.
        queue.asyncAfter(deadline: .now() + 1.0) {
            finish(false)
        }
    }
}
