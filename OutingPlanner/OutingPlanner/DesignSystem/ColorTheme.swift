//
//  ColorTheme.swift
//  OutingPlanner
//

import SwiftUI

enum ColorThemeID: String, CaseIterable, Identifiable {
    case azure
    case cobalt
    case ice
    case ocean
    case dusk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .azure: "アズール"
        case .cobalt: "コバルト"
        case .ice: "アイス"
        case .ocean: "オーシャン"
        case .dusk: "ダスク"
        }
    }

    var subtitle: String {
        switch self {
        case .azure: "明るいスカイブルー"
        case .cobalt: "深みのあるブルー"
        case .ice: "クリアな水色"
        case .ocean: "ティール寄りの青"
        case .dusk: "落ち着いたナイトブルー"
        }
    }

    /// Blue-forward palettes: soft light surfaces, strong readable ink, vivid blue accent.
    var palette: ThemePalette {
        switch self {
        case .azure:
            ThemePalette(
                ink: Color(red: 0.10, green: 0.16, blue: 0.28),
                muted: Color(red: 0.36, green: 0.44, blue: 0.56),
                canvas: Color(red: 0.94, green: 0.96, blue: 0.99),
                card: Color.white,
                mist: Color(red: 0.88, green: 0.92, blue: 0.98),
                sky: Color(red: 0.18, green: 0.42, blue: 0.92),
                leaf: Color(red: 0.12, green: 0.62, blue: 0.58),
                sun: Color(red: 1.00, green: 0.62, blue: 0.22),
                coral: Color(red: 0.96, green: 0.36, blue: 0.42),
                border: Color(red: 0.78, green: 0.84, blue: 0.94),
                onAccent: Color.white,
                heroTop: Color(red: 0.22, green: 0.48, blue: 0.98),
                heroBottom: Color(red: 0.14, green: 0.32, blue: 0.78)
            )
        case .cobalt:
            ThemePalette(
                ink: Color(red: 0.08, green: 0.12, blue: 0.26),
                muted: Color(red: 0.34, green: 0.40, blue: 0.54),
                canvas: Color(red: 0.93, green: 0.95, blue: 0.99),
                card: Color.white,
                mist: Color(red: 0.86, green: 0.90, blue: 0.97),
                sky: Color(red: 0.12, green: 0.32, blue: 0.78),
                leaf: Color(red: 0.10, green: 0.56, blue: 0.52),
                sun: Color(red: 0.98, green: 0.58, blue: 0.18),
                coral: Color(red: 0.92, green: 0.32, blue: 0.40),
                border: Color(red: 0.74, green: 0.80, blue: 0.92),
                onAccent: Color.white,
                heroTop: Color(red: 0.16, green: 0.36, blue: 0.86),
                heroBottom: Color(red: 0.08, green: 0.18, blue: 0.52)
            )
        case .ice:
            ThemePalette(
                ink: Color(red: 0.12, green: 0.20, blue: 0.32),
                muted: Color(red: 0.38, green: 0.48, blue: 0.58),
                canvas: Color(red: 0.95, green: 0.98, blue: 1.00),
                card: Color.white,
                mist: Color(red: 0.90, green: 0.95, blue: 0.99),
                sky: Color(red: 0.28, green: 0.58, blue: 0.96),
                leaf: Color(red: 0.18, green: 0.68, blue: 0.70),
                sun: Color(red: 1.00, green: 0.70, blue: 0.28),
                coral: Color(red: 0.98, green: 0.42, blue: 0.48),
                border: Color(red: 0.80, green: 0.88, blue: 0.96),
                onAccent: Color.white,
                heroTop: Color(red: 0.36, green: 0.66, blue: 0.98),
                heroBottom: Color(red: 0.20, green: 0.46, blue: 0.88)
            )
        case .ocean:
            ThemePalette(
                ink: Color(red: 0.08, green: 0.18, blue: 0.26),
                muted: Color(red: 0.32, green: 0.44, blue: 0.52),
                canvas: Color(red: 0.93, green: 0.97, blue: 0.98),
                card: Color.white,
                mist: Color(red: 0.86, green: 0.93, blue: 0.96),
                sky: Color(red: 0.10, green: 0.48, blue: 0.72),
                leaf: Color(red: 0.08, green: 0.58, blue: 0.50),
                sun: Color(red: 0.96, green: 0.60, blue: 0.20),
                coral: Color(red: 0.90, green: 0.34, blue: 0.38),
                border: Color(red: 0.74, green: 0.86, blue: 0.90),
                onAccent: Color.white,
                heroTop: Color(red: 0.12, green: 0.56, blue: 0.78),
                heroBottom: Color(red: 0.06, green: 0.34, blue: 0.58)
            )
        case .dusk:
            ThemePalette(
                ink: Color(red: 0.10, green: 0.14, blue: 0.28),
                muted: Color(red: 0.38, green: 0.42, blue: 0.56),
                canvas: Color(red: 0.94, green: 0.95, blue: 0.99),
                card: Color.white,
                mist: Color(red: 0.88, green: 0.90, blue: 0.97),
                sky: Color(red: 0.24, green: 0.36, blue: 0.82),
                leaf: Color(red: 0.20, green: 0.58, blue: 0.62),
                sun: Color(red: 0.98, green: 0.56, blue: 0.24),
                coral: Color(red: 0.94, green: 0.38, blue: 0.48),
                border: Color(red: 0.76, green: 0.80, blue: 0.92),
                onAccent: Color.white,
                heroTop: Color(red: 0.28, green: 0.40, blue: 0.88),
                heroBottom: Color(red: 0.12, green: 0.20, blue: 0.58)
            )
        }
    }
}

struct ThemePalette {
    let ink: Color
    let muted: Color
    let canvas: Color
    let card: Color
    let mist: Color
    let sky: Color
    let leaf: Color
    let sun: Color
    let coral: Color
    let border: Color
    let onAccent: Color
    let heroTop: Color
    let heroBottom: Color
}
