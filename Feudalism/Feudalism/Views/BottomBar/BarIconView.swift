import SwiftUI
import AppKit

func loadBarIcon(named name: String) -> NSImage? {
    BarIconCache.shared.image(named: name, bundle: .main)
}

func templateCopy(_ image: NSImage, enabled: Bool) -> NSImage {
    guard enabled else { return image }
    let copy = image.copy() as? NSImage ?? NSImage(size: image.size)
    copy.isTemplate = true
    return copy
}

struct BarIconView: View {
    let assetName: String
    let systemName: String
    var size: CGFloat = 48
    /// Crnu linijsku PNG ikonu oboji foreground bojom (bijela na donjem baru).
    var asTemplate: Bool = false

    private var image: NSImage? {
        guard let src = BarIconCache.shared.image(named: assetName, bundle: .main) else { return nil }
        return templateCopy(src, enabled: asTemplate)
    }

    var body: some View {
        Group {
            if let nsImage = image {
                Image(nsImage: nsImage)
                    .resizable()
                    .renderingMode(asTemplate ? .template : .original)
                    .scaledToFit()
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.58))
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(.white.opacity(0.95))
    }
}
