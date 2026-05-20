//
//  CorrectionLearningEngine.swift
//  Zirn
//
//  Created by Codex on 5/20/26.
//

import Foundation

struct PendingAssistantInsertion: Codable {
    let noteID: String?
    let noteTitle: String
    let prompt: String
    let contentBeforeInsertion: String
    let insertedMarkdown: String
    let contentAfterInsertion: String
    let createdAt: Date
}

struct CorrectionSignal: Codable, Identifiable {
    let id: String
    let noteID: String?
    let noteTitle: String
    let prompt: String
    let kind: CorrectionSignalKind
    let summary: String
    let beforeExcerpt: String
    let afterExcerpt: String
    let weight: Double
    let createdAt: Date
}

enum CorrectionSignalKind: String, Codable {
    case edit
    case deletion
    case reformat
    case rejectedStructure
    case rewrittenSummary
    case phrasingPreference
    case linkingPreference
}

struct CorrectionPreference: Codable, Identifiable {
    let id: String
    let category: CorrectionSignalKind
    var instruction: String
    var weight: Double
    var evidenceCount: Int
    var updatedAt: Date
}

struct CorrectionLearningEngine {
    private static let maxExcerptCharacters = 420

    static func makePendingInsertion(
        noteID: String?,
        noteTitle: String,
        prompt: String,
        contentBeforeInsertion: String,
        insertedMarkdown: String,
        contentAfterInsertion: String
    ) -> PendingAssistantInsertion {
        PendingAssistantInsertion(
            noteID: noteID,
            noteTitle: noteTitle,
            prompt: prompt,
            contentBeforeInsertion: contentBeforeInsertion,
            insertedMarkdown: insertedMarkdown,
            contentAfterInsertion: contentAfterInsertion,
            createdAt: Date()
        )
    }

    static func signals(
        from pending: PendingAssistantInsertion,
        revisedContent: String
    ) -> [CorrectionSignal] {
        guard revisedContent != pending.contentAfterInsertion else { return [] }

        var signals: [CorrectionSignal] = []
        let inserted = pending.insertedMarkdown
        let insertedPlain = plainText(inserted)
        let revisedPlain = plainText(revisedContent)
        let insertedWords = wordCount(insertedPlain)
        let contentAfterWords = max(1, wordCount(plainText(pending.contentAfterInsertion)))
        let revisedWords = wordCount(revisedPlain)
        let insertedStillPresent = revisedContent.localizedCaseInsensitiveContains(inserted)
            || revisedPlain.localizedCaseInsensitiveContains(insertedPlain)

        if !insertedStillPresent {
            let retainedRatio = retainedWordRatio(from: insertedPlain, in: revisedPlain)
            if retainedRatio < 0.28 {
                signals.append(
                    makeSignal(
                        pending: pending,
                        kind: .deletion,
                        summary: "User removed most of the assistant output. Treat this as a strong rejection signal.",
                        before: inserted,
                        after: revisedContent,
                        weight: 4.2
                    )
                )
            }
        }

        let insertedMetrics = MarkdownMetrics(markdown: inserted)
        let revisedMetrics = MarkdownMetrics(markdown: revisedContent)

        if insertedMetrics.headingCount > 0,
           revisedMetrics.headingCount < insertedMetrics.headingCount {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .rejectedStructure,
                    summary: "User reduced heading structure. Prefer fewer headings unless the user asks for a structured outline.",
                    before: inserted,
                    after: revisedContent,
                    weight: 3.4
                )
            )
        }

        if insertedMetrics.listItemCount >= 3,
           revisedMetrics.listItemCount < insertedMetrics.listItemCount / 2 {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .rejectedStructure,
                    summary: "User reduced list-heavy formatting. Avoid default bullet lists when prose would be more natural.",
                    before: inserted,
                    after: revisedContent,
                    weight: 3.1
                )
            )
        }

        if insertedMetrics.signature != revisedMetrics.signature,
           insertedStillPresent || retainedWordRatio(from: insertedPlain, in: revisedPlain) >= 0.28 {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .reformat,
                    summary: "User changed the Markdown shape after insertion. Mirror the user's local formatting pattern more closely.",
                    before: inserted,
                    after: revisedContent,
                    weight: 2.8
                )
            )
        }

        if insertedWords >= 40,
           revisedWords < Int(Double(contentAfterWords) * 0.72) {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .rewrittenSummary,
                    summary: "User compressed the assistant output. Prefer denser summaries with less explanatory padding.",
                    before: inserted,
                    after: revisedContent,
                    weight: 3.6
                )
            )
        }

        if insertedMetrics.linkCount > revisedMetrics.linkCount {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .linkingPreference,
                    summary: "User removed links. Add internal or external links only when they are clearly useful.",
                    before: inserted,
                    after: revisedContent,
                    weight: 2.9
                )
            )
        } else if revisedMetrics.wikiLinkCount > insertedMetrics.wikiLinkCount {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .linkingPreference,
                    summary: "User added wiki-style links. Prefer [[Note]] links when connecting related vault ideas.",
                    before: inserted,
                    after: revisedContent,
                    weight: 2.6
                )
            )
        }

        for phrase in dislikedPhrases(in: inserted, absentFrom: revisedContent) {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .phrasingPreference,
                    summary: "User removed phrasing pattern: \"\(phrase)\". Avoid that phrase or tone.",
                    before: phrase,
                    after: revisedContent,
                    weight: 2.7
                )
            )
        }

        if signals.isEmpty {
            signals.append(
                makeSignal(
                    pending: pending,
                    kind: .edit,
                    summary: "User edited assistant output. Prefer the user's post-edit style over the original generated wording.",
                    before: inserted,
                    after: revisedContent,
                    weight: 2.4
                )
            )
        }

        return deduplicated(signals)
    }

    static func mergedPreferences(
        existing: [CorrectionPreference],
        signals: [CorrectionSignal]
    ) -> [CorrectionPreference] {
        var preferences = existing

        for signal in signals {
            let instruction = instructionText(for: signal)
            if let index = preferences.firstIndex(where: {
                $0.category == signal.kind && $0.instruction == instruction
            }) {
                preferences[index].weight = min(12, preferences[index].weight + signal.weight)
                preferences[index].evidenceCount += 1
                preferences[index].updatedAt = signal.createdAt
            } else {
                preferences.insert(
                    CorrectionPreference(
                        id: UUID().uuidString,
                        category: signal.kind,
                        instruction: instruction,
                        weight: signal.weight,
                        evidenceCount: 1,
                        updatedAt: signal.createdAt
                    ),
                    at: 0
                )
            }
        }

        return preferences
            .sorted {
                if $0.weight == $1.weight {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.weight > $1.weight
            }
            .prefix(16)
            .map { $0 }
    }

    static func promptContext(
        preferences: [CorrectionPreference],
        signals: [CorrectionSignal]
    ) -> String {
        let preferenceLines = preferences
            .sorted { $0.weight > $1.weight }
            .prefix(8)
            .map { "- \($0.instruction) (weight \(String(format: "%.1f", $0.weight)), evidence \($0.evidenceCount))" }

        let signalLines = signals
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map { "- \($0.summary)" }

        return (preferenceLines + signalLines).joined(separator: "\n")
    }

    private static func instructionText(for signal: CorrectionSignal) -> String {
        switch signal.kind {
        case .edit:
            return "Prioritize the user's edited wording and structure over passive writing samples."
        case .deletion:
            return "When unsure, produce a smaller addition and avoid overwriting user-authored text."
        case .reformat:
            return "Match the user's existing Markdown shape before adding new structure."
        case .rejectedStructure:
            return signal.summary
        case .rewrittenSummary:
            return "Use concise, dense summaries and avoid filler."
        case .phrasingPreference:
            return signal.summary
        case .linkingPreference:
            return signal.summary
        }
    }

    private static func makeSignal(
        pending: PendingAssistantInsertion,
        kind: CorrectionSignalKind,
        summary: String,
        before: String,
        after: String,
        weight: Double
    ) -> CorrectionSignal {
        CorrectionSignal(
            id: UUID().uuidString,
            noteID: pending.noteID,
            noteTitle: pending.noteTitle,
            prompt: pending.prompt,
            kind: kind,
            summary: summary,
            beforeExcerpt: excerpt(before),
            afterExcerpt: excerpt(after),
            weight: weight,
            createdAt: Date()
        )
    }

    private static func deduplicated(_ signals: [CorrectionSignal]) -> [CorrectionSignal] {
        var seen = Set<String>()
        return signals.filter { signal in
            let key = "\(signal.kind.rawValue)|\(signal.summary)"
            return seen.insert(key).inserted
        }
    }

    private static func dislikedPhrases(in inserted: String, absentFrom revised: String) -> [String] {
        [
            "Here is",
            "Here's",
            "Certainly",
            "It is important to note",
            "In conclusion",
            "Overall",
            "This section",
            "Let's"
        ].filter {
            inserted.localizedCaseInsensitiveContains($0)
                && !revised.localizedCaseInsensitiveContains($0)
        }
    }

    private static func retainedWordRatio(from source: String, in target: String) -> Double {
        let sourceWords = Set(words(in: source))
        guard !sourceWords.isEmpty else { return 0 }
        let targetWords = Set(words(in: target))
        let retained = sourceWords.intersection(targetWords).count
        return Double(retained) / Double(sourceWords.count)
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    private static func wordCount(_ text: String) -> Int {
        words(in: text).count
    }

    private static func plainText(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"(?m)^---[\s\S]*?^---"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^#{1,6}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*[-*+]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*\d+[.)]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"`{1,3}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[*_~\[\]()>#|]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func excerpt(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxExcerptCharacters else { return trimmed }
        return String(trimmed.prefix(maxExcerptCharacters)) + "..."
    }
}

private struct MarkdownMetrics: Equatable {
    let headingCount: Int
    let listItemCount: Int
    let quoteCount: Int
    let codeFenceCount: Int
    let tableLineCount: Int
    let wikiLinkCount: Int
    let markdownLinkCount: Int

    var linkCount: Int {
        wikiLinkCount + markdownLinkCount
    }

    var signature: String {
        [
            "h:\(headingCount)",
            "l:\(listItemCount)",
            "q:\(quoteCount)",
            "c:\(codeFenceCount)",
            "t:\(tableLineCount)",
            "w:\(wikiLinkCount)",
            "m:\(markdownLinkCount)"
        ].joined(separator: "|")
    }

    init(markdown: String) {
        let lines = markdown.components(separatedBy: .newlines)
        headingCount = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil
        }.count
        listItemCount = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).range(of: #"^([-*+]|\d+[.)])\s+"#, options: .regularExpression) != nil
        }.count
        quoteCount = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix(">")
        }.count
        codeFenceCount = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("```")
                || $0.trimmingCharacters(in: .whitespaces).hasPrefix("~~~")
        }.count
        tableLineCount = lines.filter { $0.contains("|") }.count
        wikiLinkCount = Self.matches(in: markdown, pattern: #"\[\[[^\]]+\]\]"#)
        markdownLinkCount = Self.matches(in: markdown, pattern: #"\[[^\]]+\]\([^)]+\)"#)
    }

    private static func matches(in text: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )
    }
}
