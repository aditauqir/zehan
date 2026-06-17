//
//  ZirnApp.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import CoreText
import AppKit
import SwiftUI

@main
struct ZirnApp: App {
    @StateObject private var store = BrainStore()

    init() {
        Self.registerBundledFonts()
        ZirnSparkleController.shared.startIfNeeded()
    }

    private static func registerBundledFonts() {
        for fontName in ["PT_Serif-Web-Regular", "PT_Serif-Web-Italic"] {
            guard let url = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        Window("Zirn", id: "main") {
            ContentView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Zirn") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Zirn",
                            .applicationVersion: ZirnReleaseInfo.displayVersion,
                        ]
                    )
                }

                Button("Check for Updates…") {
                    ZirnSparkleController.shared.checkForUpdates()
                }
            }

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

                Button("Open Your Files") {
                    store.openFilesFolder()
                }
                .disabled(store.activeBrain == nil)

                Button("Go to Home") {
                    store.goToStartPage()
                }

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

            CommandMenu("Settings") {
                Button("Configure Username") {
                    store.configureUsernameFromUser()
                }

                Button("Login with iCloud (in dev)") {
                    store.loginWithICloudInDevelopment()
                }
                .disabled(true)

                Divider()

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

private enum ZirnReleaseInfo {
    static let codename = "Mizan"

    static var displayVersion: String {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "1.1"
        return "v\(version) (\(codename))"
    }
}
