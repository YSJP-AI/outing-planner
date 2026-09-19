//
//  ThemePickerView.swift
//  OutingPlanner
//

import SwiftUI

struct ThemePickerView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ブルーテーマ")
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(DesignTokens.ink)
                    Text("ブルーを基調にしたトーンを選べます。")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.muted)

                    ForEach(ColorThemeID.allCases) { theme in
                        themeRow(theme)
                    }
                }
                .padding(20)
            }
            .flatCanvasBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func themeRow(_ theme: ColorThemeID) -> some View {
        let palette = theme.palette
        let selected = themeStore.selectedID == theme

        return Button {
            themeStore.selectedID = theme
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.heroTop, palette.heroBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        HStack(spacing: 3) {
                            Circle().fill(palette.sky).frame(width: 8, height: 8)
                            Circle().fill(palette.leaf).frame(width: 8, height: 8)
                            Circle().fill(palette.sun).frame(width: 8, height: 8)
                        }
                    )
                    .shadow(color: palette.sky.opacity(0.25), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.headline)
                        .foregroundStyle(DesignTokens.ink)
                    Text(theme.subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.muted)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.sky)
                        .font(.title3)
                }
            }
            .padding(14)
            .flatCard(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? DesignTokens.sky : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ThemePickerButton: View {
    var compact: Bool = false
    var onHero: Bool = false
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Image(systemName: "paintpalette.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(onHero ? Color.white : DesignTokens.sky)
                .frame(width: compact ? 40 : 44, height: compact ? 40 : 44)
                .background {
                    if onHero {
                        Circle().fill(Color.white.opacity(0.2))
                    } else {
                        Circle().fill(DesignTokens.mist)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(onHero ? Color.white.opacity(0.35) : DesignTokens.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("テーマ")
        .sheet(isPresented: $showPicker) {
            ThemePickerView()
        }
    }
}
