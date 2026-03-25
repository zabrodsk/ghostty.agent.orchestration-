import AppKit
import System

/// The icon style for the Ghostty App.
enum AppIcon: Equatable, Codable {
    case official
    case beta
    case blueprint
    case chalkboard
    case glass
    case holographic
    case microchip
    case paper
    case retro
    case xray
    /// Save full image data to avoid sandboxing issues
    case custom(_ iconFile: Data)
    case customStyle(_ icon: ColorizedGhosttyIcon)

    init?(_ icon: Ghostty.MacOSIcon) {
        switch icon {
        case .official:
            return nil
        case .beta:
            self = .beta
        case .blueprint:
            self = .blueprint
        case .chalkboard:
            self = .chalkboard
        case .glass:
            self = .glass
        case .holographic:
            self = .holographic
        case .microchip:
            self = .microchip
        case .paper:
            self = .paper
        case .retro:
            self = .retro
        case .xray:
            self = .xray
        case .custom, .customStyle:
            return nil
        }
    }

#if !DOCK_TILE_PLUGIN
    init?(config: Ghostty.Config) {
        if let icon = Self(config.macosIcon) {
            self = icon
            return
        }

        switch config.macosIcon {
        case .custom:
            if let data = try? Data(contentsOf: URL(filePath: config.macosCustomIcon, relativeTo: nil)) {
                self = .custom(data)
            } else {
                return nil
            }
        case .customStyle:
            // Discard saved icon name
            // if no valid colours were found
            guard
                let ghostColor = config.macosIconGhostColor,
                let screenColors = config.macosIconScreenColor
            else {
                return nil
            }
            self = .customStyle(ColorizedGhosttyIcon(screenColors: screenColors, ghostColor: ghostColor, frame: config.macosIconFrame))
        case .official, .beta, .blueprint, .chalkboard, .glass, .holographic, .microchip, .paper, .retro, .xray:
            return nil
        }
    }
#endif

    func image(in bundle: Bundle) -> NSImage? {
        switch self {
        case .official:
            return nil
        case .beta:
            if let dedicatedAsset = bundle.image(forResource: "BetaImage") {
                return dedicatedAsset
            }

            // Fallback path: if no dedicated `BetaImage` is bundled, badge the
            // official icon at runtime. To switch to a hand-crafted beta icon,
            // add `BetaImage` to `Assets.xcassets` and this path is bypassed.
            guard let officialIcon = bundle.image(forResource: "AppIconImage") else {
                return nil
            }
            return officialIcon.badgedForBeta()
        case .blueprint:
            return bundle.image(forResource: "BlueprintImage")!
        case .chalkboard:
            return bundle.image(forResource: "ChalkboardImage")!
        case .glass:
            return bundle.image(forResource: "GlassImage")!
        case .holographic:
            return bundle.image(forResource: "HolographicImage")!
        case .microchip:
            return bundle.image(forResource: "MicrochipImage")!
        case .paper:
            return bundle.image(forResource: "PaperImage")!
        case .retro:
            return bundle.image(forResource: "RetroImage")!
        case .xray:
            return bundle.image(forResource: "XrayImage")!
        case let .custom(file):
            return NSImage(data: file)
        case let .customStyle(customIcon):
            return customIcon.makeImage(in: bundle)
        }
    }
}
