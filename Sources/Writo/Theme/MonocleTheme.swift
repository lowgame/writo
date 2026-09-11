import SwiftUI
import AppKit

public enum ThemeMode: String, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var title: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Açık"
        case .dark: return "Koyu"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

public enum MonocleTheme {
    // MARK: - Strict 3-Color Discipline (Achromatic: R == G == B)
    // Level 1: Zemin (Negatif Alan)
    public static var background: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.05, alpha: 1.0)
                : NSColor(white: 0.99, alpha: 1.0)
        })
    }

    public static var sidebarBackground: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.08, alpha: 1.0)
                : NSColor(white: 0.94, alpha: 1.0)
        })
    }

    // Level 2: Ön Plan (Aktif Durum, Odak, Yüksek Kontrast)
    public static var foreground: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.98, alpha: 1.0)
                : NSColor(white: 0.05, alpha: 1.0)
        })
    }

    // Level 3: Nötr Ton (Meta, İkincil, Pasif Durum)
    public static var neutral: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.55, alpha: 1.0)
                : NSColor(white: 0.46, alpha: 1.0)
        })
    }

    // Nötr Mikro-Kontur (Hafif ayrıştırma çizgisi veya pasif zemin)
    public static var microBorder: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.16, alpha: 1.0)
                : NSColor(white: 0.86, alpha: 1.0)
        })
    }

    // MARK: - Grid Metrics (Sabit Katsayılar)
    public static let unit: CGFloat = 4
    public static let spacingXS: CGFloat = unit * 1 // 4
    public static let spacingS: CGFloat = unit * 2  // 8
    public static let spacingM: CGFloat = unit * 3  // 12
    public static let spacingL: CGFloat = unit * 4  // 16
    public static let spacingXL: CGFloat = unit * 6 // 24
    public static let spacingXXL: CGFloat = unit * 8 // 32

    public static let sidebarWidth: CGFloat = 260

    // MARK: - Physical Spring Dynamics (150ms - 250ms)
    public static let spring: Animation = .spring(response: 0.22, dampingFraction: 0.85)

    // MARK: - Typography
    public static func charterFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if NSFont(name: "Charter", size: size) != nil {
            return Font.custom("Charter", size: size)
        } else {
            return Font.system(size: size, weight: weight, design: .serif)
        }
    }

    public static let fontTitle = Font.system(size: 22, weight: .semibold, design: .default)
    public static let fontSubtitle = Font.system(size: 15, weight: .medium, design: .default)
    public static let fontBody = Font.system(size: 14, weight: .regular, design: .default)
    public static let fontMeta = Font.system(size: 11, weight: .regular, design: .monospaced)
    public static let fontMono = Font.system(size: 13, weight: .regular, design: .monospaced)
}
