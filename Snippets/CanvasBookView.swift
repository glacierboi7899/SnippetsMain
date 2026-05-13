//
//  CanvasBookView.swift
//  Snippets
//
//  Full-bleed canvas with open book spread (selected layout).
//

import SwiftUI

// MARK: - Screen

struct CanvasBookView: View {
    let paperStyle: JournalPaperStyle
    var onHome: () -> Void
    var onBack: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let m = CanvasBookMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)
            let spreadSize = m.bookSpreadSizeFitting(available: proxy.size)

            ZStack {
                canvasBackgroundLayer()

                bookStage(spreadSize: spreadSize, metrics: m)
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)

                VStack {
                    canvasHeaderBar(metrics: m)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func canvasBackgroundLayer() -> some View {
        Image("BG Canvas")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func canvasHeaderBar(metrics: CanvasBookMetrics) -> some View {
        ZStack {
            HStack(spacing: metrics.headerIconSpacing) {
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

                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.94))
                            .frame(width: metrics.headerArrowChipDiameter, height: metrics.headerArrowChipDiameter)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                        Image(systemName: "arrow.left")
                            .font(.system(size: metrics.headerArrowIconSize, weight: .bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                    }
                }
                .buttonStyle(.plain)
                .offset(y: metrics.homeIconVerticalLift)
                .accessibilityLabel(Text("Back to page layout"))

                Spacer(minLength: 0)
            }
        }
        .padding(.leading, metrics.headerLeadingPadding)
        .padding(.trailing, metrics.headerTrailingPadding)
        .padding(.top, metrics.headerTopPadding)
    }

    private func bookStage(spreadSize: CGSize, metrics: CanvasBookMetrics) -> some View {
        let w = spreadSize.width
        let h = spreadSize.height

        return OpenBookSpreadCanvas(style: paperStyle)
            .frame(width: w, height: h)
            .background(
                RoundedRectangle(cornerRadius: metrics.bookCornerRadius, style: .continuous)
                    .fill(JournalPaperStyle.journalPagePaperFill)
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.bookCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Metrics (header matches PageLayoutView)

private struct CanvasBookMetrics {
    let size: CGSize
    let safeArea: EdgeInsets

    private var shortSide: CGFloat { min(size.width, size.height) }
    private var longSide: CGFloat { max(size.width, size.height) }

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

    var homeIconSize: CGFloat { min(shortSide * 0.052, 26) }

    var homeTapSide: CGFloat { max(48, shortSide * 0.11) }

    var homeIconVerticalLift: CGFloat { -shortSide * 0.032 - 15 }

    /// Horizontal inset when fitting the spread so shadows stay inside the safe width.
    var bookFitHorizontalInset: CGFloat { max(20, shortSide * 0.055) }

    /// Vertical inset when fitting the spread (safe areas + shadow).
    var bookFitVerticalInset: CGFloat { max(16, shortSide * 0.036) }

    /// Preferred spread width before fitting to the available rect.
    var bookSpreadWidthIdeal: CGFloat {
        min(longSide * 0.72, shortSide * 1.32)
    }

    var bookSpreadAspect: CGFloat { 0.62 }

    /// Scales the ideal open-book size down so it fits the screen without clipping (including shadow margin).
    func bookSpreadSizeFitting(available: CGSize) -> CGSize {
        let shadowSlop: CGFloat = 22
        let maxW = max(
            100,
            available.width - 2 * bookFitHorizontalInset - safeArea.leading - safeArea.trailing
        )
        let maxH = max(
            72,
            available.height - 2 * bookFitVerticalInset - safeArea.top - safeArea.bottom - shadowSlop
        )
        var w = min(bookSpreadWidthIdeal, maxW)
        var h = w * bookSpreadAspect
        if h > maxH {
            h = maxH
            w = h / bookSpreadAspect
        }
        return CGSize(width: w, height: h)
    }

    var bookCornerRadius: CGFloat { 12 }

    var headerIconSpacing: CGFloat { shortSide * 0.018 }

    var headerArrowIconSize: CGFloat {
        let base = clamp(shortSide * 0.058, min: 22, max: 30)
        return clamp(base * 1.5 * 0.8, min: 26, max: 38)
    }

    var headerArrowChipDiameter: CGFloat { headerArrowIconSize * 1.75 }
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - Open spread drawing (same patterns as layout thumbnails)

private struct OpenBookSpreadCanvas: View {
    let style: JournalPaperStyle

    private var paperFill: Color {
        JournalPaperStyle.journalPagePaperFill
    }

    private var spineStroke: Color {
        Color(red: 0.55, green: 0.48, blue: 0.38).opacity(0.55)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let spineX = w * 0.5
            let cornerR: CGFloat = max(3, w * 0.012)

            let leftRect = CGRect(x: w * 0.04, y: h * 0.06, width: spineX - w * 0.06, height: h * 0.88)
            context.fill(Path(roundedRect: leftRect, cornerRadius: cornerR), with: .color(paperFill))

            let rightRect = CGRect(x: spineX - w * 0.015, y: h * 0.06, width: w * 0.48, height: h * 0.88)
            context.fill(Path(roundedRect: rightRect, cornerRadius: cornerR), with: .color(paperFill))

            var spinePath = Path()
            spinePath.move(to: CGPoint(x: spineX, y: h * 0.06))
            spinePath.addLine(to: CGPoint(x: spineX, y: h * 0.94))
            context.stroke(spinePath, with: .color(spineStroke), lineWidth: max(1, w * 0.0025))

            let inner = CGRect(x: w * 0.055, y: h * 0.09, width: w * 0.89, height: h * 0.82)

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
                let rowStep: CGFloat = max(6, h / 16)
                var lineY = inner.minY + rowStep
                while lineY < inner.maxY - 2 {
                    var line = Path()
                    line.move(to: CGPoint(x: inner.minX, y: lineY))
                    line.addLine(to: CGPoint(x: inner.maxX, y: lineY))
                    context.stroke(line, with: .color(Color.blue.opacity(0.18)), lineWidth: 1)
                    lineY += rowStep
                }
            case .grid:
                let step: CGFloat = max(7, inner.width / 12)
                var gx = inner.minX + step
                while gx < inner.maxX - 1 {
                    var vLine = Path()
                    vLine.move(to: CGPoint(x: gx, y: inner.minY))
                    vLine.addLine(to: CGPoint(x: gx, y: inner.maxY))
                    context.stroke(vLine, with: .color(Color.gray.opacity(0.28)), lineWidth: 0.9)
                    gx += step
                }
                var gy = inner.minY + step
                while gy < inner.maxY - 1 {
                    var hLine = Path()
                    hLine.move(to: CGPoint(x: inner.minX, y: gy))
                    hLine.addLine(to: CGPoint(x: inner.maxX, y: gy))
                    context.stroke(hLine, with: .color(Color.gray.opacity(0.28)), lineWidth: 0.9)
                    gy += step
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Canvas — dotted") {
    CanvasBookView(
        paperStyle: .dotted,
        onHome: {},
        onBack: {}
    )
    .previewInterfaceOrientation(.landscapeLeft)
}
