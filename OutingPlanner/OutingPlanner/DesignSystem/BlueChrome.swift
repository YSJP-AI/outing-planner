//
//  BlueChrome.swift
//  OutingPlanner
//

import SwiftUI

/// Shared blue UI chrome: hero banners, gradient buttons, floating tab bar.
struct BlueHeroBanner: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.78))
                    Text(title)
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let trailing {
                    trailing
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                DesignTokens.heroGradient
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .blur(radius: 2)
                    .offset(x: 120, y: -40)
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .offset(x: -90, y: 50)
            }
            .clipped()
        }
    }
}

struct BluePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(DesignTokens.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(DesignTokens.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: DesignTokens.sky.opacity(configuration.isPressed ? 0.15 : 0.28), radius: configuration.isPressed ? 4 : 10, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    private let tabs: [(AppTab, String, String)] = [
        (.proposals, "提案", "sparkles"),
        (.slot, "日時から", "clock.badge.questionmark"),
        (.calendar, "カレンダー", "calendar")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab, title, icon in
                let selected = selection == tab
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selected {
                                Circle()
                                    .fill(DesignTokens.accentGradient)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: DesignTokens.sky.opacity(0.35), radius: 8, y: 4)
                            }
                            Image(systemName: icon)
                                .font(.system(size: selected ? 17 : 18, weight: .semibold))
                                .foregroundStyle(selected ? Color.white : DesignTokens.muted)
                        }
                        .frame(height: 44)

                        Text(title)
                            .font(.caption2.weight(selected ? .bold : .medium))
                            .fontDesign(.rounded)
                            .foregroundStyle(selected ? DesignTokens.sky : DesignTokens.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(DesignTokens.border.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: DesignTokens.sky.opacity(0.16), radius: 20, y: 8)
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct SoftPillBackground: ViewModifier {
    var selected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? DesignTokens.onAccent : DesignTokens.ink)
            .background {
                if selected {
                    Capsule(style: .continuous).fill(DesignTokens.accentGradient)
                } else {
                    Capsule(style: .continuous).fill(DesignTokens.card)
                }
            }
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selected ? Color.clear : DesignTokens.border, lineWidth: 1)
            )
            .shadow(color: selected ? DesignTokens.sky.opacity(0.22) : Color.clear, radius: 6, y: 3)
    }
}

extension View {
    func softPill(selected: Bool) -> some View {
        modifier(SoftPillBackground(selected: selected))
    }
}
