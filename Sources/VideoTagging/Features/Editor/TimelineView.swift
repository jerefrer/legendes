import SwiftUI
import VideoTaggingCore

struct TimelineView: View {
    let sections: [VideoSection]
    let totalMs: Int
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onDragBoundary: (_ beforeIndex: Int, _ toMs: Int) -> Void

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
                    Rectangle()
                        .fill(color(for: s, isCurrent: i == currentIndex))
                        .frame(width: w)
                        .offset(x: left)
                        .onTapGesture { onSelect(i) }
                }
                // Draggable handles at internal boundaries
                ForEach(1..<max(sections.count, 1), id: \.self) { i in
                    let bx = xOffset(sections[i].start, width: width)
                    Rectangle()
                        .fill(Theme.Colors.timelineHandle)
                        .frame(width: 3)
                        .offset(x: bx - 1.5)
                        .help("Drag to move the boundary")
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let ms = Int(value.location.x / width * CGFloat(totalMs))
                                    onDragBoundary(i, ms)
                                }
                        )
                }
            }
        }
        .frame(height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func color(for s: VideoSection, isCurrent: Bool) -> Color {
        if isCurrent { return Theme.Colors.accent }
        return s.isEmpty ? Theme.Colors.gapSection : Theme.Colors.panel
    }
}
