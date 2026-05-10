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
    case lightBeige

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
        case .lightBeige: return "Light beige"
        }
    }

    /// Disk fill shown in the bar (approximation of cover hue).
    var diskColor: Color {
        switch self {
        case .white:
            return Color(red: 0.98, green: 0.98, blue: 0.98)
        case .teal:
            return Color(red: 0.18, green: 0.52, blue: 0.56)
        case .paleSage:
            return Color(red: 0.72, green: 0.80, blue: 0.74)
        case .lightLavender:
            return Color(red: 0.82, green: 0.78, blue: 0.92)
        case .tan:
            return Color(red: 0.82, green: 0.72, blue: 0.56)
        case .offWhite:
            return Color(red: 0.96, green: 0.95, blue: 0.93)
        case .lightBlue:
            return Color(red: 0.78, green: 0.88, blue: 0.96)
        case .softPink:
            return Color(red: 0.96, green: 0.82, blue: 0.86)
        case .paleCream:
            return Color(red: 0.98, green: 0.94, blue: 0.84)
        case .lightBeige:
            return Color(red: 0.93, green: 0.88, blue: 0.78)
        }
    }

    /// Gradient triple for `JournalCoverView`.
    var coverColors: JournalCoverColors {
        switch self {
        case .white:
            return JournalCoverColors(
                highlight: Color(red: 1.0, green: 1.0, blue: 1.0),
                base: Color(red: 0.88, green: 0.88, blue: 0.88),
                deepShadow: Color(red: 0.62, green: 0.62, blue: 0.64)
            )
        case .teal:
            return JournalCoverStyle.deepBlue.colors
        case .paleSage:
            return JournalCoverColors(
                highlight: Color(red: 0.78, green: 0.88, blue: 0.82),
                base: Color(red: 0.52, green: 0.68, blue: 0.58),
                deepShadow: Color(red: 0.28, green: 0.42, blue: 0.34)
            )
        case .lightLavender:
            return JournalCoverColors(
                highlight: Color(red: 0.90, green: 0.86, blue: 0.98),
                base: Color(red: 0.72, green: 0.66, blue: 0.88),
                deepShadow: Color(red: 0.42, green: 0.36, blue: 0.58)
            )
        case .tan:
            return JournalCoverColors(
                highlight: Color(red: 0.92, green: 0.82, blue: 0.64),
                base: Color(red: 0.74, green: 0.60, blue: 0.42),
                deepShadow: Color(red: 0.48, green: 0.36, blue: 0.24)
            )
        case .offWhite:
            return JournalCoverColors(
                highlight: Color(red: 1.0, green: 0.99, blue: 0.97),
                base: Color(red: 0.90, green: 0.88, blue: 0.84),
                deepShadow: Color(red: 0.68, green: 0.66, blue: 0.62)
            )
        case .lightBlue:
            return JournalCoverColors(
                highlight: Color(red: 0.88, green: 0.94, blue: 1.0),
                base: Color(red: 0.62, green: 0.78, blue: 0.92),
                deepShadow: Color(red: 0.34, green: 0.52, blue: 0.72)
            )
        case .softPink:
            return JournalCoverColors(
                highlight: Color(red: 1.0, green: 0.88, blue: 0.90),
                base: Color(red: 0.88, green: 0.62, blue: 0.72),
                deepShadow: Color(red: 0.58, green: 0.32, blue: 0.44)
            )
        case .paleCream:
            return JournalCoverColors(
                highlight: Color(red: 1.0, green: 0.96, blue: 0.88),
                base: Color(red: 0.92, green: 0.84, blue: 0.68),
                deepShadow: Color(red: 0.72, green: 0.58, blue: 0.38)
            )
        case .lightBeige:
            return JournalCoverColors(
                highlight: Color(red: 0.96, green: 0.92, blue: 0.82),
                base: Color(red: 0.82, green: 0.74, blue: 0.62),
                deepShadow: Color(red: 0.56, green: 0.48, blue: 0.38)
            )
        }
    }
}

// MARK: - Page layout kinds

private enum JournalPaperStyle: Int, CaseIterable, Hashable {
    case blank
    case dotted
    case ruled
    case grid
}

// MARK: - Screen

struct PageLayoutView: View {
    var onHome: () -> Void

    @State private var selectedSwatch: CoverSwatch = .teal
    @State private var selectedPaperStyle: JournalPaperStyle = .blank

    var body: some View {
        GeometryReader { proxy in
            let m = PageLayoutMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)

            ZStack {
                PageLayoutBackgroundLayer()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar(metrics: m)

                    Spacer(minLength: m.headerToContentGap)

                    centerComposition(metrics: m)

                    Spacer(minLength: m.contentToBarGap)

                    bottomChrome(metrics: m)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func bottomChrome(metrics: PageLayoutMetrics) -> some View {
        VStack(alignment: .trailing, spacing: metrics.gapBelowColorBar) {
            colorPickerBar(metrics: metrics)

            HStack {
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: metrics.bottomArrowIconSize, weight: .semibold))
                    .foregroundStyle(PageLayoutTheme.accentYellow)
            }
            .padding(.trailing, metrics.horizontalPad)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Continue"))
        }
        .padding(.bottom, metrics.barBottomPadding)
    }

    private func headerBar(metrics: PageLayoutMetrics) -> some View {
        ZStack {
            Text("Page Style")
                .font(.system(size: metrics.titleFontSize, weight: .regular, design: .serif))
                .foregroundStyle(PageLayoutTheme.accentYellow)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
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
        max(horizontalPad, safeArea.leading + shortSide * 0.024)
    }

    var headerTrailingPadding: CGFloat {
        max(horizontalPad, safeArea.trailing + shortSide * 0.018)
    }

    /// Extra top inset so the title and home icon are not clipped by the notch / status bar.
    var headerTopPadding: CGFloat {
        safeArea.top + shortSide * 0.034 + 6
    }

    /// Horizontal inset on the title so it clears the home control when centered.
    var titleHorizontalReserve: CGFloat {
        homeTapSide + shortSide * 0.04
    }

    var titleFontSize: CGFloat {
        min(max(shortSide * 0.068, 17), 26)
    }

    var homeIconSize: CGFloat { min(shortSide * 0.052, 26) }

    var homeTapSide: CGFloat { max(48, shortSide * 0.11) }

    /// Negative offset moves the home control upward without clipping the title.
    var homeIconVerticalLift: CGFloat { -shortSide * 0.032 - 15 }

    var headerToContentGap: CGFloat { shortSide * 0.026 }

    var contentToBarGap: CGFloat { shortSide * 0.024 }

    var barBottomPadding: CGFloat { safeArea.bottom + shortSide * 0.032 }

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

    /// Space between the color pill and the bottom arrow row.
    var gapBelowColorBar: CGFloat { max(18, shortSide * 0.048) }

    var bottomArrowIconSize: CGFloat {
        clamp(shortSide * 0.058, min: 22, max: 30)
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
        Color(red: 0.97, green: 0.94, blue: 0.86)
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
                let step: CGFloat = max(5, inner.width / 16)
                var rowY = inner.minY + step * 0.55
                while rowY < inner.maxY - step * 0.45 {
                    var colX = inner.minX + step * 0.55
                    while colX < inner.maxX - step * 0.45 {
                        let dotRect = CGRect(x: colX - 0.65, y: rowY - 0.65, width: 1.3, height: 1.3)
                        context.fill(Path(ellipseIn: dotRect), with: .color(Color.gray.opacity(0.38)))
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
