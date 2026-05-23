//
//  ZirnApp.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import SwiftUI

@main
struct ZirnApp: App {
    @StateObject private var store = BrainStore()

    var body: some Scene {
        Window("Zirn", id: "main") {
            ContentView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Page") {
                    store.newDraft()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(store.activeBrain == nil)

                Button("Create New Brain") {
                    store.createBrainVaultFromUser()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Search Pages") {
                    store.showPageSearch()
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(store.activeBrain == nil)

                Button("Open Brain Vault") {
                    store.openBrainVaultFromUser()
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save Vault") {
                    store.saveVault()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeBrain == nil)
            }

            CommandGroup(after: .pasteboard) {
                Button("Delete Page") {
                    store.deleteSelectedNote()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.activeBrain == nil || (store.selectedNoteID == nil && store.currentNoteID == nil))
            }

            CommandMenu("Settings") {
                Button("Configure Model") {
                    store.configureModelFromUser()
                }
            }
        }
    }
}
