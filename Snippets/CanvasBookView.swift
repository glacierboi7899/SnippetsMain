//
//  CanvasBookView.swift
//  Snippets
//
//  Full-bleed canvas with open book spread (selected layout).
//

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

private enum CanvasBookTheme {
    static let stampPink = Color(red: 1.0, green: 0.38, blue: 0.66)
}

// MARK: - Edit session

private enum CanvasEditSession {
    static let durationSeconds: TimeInterval = 30
}

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

private struct PastedStamp: Identifiable {
    let id = UUID()
    var center: CGPoint
    var side: CGFloat
}

private enum JournalUndoEntry {
    case stroke([CGPoint])
    case photo(PastedPhoto)
    case tape(PastedTapeStrip)
    case stamp(PastedStamp)
}

// MARK: - Screen

struct CanvasBookView: View {
    let paperStyle: JournalPaperStyle
    var onHome: () -> Void
    var onBack: () -> Void
    /// Called once when the edit timer reaches zero; includes a snapshot of the spread for the gallery.
    var onTimerExpired: (CGImage?) -> Void = { _ in }

    @State private var crayonToolActive = false
    @State private var completedStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    @State private var picAwaitingPlacement = false
    @State private var pastedPhotos: [PastedPhoto] = []

    @State private var tapeAwaitingPlacement = false
    @State private var pastedTapes: [PastedTapeStrip] = []

    @State private var stampAwaitingPlacement = false
    @State private var pastedStamps: [PastedStamp] = []

    @State private var showingChecklist = false
    @State private var checklistItemsChecked = Array(repeating: false, count: 3)

    @State private var undoStack: [JournalUndoEntry] = []
    @State private var redoStack: [JournalUndoEntry] = []

    /// Timed editing window; set on first tool activation (`nil` = not started).
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
            let stampSize = m.stampToolSide(forBookHeight: spreadSize.height)
            let stickyNoteSize = m.stickyNoteToolSide(forBookHeight: spreadSize.height)
            let bookCenter = CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
            let bookLeft = bookCenter.x - spreadSize.width * 0.5
            let bookRight = bookCenter.x + spreadSize.width * 0.5
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
            let rightToolX = m.rightToolCenterX(
                bookRight: bookRight,
                toolWidth: max(stampSize, stickyNoteSize),
                availableWidth: proxy.size.width
            )
            let rightStackTop = bookCenter.y - (stampSize + toolGap + stickyNoteSize) * 0.5
            let stampCenter = CGPoint(x: rightToolX, y: rightStackTop + stampSize * 0.5)
            let stickyNoteCenter = CGPoint(
                x: rightToolX,
                y: rightStackTop + stampSize + toolGap + stickyNoteSize * 0.5
            )
            let timerCenterY = max(
                proxy.safeAreaInsets.top + m.timerChipHeight * 0.5 + 4,
                bookCenter.y - spreadSize.height * 0.5 - m.timerToBookGap - m.timerChipHeight * 0.5
            )

            ZStack {
                canvasBackgroundLayer()

                bookStage(
                    spreadSize: spreadSize,
                    metrics: m,
                    editingLocked: editingLocked,
                    crayonToolActive: crayonToolActive,
                    picAwaitingPlacement: picAwaitingPlacement,
                    tapeAwaitingPlacement: tapeAwaitingPlacement,
                    stampAwaitingPlacement: stampAwaitingPlacement,
                    completedStrokes: completedStrokes,
                    currentStroke: $currentStroke,
                    pastedPhotos: pastedPhotos,
                    pastedTapes: pastedTapes,
                    pastedStamps: pastedStamps,
                    onStrokeCommitted: commitStroke,
                    onPastePhoto: { point in
                        pastePhoto(at: point, bookSize: spreadSize, photoSide: picSize)
                    },
                    onPasteTape: { point in
                        pasteTape(at: point, bookSize: spreadSize)
                    },
                    onPasteStamp: { point in
                        pasteStamp(at: point, bookSize: spreadSize, stampSide: m.stampPasteSide(forBookHeight: spreadSize.height))
                    }
                )
                // Pin layout to the spread so `.position` does not expand hit targets to the full screen
                // (which was painting the journal fill over the canvas and breaking tap coordinates).
                .frame(width: spreadSize.width, height: spreadSize.height)
                .position(x: bookCenter.x, y: bookCenter.y)
                .opacity(showingChecklist ? 0 : 1)

                JournalEditTimerBar(
                    deadline: editingDeadline,
                    referenceDate: timerTick,
                    isLocked: editingLocked,
                    totalSessionSeconds: Int(CanvasEditSession.durationSeconds)
                )
                .opacity(editingDeadline == nil ? 0.55 : 1)
                .allowsHitTesting(false)
                .position(x: bookCenter.x, y: timerCenterY)
                .opacity(showingChecklist ? 0 : 1)

                picToolButton(size: picSize, isAwaitingPlacement: picAwaitingPlacement) {
                    guard !editingLocked else { return }
                    picAwaitingPlacement.toggle()
                    if picAwaitingPlacement {
                        startSessionTimerIfNeeded()
                        crayonToolActive = false
                        tapeAwaitingPlacement = false
                        stampAwaitingPlacement = false
                    }
                }
                .disabled(editingLocked)
                .rotationEffect(.degrees(-35))
                .position(x: picCenter.x, y: picCenter.y)
                .opacity(showingChecklist ? 0 : 1)

                crayonToolButton(size: crayonSize, isActive: crayonToolActive) {
                    guard !editingLocked else { return }
                    crayonToolActive.toggle()
                    if crayonToolActive {
                        startSessionTimerIfNeeded()
                        picAwaitingPlacement = false
                        tapeAwaitingPlacement = false
                        stampAwaitingPlacement = false
                    }
                }
                .disabled(editingLocked)
                .position(x: crayonCenter.x, y: crayonCenter.y)
                .opacity(showingChecklist ? 0 : 1)

                tapeToolButton(size: tapeSize, isAwaitingPlacement: tapeAwaitingPlacement) {
                    guard !editingLocked else { return }
                    tapeAwaitingPlacement.toggle()
                    if tapeAwaitingPlacement {
                        startSessionTimerIfNeeded()
                        crayonToolActive = false
                        picAwaitingPlacement = false
                        stampAwaitingPlacement = false
                    }
                }
                .disabled(editingLocked)
                .position(x: tapeCenter.x, y: tapeCenter.y)
                .opacity(showingChecklist ? 0 : 1)

                stampToolButton(size: stampSize, isAwaitingPlacement: stampAwaitingPlacement) {
                    guard !editingLocked else { return }
                    stampAwaitingPlacement.toggle()
                    if stampAwaitingPlacement {
                        startSessionTimerIfNeeded()
                        crayonToolActive = false
                        picAwaitingPlacement = false
                        tapeAwaitingPlacement = false
                    }
                }
                .disabled(editingLocked)
                .position(x: stampCenter.x, y: stampCenter.y)
                .opacity(showingChecklist ? 0 : 1)

                stickyNoteToolButton(size: stickyNoteSize) {
                    guard !editingLocked else { return }
                    crayonToolActive = false
                    picAwaitingPlacement = false
                    tapeAwaitingPlacement = false
                    stampAwaitingPlacement = false
                    showingChecklist = true
                }
                .disabled(editingLocked)
                .position(x: stickyNoteCenter.x, y: stickyNoteCenter.y)
                .opacity(showingChecklist ? 0 : 1)

                Group {
                    if proxy.size.width > proxy.size.height {
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
                        .ignoresSafeArea(edges: .horizontal)
                    } else {
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
                }
                .opacity(showingChecklist ? 0 : 1)

                if showingChecklist {
                    ChecklistPromptScreen(
                        checkedItems: $checklistItemsChecked,
                        onClose: { showingChecklist = false }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                timerTick = Date()
                if editingLocked {
                    crayonToolActive = false
                    picAwaitingPlacement = false
                    tapeAwaitingPlacement = false
                    stampAwaitingPlacement = false
                    // In-flight stroke is cleared in `onChange(of: editingLocked)` after the gallery snapshot.
                }
            }
            .onChange(of: editingLocked) { _, locked in
                guard locked, editingDeadline != nil, !didFireTimerExpiryCallback else { return }
                didFireTimerExpiryCallback = true
                var snapshotStrokes = completedStrokes
                if !currentStroke.isEmpty {
                    snapshotStrokes.append(currentStroke)
                }
                let thumbnail = renderJournalThumbnail(
                    spreadSize: spreadSize,
                    paperStyle: paperStyle,
                    strokes: snapshotStrokes,
                    photos: pastedPhotos,
                    tapes: pastedTapes,
                    stamps: pastedStamps,
                    bookCornerRadius: m.bookCornerRadius
                )
                onTimerExpired(thumbnail)
                currentStroke = []
            }
        }
    }

    private func startSessionTimerIfNeeded() {
        if editingDeadline == nil {
            editingDeadline = Date().addingTimeInterval(CanvasEditSession.durationSeconds)
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

    private func pasteStamp(at location: CGPoint, bookSize: CGSize, stampSide: CGFloat) {
        guard stampAwaitingPlacement, !editingLocked else { return }
        let side = min(stampSide, bookSize.width - 4, bookSize.height - 4)
        let half = side * 0.5
        let clamped = CGPoint(
            x: min(max(location.x, half), bookSize.width - half),
            y: min(max(location.y, half), bookSize.height - half)
        )
        let stamp = PastedStamp(center: clamped, side: side)
        pastedStamps.append(stamp)
        undoStack.append(.stamp(stamp))
        redoStack.removeAll()
        stampAwaitingPlacement = false
    }

    private func applyUndo(_ entry: JournalUndoEntry) {
        switch entry {
        case .stroke:
            _ = completedStrokes.popLast()
        case .photo(let p):
            pastedPhotos.removeAll { $0.id == p.id }
        case .tape(let t):
            pastedTapes.removeAll { $0.id == t.id }
        case .stamp(let s):
            pastedStamps.removeAll { $0.id == s.id }
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
        case .stamp(let s):
            pastedStamps.append(s)
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
            HStack(alignment: .top, spacing: metrics.headerIconSpacing) {
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

                HStack(alignment: .top, spacing: metrics.undoRedoSpacing) {
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
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(.leading, metrics.headerLeadingPadding)
        .padding(.trailing, metrics.headerTrailingPadding)
        .padding(.top, metrics.headerTopPadding)
    }

    private func crayonToolButton(size: CGFloat, isActive: Bool, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Image("greencrayon")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Green crayon"))
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

    private func stampToolButton(size: CGFloat, isAwaitingPlacement: Bool, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Image("stamp")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Stamp"))
        .accessibilityHint(Text("Tap to select, then tap the journal to place a pink star stamp."))
    }

    private func stickyNoteToolButton(size: CGFloat, action: @escaping () -> Void) -> some View {
        return Button(action: action) {
            Image("stickynote")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Sticky note"))
        .accessibilityHint(Text("Sticky note tool"))
    }

    private func bookStage(
        spreadSize: CGSize,
        metrics: CanvasBookMetrics,
        editingLocked: Bool,
        crayonToolActive: Bool,
        picAwaitingPlacement: Bool,
        tapeAwaitingPlacement: Bool,
        stampAwaitingPlacement: Bool,
        completedStrokes: [[CGPoint]],
        currentStroke: Binding<[CGPoint]>,
        pastedPhotos: [PastedPhoto],
        pastedTapes: [PastedTapeStrip],
        pastedStamps: [PastedStamp],
        onStrokeCommitted: @escaping ([CGPoint]) -> Void,
        onPastePhoto: @escaping (CGPoint) -> Void,
        onPasteTape: @escaping (CGPoint) -> Void,
        onPasteStamp: @escaping (CGPoint) -> Void
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
                strokeColor: JournalPaperStyle.journalGreenCrayonStroke,
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

            ForEach(pastedStamps) { stamp in
                PinkStampStar()
                    .fill(CanvasBookTheme.stampPink)
                    .frame(width: stamp.side, height: stamp.side)
                    .position(stamp.center)
                    .shadow(color: CanvasBookTheme.stampPink.opacity(0.18), radius: 2, x: 0, y: 1)
                    .allowsHitTesting(false)
            }

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
                    (picAwaitingPlacement || tapeAwaitingPlacement || stampAwaitingPlacement) && !editingLocked && !crayonToolActive
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
                            } else if stampAwaitingPlacement {
                                onPasteStamp(p)
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

    var homeIconSize: CGFloat { min(shortSide * 0.052, 26) }

    var homeTapSide: CGFloat { max(48, shortSide * 0.11) }

    /// In landscape, icons stay on the top edge; portrait keeps a slight optical lift.
    var homeIconVerticalLift: CGFloat {
        isLandscapeLayout ? 0 : (-shortSide * 0.032 - 15)
    }

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

    var timerChipHeight: CGFloat { 42 }

    var timerToBookGap: CGFloat { max(8, shortSide * 0.018) }

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

    func rightToolCenterX(bookRight: CGFloat, toolWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
        let margin = max(14, shortSide * 0.028)
        let desired = bookRight + margin + toolWidth * 0.5
        let maxX = availableWidth - safeArea.trailing - toolWidth * 0.5 - 8
        return min(desired, maxX)
    }

    /// Tool size uses `greencrayon` from the asset catalog, scaled ~3× from the previous base (capped by screen).
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

    func stampToolSide(forBookHeight bookH: CGFloat) -> CGFloat {
        clamp(bookH * 0.24, min: 56, max: 96)
    }

    func stickyNoteToolSide(forBookHeight bookH: CGFloat) -> CGFloat {
        clamp(bookH * 0.50, min: 116, max: 200)
    }

    func stampPasteSide(forBookHeight bookH: CGFloat) -> CGFloat {
        clamp(bookH * 0.14, min: 34, max: 58)
    }
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - Checklist prompt screen

private struct ChecklistPromptScreen: View {
    @Binding var checkedItems: [Bool]
    var onClose: () -> Void

    private static let prompts = [
        "Draw a flower you saw recently",
        "Write 10 words that describe your day",
        "Add a picture of a sunset",
    ]

    var body: some View {
        GeometryReader { proxy in
            let shortSide = min(proxy.size.width, proxy.size.height)
            let noteWidth = min(proxy.size.width * 0.86, shortSide * 1.84)
            let noteHeight = min(proxy.size.height * 0.88, shortSide * 1.10)

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()

                ZStack(alignment: .topTrailing) {
                    Image("note")
                        .resizable()
                        .scaledToFill()
                        .frame(width: noteWidth, height: noteHeight)
                        .clipped()
                        .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 6)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: max(10, noteHeight * 0.045)) {
                        Spacer()
                            .frame(height: noteHeight * 0.30)

                        ForEach(Self.prompts.indices, id: \.self) { index in
                            ChecklistPromptRow(
                                prompt: Self.prompts[index],
                                isChecked: checkedItems.indices.contains(index) ? checkedItems[index] : false,
                                fontSize: clamp(shortSide * 0.032, min: 11, max: 15),
                                checkboxSide: clamp(shortSide * 0.038, min: 15, max: 20)
                            ) {
                                togglePrompt(at: index)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, noteWidth * 0.12)
                    .padding(.trailing, noteWidth * 0.18)
                    .frame(width: noteWidth, height: noteHeight)

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: max(15, shortSide * 0.04), weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.74))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, noteHeight * 0.08)
                    .padding(.trailing, noteWidth * 0.08 + 70)
                    .accessibilityLabel(Text("Close checklist"))
                }
                .frame(width: noteWidth, height: noteHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func togglePrompt(at index: Int) {
        guard checkedItems.indices.contains(index) else { return }
        checkedItems[index].toggle()
    }
}

private struct ChecklistPromptRow: View {
    let prompt: String
    let isChecked: Bool
    let fontSize: CGFloat
    let checkboxSide: CGFloat
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                Text(prompt)
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: true, vertical: false)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.36), lineWidth: 1.3)
                        .frame(width: checkboxSide, height: checkboxSide)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: checkboxSide * 0.72, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.24))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(prompt))
        .accessibilityValue(Text(isChecked ? "Checked" : "Unchecked"))
    }
}

// MARK: - Gallery snapshot (render spread off-screen)

@MainActor
private func renderJournalThumbnail(
    spreadSize: CGSize,
    paperStyle: JournalPaperStyle,
    strokes: [[CGPoint]],
    photos: [PastedPhoto],
    tapes: [PastedTapeStrip],
    stamps: [PastedStamp],
    bookCornerRadius: CGFloat
) -> CGImage? {
    guard spreadSize.width > 8, spreadSize.height > 8 else { return nil }
    let content = JournalSpreadStaticView(
        spreadSize: spreadSize,
        paperStyle: paperStyle,
        strokes: strokes,
        photos: photos,
        tapes: tapes,
        stamps: stamps,
        bookCornerRadius: bookCornerRadius
    )
    let renderer = ImageRenderer(content: content)
    renderer.scale = displayPixelScale()
    return renderer.cgImage
}

@MainActor
private func displayPixelScale() -> CGFloat {
#if os(iOS)
    return UIScreen.main.scale
#elseif os(macOS)
    return NSScreen.main?.backingScaleFactor ?? 2
#else
    return 2
#endif
}

/// Non-interactive spread for `ImageRenderer` (matches `bookStage` layers minus timer and gestures).
private struct JournalSpreadStaticView: View {
    let spreadSize: CGSize
    let paperStyle: JournalPaperStyle
    let strokes: [[CGPoint]]
    let photos: [PastedPhoto]
    let tapes: [PastedTapeStrip]
    let stamps: [PastedStamp]
    let bookCornerRadius: CGFloat

    var body: some View {
        let w = spreadSize.width
        let h = spreadSize.height
        let strokeWidth = max(2.8, w * 0.0065)
        ZStack {
            OpenBookSpreadCanvas(style: paperStyle)
                .frame(width: w, height: h)

            ForEach(photos) { photo in
                Image("pic")
                    .resizable()
                    .scaledToFit()
                    .frame(width: photo.side, height: photo.side)
                    .position(photo.center)
            }

            JournalStrokeOverlay(
                completedStrokes: strokes,
                currentStroke: [],
                strokeColor: JournalPaperStyle.journalGreenCrayonStroke,
                lineWidth: strokeWidth
            )
            .frame(width: w, height: h)

            ForEach(tapes) { strip in
                Image("tapecoloured")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: strip.width, height: strip.height)
                    .position(strip.center)
            }

            ForEach(stamps) { stamp in
                PinkStampStar()
                    .fill(CanvasBookTheme.stampPink)
                    .frame(width: stamp.side, height: stamp.side)
                    .position(stamp.center)
            }
        }
        .frame(width: w, height: h)
        .background(
            RoundedRectangle(cornerRadius: bookCornerRadius, style: .continuous)
                .fill(JournalPaperStyle.journalPagePaperFill)
        )
        .clipShape(RoundedRectangle(cornerRadius: bookCornerRadius, style: .continuous))
    }
}

// MARK: - Edit session timer (on journal)

private struct JournalEditTimerBar: View {
    let deadline: Date?
    let referenceDate: Date
    let isLocked: Bool
    let totalSessionSeconds: Int

    private var displaySeconds: Int {
        if isLocked { return 0 }
        guard let deadline else { return totalSessionSeconds }
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

// MARK: - Stamp shape

private struct PinkStampStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.5
        let innerRadius = outerRadius * 0.42
        var path = Path()

        for pointIndex in 0..<10 {
            let isOuterPoint = pointIndex.isMultiple(of: 2)
            let radius = isOuterPoint ? outerRadius : innerRadius
            let angle = -CGFloat.pi / 2 + CGFloat(pointIndex) * CGFloat.pi / 5
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if pointIndex == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
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
        onTimerExpired: { _ in }
    )
    .previewInterfaceOrientation(.landscapeLeft)
}
