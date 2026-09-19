//
//  DesignTokens.swift
//  OutingPlanner
//

import SwiftUI

/// Semantic colors for the active blue theme.
enum DesignTokens {
    @MainActor
    private static var palette: ThemePalette {
        ThemeStoreBridge.palette
    }

    @MainActor static var ink: Color { palette.ink }
    @MainActor static var muted: Color { palette.muted }
    @MainActor static var mist: Color { palette.mist }
    @MainActor static var canvas: Color { palette.canvas }
    @MainActor static var card: Color { palette.card }
    @MainActor static var sky: Color { palette.sky }
    @MainActor static var leaf: Color { palette.leaf }
    @MainActor static var sun: Color { palette.sun }
    @MainActor static var coral: Color { palette.coral }
    @MainActor static var border: Color { palette.border }
    @MainActor static var onAccent: Color { palette.onAccent }
    @MainActor static var heroTop: Color { palette.heroTop }
    @MainActor static var heroBottom: Color { palette.heroBottom }

    @MainActor
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [heroTop, heroBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @MainActor
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [sky, heroBottom],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @MainActor
    static var canvasGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.94, blue: 1.00),
                canvas,
                Color(red: 0.96, green: 0.97, blue: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @MainActor
    static func softFill(_ color: Color) -> Color {
        color.opacity(0.16)
    }

    @MainActor
    static func genreColor(_ genre: String) -> Color {
        switch genre {
        case "アート": sky
        case "グルメ": sun
        case "自然": leaf
        case "エンタメ": Color(red: 0.36, green: 0.52, blue: 0.98)
        case "体験": Color(red: 0.20, green: 0.62, blue: 0.86)
        case "ショッピング": Color(red: 0.42, green: 0.48, blue: 0.92)
        case "祭り": coral
        case "映え": Color(red: 0.98, green: 0.48, blue: 0.58)
        default: muted
        }
    }
}

@MainActor
enum ThemeStoreBridge {
    static weak var store: ThemeStore?
    static var palette: ThemePalette {
        store?.palette ?? ColorThemeID.azure.palette
    }
}

extension View {
    func flatCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(SoftCardModifier(cornerRadius: cornerRadius))
    }

    func flatCanvasBackground() -> some View {
        background {
            DesignTokens.canvasGradient
                .ignoresSafeArea()
        }
    }

    func blueHeroBackground() -> some View {
        background {
            DesignTokens.heroGradient
                .ignoresSafeArea(edges: .top)
        }
    }
}

private struct SoftCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(DesignTokens.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignTokens.border.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: DesignTokens.sky.opacity(0.10), radius: 12, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}
