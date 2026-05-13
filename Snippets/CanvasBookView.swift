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

    @State private var crayonToolActive = false
    @State private var completedStrokes: [[CGPoint]] = []
    @State private var redoStrokeStack: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    var body: some View {
        GeometryReader { proxy in
            let m = CanvasBookMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)
            let spreadSize = m.bookSpreadSizeFitting(available: proxy.size)
            let crayonSize = m.crayonToolSide(forBookHeight: spreadSize.height)
            let bookCenter = CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
            let crayonCenter = m.crayonToolCenter(
                bookCenter: bookCenter,
                spreadWidth: spreadSize.width,
                crayonSize: crayonSize
            )

            ZStack {
                canvasBackgroundLayer()

                bookStage(
                    spreadSize: spreadSize,
                    metrics: m,
                    crayonToolActive: crayonToolActive,
                    completedStrokes: $completedStrokes,
                    redoStrokeStack: $redoStrokeStack,
                    currentStroke: $currentStroke
                )
                .position(x: bookCenter.x, y: bookCenter.y)

                crayonToolButton(size: crayonSize, isActive: crayonToolActive) {
                    crayonToolActive.toggle()
                }
                .position(x: crayonCenter.x, y: crayonCenter.y)

                VStack {
                    canvasHeaderBar(
                        metrics: m,
                        canUndo: !completedStrokes.isEmpty && currentStroke.isEmpty,
                        canRedo: !redoStrokeStack.isEmpty && currentStroke.isEmpty,
                        onUndo: undoLastStroke,
                        onRedo: redoLastStroke
                    )
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

    private func canvasHeaderBar(
        metrics: CanvasBookMetrics,
        canUndo: Bool,
        canRedo: Bool,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void
    ) -> some View {
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

                HStack(spacing: metrics.undoRedoSpacing) {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: metrics.undoRedoIconSize, weight: .medium))
                            .foregroundStyle(Color.black.opacity(canUndo ? 0.88 : 0.28))
                            .frame(width: metrics.undoRedoTapSide, height: metrics.undoRedoTapSide)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canUndo)
                    .offset(y: metrics.homeIconVerticalLift)
                    .accessibilityLabel(Text("Undo"))

                    Button(action: onRedo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: metrics.undoRedoIconSize, weight: .medium))
                            .foregroundStyle(Color.black.opacity(canRedo ? 0.88 : 0.28))
                            .frame(width: metrics.undoRedoTapSide, height: metrics.undoRedoTapSide)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRedo)
                    .offset(y: metrics.homeIconVerticalLift)
                    .accessibilityLabel(Text("Redo"))
                }
            }
        }
        .padding(.leading, metrics.headerLeadingPadding)
        .padding(.trailing, metrics.headerTrailingPadding)
        .padding(.top, metrics.headerTopPadding)
    }

    private func undoLastStroke() {
        guard currentStroke.isEmpty, let stroke = completedStrokes.popLast() else { return }
        redoStrokeStack.append(stroke)
    }

    private func redoLastStroke() {
        guard currentStroke.isEmpty, let stroke = redoStrokeStack.popLast() else { return }
        completedStrokes.append(stroke)
    }

    private func crayonToolButton(size: CGFloat, isActive: Bool, action: @escaping () -> Void) -> some View {
        let ringOutset: CGFloat = max(5, size * 0.055)
        return Button(action: action) {
            ZStack {
                if isActive {
                    Circle()
                        .stroke(Color.black, lineWidth: 1.25)
                        .frame(width: size + ringOutset, height: size + ringOutset)
                }
                // `bluecrayon` = `Assets.xcassets/bluecrayon.imageset`. SVG (especially with embedded raster) can look
                // slightly softer than design tools—that is normal iOS rendering.
                Image("bluecrayon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Blue crayon"))
        .accessibilityHint(Text("Tap to turn drawing on or off. When on, drag on the journal to draw."))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func bookStage(
        spreadSize: CGSize,
        metrics: CanvasBookMetrics,
        crayonToolActive: Bool,
        completedStrokes: Binding<[[CGPoint]]>,
        redoStrokeStack: Binding<[[CGPoint]]>,
        currentStroke: Binding<[CGPoint]>
    ) -> some View {
        let w = spreadSize.width
        let h = spreadSize.height
        let strokeWidth = max(2.8, w * 0.0065)
        let bookBounds = CGRect(origin: .zero, size: spreadSize)

        return ZStack {
            OpenBookSpreadCanvas(style: paperStyle)
                .frame(width: w, height: h)

            JournalStrokeOverlay(
                completedStrokes: completedStrokes.wrappedValue,
                currentStroke: currentStroke.wrappedValue,
                strokeColor: JournalPaperStyle.journalBlueCrayonStroke,
                lineWidth: strokeWidth
            )
            .frame(width: w, height: h)
            .allowsHitTesting(false)

            Color.clear
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .allowsHitTesting(crayonToolActive)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard crayonToolActive else { return }
                            let p = value.location
                            guard bookBounds.contains(p) else { return }
                            if let last = currentStroke.wrappedValue.last {
                                let dx = p.x - last.x
                                let dy = p.y - last.y
                                if (dx * dx + dy * dy) < 0.8 { return }
                            }
                            currentStroke.wrappedValue.append(p)
                        }
                        .onEnded { _ in
                            guard crayonToolActive else { return }
                            if !currentStroke.wrappedValue.isEmpty {
                                completedStrokes.wrappedValue.append(currentStroke.wrappedValue)
                                redoStrokeStack.wrappedValue = []
                            }
                            currentStroke.wrappedValue = []
                        }
                )
        }
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
            available.width - 2 * bookFitHorizontalInset - safeArea.leading - safeArea.trailing - crayonColumnReserve
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

    var undoRedoIconSize: CGFloat { min(shortSide * 0.05, 24) }

    var undoRedoTapSide: CGFloat { max(44, shortSide * 0.1) }

    var undoRedoSpacing: CGFloat { shortSide * 0.01 }

    /// Reserve horizontal space so the larger crayon can sit left of the book; keeps fitting honest.
    var crayonColumnReserve: CGFloat {
        min(shortSide * 0.48, 300) + max(12, shortSide * 0.03)
    }

    /// Tool size uses `bluecrayon` from the asset catalog, scaled ~3× from the previous base (capped by screen).
    func crayonToolSide(forBookHeight bookH: CGFloat) -> CGFloat {
        let base = clamp(bookH * 0.19, min: 44, max: 88)
        let tripled = base * 3
        let maxAllowed = min(shortSide * 0.44, bookH * 0.72)
        return min(tripled, max(72, maxAllowed))
    }

    func crayonToolGap(forCrayonSize crayonSize: CGFloat) -> CGFloat {
        max(10, crayonSize * 0.14)
    }

    func crayonToolCenter(bookCenter: CGPoint, spreadWidth: CGFloat, crayonSize: CGFloat) -> CGPoint {
        let gap = crayonToolGap(forCrayonSize: crayonSize)
        let bookLeft = bookCenter.x - spreadWidth * 0.5
        let nudgeLeft = max(10, shortSide * 0.028)
        let desiredX = bookLeft - gap - crayonSize * 0.5 - nudgeLeft
        let minX = safeArea.leading + crayonSize * 0.5 + 6
        return CGPoint(x: max(minX, desiredX), y: bookCenter.y)
    }
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - Drawing overlay

private struct JournalStrokeOverlay: View {
    let completedStrokes: [[CGPoint]]
    let currentStroke: [CGPoint]
    let strokeColor: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            for stroke in completedStrokes {
                drawStroke(stroke, in: &context)
            }
            drawStroke(currentStroke, in: &context)
        }
    }

    private func drawStroke(_ stroke: [CGPoint], in context: inout GraphicsContext) {
        guard !stroke.isEmpty else { return }
        if stroke.count == 1, let p = stroke.first {
            let r = lineWidth * 0.55
            let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            context.fill(dot, with: .color(strokeColor))
            return
        }
        var path = Path()
        path.move(to: stroke[0])
        for i in 1..<stroke.count {
            path.addLine(to: stroke[i])
        }
        context.stroke(
            path,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
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
