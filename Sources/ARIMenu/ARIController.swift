import Foundation
import SwiftUI
import AppKit
import Network

enum ARIState: Equatable {
    case unknown
    case stopped
    case starting
    case running
    case stopping

    var label: String {
        switch self {
        case .unknown:  return "ARI: checking…"
        case .stopped:  return "ARI: stopped"
        case .starting: return "ARI: starting…"
        case .running:  return "ARI: running"
        case .stopping: return "ARI: stopping…"
        }
    }

    var symbolName: String {
        switch self {
        case .running:                       return "circle.fill"
        case .starting, .stopping, .unknown: return "circle.dotted"
        case .stopped:                       return "circle"
        }
    }

    var tint: Color {
        switch self {
        case .running:           return .green
        case .starting:          return .orange
        case .stopping:          return .orange
        case .stopped, .unknown: return .secondary
        }
    }

    var isRunningOrStarting: Bool {
        self == .running || self == .starting
    }

    var isTransitioning: Bool {
        self == .starting || self == .stopping
    }
}

@MainActor
final class ARIController: ObservableObject {
    @Published private(set) var state: ARIState = .unknown
    @Published private(set) var ariPathExists: Bool = false

    private let settings = AppSettings.shared
    private let logStore = LogStore.shared
    private var poller: ARIStatusPoller?
    private var startProcess: Process?
    private var stopProcess: Process?
    private var settingsObserver: NSObjectProtocol?

    init() {
        refreshPathExistence()
        let poller = ARIStatusPoller { [weak self] running in
            Task { @MainActor in
                self?.handlePollerResult(running: running)
            }
        }
        self.poller = poller
        poller.start(interval: settings.pollInterval)

        settingsObserver = NotificationCenter.default.addObserver(
            forName: AppSettings.ariPathDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPathExistence()
            }
        }
    }

    deinit {
        if let token = settingsObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func refreshPathExistence() {
        let ariScript = ariScriptURL().path
        ariPathExists = FileManager.default.fileExists(atPath: ariScript)
    }

    /// Derive state from the world rather than from prior state so the
    /// machine recovers from any transient inconsistency on the next tick.
    private func handlePollerResult(running: Bool) {
        let next: ARIState
        if state == .stopping && stopProcess?.isRunning == true {
            return
        } else if running {
            next = .running
        } else if state == .starting && startProcess?.isRunning == true {
            return
        } else {
            next = .stopped
        }
        if state != next { state = next }
    }

    // MARK: - Start

    func start() {
        guard ariPathExists else { return }
        guard startProcess == nil else { return }

        // If the port is already open, ARI is already running (likely started
        // outside the menu app). Spawning would just crash on port conflict.
        if portIsOpenSync() {
            logStore.appendBanner("ARI already running on :\(AppConstants.devServerPort) — skipping spawn")
            if state != .running { state = .running }
            return
        }

        state = .starting
        logStore.appendBanner("Starting ARI…")

        let process = makeShellProcess("./ari start --verbose")
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                self.startProcess = nil
                self.logStore.appendBanner("ari start exited with code \(proc.terminationStatus)")
                if self.state == .starting { self.state = .stopped }
            }
        }

        do {
            try process.run()
            startProcess = process
        } catch {
            logStore.appendBanner("Failed to spawn ari start: \(error.localizedDescription)")
            state = .stopped
        }
    }

    // MARK: - Stop

    func stop() {
        guard stopProcess == nil else { return }
        state = .stopping
        logStore.appendBanner("Stopping ARI…")

        // SIGTERM our own spawned ./ari start — its signal handler
        // propagates the kill to pnpm dev.
        if let running = startProcess, running.isRunning {
            running.terminate()
        }

        // Kill whatever owns the dev port — covers the case where ARI was
        // started outside the menu app, so we have no Process handle.
        killDevServerPort()

        // Run ./ari stop for Supabase / Postgres teardown. Pipe "y\n" for
        // the interactive postgres prompt.
        let process = makeShellProcess("printf 'y\\n' | ./ari stop")
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.stopProcess = nil
                self.logStore.appendBanner("ari stop finished")
                self.state = .stopped
            }
        }

        do {
            try process.run()
            stopProcess = process
        } catch {
            logStore.appendBanner("Failed to spawn ari stop: \(error.localizedDescription)")
            state = .stopped
        }
    }

    // MARK: - Shutdown

    func shutdownAndQuit() {
        if let running = startProcess, running.isRunning {
            running.terminate()
        }
        if let stopper = stopProcess, stopper.isRunning {
            stopper.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: - Process helpers

    /// Spawns a login-shell so the user's PATH (zsh profile) loads — needed
    /// for pnpm/node/supabase/docker to resolve. `currentDirectoryURL` removes
    /// the need for a `cd '…'` prefix and the shell-quoting that came with it.
    private func makeShellProcess(_ command: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = URL(fileURLWithPath: expandedAriPath)
        let handle = logStore.openForWriting()
        process.standardOutput = handle
        process.standardError = handle
        // Null stdin so any descendant that calls read(stdin) gets EOF
        // instead of hanging the menu app forever.
        process.standardInput = FileHandle.nullDevice
        return process
    }

    private func killDevServerPort() {
        let port = AppConstants.devServerPort
        let killCmd = """
        pids=$(lsof -nP -iTCP:\(port) -sTCP:LISTEN -t 2>/dev/null); \
        if [ -n "$pids" ]; then \
          kill $pids 2>/dev/null; \
          sleep 0.3; \
          remaining=$(lsof -nP -iTCP:\(port) -sTCP:LISTEN -t 2>/dev/null); \
          [ -n "$remaining" ] && kill -9 $remaining 2>/dev/null; \
        fi; \
        exit 0
        """
        let killer = Process()
        killer.executableURL = URL(fileURLWithPath: "/bin/zsh")
        killer.arguments = ["-lc", killCmd]
        try? killer.run()
        // Fire-and-forget; ./ari stop runs long enough that the killer
        // finishes well before then.
    }

    // MARK: - Path helpers

    private var expandedAriPath: String {
        (settings.ariPath as NSString).expandingTildeInPath
    }

    private func ariScriptURL() -> URL {
        URL(fileURLWithPath: expandedAriPath).appendingPathComponent("ari")
    }

    // MARK: - Port probe (sync)

    /// Synchronous port probe used at user-action time. Resolves "localhost"
    /// so both IPv4 and IPv6 are tried — `pnpm dev -H localhost` binds to ::1
    /// only on macOS, so a v4-only probe would miss it.
    private func portIsOpenSync() -> Bool {
        // Signal on `.ready` only; whether the wait timed out tells us
        // whether anything's listening. No shared mutable state, no
        // Sendable warning.
        let semaphore = DispatchSemaphore(value: 0)
        let conn = NWConnection(
            host: NWEndpoint.Host(AppConstants.devServerHost),
            port: NWEndpoint.Port(integerLiteral: UInt16(AppConstants.devServerPort)),
            using: .tcp
        )
        conn.stateUpdateHandler = { state in
            if case .ready = state { semaphore.signal() }
        }
        conn.start(queue: DispatchQueue(label: "ari.software.menu.syncProbe"))
        let outcome = semaphore.wait(timeout: .now() + 0.3)
        conn.cancel()
        return outcome == .success
    }
}
