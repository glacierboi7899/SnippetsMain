//
//  GalleryView.swift
//  Snippets
//
//  Post-session gallery (wooden desk background). Header matches Welcome / Page Style title strip.
//

import SwiftUI

// MARK: - Screen

struct GalleryView: View {
    var onHome: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let m = GalleryHeaderMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)

            ZStack {
                Image("wooden")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    galleryHeaderBar(metrics: m)
                    Spacer(minLength: m.titleToThumbnailRowGap)
                    galleryDummyThumbnailsRow(metrics: m)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Same pattern as `PageLayoutView.headerBar` — home leading, centered serif title.
    private func galleryHeaderBar(metrics: GalleryHeaderMetrics) -> some View {
        ZStack {
            Text("Gallery")
                .font(.system(size: metrics.titleFontSize, weight: .regular, design: .serif))
                .foregroundStyle(GalleryTheme.accentYellow)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 2)
                .padding(.horizontal, metrics.titleHorizontalReserve)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 0) {
                Button(action: onHome) {
                    Image(systemName: "house.fill")
                        .font(.system(size: metrics.homeIconSize))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: metrics.homeTapSide, height: metrics.homeTapSide)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(y: metrics.homeIconVerticalLift)
                .accessibilityLabel(Text("Home"))

                Spacer(minLength: 0)
            }
        }
        .padding(.leading, metrics.headerLeadingPadding)
        .padding(.trailing, metrics.headerTrailingPadding)
        .padding(.top, metrics.headerTopPadding)
    }

    /// Three preview tiles in one row (reference gallery layout).
    private func galleryDummyThumbnailsRow(metrics: GalleryHeaderMetrics) -> some View {
        HStack(spacing: metrics.thumbnailInterSpacing) {
            ForEach(GalleryDummyImage.allCases, id: \.self) { asset in
                Image(asset.rawValue)
                    .resizable()
                    .scaledToFill()
                    .frame(width: metrics.thumbnailCellWidth, height: metrics.thumbnailCellHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: metrics.thumbnailCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, metrics.thumbnailRowHorizontalPadding)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Theme & metrics (aligned with `PageLayoutView` / `WelcomeView`)

private enum GalleryDummyImage: String, CaseIterable {
    case dummy1
    case dummy2
    case dummy3
}

private enum GalleryTheme {
    /// `#FFCC55` — matches `WelcomePalette` / `PageLayoutTheme.accentYellow`.
    static let accentYellow = Color(red: 255 / 255, green: 204 / 255, blue: 85 / 255)
}

private struct GalleryHeaderMetrics {
    let size: CGSize
    let safeArea: EdgeInsets

    private var shortSide: CGFloat { min(size.width, size.height) }

    var horizontalPad: CGFloat { shortSide * 0.045 }

    var headerLeadingPadding: CGFloat {
        max(horizontalPad, safeArea.leading + shortSide * 0.024)
    }

    var headerTrailingPadding: CGFloat {
        max(horizontalPad, safeArea.trailing + shortSide * 0.018)
    }

    var headerTopPadding: CGFloat {
        safeArea.top + shortSide * 0.034 + 6
    }

    var titleHorizontalReserve: CGFloat {
        homeTapSide + shortSide * 0.04
    }

    var titleFontSize: CGFloat {
        min(max(shortSide * 0.068, 17), 26)
    }

    var homeIconSize: CGFloat { min(shortSide * 0.052, 26) }

    var homeTapSide: CGFloat { max(48, shortSide * 0.11) }

    var homeIconVerticalLift: CGFloat { -shortSide * 0.032 - 15 }

    var titleToThumbnailRowGap: CGFloat { shortSide * 0.024 }

    var thumbnailInterSpacing: CGFloat { shortSide * 0.024 }

    var thumbnailRowHorizontalPadding: CGFloat {
        max(horizontalPad, safeArea.leading + shortSide * 0.018)
    }

    var thumbnailCellWidth: CGFloat {
        let s = thumbnailInterSpacing
        let p = thumbnailRowHorizontalPadding
        let inner = size.width - 2 * p - 2 * s
        return max(72, inner / 3)
    }

    var thumbnailCellHeight: CGFloat {
        let ideal = thumbnailCellWidth * 0.82
        let cap = min(max(shortSide * 0.34, 96), 158)
        return min(ideal, cap)
    }

    var thumbnailCornerRadius: CGFloat { 12 }
}

#Preview("Gallery") {
    GalleryView(onHome: {})
        .previewInterfaceOrientation(.landscapeLeft)
}
