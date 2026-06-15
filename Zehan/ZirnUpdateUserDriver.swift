//
//  ZirnUpdateUserDriver.swift
//  Zirn
//

import AppKit
import Sparkle

/// Presents Zirn-branded update prompts while delegating download/install UI to Sparkle.
@MainActor
final class ZirnUpdateUserDriver: NSObject, SPUUserDriver {
    private let standardDriver: SPUStandardUserDriver

    init(hostBundle: Bundle) {
        standardDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        super.init()
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        standardDriver.show(request, reply: reply)
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        standardDriver.showUserInitiatedUpdateCheck(cancellation: cancellation)
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "New update for Zirn \(appcastItem.displayVersionString) available."
        alert.informativeText = "Review what changed, then choose whether to install it now."
        if let releaseNotesView = releaseNotesAccessoryView(for: appcastItem.itemDescription) {
            alert.accessoryView = releaseNotesView
        }
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Don't Update")
        alert.addButton(withTitle: "Skip This Version")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            ZirnPendingUpdateStore.save(
                version: appcastItem.displayVersionString,
                releaseNotesHTML: appcastItem.itemDescription
            )
            reply(.install)
        case .alertThirdButtonReturn:
            reply(.skip)
        default:
            reply(.dismiss)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        standardDriver.showUpdateReleaseNotes(with: downloadData)
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        standardDriver.showUpdateReleaseNotesFailedToDownloadWithError(error)
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        standardDriver.showUpdateNotFoundWithError(error, acknowledgement: acknowledgement)
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        standardDriver.showUpdaterError(error, acknowledgement: acknowledgement)
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        standardDriver.showDownloadInitiated(cancellation: cancellation)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        standardDriver.showDownloadDidReceiveExpectedContentLength(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        standardDriver.showDownloadDidReceiveData(ofLength: length)
    }

    func showDownloadDidStartExtractingUpdate() {
        standardDriver.showDownloadDidStartExtractingUpdate()
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        standardDriver.showExtractionReceivedProgress(progress)
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        standardDriver.showReady(toInstallAndRelaunch: reply)
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        standardDriver.showInstallingUpdate(
            withApplicationTerminated: applicationTerminated,
            retryTerminatingApplication: retryTerminatingApplication
        )
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        if relaunched {
            let pending = ZirnPendingUpdateStore.consume()
            let version = pending?.version
                ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
                ?? "this version"
            ZirnUpdateSuccessPresenter.show(
                version: version,
                releaseNotesHTML: pending?.releaseNotesHTML
            )
            acknowledgement()
            return
        }

        standardDriver.showUpdateInstalledAndRelaunched(relaunched, acknowledgement: acknowledgement)
    }

    func dismissUpdateInstallation() {
        standardDriver.dismissUpdateInstallation()
    }

    func showUpdateInFocus() {
        standardDriver.showUpdateInFocus()
    }

    private func releaseNotesAccessoryView(for html: String?) -> NSView? {
        guard let html,
              !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "What's changed")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor.withAlphaComponent(0.72)
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        if let attributed = attributedReleaseNotes(from: html) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = html
        }

        scrollView.documentView = textView
        container.addArrangedSubview(title)
        container.addArrangedSubview(scrollView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 420),
            scrollView.widthAnchor.constraint(equalTo: container.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 190),
        ])

        return container
    }

    private func attributedReleaseNotes(from html: String) -> NSAttributedString? {
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
                .font: NSFont.systemFont(ofSize: 12),
            ],
            range: fullRange
        )
        return attributed
    }
}
