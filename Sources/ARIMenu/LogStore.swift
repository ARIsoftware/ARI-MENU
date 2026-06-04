import Foundation
import Combine

struct LogLine: Identifiable, Equatable {
    let id: UUID = UUID()
    let text: String
}

/// Owns the log file at ~/Library/Logs/ARIMenu/ari.log.
/// Both ARIController (write side) and LogsWindow (read side) talk to this.
@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var lines: [LogLine] = []

    private static let bannerFormatter: ISO8601DateFormatter = ISO8601DateFormatter()

    private let maxLines = 2000
    private let maxFileBytes = 10 * 1024 * 1024
    private let truncationKeepBytes = 1 * 1024 * 1024
    private let tailLoadBytes = 256 * 1024

    private var readSource: DispatchSourceFileSystemObject?
    private var readPosition: UInt64 = 0
    private var pendingBuffer = ""

    let logFileURL: URL

    init() {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("ARIMenu", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logFileURL = logsDir.appendingPathComponent("ari.log")
        truncateIfOversized()
        loadTail()
        startWatching()
    }

    deinit {
        readSource?.cancel()
    }

    // MARK: - Write side

    /// FileHandle opened with O_APPEND so multi-Process concurrent writes are
    /// atomically appended by the kernel — log lines from start, stop, and the
    /// port-killer subshell can't interleave mid-line.
    func openForWriting() -> FileHandle {
        let fd = open(logFileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard fd >= 0 else { return FileHandle.standardError }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    func appendBanner(_ text: String) {
        let stamp = LogStore.bannerFormatter.string(from: Date())
        let line = "\n── \(stamp) — \(text) ──\n"
        guard let data = line.data(using: .utf8) else { return }
        let handle = openForWriting()
        try? handle.write(contentsOf: data)
        try? handle.close()
    }

    private func truncateIfOversized() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)
        let size = (attrs?[.size] as? Int) ?? 0
        guard size > maxFileBytes else { return }
        guard let handle = try? FileHandle(forReadingFrom: logFileURL) else { return }
        defer { try? handle.close() }
        let keep = max(0, size - truncationKeepBytes)
        try? handle.seek(toOffset: UInt64(keep))
        let tail = handle.availableData
        try? tail.write(to: logFileURL, options: .atomic)
    }

    // MARK: - Read side

    /// Read only the last ~256KB of the file (well over 2000 lines of typical
    /// output) instead of reading the entire 10MB. Drop the first partial line.
    private func loadTail() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? Int, size > 0 else { return }
        readPosition = UInt64(size)
        guard let handle = try? FileHandle(forReadingFrom: logFileURL) else { return }
        defer { try? handle.close() }
        let offset = max(0, size - tailLoadBytes)
        try? handle.seek(toOffset: UInt64(offset))
        let data = handle.availableData
        guard let text = String(data: data, encoding: .utf8) else { return }
        var parts = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if offset > 0, !parts.isEmpty { parts.removeFirst() } // drop partial head
        if parts.last == "" { parts.removeLast() }
        lines = parts.suffix(maxLines).map { LogLine(text: $0) }
    }

    private func startWatching() {
        let fd = open(logFileURL.path, O_EVTONLY)
        guard fd != -1 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.readAppended() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        readSource = source
    }

    private func readAppended() {
        guard let handle = try? FileHandle(forReadingFrom: logFileURL) else { return }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: readPosition)
        } catch {
            // File truncated or rotated under us — reload from scratch.
            readPosition = 0
            try? handle.seek(toOffset: 0)
        }
        let data = handle.availableData
        guard !data.isEmpty else { return }
        readPosition += UInt64(data.count)
        guard let text = String(data: data, encoding: .utf8) else { return }
        pendingBuffer += text
        let parts = pendingBuffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else { return }
        pendingBuffer = parts.last ?? ""
        let newLines = parts.dropLast().map { LogLine(text: $0) }
        lines.append(contentsOf: newLines)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func clear() {
        try? Data().write(to: logFileURL)
        readPosition = 0
        pendingBuffer = ""
        lines = []
    }
}
