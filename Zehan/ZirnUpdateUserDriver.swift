//
//  ZirnUpdateUserDriver.swift
//  Zirn
//

import AppKit
import Sparkle
import SwiftUI

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

        let versionTitle = ZirnUpdateVersionDisplay.title(for: appcastItem)
        let releaseNotesHTML = appcastItem.itemDescription
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Update available"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = false
        panel.isReleasedWhenClosed = false
        panel.level = .modalPanel
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .alertPanel

        var didStopModal = false
        let stopModal: (NSApplication.ModalResponse) -> Void = { response in
            guard !didStopModal else { return }
            didStopModal = true
            NSApp.stopModal(withCode: response)
        }

        let closeDelegate = ZirnUpdateModalPanelDelegate {
            stopModal(.alertSecondButtonReturn)
        }
        panel.delegate = closeDelegate

        panel.contentView = NSHostingView(
            rootView: ZirnUpdateFoundView(
                version: versionTitle,
                releaseNotesHTML: releaseNotesHTML,
                onUpdate: { [weak panel] in
                    stopModal(.alertFirstButtonReturn)
                    panel?.close()
                },
                onDismiss: { [weak panel] in
                    stopModal(.alertSecondButtonReturn)
                    panel?.close()
                },
                onSkip: { [weak panel] in
                    stopModal(.alertThirdButtonReturn)
                    panel?.close()
                }
            )
        )
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        panel.delegate = nil

        switch response {
        case .alertFirstButtonReturn:
            ZirnPendingUpdateStore.save(
                version: versionTitle,
                releaseNotesHTML: releaseNotesHTML
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
        let currentVersion = Self.currentVersionDisplay()
        let originalError = error as NSError
        let presentationError = NSError(
            domain: originalError.domain,
            code: originalError.code,
            userInfo: [
                NSLocalizedDescriptionKey: "You are up to date (\(currentVersion))",
            ]
        )
        standardDriver.showUpdateNotFoundWithError(presentationError, acknowledgement: acknowledgement)
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

    private static func currentVersionDisplay() -> String {
        let rawVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rawVersion, !rawVersion.isEmpty else {
            return "the current version"
        }

        return rawVersion.lowercased().hasPrefix("v") ? rawVersion : "v\(rawVersion)"
    }
}

private final class ZirnUpdateModalPanelDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
