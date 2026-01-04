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

    // MARK: - Animations

    struct Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let bounce = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - Shadows

    struct Shadow {
        static let sm = SwiftUI.Color.black.opacity(0.1)
        static let md = SwiftUI.Color.black.opacity(0.15)
        static let lg = SwiftUI.Color.black.opacity(0.2)
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
        static let minWindowWidth: CGFloat = 800
        static let minWindowHeight: CGFloat = 500
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
