//
//  ZirnSparkleUpdaterDelegate.swift
//  Zirn
//

import Sparkle

@MainActor
final class ZirnSparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        ZirnPendingUpdateStore.save(
            version: item.displayVersionString,
            releaseNotesHTML: item.itemDescription
        )
    }
}
