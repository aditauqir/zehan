//
//  ZirnSparkleController.swift
//  Zirn
//

import AppKit
import Sparkle

/// Shared Sparkle updater for manual checks and automatic background update discovery.
@MainActor
final class ZirnSparkleController: NSObject {
    static let shared = ZirnSparkleController()

    private let userDriver: ZirnUpdateUserDriver
    private let updater: SPUUpdater
    private var started = false

    private override init() {
        userDriver = ZirnUpdateUserDriver(hostBundle: .main)
        updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: userDriver,
            delegate: nil
        )
        super.init()
    }

    func startIfNeeded() {
        guard !started else { return }
        do {
            try updater.start()
            started = true
        } catch {
            NSLog("Zirn Sparkle updater failed to start: \(error.localizedDescription)")
        }
    }

    func checkForUpdates() {
        startIfNeeded()
        updater.checkForUpdates()
    }
}
