import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onOpen: ([URL]) -> Void
    let errorMessage: String?
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(Strings.DropZone.title).font(.system(size: 30, weight: .semibold))
            Text(Strings.DropZone.subtitle)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.s)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Theme.Colors.accent.opacity(0.15) : Color(white: 0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10]))
                .foregroundStyle(Theme.Colors.panelBorder)
        )
        .contentShape(Rectangle())
        .onTapGesture { pickFiles() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            collectURLs(from: providers); return true
        }
        .padding(Theme.Spacing.l)
    }

    private func collectURLs(from providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        for p in providers.prefix(2) {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { if !urls.isEmpty { onOpen(urls) } }
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
