import SwiftUI

// MARK: - Semantic Colors

struct AureliaColors {
    // Backgrounds
    static let windowBackground = Color(.windowBackgroundColor)
    static let cardBackground = Color(.controlBackgroundColor)
    static let sidebarBackground = Color(.unemphasizedSelectedContentBackgroundColor)

    // Text
    static let primaryText = Color(.labelColor)
    static let secondaryText = Color(.secondaryLabelColor)
    static let tertiaryText = Color(.tertiaryLabelColor)

    // Accents
    static let accent = Color.accentColor
    static let accentLight = Color.accentColor.opacity(0.15)
    static let accentMedium = Color.accentColor.opacity(0.3)

    // Content type colors
    static let textType = Color.blue
    static let linkType = Color.purple
    static let imageType = Color.green
    static let fileType = Color.orange

    // Semantic
    static let separator = Color(.separatorColor)
    static let border = Color(.separatorColor).opacity(0.5)
    static let hover = Color.primary.opacity(0.05)
    static let selected = Color.accentColor.opacity(0.2)

    // Status
    static let starred = Color.yellow
    static let destructive = Color.red
}

// MARK: - Color Extensions

extension Color {
    static let aurelia = AureliaColors.self
}
