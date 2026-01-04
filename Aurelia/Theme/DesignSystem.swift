import SwiftUI

// MARK: - Design System

struct AureliaDesign {
    // MARK: - Spacing

    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    struct Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Typography

    struct Typography {
        static let largeTitle = Font.system(size: 26, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 14, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let callout = Font.system(size: 12, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)
        static let captionBold = Font.system(size: 11, weight: .medium)
    }

    // MARK: - Bioluminescent Animations

    struct Animation {
        // Standard animations
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)

        // Drift animations (underwater feel - slower, more fluid)
        static let drift = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let driftSlow = SwiftUI.Animation.easeInOut(duration: 0.8)

        // Springs (softer for underwater feel)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
        static let bounce = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.65)
        static let gentle = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)

        // Pulse animation (for menu bar icon)
        static let pulse = SwiftUI.Animation.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)

        // Dissolve animation
        static let dissolve = SwiftUI.Animation.easeOut(duration: 0.6)
    }

    // MARK: - Shadows (Bioluminescent glow-based)

    struct Shadow {
        // Dark shadows (subtle)
        static let sm = AureliaColors.abyss.opacity(0.3)
        static let md = AureliaColors.abyss.opacity(0.4)
        static let lg = AureliaColors.abyss.opacity(0.5)

        // Glow shadows (for selected/hover states)
        static let glowSm = AureliaColors.electricCyan.opacity(0.2)
        static let glowMd = AureliaColors.electricCyan.opacity(0.35)
        static let glowLg = AureliaColors.electricCyan.opacity(0.5)
    }

    // MARK: - Depth Opacity (Surface vs Deep)

    struct Depth {
        /// Calculate opacity based on item index
        /// Surface items (recent): bright, Deep items (older): dimmer
        static func opacity(for index: Int, surfaceCount: Int = 8) -> Double {
            if index < surfaceCount {
                return 1.0  // Surface: fully bright
            }
            // Gradually fade to minimum 0.5 opacity
            let depthIndex = index - surfaceCount
            let fadeAmount = min(Double(depthIndex) * 0.05, 0.5)
            return 1.0 - fadeAmount
        }

        /// Calculate opacity based on timestamp
        static func opacity(for timestamp: Date, now: Date = Date()) -> Double {
            let interval = now.timeIntervalSince(timestamp)
            let minutes = interval / 60

            if minutes < 5 {
                return 1.0  // Last 5 minutes: fully bright
            } else if minutes < 60 {
                // 5-60 minutes: gradual fade
                return max(0.7, 1.0 - (minutes - 5) / 110)
            } else {
                // Older than 1 hour: subtle fade based on hours
                let hours = minutes / 60
                return max(0.5, 0.7 - min(hours / 48, 0.2))
            }
        }
    }

    // MARK: - Card Dimensions

    struct Card {
        static let width: CGFloat = 220
        static let height: CGFloat = 160
        static let previewHeight: CGFloat = 100
    }

    // MARK: - Layout

    struct Layout {
        static let sidebarWidth: CGFloat = 200
        static let minWindowWidth: CGFloat = 1100
        static let minWindowHeight: CGFloat = 650
        static let menuBarPopoverWidth: CGFloat = 360
        static let menuBarPopoverHeight: CGFloat = 420
    }
}

// MARK: - View Modifiers

extension View {
    func cardStyle() -> some View {
        self
            .background(AureliaColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg))
            .shadow(color: AureliaDesign.Shadow.sm, radius: 2, x: 0, y: 1)
    }

    func hoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }

    /// Apply frosted glass material effect
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .background(AureliaColors.abyssMedium.opacity(0.3))
    }

    /// Card style with glass effect and bioluminescent glow
    func bioluminescentCard(isHovering: Bool = false) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg)
                            .fill(AureliaColors.abyssLight.opacity(0.4))
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg))
            .overlay {
                if isHovering {
                    RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg)
                        .stroke(AureliaColors.electricCyan.opacity(0.3), lineWidth: 1)
                }
            }
            .shadow(
                color: isHovering ? AureliaDesign.Shadow.glowSm : AureliaDesign.Shadow.sm,
                radius: isHovering ? 10 : 2,
                x: 0,
                y: isHovering ? 0 : 1
            )
    }

    /// Apply depth-based opacity (index-based)
    func depthOpacity(index: Int, surfaceCount: Int = 8) -> some View {
        self.opacity(AureliaDesign.Depth.opacity(for: index, surfaceCount: surfaceCount))
    }

    /// Apply depth-based opacity (timestamp-based)
    func depthOpacity(timestamp: Date) -> some View {
        self.opacity(AureliaDesign.Depth.opacity(for: timestamp))
    }

    /// Glow effect overlay for selected/active items
    func glowEffect(isActive: Bool, color: Color = AureliaColors.electricCyan) -> some View {
        self.overlay {
            if isActive {
                RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg)
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .blur(radius: 4)
            }
        }
    }
}

struct HoverEffectModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .shadow(color: isHovering ? AureliaDesign.Shadow.md : AureliaDesign.Shadow.sm,
                    radius: isHovering ? 8 : 2,
                    x: 0, y: isHovering ? 4 : 1)
            .animation(AureliaDesign.Animation.spring, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

// MARK: - Bioluminescent Hover Modifier

struct BioluminescentHoverModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? 1.015 : 1.0)
            .shadow(
                color: isHovering ? AureliaDesign.Shadow.glowSm : .clear,
                radius: isHovering ? 10 : 0,
                x: 0, y: 0
            )
            .animation(AureliaDesign.Animation.gentle, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func bioluminescentHover() -> some View {
        self.modifier(BioluminescentHoverModifier())
    }
}

// MARK: - Content Type Badge Style

struct ContentTypeBadge: View {
    let type: String

    var color: Color {
        switch type.lowercased() {
        case "text": return AureliaColors.textType
        case "link": return AureliaColors.linkType
        case "image": return AureliaColors.imageType
        case "file": return AureliaColors.fileType
        default: return AureliaColors.secondaryText
        }
    }

    var icon: String {
        switch type.lowercased() {
        case "text": return "doc.text"
        case "link": return "link"
        case "image": return "photo"
        case "file": return "doc"
        default: return "questionmark"
        }
    }

    var body: some View {
        HStack(spacing: AureliaDesign.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(type)
                .font(AureliaDesign.Typography.captionBold)
        }
        .foregroundStyle(color)
        .padding(.horizontal, AureliaDesign.Spacing.sm)
        .padding(.vertical, AureliaDesign.Spacing.xs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
