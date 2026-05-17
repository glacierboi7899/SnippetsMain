//
//  PageLayout.swift
//  Snippets
//
//  Page style picker: center journal cover, layout thumbnails, color bar.
//

import SwiftUI

// MARK: - Theme

private enum PageLayoutTheme {
    /// `#FFCC55`
    static let accentYellow = Color(red: 255 / 255, green: 204 / 255, blue: 85 / 255)
    /// Selection ring around swatches (dark teal).
    static let selectionRing = Color(red: 0.12, green: 0.42, blue: 0.46)
    static let barBackground = Color(red: 0.91, green: 0.91, blue: 0.92)
}

// MARK: - Cover swatches (matches center book)

private enum CoverSwatch: Int, CaseIterable, Identifiable {
    case white
    case teal
    case paleSage
    case lightLavender
    case tan
    case offWhite
    case lightBlue
    case softPink
    case paleCream
    case charcoal

    var id: Int { rawValue }

    var accessibilityTitle: String {
        switch self {
        case .white: return "White"
        case .teal: return "Teal"
        case .paleSage: return "Pale sage"
        case .lightLavender: return "Light lavender"
        case .tan: return "Tan"
        case .offWhite: return "Off-white"
        case .lightBlue: return "Light blue"
        case .softPink: return "Soft pink"
        case .paleCream: return "Pale cream"
        case .charcoal: return "Charcoal"
        }
    }

    /// sRGB components for the swatch disk — same anchor used for the center book gradient.
    var rgb: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .white:
            return (0.98, 0.98, 0.98)
        case .teal:
            return (0.18, 0.52, 0.56)
        case .paleSage:
            return (0.72, 0.80, 0.74)
        case .lightLavender:
            return (0.82, 0.78, 0.92)
        case .tan:
            return (0.82, 0.72, 0.56)
        case .offWhite:
            return (0.96, 0.95, 0.93)
        case .lightBlue:
            return (0.78, 0.88, 0.96)
        case .softPink:
            return (0.96, 0.82, 0.86)
        case .paleCream:
            return (0.98, 0.94, 0.84)
        case .charcoal:
            return (0.18, 0.17, 0.20)
        }
    }

    var diskColor: Color {
        let t = rgb
        return Color(red: t.0, green: t.1, blue: t.2)
    }

    /// Leather-style gradient built from the same `rgb` as the disk so the book matches the tapped swatch.
    var coverColors: JournalCoverColors {
        Self.coverGradient(from: rgb)
    }

    private static func coverGradient(from rgb: (CGFloat, CGFloat, CGFloat)) -> JournalCoverColors {
        let (r, g, b) = rgb
        let brightness = (r + g + b) / 3
        if brightness > 0.94 {
            return JournalCoverColors(
                highlight: Color(red: 1, green: 1, blue: 1),
                base: Color(red: r, green: g, blue: b),
                deepShadow: Color(red: max(r - 0.22, 0), green: max(g - 0.22, 0), blue: max(b - 0.24, 0))
            )
        }
        if brightness < 0.32 {
            return JournalCoverColors(
                highlight: Color(red: min(r + 0.22, 1), green: min(g + 0.18, 1), blue: min(b + 0.20, 1)),
                base: Color(red: r, green: g, blue: b),
                deepShadow: Color(red: max(r * 0.45, 0), green: max(g * 0.42, 0), blue: max(b * 0.48, 0))
            )
        }
        return JournalCoverColors(
            highlight: Color(
                red: min(r + 0.14, 1),
                green: min(g + 0.16, 1),
                blue: min(b + 0.14, 1)
            ),
            base: Color(red: r, green: g, blue: b),
            deepShadow: Color(
                red: max(r - 0.12, 0),
                green: max(g - 0.22, 0),
                blue: max(b - 0.22, 0)
            )
        )
    }
}

// MARK: - Screen

struct PageLayoutView: View {
    var onHome: () -> Void
    var onOpenCanvas: (JournalPaperStyle, JournalCoverColors) -> Void = { _, _ in }

    @State private var selectedSwatch: CoverSwatch = .teal
    @State private var selectedPaperStyle: JournalPaperStyle = .blank

    var body: some View {
        GeometryReader { proxy in
            let m = PageLayoutMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)

            ZStack {
                PageLayoutBackgroundLayer()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Group {
                        if proxy.size.width > proxy.size.height {
                            headerBar(metrics: m)
                                .ignoresSafeArea(edges: .horizontal)
                        } else {
                            headerBar(metrics: m)
                        }
                    }

                    Spacer(minLength: m.headerToContentGap)

                    centerComposition(metrics: m)

                    Spacer(minLength: m.contentToBarGap)

                    colorPickerBar(metrics: m)
                        .padding(.bottom, m.colorBarBottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Arrow sits to the right of the swatch pill (same row), slightly smaller than before.
    private func continuationArrow(metrics: PageLayoutMetrics) -> some View {
        let iconSize = metrics.bottomArrowIconSize
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(width: iconSize * 1.75, height: iconSize * 1.75)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            Image(systemName: "arrow.right")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Continue"))
    }

    private func headerBar(metrics: PageLayoutMetrics) -> some View {
        ZStack {
            Text("Page Style")
                .font(.system(size: metrics.titleFontSize, weight: .regular, design: .serif))
                .foregroundStyle(PageLayoutTheme.accentYellow)
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

    private func centerComposition(metrics: PageLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: metrics.mainRowSpacing) {
            VStack(spacing: metrics.thumbnailStackSpacing) {
                paperStyleButton(.blank, metrics: metrics)
                paperStyleButton(.dotted, metrics: metrics)
            }

            JournalCoverView(colors: selectedSwatch.coverColors)
                .frame(width: metrics.centerBookWidth, height: metrics.centerBookHeight)
                .shadow(color: .black.opacity(0.38), radius: 14, x: 6, y: 10)

            VStack(spacing: metrics.thumbnailStackSpacing) {
                paperStyleButton(.ruled, metrics: metrics)
                paperStyleButton(.grid, metrics: metrics)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.horizontalPad)
    }

    private func paperStyleButton(_ paper: JournalPaperStyle, metrics: PageLayoutMetrics) -> some View {
        Button {
            selectedPaperStyle = paper
        } label: {
            PageStyleThumbnailView(
                style: paper,
                isSelected: selectedPaperStyle == paper,
                size: metrics.thumbnailSize
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityTitle(for: paper)))
    }

    private func accessibilityTitle(for paper: JournalPaperStyle) -> String {
        switch paper {
        case .blank:
            return "Blank pages"
        case .dotted:
            return "Dot grid"
        case .ruled:
            return "Ruled lines"
        case .grid:
            return "Square grid"
        }
    }

    private func colorPickerBar(metrics: PageLayoutMetrics) -> some View {
        HStack {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: metrics.paletteArrowSpacing) {
                HStack(spacing: metrics.swatchSpacing) {
                    ForEach(CoverSwatch.allCases, id: \.self) { swatch in
                        Button {
                            selectedSwatch = swatch
                        } label: {
                            Circle()
                                .fill(swatch.diskColor)
                                .frame(width: metrics.swatchDiameter, height: metrics.swatchDiameter)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            selectedSwatch == swatch ? PageLayoutTheme.selectionRing : Color.clear,
                                            lineWidth: metrics.selectionRingWidth
                                        )
                                }
                                .overlay {
                                    if swatch == .white || swatch == .offWhite {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                                    } else if swatch == .charcoal {
                                        Circle()
                                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(swatch.accessibilityTitle))
                        .accessibilityValue(Text(selectedSwatch == swatch ? "Selected" : "Not selected"))
                    }
                }
                .padding(.horizontal, metrics.barHorizontalPadding)
                .padding(.vertical, metrics.barVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: metrics.barCornerRadius, style: .continuous)
                        .fill(PageLayoutTheme.barBackground)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                )

                Button {
                    onOpenCanvas(selectedPaperStyle, selectedSwatch.coverColors)
                } label: {
                    continuationArrow(metrics: metrics)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.horizontalPad)
    }
}

// MARK: - Metrics

private struct PageLayoutMetrics {
    let size: CGSize
    let safeArea: EdgeInsets

    private var shortSide: CGFloat { min(size.width, size.height) }
    private var longSide: CGFloat { max(size.width, size.height) }

    var horizontalPad: CGFloat { shortSide * 0.045 }

    /// Keeps home + title inside safe areas / curved edges (responsive).
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

    /// Extra top inset so the title and home icon are not clipped by the notch / status bar.
    var headerTopPadding: CGFloat {
        if isLandscapeLayout {
            return safeArea.top + 4
        }
        return safeArea.top + shortSide * 0.034 + 6
    }

    private var isLandscapeLayout: Bool { size.width > size.height }

    /// Horizontal inset on the title so it clears the home control when centered.
    var titleHorizontalReserve: CGFloat {
        homeTapSide + shortSide * 0.04
    }

    var titleFontSize: CGFloat {
        min(max(shortSide * 0.068, 17), 26)
    }

    var homeIconSize: CGFloat { min(shortSide * 0.052, 26) }

    var homeTapSide: CGFloat { max(48, shortSide * 0.11) }

    /// Negative offset moves the home control upward without clipping the title (portrait only).
    var homeIconVerticalLift: CGFloat {
        isLandscapeLayout ? 0 : (-shortSide * 0.032 - 15)
    }

    var headerToContentGap: CGFloat { shortSide * 0.026 }

    var contentToBarGap: CGFloat { shortSide * 0.024 }

    var colorBarBottomPadding: CGFloat {
        safeArea.bottom + shortSide * 0.028
    }

    /// Space between the swatch pill and the continue arrow.
    var paletteArrowSpacing: CGFloat { max(12, shortSide * 0.032) }

    /// Prior layout reduced by 30%.
    private static let centerBookScale: CGFloat = 0.7

    var centerBookWidth: CGFloat {
        clamp(shortSide * 0.38, min: 110, max: 170) * Self.centerBookScale
    }

    var centerBookHeight: CGFloat { centerBookWidth * 1.42 }

    /// Base enlargement × 1.25 for current request (25% bigger than prior layout).
    private static let thumbnailEnlarge: CGFloat = 1.7 * 1.25

    var thumbnailSize: CGSize {
        let base = clamp(shortSide * 0.14, min: 52, max: 76)
        let w = base * Self.thumbnailEnlarge
        return CGSize(width: w, height: w * 0.82)
    }

    var thumbnailStackSpacing: CGFloat { shortSide * 0.034 }

    var mainRowSpacing: CGFloat { shortSide * 0.072 + 12 }

    var barCornerRadius: CGFloat { 18 }

    var barHorizontalPadding: CGFloat { shortSide * 0.032 }

    var barVerticalPadding: CGFloat { shortSide * 0.022 }

    var swatchDiameter: CGFloat { clamp(shortSide * 0.065, min: 26, max: 34) }

    var swatchSpacing: CGFloat { shortSide * 0.02 }

    var selectionRingWidth: CGFloat { 3.5 }

    /// Arrow chip: 20% smaller than the last overlay sizing (`× 0.8`).
    var bottomArrowIconSize: CGFloat {
        let base = clamp(shortSide * 0.058, min: 22, max: 30)
        return clamp(base * 1.5 * 0.8, min: 26, max: 38)
    }
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - Background

private struct PageLayoutBackgroundLayer: View {
    var body: some View {
        Image("PageLayoutBG")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }
}

// MARK: - Thumbnails

private struct PageStyleThumbnailView: View {
    let style: JournalPaperStyle
    let isSelected: Bool
    let size: CGSize

    private var paperFill: Color {
        JournalPaperStyle.journalPagePaperFill
    }

    private var spineStroke: Color {
        Color(red: 0.55, green: 0.48, blue: 0.38).opacity(0.55)
    }

    var body: some View {
        openNotebookPages()
            .frame(width: size.width, height: size.height)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? PageLayoutTheme.selectionRing : Color.black.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 5, x: 2, y: 3)
    }

    private func openNotebookPages() -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let spineX = w * 0.5
            let cornerR: CGFloat = 4

            let leftRect = CGRect(x: w * 0.06, y: h * 0.08, width: spineX - w * 0.08, height: h * 0.84)
            context.fill(Path(roundedRect: leftRect, cornerRadius: cornerR), with: .color(paperFill))

            let rightRect = CGRect(x: spineX - w * 0.02, y: h * 0.08, width: w * 0.46, height: h * 0.84)
            context.fill(Path(roundedRect: rightRect, cornerRadius: cornerR), with: .color(paperFill))

            var spinePath = Path()
            spinePath.move(to: CGPoint(x: spineX, y: h * 0.08))
            spinePath.addLine(to: CGPoint(x: spineX, y: h * 0.92))
            context.stroke(spinePath, with: .color(spineStroke), lineWidth: 1.2)

            let inner = CGRect(x: w * 0.08, y: h * 0.11, width: w * 0.84, height: h * 0.78)

            switch style {
            case .blank:
                break
            case .dotted:
                let minDim = min(inner.width, inner.height)
                let step = JournalPaperStyle.journalDottedGridStep(minInnerDimension: minDim)
                let dotR = JournalPaperStyle.journalDottedGridDotRadius(step: step)
                let dotColor = JournalPaperStyle.journalDottedGridDotColor
                var rowY = inner.minY + step * 0.5
                while rowY <= inner.maxY - dotR {
                    var colX = inner.minX + step * 0.5
                    while colX <= inner.maxX - dotR {
                        let dotRect = CGRect(x: colX - dotR, y: rowY - dotR, width: dotR * 2, height: dotR * 2)
                        context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                        colX += step
                    }
                    rowY += step
                }
            case .ruled:
                let rowStep: CGFloat = max(5.5, h / 13)
                var lineY = inner.minY + rowStep
                while lineY < inner.maxY - 2 {
                    var line = Path()
                    line.move(to: CGPoint(x: inner.minX, y: lineY))
                    line.addLine(to: CGPoint(x: inner.maxX, y: lineY))
                    context.stroke(line, with: .color(Color.blue.opacity(0.18)), lineWidth: 0.9)
                    lineY += rowStep
                }
            case .grid:
                let step: CGFloat = max(6, inner.width / 11)
                var gx = inner.minX + step
                while gx < inner.maxX - 1 {
                    var vLine = Path()
                    vLine.move(to: CGPoint(x: gx, y: inner.minY))
                    vLine.addLine(to: CGPoint(x: gx, y: inner.maxY))
                    context.stroke(vLine, with: .color(Color.gray.opacity(0.28)), lineWidth: 0.8)
                    gx += step
                }
                var gy = inner.minY + step
                while gy < inner.maxY - 1 {
                    var hLine = Path()
                    hLine.move(to: CGPoint(x: inner.minX, y: gy))
                    hLine.addLine(to: CGPoint(x: inner.maxX, y: gy))
                    context.stroke(hLine, with: .color(Color.gray.opacity(0.28)), lineWidth: 0.8)
                    gy += step
                }
            }
        }
    }
}

// MARK: - Preview

private struct PageLayoutPreviewHost: View {
    var body: some View {
        PageLayoutView(onHome: {})
    }
}

#Preview("Page layout — landscape") {
    PageLayoutPreviewHost()
        .previewInterfaceOrientation(.landscapeLeft)
}
