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

    func makeNSView(context: Context) -> ZirnReleaseNotesScrollView {
        let scrollView = ZirnReleaseNotesScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .overlay
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
        textView.textContainer?.lineFragmentPadding = 0

        scrollView.documentView = textView
        context.coordinator.apply(html: html, to: textView, in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: ZirnReleaseNotesScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.apply(html: html, to: textView, in: scrollView)
    }

    final class Coordinator {
        private var appliedHTML: String?

        func apply(html: String, to textView: NSTextView, in scrollView: ZirnReleaseNotesScrollView) {
            guard appliedHTML != html else {
                scrollView.syncDocumentHeight()
                return
            }
            appliedHTML = html

            if let attributed = Self.attributedReleaseNotes(from: html) {
                textView.textStorage?.setAttributedString(attributed)
            } else {
                textView.string = Self.plainText(fromHTML: html)
                textView.font = NSFont.systemFont(ofSize: 13)
                textView.textColor = .labelColor
            }

            scrollView.syncDocumentHeight()
        }

        private static func attributedReleaseNotes(from html: String) -> NSAttributedString? {
            let items = extractListItems(from: html)
            guard !items.isEmpty else { return nil }

            let bodyFont = NSFont.systemFont(ofSize: 13)
            let result = NSMutableAttributedString()

            for (index, itemHTML) in items.enumerated() {
                if index > 0 {
                    result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
                }

                let itemText = plainText(fromHTML: itemHTML)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !itemText.isEmpty else { continue }

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = index == items.count - 1 ? 0 : 10
                paragraphStyle.lineSpacing = 2
                paragraphStyle.headIndent = 17
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.tabStops = [
                    NSTextTab(textAlignment: .left, location: 17, options: [:]),
                ]

                let line = NSMutableAttributedString(string: "•\t\(itemText)")
                line.addAttributes(
                    [
                        .font: bodyFont,
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: paragraphStyle,
                    ],
                    range: NSRange(location: 0, length: line.length)
                )
                result.append(line)
            }

            return result.length > 0 ? result : nil
        }

        private static func extractListItems(from html: String) -> [String] {
            guard let regex = try? NSRegularExpression(
                pattern: #"<li(?: [^>]*)?>(.*?)</li>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else { return [] }

            let nsHTML = html as NSString
            let fullRange = NSRange(location: 0, length: nsHTML.length)
            return regex.matches(in: html, range: fullRange).compactMap { match in
                guard match.numberOfRanges > 1 else { return nil }
                return nsHTML.substring(with: match.range(at: 1))
            }
        }

        private static func plainText(fromHTML fragment: String) -> String {
            let wrapped = "<meta charset=\"utf-8\">\(fragment)"
            guard let data = wrapped.data(using: .utf8),
                  let attributed = try? NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue,
                    ],
                    documentAttributes: nil
                  )
            else {
                return fragment
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
            }

            return attributed.string
                .replacingOccurrences(of: "\u{FFFC}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

final class ZirnReleaseNotesScrollView: NSScrollView {
    func syncDocumentHeight() {
        guard let textView = documentView as? NSTextView,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else { return }

        let contentWidth = max(contentSize.width, 1)
        textContainer.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)

        let usedHeight = layoutManager.usedRect(for: textContainer).height
        let inset = textView.textContainerInset
        let documentHeight = max(contentSize.height, usedHeight + inset.height * 2)

        textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: documentHeight)
        reflectScrolledClipView(contentView)
    }

    override func layout() {
        super.layout()
        syncDocumentHeight()
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        syncDocumentHeight()
    }
}
