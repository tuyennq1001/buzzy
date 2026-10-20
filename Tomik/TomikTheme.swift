import SwiftUI
import AppKit

public var isTomikDev: Bool {
    #if DEBUG
    return true
    #else
    return Bundle.main.bundleIdentifier?.contains(".dev") == true
    #endif
}

public var tomikAppTitle: String {
    isTomikDev ? "Tomik Dev" : "Tomik"
}

public enum TomikThemeColor: String, CaseIterable, Identifiable {
    case red = "red"
    case pink = "pink"
    case orange = "orange"
    case green = "green"
    case blue = "blue"
    case purple = "purple"

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .red: return "🍅"
        case .pink: return "🌸"
        case .orange: return "🍑"
        case .green: return "🌿"
        case .blue: return "☁️"
        case .purple: return "💜"
        }
    }

    public var displayName: String {
        switch self {
        case .red: return NSLocalizedString("Theme.red", value: "Đỏ Cà Chua", comment: "Tomato Red")
        case .pink: return NSLocalizedString("Theme.pink", value: "Hồng Dâu Tây", comment: "Strawberry Pink")
        case .orange: return NSLocalizedString("Theme.orange", value: "Cam Đào", comment: "Sunny Peach")
        case .green: return NSLocalizedString("Theme.green", value: "Xanh Bạc Hà", comment: "Mint Green")
        case .blue: return NSLocalizedString("Theme.blue", value: "Xanh Bầu Trời", comment: "Sky Blue")
        case .purple: return NSLocalizedString("Theme.purple", value: "Tím Lavender", comment: "Lavender Purple")
        }
    }

    public var primaryColor: Color {
        switch self {
        case .red: return Color(red: 239/255, green: 78/255, blue: 85/255)
        case .pink: return Color(red: 244/255, green: 114/255, blue: 182/255)
        case .orange: return Color(red: 249/255, green: 139/255, blue: 62/255)
        case .green: return Color(red: 45/255, green: 194/255, blue: 135/255)
        case .blue: return Color(red: 59/255, green: 148/255, blue: 246/255)
        case .purple: return Color(red: 168/255, green: 112/255, blue: 246/255)
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .red: return NSColor(srgbRed: 239/255, green: 78/255, blue: 85/255, alpha: 1.0)
        case .pink: return NSColor(srgbRed: 244/255, green: 114/255, blue: 182/255, alpha: 1.0)
        case .orange: return NSColor(srgbRed: 249/255, green: 139/255, blue: 62/255, alpha: 1.0)
        case .green: return NSColor(srgbRed: 45/255, green: 194/255, blue: 135/255, alpha: 1.0)
        case .blue: return NSColor(srgbRed: 59/255, green: 148/255, blue: 246/255, alpha: 1.0)
        case .purple: return NSColor(srgbRed: 168/255, green: 112/255, blue: 246/255, alpha: 1.0)
        }
    }

    /// Very soft pastel background for cards
    public var softBackground: Color {
        switch self {
        case .red: return Color(red: 254/255, green: 242/255, blue: 242/255)
        case .pink: return Color(red: 253/255, green: 242/255, blue: 248/255)
        case .orange: return Color(red: 255/255, green: 247/255, blue: 237/255)
        case .green: return Color(red: 240/255, green: 253/255, blue: 244/255)
        case .blue: return Color(red: 239/255, green: 246/255, blue: 255/255)
        case .purple: return Color(red: 245/255, green: 243/255, blue: 255/255)
        }
    }

    /// Medium pastel tint for pill badges and active selections
    public var tintBackground: Color {
        primaryColor.opacity(0.14)
    }

    /// Gradient colors for buttons and prominent bars
    public var gradientColors: [Color] {
        switch self {
        case .red:
            return [Color(red: 255/255, green: 107/255, blue: 115/255), Color(red: 239/255, green: 78/255, blue: 85/255)]
        case .pink:
            return [Color(red: 249/255, green: 168/255, blue: 212/255), Color(red: 244/255, green: 114/255, blue: 182/255)]
        case .orange:
            return [Color(red: 253/255, green: 186/255, blue: 116/255), Color(red: 249/255, green: 139/255, blue: 62/255)]
        case .green:
            return [Color(red: 110/255, green: 231/255, blue: 183/255), Color(red: 45/255, green: 194/255, blue: 135/255)]
        case .blue:
            return [Color(red: 147/255, green: 197/255, blue: 253/255), Color(red: 59/255, green: 148/255, blue: 246/255)]
        case .purple:
            return [Color(red: 216/255, green: 180/255, blue: 254/255), Color(red: 168/255, green: 112/255, blue: 246/255)]
        }
    }

    public static var breakColor: Color {
        Color(red: 16/255, green: 185/255, blue: 129/255) // Refreshing calming emerald mint
    }

    public static var breakNSColor: NSColor {
        NSColor(srgbRed: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
    }
}

public enum TomikProfile: String, CaseIterable, Identifiable {
    case kid = "kid"
    case medium = "medium"
    case standard = "standard"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .kid:
            return "🍼 " + TomikLocalization.shared.tr("Profile.kid", value: "Bé học (15p)")
        case .medium:
            return "⚡️ " + TomikLocalization.shared.tr("Profile.medium", value: "Vừa vặn (20p)")
        case .standard:
            return "🎯 " + TomikLocalization.shared.tr("Profile.standard", value: "Chuẩn (25p)")
        case .custom:
            return "🛠️ " + TomikLocalization.shared.tr("Profile.custom", value: "Tùy chỉnh")
        }
    }

    public var intervals: (work: Int, shortRest: Int, longRest: Int, sets: Int)? {
        switch self {
        case .kid: return (15, 3, 10, 4)
        case .medium: return (20, 5, 15, 4)
        case .standard: return (25, 5, 15, 4)
        case .custom: return nil
        }
    }

    public static func matchingProfile(work: Int, shortRest: Int, longRest: Int) -> TomikProfile {
        if work == 15 && shortRest == 3 && longRest == 10 {
            return .kid
        } else if work == 20 && shortRest == 5 && longRest == 15 {
            return .medium
        } else if work == 25 && shortRest == 5 && longRest == 15 {
            return .standard
        } else {
            return .custom
        }
    }
}

public enum TomikUnicodeFont: String, CaseIterable, Identifiable {
    case system = "system"
    case avenir = "avenir"
    case helvetica = "helvetica"
    case chalkboard = "chalkboard"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return TomikLocalization.shared.tr("Font.system", value: "SF Rounded (Tròn trịa, Đáng yêu)")
        case .avenir: return TomikLocalization.shared.tr("Font.avenir", value: "Avenir Next (Hiện đại, Thanh lịch)")
        case .helvetica: return TomikLocalization.shared.tr("Font.helvetica", value: "Helvetica Neue (Gọn gàng, Tiêu chuẩn)")
        case .chalkboard: return TomikLocalization.shared.tr("Font.chalkboard", value: "Chalkboard SE (Viết tay cho bé)")
        }
    }

    public static func match(_ raw: String?) -> TomikUnicodeFont {
        guard let raw = raw, !raw.isEmpty else { return .system }
        if let direct = TomikUnicodeFont(rawValue: raw) { return direct }
        let lower = raw.lowercased()
        if lower.contains("avenir") { return .avenir }
        if lower.contains("helvetica") { return .helvetica }
        if lower.contains("chalkboard") { return .chalkboard }
        // Fallback for "San Francisco", "Georgia", "Menlo", "Times", "Arial", etc.
        return .system
    }
}

public func tomikScale(baseSize: Int? = nil) -> CGFloat {
    let savedBase = UserDefaults.standard.integer(forKey: "tomikFontSize")
    let chosenBase = CGFloat(baseSize ?? (savedBase > 0 ? savedBase : 16))
    return chosenBase / 13.0
}

public func tomikFont(size: CGFloat, weight: Font.Weight = .regular, fontName: String? = nil, baseSize: Int? = nil) -> Font {
    let rawFont = fontName ?? UserDefaults.standard.string(forKey: "tomikFontName")
    let chosenFont = TomikUnicodeFont.match(rawFont)

    let scale = tomikScale(baseSize: baseSize)
    let finalSize = size * scale

    switch chosenFont {
    case .system:
        return .system(size: finalSize, weight: weight, design: .rounded)
    case .avenir:
        return .custom("Avenir Next", size: finalSize).weight(weight)
    case .helvetica:
        return .custom("Helvetica Neue", size: finalSize).weight(weight)
    case .chalkboard:
        return .custom("Chalkboard SE", size: finalSize).weight(weight)
    }
}
