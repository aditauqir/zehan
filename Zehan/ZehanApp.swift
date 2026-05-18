//
//  ZehanApp.swift
//  Zehan
//
//  Created by Adi Tauqir on 5/15/26.
//

import SwiftUI

@main
struct ZehanApp: App {
    @StateObject private var store = BrainStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Brain") {
                Button("Open Brain Vault") {
                    store.openBrainVaultFromUser()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Create New Brain") {
                    store.createBrainVaultFromUser()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Save Vault") {
                    store.saveVault()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeBrain == nil)
            }

            CommandMenu("Page") {
                Button("New Page") {
                    store.newDraft()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(store.activeBrain == nil)

                Button("Open Page") {
                    store.showPageSearch()
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(store.activeBrain == nil)

                Button("Save Page") {
                    store.saveCurrentNote()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(store.activeBrain == nil)
            }
        }
    }
}
