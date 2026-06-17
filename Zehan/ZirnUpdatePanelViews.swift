//
//  ZirnUpdatePanelViews.swift
//  Zirn
//

import AppKit
import SwiftUI

struct ZirnUpdateFoundView: View {
    let version: String
    let releaseNotesHTML: String?
    let onUpdate: () -> Void
    let onDismiss: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZirnUpdatePanelShell(
            headline: "Update available",
            message: "Review the changes before installing.",
            badgeText: "Ready to install",
            version: version,
            releaseNotesHTML: releaseNotesHTML
        ) {
            Button("Skip This Version", action: onSkip)
            Button("Don't Update", action: onDismiss)
            Button("Update", action: onUpdate)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct ZirnUpdateSuccessView: View {
    let version: String
    let releaseNotesHTML: String?
    let onContinue: () -> Void

    var body: some View {
        ZirnUpdatePanelShell(
            headline: "Successfully updated",
            message: "Zirn is now on this version.",
            badgeText: "Installed",
            version: version,
            releaseNotesHTML: releaseNotesHTML
        ) {
            Button("Continue", action: onContinue)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct ZirnUpdatePanelShell<Actions: View>: View {
    let headline: String
    let message: String
    let badgeText: String
    let version: String
    let releaseNotesHTML: String?
    @ViewBuilder let actions: () -> Actions

    private var hasReleaseNotes: Bool {
        guard let releaseNotesHTML else { return false }
        return !releaseNotesHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ZirnUpdateIdentityColumn(
                headline: headline,
                message: message,
                badgeText: badgeText,
                version: version
            )
            .frame(width: 232)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Features and bug fixes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Release notes for \(version)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if hasReleaseNotes {
                    ZirnReleaseNotesText(html: releaseNotesHTML ?? "")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.42))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                        }
                } else {
                    Text("No release notes were included for this update.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                        }
                }

                HStack(spacing: 8) {
                    Spacer()
                    actions()
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 760, height: 430)
        .background(.regularMaterial)
    }
}

private struct ZirnUpdateIdentityColumn: View {
    let headline: String
    let message: String
    let badgeText: String
    let version: String

    private var displayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Zirn"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 70, height: 70)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 7) {
                Text(displayName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(version)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(badgeText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.78))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.07), in: Capsule())

            Spacer(minLength: 18)

            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.045))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
    }
}

struct ZirnReleaseNotesText: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        scrollView.documentView = textView
        context.coordinator.apply(html: html, to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.apply(html: html, to: textView)
    }

    final class Coordinator {
        private var appliedHTML: String?

        func apply(html: String, to textView: NSTextView) {
            guard appliedHTML != html else { return }
            appliedHTML = html

            if let attributed = Self.attributedReleaseNotes(from: html) {
                textView.textStorage?.setAttributedString(attributed)
            } else {
                textView.string = html
            }
        }

        private static func attributedReleaseNotes(from html: String) -> NSAttributedString? {
            guard let data = html.data(using: .utf8),
                  let attributed = try? NSMutableAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue,
                    ],
                    documentAttributes: nil
                  )
            else { return nil }

            let fullRange = NSRange(location: 0, length: attributed.length)
            attributed.addAttributes(
                [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.systemFont(ofSize: 13),
                ],
                range: fullRange
            )
            return attributed
        }
    }
}
