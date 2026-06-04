import SwiftUI
import VideoTaggingCore

struct TopBar: View {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let isListVisible: Bool
    let onToggleList: () -> Void

    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        HStack(spacing: theme.s) {
            BigButton(title: Strings.undo, systemImage: "arrow.uturn.backward", action: onUndo)
                .disabled(!canUndo)
            BigButton(title: Strings.redo, systemImage: "arrow.uturn.forward", action: onRedo)
                .disabled(!canRedo)

            Spacer()

            Picker("", selection: $settings.interfaceSize) {
                Text("A").font(.system(size: 12)).tag(InterfaceSize.comfortable)
                Text("A").font(.system(size: 15)).tag(InterfaceSize.large)
                Text("A").font(.system(size: 18)).tag(InterfaceSize.extraLarge)
            }
            .pickerStyle(.segmented)
            .frame(width: 130 * theme.scale)
            .help("Interface size")

            Picker("", selection: $settings.appearance) {
                Image(systemName: "circle.lefthalf.filled").tag(AppearanceMode.system)
                Image(systemName: "sun.max").tag(AppearanceMode.light)
                Image(systemName: "moon").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)
            .frame(width: 130 * theme.scale)
            .help("Appearance")

            BigButton(title: isListVisible ? Strings.hideList : Strings.showList,
                      systemImage: "sidebar.right", action: onToggleList)
        }
    }
}
