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

    /// A few tonal steps darker than the cream paper so dots stay subtle.
    static var journalDottedGridDotColor: Color {
        Color(red: 0.97 - 0.024, green: 0.94 - 0.024, blue: 0.86 - 0.024)
    }

    static func journalDottedGridStep(minInnerDimension: CGFloat) -> CGFloat {
        max(11, minInnerDimension / 18)
    }

    static func journalDottedGridDotRadius(step: CGFloat) -> CGFloat {
        max(0.65, min(step * 0.09, 2.1))
    }
}
