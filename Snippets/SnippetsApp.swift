//
//  SnippetsApp.swift
//  Snippets
//
//  Created by Pragathi Chengappa on 02/05/26.
//

import SwiftUI

@main
struct SnippetsApp: App {
    @State private var journalTitles = WelcomeView.defaultJournalNames

    var body: some Scene {
        WindowGroup {
            WelcomeView(journalTitles: $journalTitles)
        }
    }
}
