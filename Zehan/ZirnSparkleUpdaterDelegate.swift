//
//  ZirnSparkleUpdaterDelegate.swift
//  Zirn
//

import Foundation
import Sparkle

@MainActor
final class ZirnSparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        ZirnPendingUpdateStore.save(
            version: ZirnUpdateVersionDisplay.title(for: item),
            releaseNotesHTML: item.itemDescription
        )
    }
}

enum ZirnUpdateVersionDisplay {
    static func title(for item: SUAppcastItem) -> String {
        if let heading = releaseHeading(from: item.itemDescription) {
            return normalizedReleaseTitle(heading)
        }

        return normalizedReleaseTitle(item.displayVersionString)
    }

    private static func releaseHeading(from html: String?) -> String? {
        guard let html,
              !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        let pattern = #"<h2[^>]*>(.*?)</h2>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: nsRange),
              match.numberOfRanges > 1,
              let headingRange = Range(match.range(at: 1), in: html)
        else { return nil }

        let heading = String(html[headingRange])
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return heading.isEmpty ? nil : heading
    }

    private static func normalizedReleaseTitle(_ title: String) -> String {
        var normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.localizedCaseInsensitiveCompare("Zirn") == .orderedSame {
            return "this version"
        }

        if normalized.lowercased().hasPrefix("zirn ") {
            normalized = String(normalized.dropFirst(5))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if normalized.range(of: #"^\d"#, options: .regularExpression) != nil {
            normalized = "v\(normalized)"
        }

        return normalized.isEmpty ? "this version" : normalized
    }
}
