import SwiftUI

// MARK: - Theme Configuration
struct RounderTheme {
    // Light mode
    static let bgLight = Color(hex: "#FAFAF7")
    static let surfaceLight = Color(hex: "#FFFFFF")
    static let surface2Light = Color(hex: "#F4F2EE")
    static let inkLight = Color(hex: "#0A0A0A")
    static let mutedLight = Color(hex: "#6E6E73")
    static let softLight = Color(hex: "#A1A1A6")

    // Dark mode
    static let bgDark = Color(hex: "#0A0A0A")
    static let surfaceDark = Color(hex: "#111111")
    static let surface2Dark = Color(hex: "#161616")
    static let inkDark = Color(hex: "#FAFAFA")
    static let mutedDark = Color(hex: "#9A9A9F")
    static let softDark = Color(hex: "#5E5E63")

    // Semantic
    static let success = Color(hex: "#16A34A")
    static let warn = Color(hex: "#D97706")
    static let danger = Color(hex: "#DC2626")

    // Accent palette (user-selectable)
    static let accents: [(name: String, color: Color)] = [
        ("Orange", Color(hex: "#FF4D2E")),
        ("Ink", Color(hex: "#1A1A1A")),
        ("Azure", Color(hex: "#2D7DFA")),
        ("Violet", Color(hex: "#6B5BFF")),
        ("Green", Color(hex: "#16A34A")),
    ]
}

// MARK: - Theme Environment
struct ThemeEnvironment {
    @Environment(\.colorScheme) var colorScheme

    var bg: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }
    var surface: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }
    var surface2: Color { colorScheme == .dark ? RounderTheme.surface2Dark : RounderTheme.surface2Light }
    var ink: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var muted: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }
    var soft: Color { colorScheme == .dark ? RounderTheme.softDark : RounderTheme.softLight }
}

// MARK: - Color Extension for hex initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgb = Int(hex, radix: 16) ?? 0
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography
struct Typography {
    static func hero() -> some ViewModifier {
        return HeroModifier()
    }

    static func heading() -> some ViewModifier {
        return HeadingModifier()
    }

    static func cardTitle() -> some ViewModifier {
        return CardTitleModifier()
    }

    static func body() -> some ViewModifier {
        return BodyModifier()
    }

    static func rowLabel() -> some ViewModifier {
        return RowLabelModifier()
    }

    static func monoLabel() -> some ViewModifier {
        return MonoLabelModifier()
    }
}

struct HeroModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 34, weight: .bold))
            .tracking(-1.2)
            .lineSpacing(1.05)
    }
}

struct HeadingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 36, weight: .bold))
            .tracking(-1.4)
    }
}

struct CardTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.3)
    }
}

struct BodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .regular))
            .lineSpacing(1.5)
    }
}

struct RowLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .tracking(-0.2)
    }
}

struct MonoLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .textCase(.uppercase)
    }
}
