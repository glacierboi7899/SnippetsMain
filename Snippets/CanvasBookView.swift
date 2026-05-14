//
//  CanvasBookView.swift
//  Snippets
//
//  Full-bleed canvas with open book spread (selected layout).
//

import SwiftUI

// MARK: - Pasted items

private struct PastedPhoto: Identifiable {
    let id = UUID()
    var center: CGPoint
    var side: CGFloat
}

private struct PastedTapeStrip: Identifiable {
    let id = UUID()
    var center: CGPoint
    var width: CGFloat
    var height: CGFloat
}

private enum JournalUndoEntry {
    case stroke([CGPoint])
    case photo(PastedPhoto)
    case tape(PastedTapeStrip)
}

// MARK: - Screen

struct CanvasBookView: View {
    let paperStyle: JournalPaperStyle
    var onHome: () -> Void
    var onBack: () -> Void
    /// Called once when the edit timer reaches zero (navigate to gallery, etc.).
    var onTimerExpired: () -> Void = {}

    @State private var crayonToolActive = false
    @State private var completedStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    @State private var picAwaitingPlacement = false
    @State private var pastedPhotos: [PastedPhoto] = []

    @State private var tapeAwaitingPlacement = false
    @State private var pastedTapes: [PastedTapeStrip] = []

    @State private var undoStack: [JournalUndoEntry] = []
    @State private var redoStack: [JournalUndoEntry] = []

    /// Two-minute editing window; set on first tool activation (`nil` = not started).
    @State private var editingDeadline: Date?
    @State private var timerTick = Date()
    @State private var didFireTimerExpiryCallback = false

    private var editingLocked: Bool {
        guard let deadline = editingDeadline else { return false }
        return Date() >= deadline
    }

    var body: some View {
        GeometryReader { proxy in
            let m = CanvasBookMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)
            let spreadSize = m.bookSpreadSizeFitting(available: proxy.size)
            let crayonSize = m.crayonToolSide(forBookHeight: spreadSize.height)
            let picSize = m.picToolSide(forBookHeight: spreadSize.height)
            let tapeSize = m.tapeToolSide(forBookHeight: spreadSize.height)
            let bookCenter = CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
            let bookLeft = bookCenter.x - spreadSize.width * 0.5
            let toolGap = m.verticalToolStackGap(forBookHeight: spreadSize.height)
            let journalMargin = m.journalLeftToolClearance(shortSide: min(proxy.size.width, proxy.size.height))
            // Horizontal half-extent for pic (tilted ~35°); keep entire control left of the journal.
            let picHalfWidth = picSize * 0.62
            let tapeHalfWidth = tapeSize * 0.5
            let toolsColumnX = bookLeft - journalMargin - max(picHalfWidth, tapeHalfWidth)
            let tapeCenter = CGPoint(
                x: toolsColumnX,
                y: bookCenter.y - spreadSize.height * 0.12
            )
            let picCenter = CGPoint(
                x: toolsColumnX,
                y: tapeCenter.y + tapeSize * 0.5 + toolGap + picSize * 0.5 + 20
            )
            // Extreme left; intentional partial bleed past the screen edge.
            let crayonCenter = CGPoint(x: crayonSize * 0.38, y: bookCenter.y + spreadSize.height * 0.14)

            ZStack {
                canvasBackgroundLayer()

                bookStage(
                    spreadSize: spreadSize,
                    metrics: m,
                    editingLocked: editingLocked,
                    editingDeadline: editingDeadline,
                    timerTick: timerTick,
                    crayonToolActive: crayonToolActive,
                    picAwaitingPlacement: picAwaitingPlacement,
                    tapeAwaitingPlacement: tapeAwaitingPlacement,
                    completedStrokes: completedStrokes,
                    currentStroke: $currentStroke,
                    pastedPhotos: pastedPhotos,
                    pastedTapes: pastedTapes,
                    onStrokeCommitted: commitStroke,
                    onPastePhoto: { point in
                        pastePhoto(at: point, bookSize: spreadSize, photoSide: picSize)
                    },
                    onPasteTape: { point in
                        pasteTape(at: point, bookSize: spreadSize)
                    }
                )
                // Pin layout to the spread so `.position` does not expand hit targets to the full screen
                // (which was painting the journal fill over the canvas and breaking tap coordinates).
                .frame(width: spreadSize.width, height: spreadSize.height)
                .position(x: bookCenter.x, y: bookCenter.y)

                picToolButton(size: picSize, isAwaitingPlacement: picAwaitingPlacement) {
                    guard !editingLocked else { return }
                    picAwaitingPlacement.toggle()
                    if picAwaitingPlacement {
                        startSessionTimerIfNeeded()
                        crayonToolActive = false
                        tapeAwaitingPlacement = false
                    }
                }
                .disabled(editingLocked)
                .rotationEffect(.degrees(-35))
                .position(x: picCenter.x, y: picCenter.y)

                crayonToolButton(size: crayonSize, isActive: crayonToolActive) {
                    guard !editingLocked else { return }
                    crayonToolActive.toggle()
                    if crayonToolActive {
                        startSessionTimerIfNeeded()
                        picAwaitingPlacement = false
                        tapeAwaitingPlacement = false
                    }
                }
                .disabled(editingLocked)
                .position(x: crayonCenter.x, y: crayonCenter.y)

                tapeToolButton(size: tapeSize, isAwaitingPlacement: tapeAwaitingPlacement) {
                    guard !editingLocked else { return }
                    tapeAwaitingPlacement.toggle()
                    if tapeAwaitingPlacement {
                        startSessionTimerIfNeeded()
                        crayonToolActive = false
                        picAwaitingPlacement = false
                    }
                }
                .disabled(editingLocked)
                .position(x: tapeCenter.x, y: tapeCenter.y)

                VStack {
                    canvasHeaderBar(
                        metrics: m,
                        canUndo: !undoStack.isEmpty && currentStroke.isEmpty && !editingLocked,
                        canRedo: !redoStack.isEmpty && currentStroke.isEmpty && !editingLocked,
                        onUndo: undoLastChange,
                        onRedo: redoLastChange
                    )
                    Spacer(minLength: 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                timerTick = Date()
                if editingLocked {
                    crayonToolActive = false
                    picAwaitingPlacement = false
                    tapeAwaitingPlacement = false
                    if !currentStroke.isEmpty {
                        currentStroke = []
                    }
                }
            }
            .onChange(of: editingLocked) { _, locked in
                guard locked, editingDeadline != nil, !didFireTimerExpiryCallback else { return }
                didFireTimerExpiryCallback = true
                onTimerExpired()
            }
        }
    }

    private func startSessionTimerIfNeeded() {
        if editingDeadline == nil {
            editingDeadline = Date().addingTimeInterval(120)
        }
    }

    private func commitStroke(_ points: [CGPoint]) {
        guard !points.isEmpty else { return }
        completedStrokes.append(points)
        undoStack.append(.stroke(points))
        redoStack.removeAll()
    }

    private func pastePhoto(at location: CGPoint, bookSize: CGSize, photoSide: CGFloat) {
        guard picAwaitingPlacement, !editingLocked else { return }
        let side = min(photoSide, bookSize.width - 4, bookSize.height - 4)
        let half = side * 0.5
        let clamped = CGPoint(
            x: min(max(location.x, half), bookSize.width - half),
            y: min(max(location.y, half), bookSize.height - half)
        )
        let photo = PastedPhoto(center: clamped, side: side)
        pastedPhotos.append(photo)
        undoStack.append(.photo(photo))
        redoStack.removeAll()
        picAwaitingPlacement = false
    }

    private func pasteTape(at location: CGPoint, bookSize: CGSize) {
        guard tapeAwaitingPlacement, !editingLocked else { return }
        let width = min(bookSize.width * 0.42, bookSize.height * 0.38)
        let height = width * 0.32
        let hw = width * 0.5
        let hh = height * 0.5
        let clamped = CGPoint(
            x: min(max(location.x, hw), bookSize.width - hw),
            y: min(max(location.y, hh), bookSize.height - hh)
        )
        let strip = PastedTapeStrip(center: clamped, width: width, height: height)
        pastedTapes.append(strip)
        undoStack.append(.tape(strip))
        redoStack.removeAll()
        tapeAwaitingPlacement = false
    }

    private func applyUndo(_ entry: JournalUndoEntry) {
        switch entry {
        case .stroke:
            _ = completedStrokes.popLast()
        case .photo(let p):
            pastedPhotos.removeAll { $0.id == p.id }
        case .tape(let t):
            pastedTapes.removeAll { $0.id == t.id }
        }
    }

    private func applyRedo(_ entry: JournalUndoEntry) {
        switch entry {
        case .stroke(let pts):
            completedStrokes.append(pts)
        case .photo(let p):
            pastedPhotos.append(p)
        case .tape(let t):
            pastedTapes.append(t)
        }
    }

    private func undoLastChange() {
        guard !editingLocked, currentStroke.isEmpty, let entry = undoStack.popLast() else { return }
        applyUndo(entry)
        redoStack.append(entry)
    }

    private func redoLastChange() {
        guard !editingLocked, currentStroke.isEmpty, let entry = redoStack.popLast() else { return }
        applyRedo(entry)
        undoStack.append(entry)
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

    private func crayonToolButton(size: CGFloat, isActive: Bool, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Image("bluecrayon")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Blue crayon"))
        .accessibilityHint(Text("Tap to turn drawing on or off. When on, drag on the journal to draw."))
    }

    private func picToolButton(size: CGFloat, isAwaitingPlacement: Bool, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Image("pic")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Photo"))
        .accessibilityHint(Text("Tap to select, then tap the journal to place the photo."))
    }

    private func tapeToolButton(size: CGFloat, isAwaitingPlacement: Bool, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Image("tape")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Tape"))
        .accessibilityHint(Text("Tap to select, then tap the journal to place coloured tape."))
    }

    private func bookStage(
        spreadSize: CGSize,
        metrics: CanvasBookMetrics,
        editingLocked: Bool,
        editingDeadline: Date?,
        timerTick: Date,
        crayonToolActive: Bool,
        picAwaitingPlacement: Bool,
        tapeAwaitingPlacement: Bool,
        completedStrokes: [[CGPoint]],
        currentStroke: Binding<[CGPoint]>,
        pastedPhotos: [PastedPhoto],
        pastedTapes: [PastedTapeStrip],
        onStrokeCommitted: @escaping ([CGPoint]) -> Void,
        onPastePhoto: @escaping (CGPoint) -> Void,
        onPasteTape: @escaping (CGPoint) -> Void
    ) -> some View {
        let w = spreadSize.width
        let h = spreadSize.height
        let strokeWidth = max(2.8, w * 0.0065)
        let bookBounds = CGRect(origin: .zero, size: spreadSize)

        return ZStack {
            OpenBookSpreadCanvas(style: paperStyle)
                .frame(width: w, height: h)

            ForEach(pastedPhotos) { photo in
                Image("pic")
                    .resizable()
                    .scaledToFit()
                    .frame(width: photo.side, height: photo.side)
                    .position(photo.center)
                    .allowsHitTesting(false)
            }

            JournalStrokeOverlay(
                completedStrokes: completedStrokes,
                currentStroke: currentStroke.wrappedValue,
                strokeColor: JournalPaperStyle.journalBlueCrayonStroke,
                lineWidth: strokeWidth
            )
            .frame(width: w, height: h)
            .allowsHitTesting(false)

            ForEach(pastedTapes) { strip in
                Image("tapecoloured")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: strip.width, height: strip.height)
                    .position(strip.center)
                    .allowsHitTesting(false)
            }

            VStack {
                JournalEditTimerBar(
                    deadline: editingDeadline,
                    referenceDate: timerTick,
                    isLocked: editingLocked
                )
                .opacity(editingDeadline == nil ? 0.55 : 1)
                .padding(.top, h * 0.03)
                Spacer(minLength: 0)
            }
            .frame(width: w, height: h)
            .allowsHitTesting(false)

            Color.clear
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .allowsHitTesting(crayonToolActive && !editingLocked)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard crayonToolActive, !editingLocked else { return }
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
                            guard crayonToolActive, !editingLocked else { return }
                            if !currentStroke.wrappedValue.isEmpty {
                                onStrokeCommitted(currentStroke.wrappedValue)
                            }
                            currentStroke.wrappedValue = []
                        }
                )

            Color.clear
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .allowsHitTesting(
                    (picAwaitingPlacement || tapeAwaitingPlacement) && !editingLocked && !crayonToolActive
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard !editingLocked, !crayonToolActive else { return }
                            let p = value.location
                            guard bookBounds.contains(p) else { return }
                            if picAwaitingPlacement {
                                onPastePhoto(p)
                            } else if tapeAwaitingPlacement {
                                onPasteTape(p)
                            }
                        }
                )
        }
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

    /// Reserve horizontal space so the open book does not swallow the left tool strip.
    var crayonColumnReserve: CGFloat {
        min(shortSide * 0.40, 280) + max(12, shortSide * 0.028)
    }

    /// Minimum gap between the journal’s left edge and the rightmost edge of pic/tape tools.
    func journalLeftToolClearance(shortSide: CGFloat) -> CGFloat {
        max(16, shortSide * 0.028)
    }

    /// Tool size uses `bluecrayon` from the asset catalog, scaled ~3× from the previous base (capped by screen).
    func crayonToolSide(forBookHeight bookH: CGFloat) -> CGFloat {
        let base = clamp(bookH * 0.19, min: 44, max: 88)
        let tripled = base * 3
        let maxAllowed = min(shortSide * 0.44, bookH * 0.72)
        return min(tripled, max(72, maxAllowed))
    }

    func verticalToolStackGap(forBookHeight bookH: CGFloat) -> CGFloat {
        max(10, bookH * 0.034)
    }

    /// Palette `pic` control — doubled from the prior 1.5× sizing (capped for layout).
    func picToolSide(forBookHeight bookH: CGFloat) -> CGFloat {
        let scaled = clamp(bookH * 0.225, min: 84, max: 150)
        return min(scaled * 2, shortSide * 0.42, bookH * 0.52)
    }

    /// Palette `tape` control — 3× base so it stays visible like the reference.
    func tapeToolSide(forBookHeight bookH: CGFloat) -> CGFloat {
        let base = clamp(bookH * 0.11, min: 40, max: 76)
        let scaled = min(base * 3, shortSide * 0.36, bookH * 0.5)
        return max(48, scaled)
    }
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - Edit session timer (on journal)

private struct JournalEditTimerBar: View {
    let deadline: Date?
    let referenceDate: Date
    let isLocked: Bool

    private var displaySeconds: Int {
        if isLocked { return 0 }
        guard let deadline else { return 120 }
        return max(0, Int(ceil(deadline.timeIntervalSince(referenceDate))))
    }

    var body: some View {
        let minutes = displaySeconds / 60
        let seconds = displaySeconds % 60
        HStack(spacing: 10) {
            Image(systemName: "stopwatch")
                .font(.system(size: 17, weight: .semibold))
            Text(String(format: "%02d : %02d", minutes, seconds))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Editing time remaining"))
    }
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
        onBack: {},
        onTimerExpired: {}
    )
    .previewInterfaceOrientation(.landscapeLeft)
}
