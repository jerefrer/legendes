import SwiftUI
import AVFoundation

/// Renders an `AVPlayer` through an `AVPlayerLayer` hosted in a layer-backed
/// `NSView`. This deliberately avoids SwiftUI's AVKit `VideoPlayer`, whose
/// `AVPlayerView` Objective-C metadata is not resolvable in a Swift Package
/// executable runtime (it aborts in `getSuperclassMetadata`). `AVPlayerLayer`
/// is pure AVFoundation and renders only the video — our own TransportBar
/// provides the controls, so no native overlay is wanted here anyway.
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerNSView {
        let view = PlayerLayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerNSView, context: Context) {
        nsView.player = player
    }
}

/// A layer-backed view whose backing layer IS an `AVPlayerLayer`, so the video
/// resizes with the view automatically.
final class PlayerLayerNSView: NSView {
    var player: AVPlayer? {
        get { (layer as? AVPlayerLayer)?.player }
        set { (layer as? AVPlayerLayer)?.player = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func makeBackingLayer() -> CALayer {
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
        return playerLayer
    }
}
