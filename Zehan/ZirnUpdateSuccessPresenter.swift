//
//  ZirnUpdateSuccessPresenter.swift
//  Zirn
//

import AppKit
import SwiftUI

@MainActor
enum ZirnUpdateSuccessPresenter {
    static func show(version: String, releaseNotesHTML: String?) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Update complete"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = false
        panel.isReleasedWhenClosed = true
        panel.level = .modalPanel
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.center()

        let rootView = ZirnUpdateSuccessView(
            version: version,
            releaseNotesHTML: releaseNotesHTML
        ) { [weak panel] in
            panel?.close()
        }

        panel.contentView = NSHostingView(rootView: rootView)
        panel.makeKeyAndOrderFront(nil)
    }
}
