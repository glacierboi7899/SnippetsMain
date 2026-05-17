//
//  SnippetsApp.swift
//  Snippets
//
//  Created by Pragathi Chengappa on 02/05/26.
//

import SwiftUI

@main
struct SnippetsApp: App {
    var body: some Scene {
        WindowGroup {
            SnippetsRootView()
        }
    }
}

/// Routes between welcome, page layout, and canvas editor.
struct SnippetsRootView: View {
    @State private var journalTitles = WelcomeView.defaultJournalNames
    @State private var journalCoverColors = WelcomeView.defaultJournalCoverColors
    @State private var showPageLayout = false
    @State private var showGallery = false
    @State private var canvasSession: CanvasSession?
    @State private var lastCreatedJournalThumbnail: CGImage?
    @State private var lastCreatedJournalCoverColors: JournalCoverColors?

    var body: some View {
        Group {
            if showGallery {
                GalleryView(
                    lastCreatedThumbnail: lastCreatedJournalThumbnail,
                    onDeleteLatest: {
                        lastCreatedJournalThumbnail = nil
                        lastCreatedJournalCoverColors = nil
                    },
                    onPinLatest: {
                        guard let colors = lastCreatedJournalCoverColors, !journalCoverColors.isEmpty else { return }
                        journalCoverColors[0] = colors
                    },
                    onHome: {
                        showGallery = false
                        showPageLayout = false
                        canvasSession = nil
                        lastCreatedJournalThumbnail = nil
                        lastCreatedJournalCoverColors = nil
                    }
                )
            } else if let session = canvasSession {
                CanvasBookView(
                    paperStyle: session.paperStyle,
                    onHome: {
                        canvasSession = nil
                        showPageLayout = false
                        showGallery = false
                    },
                    onBack: {
                        canvasSession = nil
                    },
                    onTimerExpired: { image in
                        canvasSession = nil
                        showPageLayout = false
                        lastCreatedJournalThumbnail = image
                        lastCreatedJournalCoverColors = session.coverColors
                        showGallery = true
                    }
                )
                .id(session.transitionId)
            } else if showPageLayout {
                PageLayoutView(
                    onHome: { showPageLayout = false },
                    onOpenCanvas: { paper, colors in
                        canvasSession = CanvasSession(
                            paperStyle: paper,
                            coverColors: colors,
                            transitionId: UUID()
                        )
                    }
                )
            } else {
                WelcomeView(
                    journalTitles: $journalTitles,
                    journalCoverColors: $journalCoverColors,
                    onAddJournal: { showPageLayout = true }
                )
            }
        }
    }
}

private struct CanvasSession {
    var paperStyle: JournalPaperStyle
    var coverColors: JournalCoverColors
    var transitionId: UUID
}
