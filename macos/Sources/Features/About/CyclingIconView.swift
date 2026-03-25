import SwiftUI
import GhosttyKit
import Combine

/// A view that cycles through Ghostty's official icon variants.
struct CyclingIconView: View {
    @EnvironmentObject var viewModel: AboutViewModel

    var body: some View {
        ZStack {
            iconView(for: viewModel.currentIcon)
                .id(viewModel.currentIcon)
        }
        .animation(.easeInOut(duration: 0.5), value: viewModel.currentIcon)
        .frame(height: 128)
        .onHover { hovering in
            viewModel.isHovering = hovering
        }
        .onTapGesture {
            viewModel.advanceToNextIcon()
        }
        .contextMenu {
            if let currentIcon = viewModel.currentIcon {
                Button("Copy Icon Config") {
                    NSPasteboard.general.setString("macos-icon = \(currentIcon.rawValue)", forType: .string)
                }
            }
        }
        .accessibilityLabel("Ghostty Application Icon")
        .accessibilityHint("Click to cycle through icon variants")
    }

    @ViewBuilder
    private func iconView(for icon: Ghostty.MacOSIcon?) -> some View {
        let iconImage: Image = if
            let icon,
            let appIcon = AppIcon(icon),
            let nsImage = appIcon.image(in: .main)
        {
            Image(nsImage: nsImage)
        } else if let assetName = icon?.assetName {
            Image(assetName)
        } else {
            ghosttyIconImage()
        }

        iconImage
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
