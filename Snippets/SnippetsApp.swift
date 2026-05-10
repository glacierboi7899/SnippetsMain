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

/// Routes between welcome home and new-journal page layout.
struct SnippetsRootView: View {
    @State private var journalTitles = WelcomeView.defaultJournalNames
    @State private var showPageLayout = false

    var body: some View {
        Group {
            if showPageLayout {
                PageLayoutView(onHome: { showPageLayout = false })
            } else {
                WelcomeView(
                    journalTitles: $journalTitles,
                    onAddJournal: { showPageLayout = true }
                )
            }
        }
    }
}
