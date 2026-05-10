//
//  JournalCoverView.swift
//  Snippets
//
//  Shared leather-style journal cover used on Welcome and Page Layout screens.
//

import SwiftUI

// MARK: - Color triple

struct JournalCoverColors: Equatable {
    var highlight: Color
    var base: Color
    var deepShadow: Color
}

// MARK: - Preset styles (Welcome screen)

enum JournalCoverStyle {
    case brownLeather
    case deepBlue
    case richRed

    var colors: JournalCoverColors {
        switch self {
        case .brownLeather:
            return JournalCoverColors(
                highlight: Color(red: 0.52, green: 0.37, blue: 0.26),
                base: Color(red: 0.38, green: 0.24, blue: 0.15),
                deepShadow: Color(red: 0.22, green: 0.13, blue: 0.09)
            )
        case .deepBlue:
            return JournalCoverColors(
                highlight: Color(red: 0.28, green: 0.48, blue: 0.74),
                base: Color(red: 0.12, green: 0.28, blue: 0.50),
                deepShadow: Color(red: 0.06, green: 0.14, blue: 0.30)
            )
        case .richRed:
            return JournalCoverColors(
                highlight: Color(red: 0.72, green: 0.22, blue: 0.26),
                base: Color(red: 0.48, green: 0.12, blue: 0.16),
                deepShadow: Color(red: 0.26, green: 0.06, blue: 0.09)
            )
        }
    }
}

// MARK: - View

struct JournalCoverView: View {
    let colors: JournalCoverColors
    private let cornerRadius: CGFloat

    init(colors: JournalCoverColors, cornerRadius: CGFloat = 14) {
        self.colors = colors
        self.cornerRadius = cornerRadius
    }

    init(style: JournalCoverStyle, cornerRadius: CGFloat = 14) {
        self.colors = style.colors
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [colors.highlight, colors.base, colors.deepShadow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.02),
                        Color.black.opacity(0.08),
                    ],
                    startPoint: UnitPoint(x: 0.15, y: 0),
                    endPoint: UnitPoint(x: 0.85, y: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .blendMode(.softLight)
            }
    }
}
