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

                Button("Open Page") {
                    store.togglePageSearch()
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
                Button("Save Page") {
                    store.saveCurrentNote()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(store.activeBrain == nil)

                Button("Save Vault") {
                    store.saveVault()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeBrain == nil)
            }

            CommandMenu("Settings") {
                Button("Configure Model") {
                    store.configureModelFromUser()
                }
            }
        }
    }
}
