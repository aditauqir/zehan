//
//  ZirnPendingUpdateStore.swift
//  Zirn
//

import Foundation

/// Persists update metadata across the Sparkle relaunch so we can show release notes on first launch.
enum ZirnPendingUpdateStore {
    private static let versionKey = "zirn.pendingUpdate.version"
    private static let notesKey = "zirn.pendingUpdate.notesHTML"

    static func save(version: String, releaseNotesHTML: String?) {
        UserDefaults.standard.set(version, forKey: versionKey)
        UserDefaults.standard.set(releaseNotesHTML, forKey: notesKey)
    }

    static func consume() -> (version: String, releaseNotesHTML: String?)? {
        guard let version = UserDefaults.standard.string(forKey: versionKey), !version.isEmpty else {
            return nil
        }
        let notes = UserDefaults.standard.string(forKey: notesKey)
        UserDefaults.standard.removeObject(forKey: versionKey)
        UserDefaults.standard.removeObject(forKey: notesKey)
        return (version, notes)
    }
}
