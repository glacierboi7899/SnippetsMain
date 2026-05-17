//
//  GalleryView.swift
//  Snippets
//
//  Post-session gallery (wooden desk background). Header matches Welcome / Page Style title strip.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

// MARK: - Screen

struct GalleryView: View {
    /// Snapshot of the journal when the edit session ended (top-left cell).
    var lastCreatedThumbnail: CGImage?
    var onDeleteLatest: () -> Void = {}
    var onPinLatest: () -> Void = {}
    var onHome: () -> Void

    @State private var showingLatestActions = false

    var body: some View {
        GeometryReader { proxy in
            let m = GalleryHeaderMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)

            ZStack {
                Image("Gallery")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 0) {
                    Group {
                        if proxy.size.width > proxy.size.height {
                            galleryHeaderBar(metrics: m)
                                .ignoresSafeArea(edges: .horizontal)
                        } else {
                            galleryHeaderBar(metrics: m)
                        }
                    }
                    Spacer(minLength: m.titleToGalleryGap)
                    galleryJournalRows(metrics: m)
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.leading, metrics.headerLeadingPadding)
        .padding(.trailing, metrics.headerTrailingPadding)
        .padding(.top, metrics.headerTopPadding)
    }

    private func galleryJournalRows(metrics: GalleryHeaderMetrics) -> some View {
        VStack(spacing: metrics.galleryRowSpacing) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: metrics.galleryColumnSpacing) {
                    ForEach(0..<3, id: \.self) { column in
                        let index = row * 3 + column
                        galleryJournalSlot(at: index, metrics: metrics)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, metrics.galleryHorizontalPadding)
        .frame(maxWidth: .infinity)
    }

    private func galleryJournalSlot(at index: Int, metrics: GalleryHeaderMetrics) -> some View {
        VStack(spacing: metrics.dateTagTopGap) {
            if index == 0, lastCreatedThumbnail != nil {
                Button {
                    showingLatestActions = true
                } label: {
                    galleryJournalThumbnail(at: index, metrics: metrics)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Latest journal entry", isPresented: $showingLatestActions, titleVisibility: .visible) {
                    Button("Pin") {
                        onPinLatest()
                    }

                    Button("Delete", role: .destructive) {
                        onDeleteLatest()
                    }

                    Button("Cancel", role: .cancel) {}
                }
            } else {
                galleryJournalThumbnail(at: index, metrics: metrics)
            }

            Text(Self.placeholderDate(forSlot: index))
                .font(.system(size: metrics.dateTagFontSize, weight: .medium, design: .serif))
                .foregroundStyle(GalleryTheme.accentYellow)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, metrics.dateTagHorizontalPadding)
                .padding(.vertical, metrics.dateTagVerticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(GalleryTheme.dateTagFill)
                )
                .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
        }
        .frame(width: metrics.journalCellWidth)
        .opacity(Self.gridCellOpacity(for: index))
    }

    @ViewBuilder
    private func galleryJournalThumbnail(at index: Int, metrics: GalleryHeaderMetrics) -> some View {
        Group {
            if index == 0 {
                if let lastCreatedThumbnail {
                    galleryUserThumbnail(lastCreatedThumbnail)
                } else {
                    GalleryBlankJournalCell(cornerRadius: metrics.journalCornerRadius)
                }
            } else if let name = Self.fillerAssetName(forSlot: index) {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                GalleryBlankJournalCell(cornerRadius: metrics.journalCornerRadius)
            }
        }
        .frame(width: metrics.journalThumbnailWidth, height: metrics.journalThumbnailHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: metrics.journalCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.journalCornerRadius, style: .continuous)
                .strokeBorder(GalleryTheme.gridCellOutline, lineWidth: GalleryTheme.gridCellOutlineWidth)
        }
        .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 3)
    }

    @ViewBuilder
    private func galleryUserThumbnail(_ cgImage: CGImage) -> some View {
#if os(iOS)
        Image(uiImage: UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up))
            .resizable()
            .interpolation(.high)
            .scaledToFill()
#elseif os(macOS)
        Image(nsImage: NSImage(
            cgImage: cgImage,
            size: NSSize(
                width: CGFloat(cgImage.width) / (NSScreen.main?.backingScaleFactor ?? 2),
                height: CGFloat(cgImage.height) / (NSScreen.main?.backingScaleFactor ?? 2)
            )
        ))
        .resizable()
        .interpolation(.high)
        .scaledToFill()
#else
        Image(decorative: cgImage, scale: 2)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
#endif
    }

    /// Opacity by row: newest (top-left) full strength; older rows fade like archived work.
    private static func gridCellOpacity(for index: Int) -> CGFloat {
        switch index {
        case 0: return 1.0
        case 1, 2: return 0.85
        case 3, 4, 5: return 0.6
        case 6, 7, 8: return 0.25
        default: return 1.0
        }
    }

    private static func placeholderDate(forSlot index: Int) -> String {
        switch index {
        case 0: return "Fri, 27 March"
        case 1: return "Thu, 26 March"
        case 2: return "Wed, 25 March"
        case 3: return "Tue, 24 March"
        case 4: return "Mon, 23 March"
        case 5: return "Sun, 22 March"
        case 6: return "Sat, 21 March"
        case 7: return "Fri, 20 March"
        case 8: return "Thu, 19 March"
        default: return "Fri, 27 March"
        }
    }

    /// Slots 1…8: cycle `dummy1`…`dummy3` then blanks to fill the 3×3 grid.
    private static func fillerAssetName(forSlot index: Int) -> String? {
        switch index {
        case 1: return "dummy1"
        case 2: return "dummy2"
        case 3: return "dummy3"
        case 4: return nil
        case 5: return "dummy1"
        case 6: return "dummy2"
        case 7: return "dummy3"
        case 8: return nil
        default: return nil
        }
    }
}

// MARK: - Blank cell

private struct GalleryBlankJournalCell: View {
    var cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(JournalPaperStyle.journalPagePaperFill)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - Theme & metrics (aligned with `PageLayoutView` / `WelcomeView`)

private enum GalleryTheme {
    /// `#FFCC55` — matches `WelcomePalette` / `PageLayoutTheme.accentYellow`.
    static let accentYellow = Color(red: 255 / 255, green: 204 / 255, blue: 85 / 255)

    /// Dark brown frame so each tile reads clearly on the wooden desk.
    static let gridCellOutline = Color(red: 0.38, green: 0.24, blue: 0.14)

    static let gridCellOutlineWidth: CGFloat = 2

    static let dateTagFill = Color(red: 0.31, green: 0.22, blue: 0.13).opacity(0.62)
}

private struct GalleryHeaderMetrics {
    let size: CGSize
    let safeArea: EdgeInsets

    private var shortSide: CGFloat { min(size.width, size.height) }

    var horizontalPad: CGFloat { shortSide * 0.045 }

    var headerLeadingPadding: CGFloat {
        if isLandscapeLayout {
            return 8
        }
        return max(horizontalPad, safeArea.leading + shortSide * 0.024)
    }

    var headerTrailingPadding: CGFloat {
        if isLandscapeLayout {
            return 8
        }
        return max(horizontalPad, safeArea.trailing + shortSide * 0.018)
    }

    var headerTopPadding: CGFloat {
        if isLandscapeLayout {
            return safeArea.top + 4
        }
        return safeArea.top + shortSide * 0.034 + 6
    }

    private var isLandscapeLayout: Bool { size.width > size.height }

    var titleHorizontalReserve: CGFloat {
        homeTapSide + shortSide * 0.04
    }

    var titleFontSize: CGFloat {
        min(max(shortSide * 0.068, 17), 26)
    }

    var homeIconSize: CGFloat { min(shortSide * 0.052, 26) }

    var homeTapSide: CGFloat { max(48, shortSide * 0.11) }

    var homeIconVerticalLift: CGFloat {
        isLandscapeLayout ? 0 : (-shortSide * 0.032 - 15)
    }

    var titleToGalleryGap: CGFloat { shortSide * 0.024 }

    var galleryHorizontalPadding: CGFloat {
        max(horizontalPad, safeArea.leading + shortSide * 0.014)
    }

    var galleryColumnSpacing: CGFloat {
        let available = size.width - 2 * galleryHorizontalPadding - 3 * journalCellWidth
        return max(28, available / 2)
    }

    var galleryRowSpacing: CGFloat { max(16, shortSide * 0.044) }

    var journalCellWidth: CGFloat {
        let maxWidth = (size.width - 2 * galleryHorizontalPadding - 2 * 28) / 3
        return min(maxWidth, shortSide * 0.42)
    }

    var journalThumbnailWidth: CGFloat { journalCellWidth }

    var journalThumbnailHeight: CGFloat { journalThumbnailWidth * 0.53 }

    var journalCornerRadius: CGFloat { 3 }

    var dateTagTopGap: CGFloat { max(5, shortSide * 0.011) }

    var dateTagFontSize: CGFloat { clamp(shortSide * 0.031, min: 9, max: 13) }

    var dateTagHorizontalPadding: CGFloat { clamp(shortSide * 0.022, min: 8, max: 13) }

    var dateTagVerticalPadding: CGFloat { clamp(shortSide * 0.009, min: 3, max: 5) }
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

#Preview("Gallery") {
    GalleryView(lastCreatedThumbnail: nil, onHome: {})
        .previewInterfaceOrientation(.landscapeLeft)
}
