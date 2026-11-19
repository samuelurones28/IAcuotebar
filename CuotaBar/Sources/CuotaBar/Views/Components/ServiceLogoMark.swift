import AppKit
import SwiftUI

struct ServiceLogoMark: View {
    let service: ServiceKind
    var size: CGFloat = 30

    private var accentColor: Color {
        switch service {
        case .codex: Color(red: 0.43, green: 0.73, blue: 0.92)
        case .claudeCode: Color(red: 0.92, green: 0.66, blue: 0.34)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(accentColor.opacity(0.14))

            ServiceLogoGlyph(service: service, size: size * 0.64, fallbackTint: accentColor.opacity(0.95))

            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: accentColor.opacity(0.22), radius: 12, y: 5)
        .accessibilityLabel(service.displayName)
    }
}

struct ServiceLogoGlyph: View {
    let service: ServiceKind
    let size: CGFloat
    var fallbackTint: Color = .white

    /// Loaded once; `body` runs on every hover and refresh.
    @MainActor private static let logos: [ServiceKind: NSImage] = {
        var images: [ServiceKind: NSImage] = [:]
        for service in ServiceKind.allCases {
            let name = service == .claudeCode ? "claude" : "openai"
            if let url = Bundle.moduleResources.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                images[service] = image
            }
        }
        return images
    }()

    private var logoImage: NSImage? { Self.logos[service] }

    var body: some View {
        Group {
            if let logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.96)
            } else {
                Text(service.logoText)
                    .font(.system(size: size * 0.53, weight: .semibold, design: .rounded))
                    .foregroundStyle(fallbackTint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#if DEBUG
private struct ServiceLogoMarkPreview: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            ServiceLogoMark(service: .codex, size: 34)
            ServiceLogoMark(service: .claudeCode, size: 34)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
