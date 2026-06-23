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

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("y", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
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

                Button("Configure Models") {
                    store.configureModelFromUser()
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

        MenuBarExtra {
            UsageStatusBarView(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                Text(store.totalUsagePercentLabel)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct UsageStatusBarView: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Usage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(store.totalUsageLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 18)

                Text(store.totalUsagePercentLabel)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            ProgressView(value: store.totalUsageFraction)
                .progressViewStyle(.linear)
                .controlSize(.small)

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                UsageBreakdownRow(
                    title: "Mistral usage",
                    value: store.mistralUsageBreakdownLabel,
                    icon: .asset("ProviderMistralLogo")
                )

                UsageBreakdownRow(
                    title: "Mistral OCR",
                    value: store.mistralOCRUsageBreakdownLabel,
                    icon: .symbol("doc.viewfinder")
                )

                UsageBreakdownRow(
                    title: "DeepSeek usage",
                    value: store.deepSeekUsageBreakdownLabel,
                    icon: .asset("ProviderDeepSeekLogo")
                )
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}

private struct UsageBreakdownRow: View {
    let title: String
    let value: String
    let icon: UsageBreakdownIcon

    var body: some View {
        HStack(spacing: 9) {
            iconView
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.86))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private enum UsageBreakdownIcon {
    case asset(String)
    case symbol(String)
}

private enum ZirnReleaseInfo {
    static let codename = "Raxat"

    static var displayVersion: String {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "1.4.1"
        return "v\(version) (\(codename))"
    }
}
