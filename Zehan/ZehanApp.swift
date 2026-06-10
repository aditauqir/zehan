//
//  ZirnApp.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import CoreText
import SwiftUI

@main
struct ZirnApp: App {
    @StateObject private var store = BrainStore()

    init() {
        Self.registerBundledFonts()
    }

    private static func registerBundledFonts() {
        guard let url = Bundle.main.url(forResource: "PT_Serif-Web-Regular", withExtension: "ttf") else {
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

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

                Button("New Group") {
                    store.createSidebarGroup()
                }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(store.activeBrain == nil)
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
                Button("Bold") {
                    NSApp.sendAction(NSSelectorFromString("toggleBoldface:"), to: nil, from: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    NSApp.sendAction(NSSelectorFromString("toggleItalics:"), to: nil, from: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Underline") {
                    NSApp.sendAction(NSSelectorFromString("underline:"), to: nil, from: nil)
                }
                .keyboardShortcut("u", modifiers: .command)

                Button("Highlight") {
                    NSApp.sendAction(NSSelectorFromString("highlightSelection:"), to: nil, from: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Delete") {
                    store.deleteSelectedSidebarItem()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.activeBrain == nil || (store.selectedSidebarGroupID == nil && store.selectedNoteID == nil && store.currentNoteID == nil))
            }

            CommandGroup(replacing: .appVisibility) {
                Button("Hide Zirn") {
                    NSApp.hide(nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option])

                Button("Hide Others") {
                    NSApp.hideOtherApplications(nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option, .shift])

                Button("Show All") {
                    NSApp.unhideAllApplications(nil)
                }
            }

            CommandMenu("User Settings") {
                Button("Configure Username") {
                    store.configureUsernameFromUser()
                }
            }

            CommandMenu("Settings") {
                Button("Configure Model") {
                    store.configureModelFromUser()
                }

                Button("Models Used Where") {
                    store.showUsedModelsConfiguration()
                }

                Divider()

                Button("Compile Highlight Summary") {
                    store.compileCurrentHighlightSummary()
                }
                .disabled(!store.canCompileCurrentHighlights)
            }

            CommandGroup(replacing: .help) {
                Button("Zirn Help") {
                    store.showHelp()
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
    }
}
