import SwiftUI

// MARK: - Bioluminescent Color Palette

struct AureliaColors {
    // MARK: - Abyss Backgrounds (Deep charcoal-blue, NOT pure black)
    static let abyss = Color(red: 0.08, green: 0.10, blue: 0.14)           // #141A24
    static let abyssLight = Color(red: 0.12, green: 0.14, blue: 0.20)      // #1E2433
    static let abyssMedium = Color(red: 0.16, green: 0.18, blue: 0.24)     // #292E3D

    // Semantic backgrounds (use abyss palette)
    static let windowBackground = abyss
    static let cardBackground = abyssLight
    static let sidebarBackground = Color(red: 0.06, green: 0.12, blue: 0.18)  // Deeper blue tint

    // MARK: - Bioluminescent Accents
    static let electricCyan = Color(red: 0.0, green: 0.87, blue: 0.95)     // #00DEF2
    static let bioluminescentGlow = Color(red: 0.0, green: 0.95, blue: 0.85) // #00F2D9
    static let deepTeal = Color(red: 0.0, green: 0.65, blue: 0.70)         // #00A6B3

    // Primary accent (electric cyan)
    static let accent = electricCyan
    static let accentLight = electricCyan.opacity(0.15)
    static let accentMedium = electricCyan.opacity(0.3)

    // MARK: - Text Colors (subtle cyan tint)
    static let primaryText = Color(red: 0.92, green: 0.95, blue: 0.98)     // #EBF2FA
    static let secondaryText = Color(red: 0.60, green: 0.67, blue: 0.75)   // #99ABBF
    static let tertiaryText = Color(red: 0.40, green: 0.47, blue: 0.55)    // #66788C

    // MARK: - Content Type Colors (Bioluminescent variants)
    static let textType = Color(red: 0.30, green: 0.70, blue: 0.90)        // Soft cyan-blue
    static let linkType = Color(red: 0.60, green: 0.40, blue: 0.95)        // Deep violet
    static let imageType = Color(red: 0.20, green: 0.85, blue: 0.65)       // Seafoam green
    static let fileType = Color(red: 0.95, green: 0.60, blue: 0.20)        // Warm amber (anglerfish)

    // MARK: - Semantic Colors
    static let separator = Color.white.opacity(0.08)
    static let border = electricCyan.opacity(0.2)
    static let hover = electricCyan.opacity(0.08)
    static let selected = electricCyan.opacity(0.25)

    // MARK: - Status Colors
    static let anchored = Color(red: 0.95, green: 0.75, blue: 0.20)        // Golden
    static let starred = anchored  // Backward compatibility alias
    static let destructive = Color(red: 0.95, green: 0.30, blue: 0.35)

    // MARK: - Glow Colors (for selected/hover states)
    static let glowCyan = electricCyan.opacity(0.4)
    static let glowSoft = electricCyan.opacity(0.2)

    // MARK: - Light Mode (Ocean Surface) - for future use
    static let surfaceLight = Color(red: 0.85, green: 0.95, blue: 0.98)    // Light ocean blue
    static let surfaceTeal = Color(red: 0.70, green: 0.90, blue: 0.92)     // Shallow water teal
}

// MARK: - Color Extensions

extension Color {
    static let aurelia = AureliaColors.self
}
