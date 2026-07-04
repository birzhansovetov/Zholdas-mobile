import SwiftUI

enum ZholdasTheme {
    static let background = Color(red: 0.025, green: 0.018, blue: 0.070)
    static let backgroundDeep = Color(red: 0.010, green: 0.010, blue: 0.032)
    static let surface = Color(red: 0.060, green: 0.046, blue: 0.120)
    static let elevatedSurface = Color(red: 0.095, green: 0.070, blue: 0.175)
    static let panel = Color(red: 0.045, green: 0.037, blue: 0.098)
    static let border = Color.white.opacity(0.095)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.64)
    static let textTertiary = Color.white.opacity(0.42)
    static let accent = Color(red: 0.58, green: 0.42, blue: 1.0)
    static let accentDeep = Color(red: 0.34, green: 0.18, blue: 0.78)
    static let accentSoft = Color(red: 0.36, green: 0.27, blue: 0.78)
    static let amber = accent
    static let amberDeep = accentDeep
    static let success = Color(red: 0.180, green: 0.800, blue: 0.500)
    static let danger = Color(red: 1.000, green: 0.260, blue: 0.340)

    static var appBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.040, green: 0.030, blue: 0.105),
                background,
                backgroundDeep
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSoft, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                elevatedSurface.opacity(0.96),
                surface.opacity(0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var strokeColor: Color = ZholdasTheme.border
    
    func body(content: Content) -> some View {
        let radius = min(cornerRadius, 8)
        content
            .background(ZholdasTheme.surfaceGradient)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [strokeColor.opacity(0.95), strokeColor.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 8, strokeColor: Color = Color.white.opacity(0.12)) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius, strokeColor: strokeColor))
    }

    func modernCard(strokeColor: Color = ZholdasTheme.border) -> some View {
        self
            .padding()
            .glassBackground(cornerRadius: 8, strokeColor: strokeColor)
    }

    func modernFieldSurface(isFocused: Bool = false) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(isFocused ? ZholdasTheme.elevatedSurface : ZholdasTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isFocused ? ZholdasTheme.accent.opacity(0.72) : ZholdasTheme.border, lineWidth: 1)
            )
    }

    func primaryActionSurface() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(ZholdasTheme.accentGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: ZholdasTheme.accent.opacity(0.22), radius: 16, x: 0, y: 10)
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
    }
}

struct ZholdasAvatarView: View {
    let avatarURL: String?
    let initials: String
    var size: CGFloat = 40
    
    var body: some View {
        Group {
            if let urlStr = avatarURL, !urlStr.isEmpty {
                if urlStr.hasPrefix("asset:") {
                    let assetName = urlStr.replacingOccurrences(of: "asset:", with: "")
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else if urlStr.hasPrefix("symbol:") {
                    let symbolName = urlStr.replacingOccurrences(of: "symbol:", with: "")
                    Image(systemName: symbolName)
                        .font(.system(size: size * 0.45))
                        .foregroundColor(.white)
                        .frame(width: size, height: size)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else if urlStr.hasPrefix("emoji:") {
                    let emoji = urlStr.replacingOccurrences(of: "emoji:", with: "")
                    Text(emoji)
                        .font(.system(size: size * 0.5))
                        .frame(width: size, height: size)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else if let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        default:
                            fallbackCircle
                        }
                    }
                    .frame(width: size, height: size)
                } else {
                    fallbackCircle
                }
            } else {
                fallbackCircle
            }
        }
    }
    
    private var fallbackCircle: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 4)
    }
}
