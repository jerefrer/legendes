import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onOpen: ([URL]) -> Void
    let errorMessage: String?
    @State private var isTargeted = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.l) {
            Image(systemName: "film.stack")
                .font(.system(size: 64 * theme.scale))
                .foregroundStyle(theme.accent.gradient)
            Text(Strings.DropZone.title).font(theme.font(30, .semibold))
            Text(Strings.DropZone.subtitle)
                .font(theme.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(theme.body)
                    .foregroundStyle(theme.error)
                    .multilineTextAlignment(.center)
                    .padding(.top, theme.s)
            }
        }
        .padding(theme.xl + theme.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? AnyShapeStyle(theme.accent.opacity(0.12)) : AnyShapeStyle(.regularMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundStyle(isTargeted ? theme.accent : theme.separator)
        )
        .contentShape(Rectangle())
        .onTapGesture { pickFiles() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            collectURLs(from: providers); return true
        }
        .padding(theme.l)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    private func collectURLs(from providers: [NSItemProvider]) {
        let urls = URLBox()
        let group = DispatchGroup()
        for p in providers.prefix(2) {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let collected = urls.snapshot()
            if !collected.isEmpty { onOpen(collected) }
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie,
                                     UTType(filenameExtension: "srt") ?? .plainText]
        if panel.runModal() == .OK {
            onOpen(Array(panel.urls.prefix(2)))
        }
    }
}

/// Thread-safe URL accumulator for concurrent NSItemProvider completions.
private final class URLBox: @unchecked Sendable {
    private var urls: [URL] = []
    private let lock = NSLock()
    func append(_ url: URL) { lock.lock(); urls.append(url); lock.unlock() }
    func snapshot() -> [URL] { lock.lock(); defer { lock.unlock() }; return urls }
}
