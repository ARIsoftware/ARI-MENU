import SwiftUI
import AppKit

struct LogsWindow: View {
    @StateObject private var store = LogStore.shared
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ARI Log")
                    .font(.headline)
                Text(store.logFileURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
                    .lineLimit(1)
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                Button("Copy") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(store.lines.map(\.text).joined(separator: "\n"), forType: .string)
                }
                Button("Clear") { store.clear() }
            }
            .padding(8)
            .background(.bar)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Stable per-line IDs survive buffer pruning — SwiftUI
                        // can reuse rows instead of re-creating every one when
                        // `removeFirst` slides the window.
                        ForEach(store.lines) { line in
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: store.lines.count) { _ in
                    if autoScroll {
                        withAnimation(.linear(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}
