//
//  WelcomeView.swift
//  Snippets
//
//  Landscape welcome screen with full-bleed background and journal picks.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - WelcomeView

/// Primary landscape welcome experience for Snippets.
struct WelcomeView: View {
    /// Display names for the three journals (brown, blue, red), index `0...2`.
    @Binding var journalTitles: [String]
    @Binding var journalCoverColors: [JournalCoverColors]

    var onJournalSelected: (Int) -> Void
    var onAddJournal: () -> Void

    init(
        journalTitles: Binding<[String]>,
        journalCoverColors: Binding<[JournalCoverColors]> = .constant(WelcomeView.defaultJournalCoverColors),
        onJournalSelected: @escaping (Int) -> Void = { _ in },
        onAddJournal: @escaping () -> Void = {}
    ) {
        _journalTitles = journalTitles
        _journalCoverColors = journalCoverColors
        self.onJournalSelected = onJournalSelected
        self.onAddJournal = onAddJournal
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = WelcomeMetrics(size: proxy.size, safeArea: proxy.safeAreaInsets)

            ZStack {
                HomeBackgroundLayer()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    welcomeTitleBar(metrics: metrics)

                    journalsSection(metrics: metrics)
                        .padding(.top, metrics.titleToJournalsGap)

                    Spacer(minLength: metrics.contentToFooterSpacing)

                    AddJournalButton(iconPointSize: metrics.addIconPointSize, action: onAddJournal)
                        .frame(width: metrics.addButtonSide, height: metrics.addButtonSide)
                        .padding(.bottom, metrics.footerBottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func welcomeTitleBar(metrics: WelcomeMetrics) -> some View {
        Text("Snippets")
            .font(.system(size: metrics.titleFontSize, weight: .regular, design: .serif))
            .foregroundStyle(WelcomePalette.accentYellow)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, metrics.titleHorizontalReserve)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity)
            .padding(.leading, metrics.headerLeadingPadding)
            .padding(.trailing, metrics.headerTrailingPadding)
            .padding(.top, metrics.headerTopPadding)
    }

    private func journalsSection(metrics: WelcomeMetrics) -> some View {
        HStack(alignment: .top, spacing: metrics.journalColumnSpacing) {
            JournalColumn(
                title: bindingForJournalTitle(at: 0),
                coverColors: coverColorsForJournal(at: 0, fallback: .brownLeather),
                rotationDegrees: -10,
                metrics: metrics,
                onCoverTap: { onJournalSelected(0) }
            )
            .frame(maxWidth: .infinity)

            JournalColumn(
                title: bindingForJournalTitle(at: 1),
                coverColors: coverColorsForJournal(at: 1, fallback: .deepBlue),
                rotationDegrees: 0,
                metrics: metrics,
                onCoverTap: { onJournalSelected(1) }
            )
            .frame(maxWidth: .infinity)

            JournalColumn(
                title: bindingForJournalTitle(at: 2),
                coverColors: coverColorsForJournal(at: 2, fallback: .richRed),
                rotationDegrees: 10,
                metrics: metrics,
                onCoverTap: { onJournalSelected(2) }
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: metrics.contentRailWidth)
        .frame(maxWidth: .infinity)
    }

    private func bindingForJournalTitle(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard journalTitles.indices.contains(index) else { return "" }
                return journalTitles[index]
            },
            set: { newValue in
                guard journalTitles.indices.contains(index) else { return }
                journalTitles[index] = String(newValue.prefix(WelcomeView.maxJournalTitleLength))
            }
        )
    }

    private func coverColorsForJournal(at index: Int, fallback: JournalCoverStyle) -> JournalCoverColors {
        guard journalCoverColors.indices.contains(index) else { return fallback.colors }
        return journalCoverColors[index]
    }
}

extension WelcomeView {
    /// Maximum characters allowed per journal title (single-line field).
    static let maxJournalTitleLength = 15

    static let defaultJournalNames: [String] = [
        "Vacation Notes",
        "Daily Snippets",
        "Diary Sketches",
    ]

    static let defaultJournalCoverColors: [JournalCoverColors] = [
        JournalCoverStyle.brownLeather.colors,
        JournalCoverStyle.deepBlue.colors,
        JournalCoverStyle.richRed.colors,
    ]
}

// MARK: - Palette & layout metrics

private enum WelcomePalette {
    /// `#FFCC55` — all yellow accents on this screen.
    static let accentYellow = Color(red: 255 / 255, green: 204 / 255, blue: 85 / 255)
}

private struct WelcomeMetrics {
    let size: CGSize
    let safeArea: EdgeInsets

    private var shortSide: CGFloat { min(size.width, size.height) }
    private var longSide: CGFloat { max(size.width, size.height) }

    /// Horizontal band (~76%) reserved for journals so desk props stay visible at the sides.
    var contentRailWidth: CGFloat { longSide * 0.76 }

    // MARK: Title strip (aligned with `PageLayoutView` “Page Style” header)

    private var horizontalPad: CGFloat { shortSide * 0.045 }

    var headerLeadingPadding: CGFloat {
        max(horizontalPad, safeArea.leading + shortSide * 0.024)
    }

    var headerTrailingPadding: CGFloat {
        max(horizontalPad, safeArea.trailing + shortSide * 0.018)
    }

    var headerTopPadding: CGFloat {
        safeArea.top + shortSide * 0.034 + 6
    }

    var titleFontSize: CGFloat {
        min(max(shortSide * 0.068, 17), 26)
    }

    /// Matches Page Layout reserve (`homeTapSide + shortSide * 0.04`) for identical title inset.
    private var referenceTapSide: CGFloat { max(48, shortSide * 0.11) }

    var titleHorizontalReserve: CGFloat {
        referenceTapSide + shortSide * 0.04
    }

    var titleToJournalsGap: CGFloat { shortSide * 0.026 }

    /// Single-line title row height (room for up to 15 characters).
    var labelFieldHeight: CGFloat {
        tagFontSize * 1.38 + tagVerticalPadding * 2
    }

    var contentToFooterSpacing: CGFloat {
        shortSide * 0.024
    }

    var footerBottomPadding: CGFloat {
        safeArea.bottom + shortSide * 0.036
    }

    private var targetJournalHeight: CGFloat {
        clamp(shortSide * 0.58, min: 128, max: 258)
    }

    /// Journal width derived from portrait aspect and available rail width, scaled to 75% of the prior layout size.
    var journalWidth: CGFloat {
        let ideal = targetJournalHeight / 1.42
        let minimumGap = shortSide * 0.02
        let maxWidth = (contentRailWidth - 2 * minimumGap) / 3
        return min(ideal, maxWidth) * WelcomeMetrics.journalSizeScale
    }

    var journalHeight: CGFloat { journalWidth * 1.42 }

    var journalColumnSpacing: CGFloat {
        let minimumGap = shortSide * 0.02
        let spread = contentRailWidth - 3 * journalWidth
        return max(spread / 2, minimumGap)
    }

    var labelGap: CGFloat { shortSide * 0.018 }

    var tagFontSize: CGFloat {
        clamp(shortSide * 0.042, min: 10, max: 14)
    }

    var tagHorizontalPadding: CGFloat {
        clamp(shortSide * 0.028, min: 8, max: 14)
    }

    var tagVerticalPadding: CGFloat {
        clamp(shortSide * 0.014, min: 5, max: 8)
    }

    var addButtonSide: CGFloat {
        clamp(shortSide * 0.108, min: 36, max: 48)
    }

    var addIconPointSize: CGFloat {
        clamp(shortSide * 0.056, min: 18, max: 24)
    }

    private static let journalSizeScale: CGFloat = 0.75
}

private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - Background

private struct HomeBackgroundLayer: View {
    var body: some View {
        Image("BG Home")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }
}

// MARK: - Journal column

private struct JournalColumn: View {
    @Binding var title: String
    let coverColors: JournalCoverColors
    let rotationDegrees: Double
    let metrics: WelcomeMetrics
    let onCoverTap: () -> Void

    var body: some View {
        VStack(spacing: metrics.labelGap) {
            Button(action: onCoverTap) {
                JournalCoverView(colors: coverColors)
                    .frame(width: metrics.journalWidth, height: metrics.journalHeight)
                    .rotationEffect(.degrees(rotationDegrees))
                    .shadow(color: .black.opacity(0.36), radius: 11, x: 5, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title.isEmpty ? "Journal" : title))
            .accessibilityHint(Text("Opens this journal"))

            JournalTitleField(
                title: $title,
                fontSize: metrics.tagFontSize,
                horizontalPadding: metrics.tagHorizontalPadding,
                verticalPadding: metrics.tagVerticalPadding,
                editorHeight: metrics.labelFieldHeight
            )
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Editable title field

/// Single-line titles: `UITextField` on iOS (reliable display), SwiftUI `TextField` on macOS.

#if canImport(UIKit)

private struct JournalTitleEditor: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var characterLimit: Int

    private static let titleUIColor = UIColor(red: 255 / 255, green: 204 / 255, blue: 85 / 255, alpha: 1)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textAlignment = .center
        field.font = Self.serifFont(size: fontSize)
        field.textColor = Self.titleUIColor
        field.text = text
        field.autocorrectionType = .yes
        field.returnKeyType = .done
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = max(10, fontSize * 0.72)
        field.adjustsFontForContentSizeCategory = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        Self.applyHorizontalPadding(field, width: horizontalPadding)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.font = Self.serifFont(size: fontSize)
        uiView.textColor = Self.titleUIColor
        uiView.minimumFontSize = max(10, fontSize * 0.72)
        Self.applyHorizontalPadding(uiView, width: horizontalPadding)
        if uiView.text != text {
            uiView.text = text
        }
    }

    private static func applyHorizontalPadding(_ field: UITextField, width: CGFloat) {
        let h: CGFloat = 32
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: h))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: h))
        field.rightViewMode = .always
    }

    private static func serifFont(size: CGFloat) -> UIFont {
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        let descriptor = base.withDesign(.serif) ?? base
        return UIFont(descriptor: descriptor, size: size)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: JournalTitleEditor

        init(_ parent: JournalTitleEditor) {
            self.parent = parent
        }

        @objc func editingChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.rangeOfCharacter(from: .newlines) != nil {
                return false
            }
            let current = textField.text ?? ""
            guard let stringRange = Range(range, in: current) else { return true }
            let updated = current.replacingCharacters(in: stringRange, with: string)
            return updated.count <= parent.characterLimit
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

#else

private struct JournalTitleEditor: View {
    @Binding var text: String
    var fontSize: CGFloat
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var characterLimit: Int

    var body: some View {
        TextField("", text: constrainedBinding)
            .font(.system(size: fontSize, weight: .medium, design: .serif))
            .foregroundStyle(WelcomePalette.accentYellow)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }

    private var constrainedBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                let flat = newValue.replacingOccurrences(of: "\n", with: "")
                text = String(flat.prefix(characterLimit))
            }
        )
    }
}

#endif

private struct JournalTitleField: View {
    @Binding var title: String
    let fontSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let editorHeight: CGFloat

    private let cornerRadius: CGFloat = 8

    var body: some View {
        JournalTitleEditor(
            text: $title,
            fontSize: fontSize,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            characterLimit: WelcomeView.maxJournalTitleLength
        )
        .frame(height: editorHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.46))
        )
        .accessibilityLabel(Text("Journal name"))
        .accessibilityHint(Text("One line, up to \(WelcomeView.maxJournalTitleLength) characters"))
    }
}

// MARK: - Add button

private struct AddJournalButton: View {
    let iconPointSize: CGFloat
    let action: () -> Void

    private let cornerRadius: CGFloat = 10

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: iconPointSize, weight: .medium))
                .foregroundStyle(WelcomePalette.accentYellow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(WelcomePalette.accentYellow, lineWidth: 2)
        )
        .accessibilityLabel(Text("Add journal"))
        .accessibilityHint(Text("Creates a new journal"))
    }
}

// MARK: - Previews

/// Hosts `@State` for previews without `@Previewable` (broader Xcode compatibility).
private struct WelcomePreviewHost: View {
    @State private var titles = WelcomeView.defaultJournalNames

    var body: some View {
        WelcomeView(journalTitles: $titles)
    }
}

#Preview("Welcome — landscape") {
    WelcomePreviewHost()
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("Welcome — compact phone") {
    WelcomePreviewHost()
        .previewInterfaceOrientation(.landscapeLeft)
        .previewDevice("iPhone SE (3rd generation)")
}
