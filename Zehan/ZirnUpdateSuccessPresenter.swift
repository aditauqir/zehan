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
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
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
        ) {
            panel.close()
        }

        panel.contentView = NSHostingView(rootView: rootView)
        panel.makeKeyAndOrderFront(nil)
    }
}

private struct ZirnUpdateSuccessView: View {
    let version: String
    let releaseNotesHTML: String?
    let onContinue: () -> Void

    private var hasReleaseNotes: Bool {
        guard let releaseNotesHTML else { return false }
        return !releaseNotesHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Successfully updated")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Zirn is now on version \(version).")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            if hasReleaseNotes {
                Text("What's new")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                ZirnReleaseNotesText(html: releaseNotesHTML ?? "")
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }

            HStack {
                Spacer()
                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(.regularMaterial)
    }
}

private struct ZirnReleaseNotesText: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        if let data = html.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue,
               ],
               documentAttributes: nil
           ) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = html
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}
}
