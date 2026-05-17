//
//  JournalPaperStyle.swift
//  Snippets
//
//  Shared page pattern for layout picker and canvas editor.
//

import SwiftUI

enum JournalPaperStyle: Int, CaseIterable, Hashable, Sendable {
    case blank
    case dotted
    case ruled
    case grid
}

// MARK: - Paper + dotted grid (shared by canvas spread and layout thumbnails)

extension JournalPaperStyle {
    static var journalPagePaperFill: Color {
        Color(red: 0.97, green: 0.94, blue: 0.86)
    }

    /// Dot grid on cream paper (`#b6ac85`).
    static var journalDottedGridDotColor: Color {
        Color(red: 182 / 255, green: 172 / 255, blue: 133 / 255)
    }

    static func journalDottedGridStep(minInnerDimension: CGFloat) -> CGFloat {
        max(11, minInnerDimension / 18)
    }

    static func journalDottedGridDotRadius(step: CGFloat) -> CGFloat {
        max(0.65, min(step * 0.09, 2.1))
    }

    /// Stroke colour for the green crayon tool (matches the `greencrayon` asset).
    static var journalGreenCrayonStroke: Color {
        Color(red: 0.12, green: 0.52, blue: 0.30)
    }
}
