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
    @State private var showPageLayout = false
    @State private var canvasSession: CanvasSession?

    var body: some View {
        Group {
            if let session = canvasSession {
                CanvasBookView(
                    paperStyle: session.paperStyle,
                    coverColors: session.coverColors,
                    onHome: {
                        canvasSession = nil
                        showPageLayout = false
                    },
                    onBack: {
                        canvasSession = nil
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
