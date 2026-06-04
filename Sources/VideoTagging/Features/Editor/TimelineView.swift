import SwiftUI
import VideoTaggingCore

struct TimelineView: View {
    let sections: [VideoSection]
    let totalMs: Int
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onDragBoundary: (_ beforeIndex: Int, _ toMs: Int) -> Void
    let onDragEnded: () -> Void

    @Environment(\.theme) private var theme

    private func xOffset(_ ms: Int, width: CGFloat) -> CGFloat {
        CGFloat(ms) / CGFloat(max(totalMs, 1)) * width
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { i, s in
                    let left = xOffset(s.start, width: width)
                    let w = max(2, xOffset(s.end, width: width) - left)
                    RoundedRectangle(cornerRadius: 4 * theme.scale, style: .continuous)
                        .fill(fill(for: s, isCurrent: i == currentIndex))
                        .frame(width: max(0, w - 1.5))
                        .offset(x: left)
                        .onTapGesture { onSelect(i) }
                        .animation(.easeInOut(duration: 0.18), value: currentIndex)
                }
                ForEach(1..<max(sections.count, 1), id: \.self) { i in
                    let bx = xOffset(sections[i].start, width: width)
                    Capsule()
                        .fill(.white)
                        .frame(width: 3 * theme.scale, height: 44 * theme.scale)
                        .overlay(Capsule().strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
                        .offset(x: bx - 1.5 * theme.scale)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .help("Drag to move the boundary")
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                                .onChanged { value in
                                    onDragBoundary(i, Int(value.location.x / width * CGFloat(totalMs)))
                                }
                                .onEnded { _ in onDragEnded() }
                        )
                }
            }
            .coordinateSpace(name: "timeline")
        }
        .frame(height: 44 * theme.scale)
        .background(RoundedRectangle(cornerRadius: 6 * theme.scale, style: .continuous).fill(.quaternary))
        .clipShape(RoundedRectangle(cornerRadius: 6 * theme.scale, style: .continuous))
    }

    private func fill(for s: VideoSection, isCurrent: Bool) -> Color {
        if isCurrent { return theme.accent }
        return s.isEmpty ? theme.gap.opacity(0.5) : Color.secondary.opacity(0.5)
    }
}
