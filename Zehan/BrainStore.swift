//
//  BrainStore.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import Combine
import Foundation
import AVFoundation
import AppKit
import CoreMedia
import NaturalLanguage
import PDFKit
import ScreenCaptureKit
import Speech
import SwiftUI
import UniformTypeIdentifiers
import WebKit

extension UTType {
    static let brainFile = UTType(filenameExtension: "brain") ?? .json
}

private enum AttachmentTarget {
    case assistant
    case helpDesk
}

private enum WorkspaceFileKind {
    case documents
    case images
    case pdfs

    var folderName: String {
        switch self {
        case .documents:
            return "Documents"
        case .images:
            return "Images"
        case .pdfs:
            return "PDFs"
        }
    }
}

enum AssistantGenerationPhase: Equatable {
    case idle
    case preparingContext
    case requesting
    case streaming
    case timedOut
    case failed(String)
}

enum VoiceCaptureTarget: Equatable {
    case editor
    case helpDesk
}

enum VoiceAudioSource: String, Equatable, CaseIterable, Identifiable {
    case systemAudio
    case microphone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemAudio:
            return "On Screen"
        case .microphone:
            return "Voice"
        }
    }

    var subtitle: String {
        switch self {
        case .systemAudio:
            return "Capture system audio"
        case .microphone:
            return "Capture microphone"
        }
    }

    var symbolName: String {
        switch self {
        case .systemAudio:
            return "display"
        case .microphone:
            return "mic.fill"
        }
    }
}

enum WhisperSmallModelInstallState: Equatable {
    case idle
    case checking
    case installing
    case ready(String)
    case failed(String)
}

enum VoiceTranscriptDestinationKind: Equatable {
    case note
    case folder
}

struct VoiceTranscriptDestination: Identifiable, Equatable {
    let id: String
    let kind: VoiceTranscriptDestinationKind
    let noteID: Note.ID?
    let groupID: SidebarItem.ID?
    let title: String
    let breadcrumb: String

    var symbolName: String {
        switch kind {
        case .note:
            return "doc.text"
        case .folder:
            return "folder"
        }
    }
}

struct VoiceTranscriptBreadcrumbSegment: Identifiable, Equatable {
    let id: Int
    let title: String
    let isDestinationPicker: Bool
}

struct VoiceTranscriptDraft: Identifiable, Equatable {
    let id = UUID()
    let target: VoiceCaptureTarget
    var text: String
    var noteID: Note.ID?
    var noteTitle: String
    var destinationGroupID: SidebarItem.ID?
    var destinationKind: VoiceTranscriptDestinationKind = .note
    let createdAt = Date()
    /// Full refine history; index 0 is the original transcript.
    var revisionHistory: [String]
    /// Current position in `revisionHistory` (0-based).
    var revisionIndex: Int

    init(
        target: VoiceCaptureTarget,
        text: String,
        noteID: Note.ID? = nil,
        noteTitle: String,
        destinationGroupID: SidebarItem.ID? = nil,
        destinationKind: VoiceTranscriptDestinationKind = .note
    ) {
        self.target = target
        self.text = text
        self.noteID = noteID
        self.noteTitle = noteTitle
        self.destinationGroupID = destinationGroupID
        self.destinationKind = destinationKind
        self.revisionHistory = [text]
        self.revisionIndex = 0
    }

    var revisionCounterLabel: String {
        let total = max(revisionHistory.count, 1)
        let current = min(max(revisionIndex + 1, 1), total)
        return "\(current)/\(total)"
    }

    var canUndoRevision: Bool { revisionIndex > 0 }
    var canRedoRevision: Bool { revisionIndex < revisionHistory.count - 1 }
}

struct VoiceClippingConfirmation: Identifiable, Equatable {
    let id = UUID()
    let target: VoiceCaptureTarget
    let destinationTitle: String
    let transcript: String
}

/// One voice insert recorded in the vault-local `.convo` sidecar (not the main brain file).
struct VoiceConversationEntry: Identifiable, Codable, Equatable {
    let id: String
    let createdAt: Date
    /// Number of revisions on the refine undo/redo stack at insert time.
    let revisionCount: Int
    let transcript: String
    let noteID: Note.ID
    let noteTitle: String
    /// Path relative to the vault Notes folder when known.
    let notePath: String?
    /// UTF-16 character offsets of the inserted transcript within the note body.
    let characterStart: Int?
    let characterEnd: Int?
    /// Compact 3-word AI title for Home Voice History (persisted to avoid regenerating).
    var shortTitle: String?

    var previewLines: [String] {
        let cleaned = transcript
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if cleaned.isEmpty {
            let words = transcript
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            guard !words.isEmpty else { return ["(empty transcript)"] }
            var lines: [String] = []
            var current = ""
            for word in words {
                let next = current.isEmpty ? word : "\(current) \(word)"
                if next.count > 56, !current.isEmpty {
                    lines.append(current)
                    current = word
                    if lines.count >= 5 { break }
                } else {
                    current = next
                }
            }
            if !current.isEmpty, lines.count < 5 {
                lines.append(current)
            }
            return Array(lines.prefix(5))
        }
        return Array(cleaned.prefix(5))
    }

    /// Prefer the real markdown filename; fall back to note title (never invent Untitled when we know better).
    var displayFileName: String {
        if let notePath, !notePath.isEmpty {
            let fileName = (notePath as NSString).lastPathComponent
            let base = (fileName as NSString).deletingPathExtension
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !base.isEmpty, base.caseInsensitiveCompare("Untitled") != .orderedSame {
                return fileName.hasSuffix(".md") ? fileName : "\(fileName).md"
            }
            // Path is Untitled.md — prefer a better stored note title when available.
            let cleanTitle = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty, cleanTitle.caseInsensitiveCompare("Untitled") != .orderedSame {
                return cleanTitle.hasSuffix(".md") ? cleanTitle : "\(cleanTitle).md"
            }
            return fileName.hasSuffix(".md") ? fileName : "\(fileName).md"
        }
        let clean = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "Untitled.md" }
        return clean.hasSuffix(".md") ? clean : "\(clean).md"
    }

    var displayShortTitle: String {
        if let shortTitle {
            let cleaned = shortTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.isValidThreeWordTitle(cleaned) {
                return cleaned
            }
            // Legacy 3-letter titles: show word fallback while background regen runs.
        }
        return Self.fallbackShortTitle(from: transcript)
    }

    /// Exactly three whitespace-separated words (new shortTitle format).
    static func isValidThreeWordTitle(_ title: String) -> Bool {
        let words = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .filter { !$0.isEmpty }
        return words.count == 3
    }

    /// Old airport-code style mnemonic (exactly three ASCII letters, no spaces).
    static func isLegacyLetterTitle(_ title: String) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count == 3 else { return false }
        return cleaned.allSatisfy { $0.isLetter && $0.isASCII }
    }

    static func needsShortTitleRefresh(_ title: String?) -> Bool {
        guard let title else { return true }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return true }
        if isLegacyLetterTitle(cleaned) { return true }
        return !isValidThreeWordTitle(cleaned)
    }

    static func fallbackShortTitle(from transcript: String) -> String {
        let stopWords: Set<String> = [
            "a", "an", "the", "and", "or", "to", "of", "in", "on", "for",
            "is", "it", "my", "i", "we", "you", "this", "that", "with", "from"
        ]
        let words = transcript
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let meaningful = words.filter { !stopWords.contains($0.lowercased()) }
        let source = meaningful.isEmpty ? words : meaningful
        var picked = Array(source.prefix(3))
        let fillers = ["Voice", "Note", "Clip"]
        var fillerIndex = 0
        while picked.count < 3 {
            picked.append(fillers[fillerIndex % fillers.count])
            fillerIndex += 1
        }
        return picked
            .prefix(3)
            .map { word in
                let lower = word.lowercased()
                guard let first = lower.first else { return word }
                return String(first).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }
}

private struct VoiceConversationFile: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    let vaultID: String
    let brainFileName: String
    var entries: [VoiceConversationEntry]
}

@MainActor
final class BrainStore: ObservableObject {
    @Published var activeBrain: BrainSummary?
    @Published var notes: [NoteSummary] = []
    @Published var selectedNoteID: Note.ID?
    @Published var selectedSidebarGroupID: SidebarItem.ID?
    @Published var currentNoteID: Note.ID?
    @Published var title = "Untitled"
    @Published var content = starterMarkdown
    @Published var status = "Ready"
    @Published var isBusy = false
    @Published var isShowingPageSearch = false
    @Published var recentVaults: [RecentVault] = []
    @Published var graphLinks: [BrainLinkReference] = []
    @Published var selectedAssistantModel: AssistantModel = .mistral
    @Published var assistantPrompt = ""
    @Published var assistantPromptLinkedPages: [PromptLinkedPage] = []
    @Published var isAssistantWritingMode = false
    @Published var isGeneratingAssistantResponse = false
    @Published private(set) var assistantGenerationPhase: AssistantGenerationPhase = .idle
    @Published private(set) var lastAssistantGenerationDiagnostics: AssistantGenerationDiagnostics?
    @Published var isUsingWebSearch = false
    @Published var isShowingModelConfiguration = false
    @Published var isShowingMarkdownHelp = false
    @Published var isShowingUsedModelsConfiguration = false
    @Published var isShowingUsernameConfiguration = false
    @Published var userName = ""
    @Published var userProfile = UserProfile()
    @Published var isShowingHighlightSummaryCompiler = false
    @Published var pendingAssistantPreview: AssistantPreview?
    @Published var assistantConversationResponse: AssistantConversationResponse?
    @Published var activeSearchHighlight: SearchHighlight?
    @Published var assistantAttachment: PromptAttachment?
    @Published var generatedSummaries: [HighlightSummary] = []
    @Published var currentHighlightSummary: HighlightSummary?
    @Published var isShowingHomePage = false
    @Published var isShowingHelpDesk = false
    @Published var sidebarItems: [SidebarItem] = []
    @Published var selectedHomeGenerationModel: HighlightSummaryModel = .mistral
    @Published var selectedFlashcardGenerationModel: HighlightSummaryModel = .mistral
    @Published var isAppleCalendarSyncEnabled = false
    @Published var isCompilingHighlightSummary = false
    @Published var isGeneratingHomePage = false
    @Published private(set) var nextCalendarClass: NextCalendarClassOverview?
    @Published private(set) var isFindingRecommendedPage = false
    @Published private(set) var recommendedPageHintDismissed = false
    @Published var pageFlashcardStates: [Note.ID: PageFlashcardState] = [:]
    @Published var helpDeskConversations: [HelpDeskConversation] = []
    @Published var selectedHelpDeskConversationID: HelpDeskConversation.ID?
    @Published var helpDeskInput = ""
    @Published var helpDeskAttachment: PromptAttachment?
    @Published var isGeneratingHelpDeskResponse = false
    @Published var isShowingHelpDeskConversationBrowser = false
    @Published var helpDeskMarkdownSuggestions: [HelpDeskMarkdownSuggestion] = []
    @Published var activeVoiceCaptureTarget: VoiceCaptureTarget?
    @Published var activeVoiceAudioSource: VoiceAudioSource?
    @Published var pendingVoiceAudioSourceSelection: VoiceCaptureTarget?
    @Published var isVoiceCapturePaused = false
    @Published var isFinalizingVoiceTranscript = false
    @Published var voiceTranscriptionProgress = 0.0
    @Published var liveVoiceTranscript = ""
    @Published var voiceTranscriptionNotice: String?
    @Published var pendingVoiceTranscriptDraft: VoiceTranscriptDraft?
    @Published var isEnhancingVoiceTranscript = false
    @Published var unreadVoiceInsertNoteIDs: Set<Note.ID> = []
    /// Newest-first voice insert history from the vault `.convo` sidecar.
    @Published private(set) var voiceConversationHistory: [VoiceConversationEntry] = []
    @Published var pendingVoiceClippingConfirmation: VoiceClippingConfirmation?
    /// Note title the active editor capture will insert into (set when recording starts).
    @Published private(set) var voiceCaptureDestinationTitle: String?
    /// Wall-clock start of the current recording session (for Island timer).
    @Published private(set) var voiceCaptureStartedAt: Date?
    @Published private(set) var whisperSmallModelInstallState: WhisperSmallModelInstallState = .idle
    @Published private(set) var isVoiceInputLikelyUserSpeech = false
    @Published private(set) var helpDeskSuggestionsDisabledConversationIDs: Set<HelpDeskConversation.ID> = []
    @Published private(set) var mistralBudgetSpentUSD = 0.0
    @Published private(set) var mistralOCRBudgetSpentUSD = 0.0
    @Published private(set) var mistralOCRPagesUsed = 0
    @Published private(set) var mistralTokensConsumed = 0
    @Published private(set) var deepSeekBudgetSpentUSD = 0.0
    @Published private(set) var deepSeekTokensConsumed = 0
    @Published private(set) var mistralRateLimitTokens: Int?
    @Published private(set) var mistralRateLimitTokensRemaining: Int?

    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let recentVaultsKey = "RecentVaults"
    private let openAIAPIKeyKey = "Assistant.OpenAIAPIKey"
    private let openAIModelKey = "Assistant.OpenAIModel"
    private let mistralAPIKeyKey = "Assistant.MistralAPIKey"
    private let mistralModelKey = "Assistant.MistralModel"
    private let deepSeekAPIKeyKey = "Assistant.DeepSeekAPIKey"
    private let deepSeekModelKey = "Assistant.DeepSeekModel"
    private let mistralBudgetSpentUSDKey = "Assistant.MistralBudgetSpentUSD"
    private let mistralOCRBudgetSpentUSDKey = "Assistant.MistralOCRBudgetSpentUSD"
    private let mistralOCRPagesUsedKey = "Assistant.MistralOCRPagesUsed"
    private let mistralTokensConsumedKey = "Assistant.MistralTokensConsumed"
    private let deepSeekBudgetSpentUSDKey = "Assistant.DeepSeekBudgetSpentUSD"
    private let deepSeekTokensConsumedKey = "Assistant.DeepSeekTokensConsumed"
    private let selectedAssistantModelKey = "Assistant.SelectedModel"
    private let selectedHighlightSummaryModelKey = "Assistant.HighlightSummaryModel"
    private let selectedHomeGenerationModelKey = "Assistant.HomeGenerationModel"
    private let selectedFlashcardGenerationModelKey = "Assistant.FlashcardGenerationModel"
    private let appleCalendarSyncEnabledKey = "Assistant.AppleCalendarSyncEnabled"
    private let recommendedPageHintDismissedKey = "Assistant.RecommendedPageHintDismissed"
    private let nextClassNoteMapKey = "Assistant.NextClassNoteMap"
    private let ollamaModelKey = "Assistant.OllamaModel"
    private let ollamaURLKey = "Assistant.OllamaURL"
    private let userNameKey = "User.Name"
    private let userProfileKey = "User.Profile"
    private let homeSummaryID = "home-summary"
    private var mistralAPIKey = ""
    private var mistralModel = BrainStore.defaultMistralModel
    private var deepSeekAPIKey = ""
    private var deepSeekModel = BrainStore.defaultDeepSeekModel
    private var ollamaModel = BrainStore.defaultOllamaModel
    private var ollamaURL = BrainStore.defaultOllamaURL
    private var autosaveTask: Task<Void, Never>?
    private var assistantGenerationTask: Task<Void, Never>?
    private var homeCompilationTask: Task<Void, Never>?
    private var lastHomeSourceDiceTokensForSimilarityCheck: [String]?
    private var suppressNextAutosaveHomeCompilation = false
    private var homePreparedNoteCache: [String: HomePreparedNoteCacheEntry] = [:]
    private var cachedHomeSourceNotes: [HomePageSourceNote]?
    private var cachedHomePagePresentationMarkdown: String?
    private var cachedHomePagePresentationSourceSignature: String?
    private var cachedHomePagePresentation: HomePagePresentation?
    private var activeHomeGenerationID: UUID?
    private var activeHighlightGenerationID: UUID?
    private var assistantConversationMemory = LangChainConversationMemory()
    private var needsHomeRegenerationAfterCurrentCompile = false
    private var needsForcedHomeRegenerationAfterCurrentCompile = false
    private var pendingAssistantInsertion: PendingAssistantInsertion?
    private var isApplyingAssistantOutput = false
    private var lastOpenNoteID: Note.ID?
    private var nextClassNoteIDsByEventKey: [String: Note.ID] = [:]
    private var noteIdentityDatabase: NoteIdentityDatabase?
    private var searchIndex: [NoteSearchIndexEntry] = []
    private var semanticSearchIndex: [SemanticSearchIndexEntry] = []
    private lazy var semanticSearchEmbedding = NLEmbedding.wordEmbedding(for: .english)
    private var helpDeskDatabase = HelpDeskDatabase(vaultID: nil, conversations: [])
    private var helpDeskSessionDatabase: HelpDeskSessionDatabase?
    private var didAttemptDeferredPreviousBrainOpen = false
    private var whisperSmallModelInstallTask: Task<URL, Error>?
    private var voiceTranscriptionController: VoiceTranscriptionController?
    private var finalizingVoiceTranscriptionController: VoiceTranscriptionController?
    private var voiceTranscriptionProgressTask: Task<Void, Never>?
    private var voiceEnhanceTask: Task<Void, Never>?
    private var voiceHistoryShortTitleTask: Task<Void, Never>?
    private var activeVoiceEditorNoteID: Note.ID?
    private var activeVoiceEditorNoteTitle: String?
    private var voiceCapturePausedAccumulated: TimeInterval = 0
    private var voiceCapturePauseStartedAt: Date?
    /// When set, the next completed transcript is appended onto this draft as a new revision.
    private var pendingVoiceAppendContext: PendingVoiceAppendContext?

    static let defaultMistralModel = "mistral-large-latest"
    static let defaultDeepSeekModel = "deepseek-v4-flash"
    static let defaultOllamaModel = "llama3.1"
    static let defaultOllamaURL = "http://localhost:11434"

    private static let usageSoftBudgetUSD = 10.0
    private static let mistralInputPricePerMillionTokens = 2.00
    private static let mistralOutputPricePerMillionTokens = 6.00
    private static let mistralOCRPricePerThousandPages = 2.00
    private static let deepSeekInputCacheMissPricePerMillionTokens = 0.14
    private static let deepSeekInputCacheHitPricePerMillionTokens = 0.0028
    private static let deepSeekOutputPricePerMillionTokens = 0.28
    private static let mistralMaxUploadFileBytes = 512 * 1024 * 1024
    private static let maxNoteFileBytes = 50 * 1024 * 1024
    private static let mistralMaxOCRPagesPerRequest = 1_000
    private static let supportedImageAttachmentExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "webp", "avif"]
    private static let supportedDocumentAttachmentExtensions: Set<String> = ["pdf", "doc", "docx", "ppt", "pptx"]
    private static let maxAssistantOutputTokens = 4096
    private static let assistantConversationOutputTokens = 1_600
    private static let assistantConversationInsertionOutputTokens = 2_500
    private static let assistantConversationContextBudget = 9_000
    private static let assistantConversationRetryContextBudget = 4_500
    private static let assistantConversationSmallPageCharacterLimit = 6_000
    private static let mistralChatTimeoutSeconds: TimeInterval = 220
    private static let homeCompilationDebounceNanoseconds: UInt64 = 1_500_000_000
    private static let homeCompilationAfterAutosaveNanoseconds: UInt64 = 300_000_000
    private static let homeDirectCharacterBudget = 18_000
    private static let homeNoteCondenseCharacterLimit = 4_500
    private static let pageFlashcardSimilarityRegenerateThreshold = 0.92
    private static let pageFlashcardMaxOutputTokens = 900
    private static let recommendedPageMaxOutputTokens = 700
    private static let helpDeskContextCharacterBudget = 16_000
    private static let helpDeskRelevantBlockLimit = 10
    private static let helpDeskHistoryMessageLimit = 8
    private static let semanticSearchMinimumSimilarity = 0.22
    // Dice-Sorensen cutoff for skipping Home regeneration; raise to refresh more often, lower to save more tokens.
    private static let homePageDiceSimilaritySkipThreshold = 0.94
    private static let estimatedCharactersPerToken = 4
    private static let mistralOCRModel = "mistral-ocr-latest"

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadRecentVaults()
        loadAssistantConfiguration()
        Task {
            await ensureWhisperSmallModelInstalledForCurrentUser(reportReadyStatus: false)
        }
    }

    var documentStats: String {
        let wordCount = content
            .split { $0.isWhitespace || $0.isNewline }
            .count
        return "\(wordCount) words · \(content.count.formatted()) characters"
    }

    var canShareCurrentDocument: Bool {
        currentShareDocument != nil
    }

    func openPreviousBrainAfterFirstFrame() async {
        guard !didAttemptDeferredPreviousBrainOpen else { return }
        didAttemptDeferredPreviousBrainOpen = true

        await Task.yield()
        try? await Task.sleep(nanoseconds: 60_000_000)
        guard activeBrain == nil else { return }
        openPreviousBrainOnLaunch()
    }

    var contextUsageFraction: Double {
        guard let limit = mistralRateLimitTokens,
              let remaining = mistralRateLimitTokensRemaining,
              limit > 0
        else {
            return 0
        }
        let used = max(0, limit - remaining)
        return min(1, Double(used) / Double(limit))
    }

    var totalUsageSpendUSD: Double {
        mistralBudgetSpentUSD + mistralOCRBudgetSpentUSD + deepSeekBudgetSpentUSD
    }

    var totalUsageFraction: Double {
        guard Self.usageSoftBudgetUSD > 0 else { return 0 }
        return min(1, max(0, totalUsageSpendUSD / Self.usageSoftBudgetUSD))
    }

    var totalUsagePercent: Int {
        Int((totalUsageFraction * 100).rounded())
    }

    var totalUsagePercentLabel: String {
        "\(totalUsagePercent)%"
    }

    var totalUsageLabel: String {
        "\(formatUSD(totalUsageSpendUSD)) / \(formatUSD(Self.usageSoftBudgetUSD))"
    }

    var totalUsageDetail: String {
        "Mistral, Mistral OCR, and DeepSeek spend"
    }

    var contextUsagePercent: Int {
        Int((contextUsageFraction * 100).rounded())
    }

    var contextUsageLabel: String {
        if let limit = mistralRateLimitTokens,
           let remaining = mistralRateLimitTokensRemaining,
           limit > 0 {
            let used = max(0, limit - remaining)
            return "\(used.formatted()) / \(limit.formatted()) tokens"
        }
        return "\(formatUSD(mistralBudgetSpentUSD)) spent"
    }

    var contextUsageDetail: String {
        if mistralRateLimitTokens != nil {
            return "Mistral token/min quota"
        }
        return "\(mistralTokensConsumed.formatted()) total tokens"
    }

    var ocrUploadUsageFraction: Double {
        0
    }

    var ocrUploadCounterLabel: String {
        "512 MB · \(Self.mistralMaxOCRPagesPerRequest.formatted()) pg"
    }

    var ocrUploadCounterDetail: String {
        "\(mistralOCRPagesUsed.formatted()) OCR pages processed · up to \(Self.mistralMaxOCRPagesPerRequest.formatted()) pages per upload"
    }

    var mistralUsageBreakdownLabel: String {
        "\(formatUSD(mistralBudgetSpentUSD)) · \(mistralTokensConsumed.formatted()) tokens"
    }

    var mistralOCRUsageBreakdownLabel: String {
        "\(formatUSD(mistralOCRBudgetSpentUSD)) · \(mistralOCRPagesUsed.formatted()) pages"
    }

    var deepSeekUsageBreakdownLabel: String {
        "\(formatUSD(deepSeekBudgetSpentUSD)) · \(deepSeekTokensConsumed.formatted()) tokens"
    }

    var assistantConnectionStatus: AssistantConnectionStatus {
        switch selectedAssistantModel {
        case .mistral:
            return mistralAPIKey.isEmpty ? .offline : .online
        case .deepseek:
            return deepSeekAPIKey.isEmpty ? .offline : .online
        }
    }

    var isViewingHighlightSummary: Bool {
        currentHighlightSummary != nil
    }

    var isViewingGeneratedPage: Bool {
        currentHighlightSummary != nil || isShowingHomePage || isShowingHelpDesk
    }

    var canCompileCurrentHighlights: Bool {
        !highlightedTextFragments(in: content).isEmpty && currentNoteID != nil && !isCompilingHighlightSummary
    }

    var homeReturnPage: NoteSummary? {
        if let lastOpenNoteID,
           let note = notes.first(where: { $0.id == lastOpenNoteID }) {
            return note
        }

        return notes.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    var homeReturnPageTitle: String {
        homeReturnPage?.title ?? "last page"
    }

    var canOpenHomeReturnPage: Bool {
        homeReturnPage != nil
    }

    var canRecommendCalendarPage: Bool {
        activeBrain != nil
            && isAppleCalendarSyncEnabled
            && !isFindingRecommendedPage
            && !notes.isEmpty
    }

    var shouldShowCalendarRecommendationHint: Bool {
        !isAppleCalendarSyncEnabled && !recommendedPageHintDismissed
    }

    var canCreateNextClassNote: Bool {
        activeBrain != nil && nextCalendarClass != nil
    }

    var canContinueNextClassNote: Bool {
        guard let noteID = nextCalendarClass?.continueNoteID else { return false }
        return notes.contains { $0.id == noteID }
    }

    var homeMarkdown: String {
        if let latestHomeSummary {
            return latestHomeSummary.markdown
        }

        let pageList = notes.isEmpty
            ? "No pages yet."
            : notes.map { "- [[\($0.title)]]" }.joined(separator: "\n")

        return """
        # Home

        ## Summary

        No Home summary generated yet.

        ## Page Summaries

        \(pageList)
        """
    }

    var latestHomeSummary: HighlightSummary? {
        generatedSummaries.first { $0.id == homeSummaryID }
    }

    var homePagePresentation: HomePagePresentation {
        let markdown = homeMarkdown
        let sourceNotes = cachedHomeSourceNotes
        let sourceSignature = sourceNotes.map { homePresentationSourceSignature($0) }

        if cachedHomePagePresentationMarkdown == markdown,
           cachedHomePagePresentationSourceSignature == sourceSignature,
           let cachedHomePagePresentation {
            return cachedHomePagePresentation
        }

        var presentation = parseHomePagePresentation(from: markdown)
        if let sourceNotes {
            presentation = homePresentationEnsuringAllPages(
                presentation,
                sourceNotes: sourceNotes
            )
            if presentation.pageCards.isEmpty {
                presentation = HomePagePresentation(
                    vaultSummary: presentation.vaultSummary,
                    pageCards: localPageCards(from: sourceNotes),
                    flashcardGroups: []
                )
            }
            if presentation.vaultSummary.isEmpty {
                presentation = HomePagePresentation(
                    vaultSummary: lineLimited(localVaultSummary(from: sourceNotes), maxLines: 7),
                    pageCards: presentation.pageCards,
                    flashcardGroups: []
                )
            }
        }
        let enriched = enrichHomePagePresentation(presentation)
        cachedHomePagePresentationMarkdown = markdown
        cachedHomePagePresentationSourceSignature = sourceSignature
        cachedHomePagePresentation = enriched
        return enriched
    }

    func createBrainVaultFromUser() {
        guard let name = requestText(
            title: "Create New Brain",
            message: "Start your new flowstate",
            placeholder: "Project name",
            initialValue: "Untitled Brain"
        ) else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose Where to Store Your Brain"
        panel.message = "Select an empty folder. Zirn will create a visible .brain vault file in that folder."
        panel.prompt = "Create Brain"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        createBrain(at: folderURL, named: name)
    }

    func openBrainVaultFromUser() {
        let panel = NSOpenPanel()
        panel.title = "Open Brain Vault"
        panel.message = "Select the folder that contains your Zirn .brain vault file."
        panel.prompt = "Open Vault"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }
        openBrain(fileURL: folderURL, showsInvalidVaultAlert: true)
    }

    func goToStartPage() {
        closeBrain()
    }

    func createBrain(at folderURL: URL, named explicitName: String? = nil) {
        withSecurityScopedAccess(to: folderURL) {
            isBusy = true
            defer { isBusy = false }

            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                let brainName = cleanBrainName(explicitName)
                    ?? (folderURL.lastPathComponent.isEmpty ? "Untitled Brain" : folderURL.lastPathComponent)
                let brainURL = folderURL.appendingPathComponent(
                    "\(brainFileName(for: brainName)).brain",
                    isDirectory: false
                )
                guard findBrainFile(in: folderURL) == nil else {
                    let message = """
                    This folder already contains a brain vault. \
                    Choose a different folder, or create a new empty folder with no existing brain.
                    """
                    status = message
                    showAlert(title: "Cannot Create Brain", message: message)
                    return
                }

                let now = Date()
                let brain = BrainFile(
                    schemaVersion: 1,
                    vault: VaultIdentity(
                        id: UUID().uuidString,
                        name: brainName,
                        createdAt: now,
                        updatedAt: now
                    ),
                    rootNoteID: nil,
                    graph: BrainGraph(notes: [], links: []),
                    sourceRegistry: SourceRegistryPointer(path: "sources.json"),
                    ai: BrainAIPreferences(
                        provider: "mistral",
                        mistralModel: Self.defaultMistralModel,
                        deepSeekModel: Self.defaultDeepSeekModel,
                        ollamaModel: nil,
                        ollamaURL: nil,
                        appleModel: nil
                    ),
                    styleMemory: [],
                    memory: BrainMemory(writingArtifacts: [], preferences: [], updatedAt: nil),
                    app: BrainAppCompatibility(
                        appID: "noortech.Zirn",
                        minAppVersion: "1.0",
                        lastOpenedWith: "1.0"
                    )
                )

                try writeBrain(brain, to: brainURL)
                openBrain(fileURL: brainURL)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func openBrain(
        fileURL: URL,
        showsInvalidVaultAlert: Bool = false,
        restoring recentVault: RecentVault? = nil
    ) {
        let folderURL = isBrainFile(fileURL)
            ? fileURL.deletingLastPathComponent()
            : fileURL

        withSecurityScopedAccess(to: folderURL) {
            isBusy = true
            defer { isBusy = false }

            do {
                guard let brainURL = brainURL(from: fileURL) else {
                    let message = "That folder does not contain a Zirn .brain vault file."
                    status = message
                    if showsInvalidVaultAlert {
                        showAlert(title: "Cannot Open Vault", message: message)
                    }
                    return
                }

                let brain = try readBrain(from: brainURL)
                activeBrain = BrainSummary(
                    id: brain.vault.id,
                    name: brain.vault.name,
                    folderURL: folderURL,
                    brainURL: brainURL,
                    updatedAt: brain.vault.updatedAt
                )
                noteIdentityDatabase = try NoteIdentityDatabase(vaultFolderURL: folderURL)
                resetDraft()
                try loadNotes()
                try loadHighlightSummaries()
                try loadHelpDeskDatabase()
                try loadVoiceConversationHistory()

                if let activeBrain,
                   let noteID = recentVault?.noteFileName.flatMap({ noteID(forRecentNoteFileName: $0, in: activeBrain) }) {
                    openNote(id: noteID)
                } else {
                    openHomePageForLaunch()
                    recordRecentVault(note: nil)
                }
                status = "\(brain.vault.name) opened"
            } catch {
                status = error.localizedDescription
                if showsInvalidVaultAlert {
                    showAlert(title: "Cannot Open Vault", message: error.localizedDescription)
                }
            }
        }
    }

    func closeBrain() {
        autosaveTask?.cancel()
        autosaveTask = nil
        homeCompilationTask?.cancel()
        homeCompilationTask = nil
        lastHomeSourceDiceTokensForSimilarityCheck = nil
        cachedHomeSourceNotes = nil
        invalidateHomePagePresentationCache()
        needsHomeRegenerationAfterCurrentCompile = false
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        noteIdentityDatabase = nil
        helpDeskSessionDatabase = nil
        currentHighlightSummary = nil
        isShowingHomePage = false
        isShowingHelpDesk = false
        generatedSummaries = []
        helpDeskDatabase = HelpDeskDatabase(vaultID: nil, conversations: [])
        helpDeskConversations = []
        selectedHelpDeskConversationID = nil
        helpDeskInput = ""
        helpDeskAttachment = nil
        isGeneratingHelpDeskResponse = false
        isShowingHelpDeskConversationBrowser = false
        helpDeskMarkdownSuggestions = []
        helpDeskSuggestionsDisabledConversationIDs = []
        unreadVoiceInsertNoteIDs = []
        voiceConversationHistory = []
        pendingVoiceTranscriptDraft = nil
        pendingVoiceAppendContext = nil
        isEnhancingVoiceTranscript = false
        activeBrain = nil
        notes = []
        sidebarItems = []
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        graphLinks = []
        searchIndex = []
        semanticSearchIndex = []
        resetDraft()
        status = "Choose a brain"
    }

    func newDraft() {
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        currentHighlightSummary = nil
        isShowingHomePage = false
        isShowingHelpDesk = false
        currentNoteID = nil
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        title = uniqueTitle(for: "Untitled")
        content = contentBySettingDocumentTitle(title, in: Self.starterMarkdown)
        if activeBrain != nil {
            saveCurrentNote(statusText: "Page created")
        }
    }

    private func resetDraft() {
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        currentHighlightSummary = nil
        isShowingHomePage = false
        isShowingHelpDesk = false
        currentNoteID = nil
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        title = "Untitled"
        content = Self.starterMarkdown
    }

    func updateTitleFromEditor(_ newTitle: String) {
        let uniqueTitle = uniqueTitle(for: newTitle, excluding: currentNoteID)
        title = uniqueTitle
        content = contentBySettingDocumentTitle(uniqueTitle, in: content)
        updateCurrentNoteSummaryTitle(to: uniqueTitle)
        updateCachedHomeSourceNoteForCurrentEditor()
        scheduleAutosave()
        scheduleLiveHomePageCompilation()
    }

    func updateContentFromEditor(_ newContent: String) {
        let previousContent = content
        if let documentTitle = markdownDocumentTitle(in: newContent) {
            let uniqueTitle = uniqueTitle(for: documentTitle, excluding: currentNoteID)
            content = uniqueTitle == documentTitle
                ? newContent
                : contentBySettingDocumentTitle(uniqueTitle, in: newContent)
            if uniqueTitle != title {
                title = uniqueTitle
                updateCurrentNoteSummaryTitle(to: uniqueTitle)
            }
        } else {
            content = newContent
        }
        let isHighlightOnlyChange = Self.isHighlightMarkerOnlyChange(from: previousContent, to: content)
        suppressNextAutosaveHomeCompilation = isHighlightOnlyChange
        learnFromUserCorrectionIfNeeded(revisedContent: newContent)
        updateCachedHomeSourceNoteForCurrentEditor()
        scheduleAutosave()
        if !isHighlightOnlyChange {
            scheduleLiveHomePageCompilation()
        }
    }

    private static func isHighlightMarkerOnlyChange(from oldContent: String, to newContent: String) -> Bool {
        guard oldContent != newContent else { return false }
        return markdownWithoutHighlightMarkers(oldContent) == markdownWithoutHighlightMarkers(newContent)
    }

    private static func markdownWithoutHighlightMarkers(_ markdown: String) -> String {
        markdown.replacingOccurrences(of: #"==(.+?)=="#, with: "$1", options: [.regularExpression])
    }

    func showPageSearch() {
        guard activeBrain != nil else {
            status = "Open or create a brain first"
            return
        }

        isShowingPageSearch = true
    }

    func togglePageSearch() {
        guard activeBrain != nil else {
            status = "Open or create a brain first"
            return
        }

        isShowingPageSearch.toggle()
    }

    func showHelp() {
        isShowingMarkdownHelp = true
    }

    func openNote(id: Note.ID) {
        activeSearchHighlight = nil
        currentHighlightSummary = nil
        isShowingHomePage = false
        isShowingHelpDesk = false
        selectedSidebarGroupID = nil
        if let currentNoteID, currentNoteID != id {
            autosaveTask?.cancel()
            autosaveTask = nil
            saveCurrentNote()
        }

        guard let noteURL = noteURL(for: id) else {
            status = "Could not find page file."
            return
        }
        withActiveBrainAccess {
            do {
                let note = try readNote(from: noteURL)
                currentNoteID = note.id
                selectedNoteID = note.id
                lastOpenNoteID = note.id
                pendingAssistantInsertion = nil
                title = note.title
                content = note.content
                clearUnreadVoiceInsert(for: note.id)
                recordRecentVault(
                    note: NoteSummary(
                        id: note.id,
                        title: note.title,
                        updatedAt: note.updatedAt
                    )
                )
                status = "Opened"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func openLinkedNote(named linkedTitle: String) {
        let normalizedTitle = normalizedLinkTitle(linkedTitle)
        guard let note = notes.first(where: { normalizedLinkTitle($0.title) == normalizedTitle }) else {
            status = "No page named \(linkedTitle)"
            return
        }

        openNote(id: note.id)
    }

    func openHomeReturnPage() {
        guard let note = homeReturnPage else {
            status = "No previous page to open"
            return
        }

        openNote(id: note.id)
    }

    func refreshNextCalendarClass() {
        guard activeBrain != nil, isAppleCalendarSyncEnabled else {
            nextCalendarClass = nil
            return
        }

        Task {
            do {
                let classes = try await AppleCalendarEventProvider.upcomingClassEvents()
                guard let event = classes.first else {
                    nextCalendarClass = nil
                    return
                }

                nextCalendarClass = classOverview(for: event)
            } catch {
                nextCalendarClass = nil
            }
        }
    }

    func createNoteForNextClass() {
        guard let nextCalendarClass else {
            status = "No upcoming class found"
            return
        }

        if currentNoteID != nil, currentHighlightSummary == nil, !isShowingHomePage {
            saveCurrentNote(statusText: "Autosaved")
        }

        withActiveBrainAccess {
            do {
                guard let brain = activeBrain else { return }
                let now = Date()
                let noteID = UUID().uuidString
                let noteTitle = uniqueTitle(for: nextCalendarClass.title)
                let note = Note(
                    id: noteID,
                    title: noteTitle,
                    content: contentBySettingDocumentTitle(noteTitle, in: classNoteMarkdown(for: nextCalendarClass)),
                    createdAt: now,
                    updatedAt: now
                )

                try FileManager.default.createDirectory(at: notesFolderURL(for: brain), withIntermediateDirectories: true)
                let targetURL = markdownNoteURL(for: note, in: brain)
                try FileManager.default.createDirectory(
                    at: targetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try writeMarkdownNote(note, to: targetURL)
                try persistHighlightedText(from: note, in: brain)
                try noteIdentityDatabase?.upsert(
                    noteID: note.id,
                    title: note.title,
                    fileName: relativeNoteFileName(for: targetURL, in: brain),
                    updatedAt: note.updatedAt
                )
                try loadNotes()
                try syncBrainMetadata()
                rememberClassNote(noteID: note.id, event: nextCalendarClass.event)
                self.nextCalendarClass = classOverview(for: nextCalendarClass.event)
                status = "Class page created"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func continueNextClassNote() {
        guard let nextCalendarClass else {
            status = "No upcoming class found"
            return
        }
        guard let noteID = nextCalendarClass.continueNoteID,
              notes.contains(where: { $0.id == noteID })
        else {
            status = "Create a class page first"
            return
        }

        openNote(id: noteID)
    }

    func dismissCalendarRecommendationHint() {
        recommendedPageHintDismissed = true
        UserDefaults.standard.set(true, forKey: recommendedPageHintDismissedKey)
    }

    func setAppleCalendarSyncEnabled(_ enabled: Bool) {
        isAppleCalendarSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: appleCalendarSyncEnabledKey)

        if enabled {
            recommendedPageHintDismissed = false
            UserDefaults.standard.set(false, forKey: recommendedPageHintDismissedKey)
            status = "Enabling Apple Calendar Sync"
            Task {
                do {
                    try await AppleCalendarEventProvider.requestAccessIfNeeded()
                    refreshNextCalendarClass()
                    status = "Apple Calendar Sync enabled"
                } catch {
                    isAppleCalendarSyncEnabled = false
                    nextCalendarClass = nil
                    UserDefaults.standard.set(false, forKey: appleCalendarSyncEnabledKey)
                    status = error.localizedDescription
                }
            }
        } else {
            nextCalendarClass = nil
            status = "Apple Calendar Sync disabled"
        }
    }

    func openRecommendedCalendarPage() {
        guard canRecommendCalendarPage else {
            if !isAppleCalendarSyncEnabled {
                status = "Enable Apple Calendar Sync first"
            } else if notes.isEmpty {
                status = "Create a page before using recommendations"
            }
            return
        }

        isFindingRecommendedPage = true
        status = "Finding recommended page"

        Task {
            defer { isFindingRecommendedPage = false }

            do {
                try await AppleCalendarEventProvider.requestAccessIfNeeded()
                let events = try await AppleCalendarEventProvider.upcomingRecommendationEvents()
                guard let event = events.first else {
                    status = "No upcoming calendar event found"
                    return
                }

                let candidates = try calendarRecommendationCandidates(limit: 24)
                guard !candidates.isEmpty else {
                    status = "No pages available to recommend"
                    return
                }

                let memory = try loadSmartFeatureMemory()
                let recommendation = try await recommendedPage(
                    for: event,
                    candidates: candidates,
                    smartFeatureMemory: memory
                )
                let fallback = locallyRecommendedPage(for: event, candidates: candidates)
                let selected = candidates.first { $0.noteID == recommendation?.noteID }
                    ?? fallback

                let reasoning = recommendation?.reasoning
                    ?? "Local fallback matched calendar keywords against page titles and excerpts."
                try persistSmartFeatureBlob(
                    event: event,
                    candidates: candidates,
                    selected: selected,
                    reasoning: reasoning,
                    usedAI: recommendation != nil
                )
                if event.priority == .classSession {
                    rememberClassNote(noteID: selected.noteID, event: event)
                    refreshNextCalendarClass()
                }

                openNote(id: selected.noteID)
                status = "Recommended \(selected.title) for \(event.priority.displayTitle.lowercased())"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func calendarRecommendationCandidates(limit: Int) throws -> [CalendarRecommendationCandidate] {
        try withActiveBrainAccessThrowing {
            let sortedNotes = notes.sorted { $0.updatedAt > $1.updatedAt }

            return sortedNotes.prefix(limit).compactMap { summary in
                guard let url = noteURL(for: summary.id),
                      let note = try? readNote(from: url)
                else {
                    return nil
                }

                return CalendarRecommendationCandidate(
                    noteID: note.id,
                    title: note.title,
                    excerpt: String(plainText(fromMarkdown: note.content).prefix(900)),
                    updatedAt: note.updatedAt
                )
            }
        }
    }

    private func recommendedPage(
        for event: CalendarRecommendationEvent,
        candidates: [CalendarRecommendationCandidate],
        smartFeatureMemory: String
    ) async throws -> CalendarPageRecommendationResponse? {
        let model = selectedHomeGenerationModel
        let system = """
        You recommend one existing Zirn page for the user's next calendar priority.
        Return only JSON with keys noteID and reasoning. noteID must exactly match one candidate ID.
        Prefer the page that best helps the user prepare for the calendar item.
        """
        let user = calendarRecommendationPrompt(
            event: event,
            candidates: candidates,
            smartFeatureMemory: smartFeatureMemory
        )

        let result: ChatCompletionResult
        switch model {
        case .mistral:
            result = try await generateWithMistral(system: system, user: user, maxTokens: Self.recommendedPageMaxOutputTokens)
        case .deepseek:
            result = try await generateWithDeepSeek(system: system, user: user, maxTokens: Self.recommendedPageMaxOutputTokens)
        case .ollama:
            result = try await generateWithOllama(system: system, user: user)
        }

        recordUsage(
            for: model,
            result: result,
            fallbackInputTokens: estimatedTokenCount(for: user),
            fallbackOutputTokens: estimatedTokenCount(for: result.content)
        )

        guard let json = firstJSONObject(in: result.content),
              let data = json.data(using: .utf8),
              let response = try? decoder.decode(CalendarPageRecommendationResponse.self, from: data),
              candidates.contains(where: { $0.noteID == response.noteID })
        else {
            return nil
        }

        return response
    }

    private func calendarRecommendationPrompt(
        event: CalendarRecommendationEvent,
        candidates: [CalendarRecommendationCandidate],
        smartFeatureMemory: String
    ) -> String {
        let pageList = candidates.map { candidate in
            """
            - ID: \(candidate.noteID)
              Title: \(candidate.title)
              Updated: \(candidate.updatedAt.formatted(date: .abbreviated, time: .shortened))
              Excerpt: \(candidate.excerpt)
            """
        }
        .joined(separator: "\n")

        return """
        Calendar priority:
        \(event.compactDescription)

        Existing smart feature blobs:
        \(smartFeatureMemory.isEmpty ? "None yet." : smartFeatureMemory)

        Candidate pages:
        \(pageList)
        """
    }

    private func locallyRecommendedPage(
        for event: CalendarRecommendationEvent,
        candidates: [CalendarRecommendationCandidate]
    ) -> CalendarRecommendationCandidate {
        let queryTokens = searchTokens(
            in: [event.title, event.location, event.notes, event.calendarTitle]
                .compactMap { $0 }
                .joined(separator: " ")
        )
        guard !queryTokens.isEmpty else {
            return candidates.sorted { $0.updatedAt > $1.updatedAt }.first ?? candidates[0]
        }

        return candidates.max { lhs, rhs in
            localCalendarRecommendationScore(for: lhs, tokens: queryTokens)
                < localCalendarRecommendationScore(for: rhs, tokens: queryTokens)
        } ?? candidates[0]
    }

    private func localCalendarRecommendationScore(
        for candidate: CalendarRecommendationCandidate,
        tokens: [String]
    ) -> Int {
        let titleText = normalizedSearchText(candidate.title)
        let excerptText = normalizedSearchText(candidate.excerpt)

        return tokens.reduce(0) { score, token in
            var nextScore = score
            if titleText.contains(token) {
                nextScore += 4
            }
            if excerptText.contains(token) {
                nextScore += 1
            }
            return nextScore
        }
    }

    private func loadSmartFeatureMemory() throws -> String {
        try withActiveBrainAccessThrowing {
            guard let activeBrain else { return "" }
            let url = smartFeatureURL(for: activeBrain)
            guard FileManager.default.fileExists(atPath: url.path) else { return "" }
            let text = try String(contentsOf: url, encoding: .utf8)
            return String(text.suffix(6_000))
        }
    }

    private func persistSmartFeatureBlob(
        event: CalendarRecommendationEvent,
        candidates: [CalendarRecommendationCandidate],
        selected: CalendarRecommendationCandidate,
        reasoning: String,
        usedAI: Bool
    ) throws {
        try withActiveBrainAccessThrowing {
            guard let activeBrain else { return }
            let url = smartFeatureURL(for: activeBrain)
            let blob = SmartFeatureBlob(
                version: 1,
                vaultID: activeBrain.id,
                brainFileName: activeBrain.brainURL.lastPathComponent,
                brainPath: activeBrain.brainURL.path,
                feature: "calendar-page-recommendation",
                createdAt: Date(),
                event: event,
                selectedNoteID: selected.noteID,
                selectedTitle: selected.title,
                reasoning: reasoning,
                usedAI: usedAI,
                candidateTitles: candidates.map(\.title)
            )
            let json = try String(data: encoder.encode(blob), encoding: .utf8) ?? "{}"
            if !FileManager.default.fileExists(atPath: url.path) {
                try """
                # Zirn smart feature blobs
                # Linked brain: \(activeBrain.brainURL.lastPathComponent)
                # One JSON blob per line.

                """.write(to: url, atomically: true, encoding: .utf8)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            handle.write(Data((json + "\n").utf8))
        }
    }

    private func smartFeatureURL(for brain: BrainSummary) -> URL {
        brain.folderURL.appendingPathComponent("brain.smart.features")
    }

    private func classOverview(for event: CalendarRecommendationEvent) -> NextCalendarClassOverview {
        let eventKey = classEventTrackingKey(for: event)
        let trackedNoteID = nextClassNoteIDsByEventKey[eventKey]
            .flatMap { noteID in notes.contains(where: { $0.id == noteID }) ? noteID : nil }

        return NextCalendarClassOverview(
            event: event,
            title: event.title,
            timingText: classTimingText(for: event),
            locationText: event.location,
            continueNoteID: trackedNoteID
        )
    }

    private func classNoteMarkdown(for overview: NextCalendarClassOverview) -> String {
        var lines = [
            "# \(overview.title)",
            ""
        ]

        if let timingText = overview.timingText {
            lines.append("Time: \(timingText)")
        }
        if let locationText = overview.locationText {
            lines.append("Location: \(locationText)")
        }
        if lines.count > 2 {
            lines.append("")
        }
        lines.append("## Notes")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private func classTimingText(for event: CalendarRecommendationEvent) -> String? {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.dateStyle = calendar.isDateInToday(event.startDate) ? .none : .medium
        dayFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let timeRange = "\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))"
        if calendar.isDateInToday(event.startDate) {
            return "Today, \(timeRange)"
        }

        let day = dayFormatter.string(from: event.startDate)
        guard !day.isEmpty else { return timeRange }
        return "\(day), \(timeRange)"
    }

    private func rememberClassNote(noteID: Note.ID, event: CalendarRecommendationEvent) {
        nextClassNoteIDsByEventKey[classEventTrackingKey(for: event)] = noteID
        saveNextClassNoteMap()
    }

    private func saveNextClassNoteMap() {
        if let data = try? encoder.encode(nextClassNoteIDsByEventKey) {
            UserDefaults.standard.set(data, forKey: nextClassNoteMapKey)
        }
    }

    private func classEventTrackingKey(for event: CalendarRecommendationEvent) -> String {
        let titleKey = normalizedSearchText(event.title)
        let startMinute = Int(event.startDate.timeIntervalSince1970 / 60)
        let endMinute = Int(event.endDate.timeIntervalSince1970 / 60)
        return "\(activeBrain?.id ?? "no-vault")|\(titleKey)|\(startMinute)|\(endMinute)"
    }

    private func firstJSONObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end
        else {
            return nil
        }
        return String(text[start...end])
    }

    func saveCurrentNote() {
        saveCurrentNote(statusText: "Autosaved")
    }

    func exportCurrentDocumentAsPDF() {
        guard let document = currentShareDocument else {
            status = "Open a page to export"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(document.fileName).pdf"
        panel.title = "Export as PDF"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task { @MainActor in
            do {
                status = "Exporting PDF"
                try await MarkdownPDFRenderer().writePDF(
                    markdown: document.markdown,
                    title: document.title,
                    to: url,
                    imageData: { [weak self] path in
                        self?.markdownImageData(for: path)
                    }
                )
                status = "PDF exported"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func airDropCurrentDocumentAsPDF() {
        guard let document = currentShareDocument else {
            status = "Open a page to AirDrop"
            return
        }

        Task { @MainActor in
            do {
                status = "Preparing PDF for AirDrop"
                let exportFolder = try temporaryExportFolder()
                let pdfURL = exportFolder.appendingPathComponent("\(document.fileName).pdf")

                try await MarkdownPDFRenderer().writePDF(
                    markdown: document.markdown,
                    title: document.title,
                    to: pdfURL,
                    imageData: { [weak self] path in
                        self?.markdownImageData(for: path)
                    }
                )

                guard let sharingService = NSSharingService(named: .sendViaAirDrop) else {
                    status = "AirDrop is unavailable"
                    return
                }

                sharingService.perform(withItems: [pdfURL])
                status = "AirDrop ready"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func airDropCurrentDocumentAsMarkdown() {
        guard let document = currentShareDocument else {
            status = "Open a page to AirDrop"
            return
        }

        do {
            status = "Preparing Markdown for AirDrop"
            let exportFolder = try temporaryExportFolder()
            let markdownURL = exportFolder.appendingPathComponent("\(document.fileName).md")
            try Data(document.markdown.utf8).write(to: markdownURL, options: .atomic)

            guard let sharingService = NSSharingService(named: .sendViaAirDrop) else {
                status = "AirDrop is unavailable"
                return
            }

            sharingService.perform(withItems: [markdownURL])
            status = "AirDrop ready"
        } catch {
            status = error.localizedDescription
        }
    }

    private var currentShareDocument: ShareExportDocument? {
        guard !isShowingHomePage, !isShowingHelpDesk else { return nil }

        if let summary = currentHighlightSummary {
            return ShareExportDocument(title: summary.title, markdown: summary.markdown)
        }

        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty else { return nil }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let exportTitle = cleanTitle.isEmpty ? "Untitled" : cleanTitle
        return ShareExportDocument(
            title: exportTitle,
            markdown: contentBySettingDocumentTitle(exportTitle, in: content)
        )
    }

    private func temporaryExportFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZirnExports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func saveCurrentNote(statusText: String) {
        autosaveTask?.cancel()
        autosaveTask = nil
        withActiveBrainAccess {
            do {
                guard let brain = activeBrain else { return }
                let now = Date()
                let id = currentNoteID ?? UUID().uuidString
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let uniqueTitle = uniqueTitle(for: cleanTitle, excluding: id)
                let note = Note(
                    id: id,
                    title: uniqueTitle,
                    content: contentBySettingDocumentTitle(uniqueTitle, in: content),
                    createdAt: existingCreatedAt(for: id) ?? now,
                    updatedAt: now
                )

                try FileManager.default.createDirectory(at: notesFolderURL(for: brain), withIntermediateDirectories: true)
                let existingURL = noteURL(for: id, in: brain)
                let targetURL = existingURL?.pathExtension == "md"
                    ? existingURL!
                    : markdownNoteURL(for: note, in: brain)
                try FileManager.default.createDirectory(
                    at: targetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try writeMarkdownNote(note, to: targetURL)
                try persistHighlightedText(from: note, in: brain)
                try noteIdentityDatabase?.upsert(
                    noteID: note.id,
                    title: note.title,
                    fileName: relativeNoteFileName(for: targetURL, in: brain),
                    updatedAt: note.updatedAt
                )
                if let existingURL, existingURL.pathExtension == "json" {
                    try? FileManager.default.removeItem(at: existingURL)
                }
                currentNoteID = id
                selectedNoteID = id
                title = note.title
                try loadNotes()
                try syncBrainMetadata()
                try updateStyleMemory(with: note.content)
                recordRecentVault(
                    note: NoteSummary(
                        id: note.id,
                        title: note.title,
                        updatedAt: note.updatedAt
                    )
                )
                status = statusText
                if suppressNextAutosaveHomeCompilation {
                    suppressNextAutosaveHomeCompilation = false
                } else {
                    scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds)
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func configureModelFromUser() {
        isShowingModelConfiguration = true
    }

    func showUsedModelsConfiguration() {
        isShowingModelConfiguration = true
    }

    func configureUsernameFromUser() {
        isShowingUsernameConfiguration = true
    }

    func loginWithICloudInDevelopment() {
        // Placeholder for future iCloud sign-in.
    }

    func saveUserProfile(_ profile: UserProfile) {
        userProfile = profile
        userName = profile.greetingName
        UserDefaults.standard.set(userName, forKey: userNameKey)
        if let data = try? encoder.encode(profile) {
            UserDefaults.standard.set(data, forKey: userProfileKey)
        }
        isShowingUsernameConfiguration = false
        status = profile.greetingName.isEmpty ? "Profile cleared" : "Profile saved"
    }

    func saveUserName(_ name: String) {
        var profile = userProfile
        profile.firstName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.lastName = ""
        saveUserProfile(profile)
    }

    func showHighlightSummaryCompiler() {
        compileCurrentHighlightSummary()
    }

    func openHomePage() {
        openHomePage(regenerate: false)
    }

    func openHomePageAndCompile() {
        regenerateHomePage()
    }

    private func openHomePageForLaunch() {
        autosaveTask?.cancel()
        autosaveTask = nil
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        activeSearchHighlight = nil
        currentHighlightSummary = nil
        isShowingHomePage = true
        isShowingHelpDesk = false
        currentNoteID = nil
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        title = "Home"
        content = homeMarkdown
        status = "Home opened"
        refreshNextCalendarClass()

        guard latestHomeSummary == nil else {
            isGeneratingHomePage = false
            return
        }

        compileHomePageSummary(force: false)
    }

    func openHelpDesk() {
        if currentNoteID != nil, currentHighlightSummary == nil, !isShowingHomePage {
            saveCurrentNote(statusText: "Autosaved")
        }

        autosaveTask?.cancel()
        autosaveTask = nil
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        activeSearchHighlight = nil
        currentHighlightSummary = nil
        isShowingHomePage = false
        isShowingHelpDesk = true
        currentNoteID = nil
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        title = "Zirn Chat"
        content = ""
        if selectedHelpDeskConversationID == nil {
            startNewHelpDeskConversation()
        }
        status = "Zirn Chat opened"
    }

    func startNewHelpDeskConversation() {
        let now = Date()
        let conversation = HelpDeskConversation(
            id: UUID().uuidString,
            title: "New conversation",
            messages: [],
            createdAt: now,
            updatedAt: now
        )
        helpDeskDatabase.conversations.insert(conversation, at: 0)
        syncHelpDeskConversations()
        selectedHelpDeskConversationID = conversation.id
        helpDeskInput = ""
        helpDeskAttachment = nil
        helpDeskMarkdownSuggestions = []
        persistHelpDeskConversationQuietly(conversation)
        status = "New Zirn Chat conversation"
    }

    func selectHelpDeskConversation(id: HelpDeskConversation.ID) {
        guard helpDeskDatabase.conversations.contains(where: { $0.id == id }) else { return }
        selectedHelpDeskConversationID = id
        helpDeskAttachment = nil
        isShowingHelpDeskConversationBrowser = false
        openHelpDesk()
    }

    func deleteHelpDeskConversation(id: HelpDeskConversation.ID) {
        guard let index = helpDeskDatabase.conversations.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedHelpDeskConversationID == id
        helpDeskDatabase.conversations.remove(at: index)
        syncHelpDeskConversations()
        if wasSelected {
            selectedHelpDeskConversationID = helpDeskConversations.first?.id
            helpDeskAttachment = nil
            helpDeskInput = ""
        }
        deleteHelpDeskConversationFromStoreQuietly(id: id)
        status = "Conversation deleted"
    }

    func submitHelpDeskPrompt() {
        let prompt = helpDeskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty || helpDeskAttachment != nil, !isGeneratingHelpDeskResponse else { return }
        guard activeBrain != nil else {
            status = "Open or create a brain first"
            return
        }

        if selectedHelpDeskConversationID == nil {
            startNewHelpDeskConversation()
        }
        guard let brainID = activeBrain?.id,
              let conversationID = selectedHelpDeskConversationID else {
            status = "No Zirn Chat conversation is selected."
            return
        }

        let userMessage = HelpDeskMessage(
            id: UUID().uuidString,
            role: .user,
            content: prompt.isEmpty ? "Use the attached file as context." : prompt,
            attachmentName: helpDeskAttachment?.fileName,
            createdAt: Date()
        )
        appendHelpDeskMessage(userMessage)
        helpDeskInput = ""
        isGeneratingHelpDeskResponse = true
        status = "\(selectedAssistantModel.title) is answering Zirn Chat"

        let attachment = helpDeskAttachment
        helpDeskAttachment = nil

        Task {
            await generateHelpDeskResponse(
                for: userMessage,
                attachment: attachment,
                vaultID: brainID,
                conversationID: conversationID
            )
        }
    }

    func chooseHelpDeskAttachmentFromUser() {
        let panel = NSOpenPanel()
        panel.title = "Attach File"
        panel.message = "Choose a PDF, Word document, PowerPoint, or image."
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .pdf,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "ppt") ?? .data,
            UTType(filenameExtension: "pptx") ?? .data,
            .image
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        attachHelpDeskDocument(from: url)
    }

    func removeHelpDeskAttachment() {
        helpDeskAttachment = nil
    }

    func deleteHelpDeskExchange(assistantMessageID: String) {
        guard !isGeneratingHelpDeskResponse,
              let conversationID = selectedHelpDeskConversationID,
              let conversationIndex = helpDeskDatabase.conversations.firstIndex(where: { $0.id == conversationID })
        else { return }

        let messages = helpDeskDatabase.conversations[conversationIndex].messages
        guard let assistantIndex = messages.firstIndex(where: { $0.id == assistantMessageID }),
              messages[assistantIndex].role == .assistant,
              assistantIndex > 0
        else { return }

        var userIndex = assistantIndex - 1
        while userIndex >= 0, messages[userIndex].role != .user {
            userIndex -= 1
        }
        guard userIndex >= 0, messages[userIndex].role == .user else { return }

        let userMessageID = messages[userIndex].id
        var updatedMessages = messages
        updatedMessages.remove(at: assistantIndex)
        updatedMessages.remove(at: userIndex)
        helpDeskDatabase.conversations[conversationIndex].messages = updatedMessages
        syncHelpDeskConversations()

        helpDeskMarkdownSuggestions.removeAll { $0.messageID == assistantMessageID }

        do {
            try helpDeskSessionDatabase?.deleteMessages(
                in: conversationID,
                withIDs: [userMessageID, assistantMessageID]
            )
            status = "Message deleted"
        } catch {
            status = error.localizedDescription
        }
    }

    func regenerateHelpDeskResponse(assistantMessageID: String) {
        guard !isGeneratingHelpDeskResponse,
              let brainID = activeBrain?.id,
              let conversationID = selectedHelpDeskConversationID,
              let conversationIndex = helpDeskDatabase.conversations.firstIndex(where: { $0.id == conversationID })
        else { return }

        let messages = helpDeskDatabase.conversations[conversationIndex].messages
        guard let assistantIndex = messages.firstIndex(where: { $0.id == assistantMessageID }),
              messages[assistantIndex].role == .assistant,
              assistantIndex > 0
        else { return }

        var userIndex = assistantIndex - 1
        while userIndex >= 0, messages[userIndex].role != .user {
            userIndex -= 1
        }
        guard userIndex >= 0, messages[userIndex].role == .user else { return }

        let userMessage = messages[userIndex]
        helpDeskDatabase.conversations[conversationIndex].messages = Array(messages.prefix(assistantIndex))
        syncHelpDeskConversations()
        helpDeskMarkdownSuggestions.removeAll { $0.messageID == assistantMessageID }

        do {
            try helpDeskSessionDatabase?.deleteMessages(
                in: conversationID,
                startingFromMessageID: assistantMessageID
            )
        } catch {
            status = error.localizedDescription
            return
        }

        isGeneratingHelpDeskResponse = true
        status = "\(selectedAssistantModel.title) is regenerating"

        Task {
            await generateHelpDeskResponse(
                for: userMessage,
                attachment: nil,
                vaultID: brainID,
                conversationID: conversationID
            )
        }
    }

    func addHelpDeskMessageToMarkdown(messageID: String) {
        guard activeBrain != nil,
              let conversationID = selectedHelpDeskConversationID,
              let message = helpDeskMessages(for: conversationID).first(where: { $0.id == messageID }),
              message.role == .assistant,
              !isGeneratingHelpDeskResponse
        else { return }

        if let suggestion = helpDeskMarkdownSuggestion(for: messageID), !suggestion.isLoading {
            applyHelpDeskMarkdownSuggestion(messageID: messageID)
            return
        }

        Task {
            await resolveAndApplyHelpDeskMarkdown(
                assistantMessage: message,
                conversationID: conversationID
            )
        }
    }

    func applyHelpDeskMarkdownSuggestion(messageID: String) {
        guard let suggestion = helpDeskMarkdownSuggestion(for: messageID),
              !suggestion.isLoading
        else { return }

        do {
            switch suggestion.action {
            case .appendToExisting:
                guard let note = noteSummary(matchingTitle: suggestion.pageTitle) else {
                    throw AssistantError.requestFailed("Could not find page \"\(suggestion.pageTitle)\".")
                }
                try withActiveBrainAccessThrowing {
                    try appendMarkdownToNote(noteID: note.id, markdown: suggestion.formattedMarkdown)
                }
                status = "Added to \(note.title)"
            case .createNew:
                let note = try withActiveBrainAccessThrowing {
                    try createNoteFromHelpDesk(
                        title: suggestion.pageTitle,
                        bodyMarkdown: suggestion.formattedMarkdown
                    )
                }
                status = "Created \(note.title)"
            }
            helpDeskMarkdownSuggestions.removeAll { $0.messageID == messageID }
        } catch {
            status = error.localizedDescription
        }
    }

    func dismissHelpDeskMarkdownSuggestion(messageID: String) {
        helpDeskMarkdownSuggestions.removeAll { $0.messageID == messageID }
        status = "Suggestion dismissed"
    }

    func areHelpDeskSuggestionsEnabled(for conversationID: HelpDeskConversation.ID?) -> Bool {
        guard let conversationID else { return true }
        return !helpDeskSuggestionsDisabledConversationIDs.contains(conversationID)
    }

    func disableHelpDeskSuggestionsForCurrentSession() {
        guard let conversationID = selectedHelpDeskConversationID else { return }
        helpDeskSuggestionsDisabledConversationIDs.insert(conversationID)
        helpDeskMarkdownSuggestions.removeAll { $0.conversationID == conversationID }
        status = "Suggestions turned off for this conversation"
    }

    func regenerateHomePage() {
        guard isShowingHomePage else {
            openHomePage()
            return
        }

        if currentNoteID != nil, currentHighlightSummary == nil, !isShowingHomePage {
            saveCurrentNote(statusText: "Autosaved")
        }

        try? refreshVaultNotesForHome()
        homeCompilationTask?.cancel()
        homeCompilationTask = nil
        needsHomeRegenerationAfterCurrentCompile = false
        needsForcedHomeRegenerationAfterCurrentCompile = false
        isShowingHomePage = true
        isShowingHelpDesk = false
        currentNoteID = nil
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        currentHighlightSummary = nil
        title = "Home"
        isGeneratingHomePage = true
        status = "Regenerating Home page"

        startForcedHomePageGeneration()
    }

    func requestPageFlashcards(noteID: Note.ID, force: Bool = false) {
        guard !pageFlashcardStates[noteID, default: .idle].isLoading else { return }
        if noteID == currentNoteID,
           currentHighlightSummary == nil,
           !isShowingHomePage {
            saveCurrentNote(statusText: force ? "Regenerating flashcards" : "Preparing flashcards")
        }
        pageFlashcardStates[noteID] = PageFlashcardState(
            isLoading: true,
            bundle: existingGeneratedPageFlashcardBundle(for: noteID),
            pinnedCardIDs: existingPinnedPageFlashcardIDs(for: noteID),
            errorMessage: nil
        )
        status = force ? "Regenerating flashcards" : "Preparing flashcards"

        Task { [weak self] in
            await self?.loadOrGeneratePageFlashcards(noteID: noteID, force: force)
        }
    }

    func togglePinnedPageFlashcard(noteID: Note.ID, cardID: PageFlashcard.ID) {
        guard let currentBundle = pageFlashcardStates[noteID]?.bundle,
              isGeneratedPageFlashcardBundle(currentBundle)
        else {
            status = "Generate flashcards before pinning"
            return
        }

        do {
            try withActiveBrainAccessThrowing {
                let cachedRecord = try loadPageFlashcardCache(noteID: noteID)
                    ?? initialPageFlashcardCache(for: currentBundle)
                var pinnedIDs = pinnedPageFlashcardIDs(in: cachedRecord)
                if pinnedIDs.contains(cardID) {
                    pinnedIDs.remove(cardID)
                } else {
                    pinnedIDs.insert(cardID)
                }

                let sortedBundle = pageFlashcardBundle(cachedRecord.bundle, sortingPinnedCardIDs: pinnedIDs)
                let updatedRecord = PageFlashcardCacheFile(
                    version: PageFlashcardCacheFile.currentVersion,
                    bundle: sortedBundle,
                    pinnedCardIDs: Array(pinnedIDs),
                    previousSimilarityScore: cachedRecord.previousSimilarityScore,
                    latestSimilarityScore: cachedRecord.latestSimilarityScore,
                    similarityThreshold: cachedRecord.similarityThreshold,
                    lastCheckedAt: Date()
                )
                try persistPageFlashcardCache(updatedRecord)
                pageFlashcardStates[noteID] = PageFlashcardState(
                    isLoading: false,
                    bundle: sortedBundle,
                    pinnedCardIDs: pinnedIDs,
                    errorMessage: nil
                )
                status = pinnedIDs.contains(cardID) ? "Flashcard pinned" : "Flashcard unpinned"
            }
        } catch {
            status = error.localizedDescription
        }
    }

    func openPageFlashcardSource(noteID: Note.ID, query: String?) {
        openNote(id: noteID)
        let cleanQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanQuery.isEmpty {
            let normalizedQuery = normalizedSearchText(cleanQuery)
            let blockIndex = markdownSearchBlocks(from: content)
                .first { block in
                    normalizedSearchText(block.text).contains(normalizedQuery)
                }?
                .index ?? 0
            activeSearchHighlight = SearchHighlight(
                noteID: noteID,
                query: cleanQuery,
                blockIndex: blockIndex
            )
        }
    }

    private func openHomePage(regenerate: Bool) {
        if currentNoteID != nil, currentHighlightSummary == nil, !isShowingHomePage {
            saveCurrentNote(statusText: "Autosaved")
        }

        autosaveTask?.cancel()
        autosaveTask = nil
        if !regenerate {
            homeCompilationTask?.cancel()
            homeCompilationTask = nil
            activeHomeGenerationID = nil
            needsHomeRegenerationAfterCurrentCompile = false
            needsForcedHomeRegenerationAfterCurrentCompile = false
            isGeneratingHomePage = false
            isCompilingHighlightSummary = activeHighlightGenerationID != nil
        }
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        activeSearchHighlight = nil
        currentHighlightSummary = nil
        isShowingHomePage = true
        isShowingHelpDesk = false
        currentNoteID = nil
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        title = "Home"
        content = homeMarkdown
        status = "Home opened"
        refreshNextCalendarClass()

        if regenerate {
            compileHomePageSummary(force: true)
        }
    }

    func openHighlightSummary(id: HighlightSummary.ID) {
        guard let summary = generatedSummaries.first(where: { $0.id == id }) else { return }
        autosaveTask?.cancel()
        autosaveTask = nil
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        activeSearchHighlight = nil
        currentHighlightSummary = summary
        isShowingHomePage = false
        isShowingHelpDesk = false
        currentNoteID = nil
        selectedNoteID = nil
        selectedSidebarGroupID = nil
        title = summary.title
        content = summary.markdown
        status = "Summary opened"
    }

    func openLatestHighlightSummaryOrCompiler() {
        if let noteID = currentNoteID,
           let summary = generatedSummaries.first(where: { $0.sourceNoteID == noteID && $0.id != homeSummaryID }) {
            openHighlightSummary(id: summary.id)
            return
        }

        if canCompileCurrentHighlights {
            compileCurrentHighlightSummary()
            return
        }

        if let latestSummary = generatedSummaries.first(where: { $0.id != homeSummaryID }) {
            openHighlightSummary(id: latestSummary.id)
            return
        }

        status = "Highlight text on a page, then compile a summary"
    }

    func compileCurrentHighlightSummary() {
        compileCurrentHighlightSummary(using: selectedFlashcardGenerationModel)
    }

    private func compileHomePageSummary(force: Bool = false) {
        guard activeHighlightGenerationID == nil else {
            needsHomeRegenerationAfterCurrentCompile = true
            needsForcedHomeRegenerationAfterCurrentCompile = needsForcedHomeRegenerationAfterCurrentCompile || force
            if force {
                isGeneratingHomePage = true
            }
            return
        }
        homeCompilationTask?.cancel()
        homeCompilationTask = nil
        activeHomeGenerationID = nil
        guard let activeBrain else {
            isGeneratingHomePage = false
            status = "Open or create a brain first"
            return
        }

        do {
            let sourceNotes = try loadHomePageSourceNotes()
            guard !sourceNotes.isEmpty else {
                let sourceFingerprint = homeSourceFingerprint(for: sourceNotes)
                persistImmediateHomeSummary(
                    vaultName: activeBrain.name,
                    sourceNotes: sourceNotes,
                    modelTitle: "Local live summary",
                    sourceFingerprint: sourceFingerprint,
                    sourceDiceTokens: homeSourceDiceTokens(for: sourceNotes)
                )
                isGeneratingHomePage = false
                status = "Home cleared"
                return
            }

            let sourceFingerprint = homeSourceFingerprint(for: sourceNotes)
            let currentSourceDiceTokens = homeSourceDiceTokens(for: sourceNotes)
            if !force, latestHomeSummary?.sourceFingerprint == sourceFingerprint {
                lastHomeSourceDiceTokensForSimilarityCheck = currentSourceDiceTokens
                if isShowingHomePage {
                    title = "Home"
                    content = homeMarkdown
                }
                isGeneratingHomePage = false
                status = "Home is up to date"
                return
            }

            if !force,
               let previousSourceDiceTokens = latestHomeSummary?.sourceDiceTokens ?? lastHomeSourceDiceTokensForSimilarityCheck,
               let similarity = homeSourceDiceSimilarity(previousSourceDiceTokens, currentSourceDiceTokens),
               similarity >= Self.homePageDiceSimilaritySkipThreshold {
                refreshHomeSummarySourceSignature(
                    sourceFingerprint,
                    sourceDiceTokens: currentSourceDiceTokens,
                    sourceNotes: sourceNotes
                )
                lastHomeSourceDiceTokensForSimilarityCheck = currentSourceDiceTokens
                if isShowingHomePage {
                    title = "Home"
                    content = homeMarkdown
                }
                isGeneratingHomePage = false
                status = "Home is up to date (Dice similarity \(Int(similarity * 100))%)"
                return
            }

            let model = selectedHomeGenerationModel
            isGeneratingHomePage = true
            persistImmediateHomeSummary(
                vaultName: activeBrain.name,
                sourceNotes: sourceNotes,
                modelTitle: "Local live summary",
                sourceFingerprint: sourceFingerprint,
                sourceDiceTokens: currentSourceDiceTokens
            )
            isCompilingHighlightSummary = true
            status = "\(model.title) is generating Home page"

            let generationID = UUID()
            activeHomeGenerationID = generationID
            homeCompilationTask = Task { [weak self] in
                await self?.generateHomePageSummary(
                    vaultName: activeBrain.name,
                    sourceNotes: sourceNotes,
                    sourceFingerprint: sourceFingerprint,
                    sourceDiceTokens: currentSourceDiceTokens,
                    model: model,
                    generationID: generationID
                )
            }
        } catch {
            isGeneratingHomePage = false
            status = error.localizedDescription
        }
    }

    private func startForcedHomePageGeneration() {
        homeCompilationTask?.cancel()
        homeCompilationTask = nil
        activeHomeGenerationID = nil

        guard let activeBrain else {
            isGeneratingHomePage = false
            status = "Open or create a brain first"
            return
        }

        do {
            let sourceNotes = try loadHomePageSourceNotes()
            let sourceFingerprint = homeSourceFingerprint(for: sourceNotes)
            guard !sourceNotes.isEmpty else {
                persistImmediateHomeSummary(
                    vaultName: activeBrain.name,
                    sourceNotes: sourceNotes,
                    modelTitle: "Local live summary",
                    sourceFingerprint: sourceFingerprint,
                    sourceDiceTokens: homeSourceDiceTokens(for: sourceNotes)
                )
                content = homeMarkdown
                isGeneratingHomePage = false
                status = "Home cleared"
                return
            }

            let model = selectedHomeGenerationModel
            let sourceDiceTokens = homeSourceDiceTokens(for: sourceNotes)
            let generationID = UUID()
            activeHomeGenerationID = generationID
            persistImmediateHomeSummary(
                vaultName: activeBrain.name,
                sourceNotes: sourceNotes,
                modelTitle: "Local live summary",
                sourceFingerprint: sourceFingerprint,
                sourceDiceTokens: sourceDiceTokens
            )
            content = homeMarkdown
            isCompilingHighlightSummary = true
            isGeneratingHomePage = true
            status = "\(model.title) is generating Home page"

            homeCompilationTask = Task { [weak self] in
                await self?.generateHomePageSummary(
                    vaultName: activeBrain.name,
                    sourceNotes: sourceNotes,
                    sourceFingerprint: sourceFingerprint,
                    sourceDiceTokens: sourceDiceTokens,
                    model: model,
                    generationID: generationID
                )
            }
        } catch {
            isGeneratingHomePage = false
            status = error.localizedDescription
        }
    }

    private func loadOrGeneratePageFlashcards(noteID: Note.ID, force: Bool) async {
        do {
            let note = try withActiveBrainAccessThrowing { () -> Note in
                guard let noteURL = noteURL(for: noteID) else {
                    throw CocoaError(.fileNoSuchFile)
                }
                return try readNote(from: noteURL)
            }
            let sourceTokens = pageFlashcardDiceTokens(for: note.content)
            let cachedRecord = try? loadPageFlashcardCache(noteID: noteID)

            if let cachedRecord {
                let similarity = homeSourceDiceSimilarity(cachedRecord.bundle.sourceDiceTokens, sourceTokens)
                let pinnedIDs = pinnedPageFlashcardIDs(in: cachedRecord)
                let refreshedRecord = refreshedPageFlashcardCache(
                    cachedRecord,
                    latestSimilarityScore: similarity
                )
                try? withActiveBrainAccessThrowing {
                    try persistPageFlashcardCache(refreshedRecord)
                }

                if let similarity,
                   similarity >= Self.pageFlashcardSimilarityRegenerateThreshold {
                    pageFlashcardStates[noteID] = PageFlashcardState(
                        isLoading: false,
                        bundle: refreshedRecord.bundle,
                        pinnedCardIDs: pinnedIDs,
                        errorMessage: nil
                    )
                    status = force ? "Flashcards unchanged; skipped regeneration" : "Flashcards ready"
                    return
                }

                guard force else {
                    pageFlashcardStates[noteID] = PageFlashcardState(
                        isLoading: false,
                        bundle: refreshedRecord.bundle,
                        pinnedCardIDs: pinnedIDs,
                        errorMessage: nil
                    )
                    status = "Flashcards ready from cache"
                    return
                }

                pageFlashcardStates[noteID] = PageFlashcardState(
                    isLoading: true,
                    bundle: refreshedRecord.bundle,
                    pinnedCardIDs: pinnedIDs,
                    errorMessage: nil
                )
            }

            if !force {
                pageFlashcardStates[noteID] = PageFlashcardState(
                    isLoading: true,
                    bundle: existingGeneratedPageFlashcardBundle(for: noteID),
                    pinnedCardIDs: existingPinnedPageFlashcardIDs(for: noteID),
                    errorMessage: nil
                )
                status = "Generating flashcards"
            }

            let generated: PageFlashcardBundle
            do {
                let rawGenerated = try await generatePageFlashcards(note: note, sourceDiceTokens: sourceTokens)
                generated = pageFlashcardBundle(rawGenerated, preservingPinnedCardsFrom: cachedRecord)
                try withActiveBrainAccessThrowing {
                    let latestSimilarity = cachedRecord.flatMap {
                        homeSourceDiceSimilarity($0.bundle.sourceDiceTokens, sourceTokens)
                    }
                    let pinnedIDs = cachedRecord.map { pinnedPageFlashcardIDs(in: $0) } ?? []
                    let cache = PageFlashcardCacheFile(
                        version: PageFlashcardCacheFile.currentVersion,
                        bundle: generated,
                        pinnedCardIDs: Array(pinnedIDs),
                        previousSimilarityScore: cachedRecord?.latestSimilarityScore,
                        latestSimilarityScore: cachedRecord == nil ? 1 : latestSimilarity,
                        similarityThreshold: Self.pageFlashcardSimilarityRegenerateThreshold,
                        lastCheckedAt: Date()
                    )
                    try persistPageFlashcardCache(cache)
                }
            } catch {
                let message = flashcardErrorMessage(from: error)
                pageFlashcardStates[noteID] = PageFlashcardState(
                    isLoading: false,
                    bundle: existingGeneratedPageFlashcardBundle(for: noteID) ?? cachedRecord?.bundle,
                    pinnedCardIDs: cachedRecord.map { pinnedPageFlashcardIDs(in: $0) } ?? existingPinnedPageFlashcardIDs(for: noteID),
                    errorMessage: message
                )
                status = message
                return
            }

            pageFlashcardStates[noteID] = PageFlashcardState(
                isLoading: false,
                bundle: generated,
                pinnedCardIDs: cachedRecord.map { pinnedPageFlashcardIDs(in: $0) } ?? [],
                errorMessage: nil
            )
            status = "Flashcards generated"
        } catch {
            pageFlashcardStates[noteID] = PageFlashcardState(
                isLoading: false,
                bundle: existingGeneratedPageFlashcardBundle(for: noteID),
                pinnedCardIDs: existingPinnedPageFlashcardIDs(for: noteID),
                errorMessage: flashcardErrorMessage(from: error)
            )
            status = flashcardErrorMessage(from: error)
        }
    }

    private func localPageFlashcardBundle(note: Note, sourceDiceTokens: [String]) -> PageFlashcardBundle {
        let highlights = highlightedTextFragments(in: note.content)
            .map { cleanedFlashcardText($0) }
            .filter { !$0.isEmpty }

        let cards: [PageFlashcard]
        if highlights.isEmpty {
            let summary = cleanedFlashcardText(
                localPageSummary(
                    for: HomePageSourceNote(
                        id: note.id,
                        title: note.title,
                        content: note.content,
                        updatedAt: note.updatedAt
                    ),
                    sentenceLimit: 4,
                    wordLimit: 80
                )
            )
            cards = [
                PageFlashcard(
                    id: "\(note.id)-local-main-idea",
                    question: "What is the main idea of \(note.title)?",
                    answer: summary,
                    anchor: summary
                )
            ]
        } else {
            cards = highlights.prefix(6).enumerated().map { index, highlight in
                PageFlashcard(
                    id: "\(note.id)-local-\(index)",
                    question: localFlashcardQuestion(for: highlight, pageTitle: note.title),
                    answer: lineLimited(highlight, maxLines: 4),
                    anchor: String(highlight.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        return PageFlashcardBundle(
            noteID: note.id,
            noteTitle: note.title,
            sourceFingerprint: stableFingerprint(for: note.content),
            sourceDiceTokens: sourceDiceTokens,
            generatedAt: Date(),
            modelTitle: "Local instant flashcards",
            cards: cards
        )
    }

    private func generatePageFlashcards(note: Note, sourceDiceTokens: [String]) async throws -> PageFlashcardBundle {
        let prompt = pageFlashcardPrompt(note: note)
        let result: ChatCompletionResult
        let model = selectedFlashcardGenerationModel
        switch model {
        case .mistral:
            result = try await generateWithMistral(
                system: pageFlashcardInstructions(),
                user: prompt,
                maxTokens: Self.pageFlashcardMaxOutputTokens
            )
        case .deepseek:
            result = try await generateWithDeepSeek(
                system: pageFlashcardInstructions(),
                user: prompt,
                maxTokens: Self.pageFlashcardMaxOutputTokens
            )
        case .ollama:
            result = try await generateWithOllama(
                system: pageFlashcardInstructions(),
                user: prompt
            )
        }
        recordUsage(
            for: model,
            result: result,
            fallbackInputTokens: estimatedTokenCount(for: prompt),
            fallbackOutputTokens: estimatedTokenCount(for: result.content)
        )

        let cards = try parsePageFlashcards(from: result.content, fallbackNote: note)
        return PageFlashcardBundle(
            noteID: note.id,
            noteTitle: note.title,
            sourceFingerprint: stableFingerprint(for: note.content),
            sourceDiceTokens: sourceDiceTokens,
            generatedAt: Date(),
            modelTitle: model.displayModelName(
                mistralModel: mistralModel,
                deepSeekModel: deepSeekModel,
                ollamaModel: ollamaModel
            ),
            cards: cards
        )
    }

    private func scheduleLiveHomePageCompilation(delay requestedDelay: UInt64? = nil, force: Bool = false) {
        guard activeBrain != nil else { return }
        let delay = requestedDelay ?? Self.homeCompilationDebounceNanoseconds
        homeCompilationTask?.cancel()
        activeHomeGenerationID = nil
        homeCompilationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.compileHomePageSummary(force: force)
            }
        }
    }

    private func compileCurrentHighlightSummary(using model: HighlightSummaryModel) {
        guard activeHighlightGenerationID == nil else { return }
        guard let sourceNoteID = currentNoteID else {
            status = "Open a page with highlights first"
            return
        }

        let sourceTitle = displayTitle(for: title)
        let sourceMarkdown = content
        let highlights = highlightedTextFragments(in: sourceMarkdown)
        guard !highlights.isEmpty else {
            status = "Highlight text before compiling a summary"
            return
        }

        selectedFlashcardGenerationModel = model
        isShowingHighlightSummaryCompiler = false
        let generationID = UUID()
        activeHighlightGenerationID = generationID
        isCompilingHighlightSummary = true
        saveCurrentNote(statusText: "Highlights saved")

        let summaryID = "summary-\(sourceNoteID)"
        if let existingSummary = generatedSummaries.first(where: { $0.id == summaryID }) {
            openHighlightSummary(id: existingSummary.id)
        }

        status = "\(model.title) is compiling highlight summary"

        Task {
            await generateHighlightSummary(
                sourceNoteID: sourceNoteID,
                sourceTitle: sourceTitle,
                highlights: highlights,
                model: model,
                generationID: generationID
            )
        }
    }

    var assistantConfigurationSnapshot: AssistantConfiguration {
        AssistantConfiguration(
            mistralAPIKey: mistralAPIKey,
            mistralModel: mistralModel,
            deepSeekAPIKey: deepSeekAPIKey,
            deepSeekModel: deepSeekModel
        )
    }

    func saveModelConfiguration(
        mistralAPIKey: String,
        mistralModel: String,
        deepSeekAPIKey: String,
        deepSeekModel: String,
        contentModel: AssistantModel,
        homeGenerationModel: HighlightSummaryModel,
        flashcardGenerationModel: HighlightSummaryModel,
        appleCalendarSyncEnabled: Bool
    ) {
        let previousAppleCalendarSyncEnabled = isAppleCalendarSyncEnabled
        self.mistralAPIKey = mistralAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mistralModel = mistralModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deepSeekAPIKey = deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deepSeekModel = deepSeekModel.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedAssistantModel = contentModel
        selectedHomeGenerationModel = homeGenerationModel
        selectedFlashcardGenerationModel = flashcardGenerationModel
        isAppleCalendarSyncEnabled = appleCalendarSyncEnabled
        if appleCalendarSyncEnabled {
            recommendedPageHintDismissed = false
        }

        if self.mistralModel.isEmpty { self.mistralModel = Self.defaultMistralModel }
        if self.deepSeekModel.isEmpty { self.deepSeekModel = Self.defaultDeepSeekModel }

        do {
            try saveAssistantConfiguration()
            isShowingModelConfiguration = false
            refreshMistralAccountLimitsIfNeeded()
            status = "Model settings saved"
            if appleCalendarSyncEnabled != previousAppleCalendarSyncEnabled {
                setAppleCalendarSyncEnabled(appleCalendarSyncEnabled)
            }
        } catch {
            status = error.localizedDescription
        }
    }

    func verifyAndSaveMistralAPIKey(_ apiKey: String) async throws {
        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Paste a Mistral API key.")
        }

        try await verifyMistralAPIKey(cleanAPIKey)
        mistralAPIKey = cleanAPIKey
        mistralModel = Self.defaultMistralModel
        try saveAssistantConfiguration()
        refreshMistralAccountLimitsIfNeeded()
        status = "Mistral API key verified"
    }

    func verifyAndSaveDeepSeekAPIKey(_ apiKey: String) async throws {
        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Paste a DeepSeek API key.")
        }

        try await verifyDeepSeekAPIKey(cleanAPIKey)
        deepSeekAPIKey = cleanAPIKey
        deepSeekModel = Self.defaultDeepSeekModel
        try saveAssistantConfiguration()
        status = "DeepSeek API key verified"
    }

    @discardableResult
    func saveMistralAPIKeyToKeychain(_ apiKey: String) async throws -> MistralKeychainStore.SaveLocation {
        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add and verify a Mistral API key first.")
        }

        let location = try await MistralKeychainStore.saveMistralAPIKey(cleanAPIKey)
        status = location == .applePasswords
            ? "Mistral API key saved to Apple Passwords"
            : "Mistral API key saved to Apple Passwords on this Mac"
        return location
    }

    @discardableResult
    func saveDeepSeekAPIKeyToKeychain(_ apiKey: String) async throws -> MistralKeychainStore.SaveLocation {
        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add and verify a DeepSeek API key first.")
        }

        let location = try await MistralKeychainStore.saveDeepSeekAPIKey(cleanAPIKey)
        status = location == .applePasswords
            ? "DeepSeek API key saved to Apple Passwords"
            : "DeepSeek API key saved to Apple Passwords on this Mac"
        return location
    }

    func selectAssistantModel(_ model: AssistantModel) {
        selectedAssistantModel = model
        do {
            try saveAssistantConfiguration()
            status = "\(model.title) selected for Zirn Chat"
        } catch {
            UserDefaults.standard.set(model.rawValue, forKey: selectedAssistantModelKey)
            status = error.localizedDescription
        }
    }

    func submitAssistantPrompt() {
        let prompt = assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedPageTitles = assistantPromptLinkedPages.map(\.title)
        guard (!prompt.isEmpty || assistantAttachment != nil || !linkedPageTitles.isEmpty), !isGeneratingAssistantResponse else { return }

        let intent = assistantIntent(for: prompt)
        pendingAssistantPreview = nil
        if intent == .writing {
            assistantConversationResponse = nil
            assistantConversationMemory.clear()
        }
        isGeneratingAssistantResponse = true
        assistantGenerationPhase = .preparingContext
        isUsingWebSearch = selectedAssistantModel.supportsWebSearch && promptSuggestsWebSearch(prompt)
        status = intent == .writing ? "\(selectedAssistantModel.title) is writing" : "\(selectedAssistantModel.title) is answering"

        assistantGenerationTask?.cancel()
        assistantGenerationTask = Task {
            switch intent {
            case .writing:
                await generateAssistantResponse(for: prompt, linkedPageTitles: linkedPageTitles)
            case .conversation:
                await generateAssistantConversationResponse(for: prompt, linkedPageTitles: linkedPageTitles)
            }
        }
    }

    func cancelAssistantResponse() {
        guard isGeneratingAssistantResponse else { return }
        assistantGenerationTask?.cancel()
        assistantGenerationTask = nil
        isGeneratingAssistantResponse = false
        isUsingWebSearch = false
        assistantGenerationPhase = .idle
        status = "Answer cancelled"
    }

    func addAssistantPromptLink(title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              !assistantPromptLinkedPages.contains(where: { normalizedLinkTitle($0.title) == normalizedLinkTitle(cleanTitle) })
        else { return }

        assistantPromptLinkedPages.append(PromptLinkedPage(title: cleanTitle))
    }

    func removeAssistantPromptLink(id: PromptLinkedPage.ID) {
        assistantPromptLinkedPages.removeAll { $0.id == id }
    }

    func toggleAssistantWritingMode() {
        isAssistantWritingMode.toggle()
        if isAssistantWritingMode {
            assistantConversationResponse = nil
            assistantConversationMemory.clear()
        }
        status = isAssistantWritingMode ? "Writing mode on" : "Question mode on"
    }

    func toggleVoiceCapture(target: VoiceCaptureTarget) {
        guard !isFinalizingVoiceTranscript else {
            status = "Voice transcription is still processing"
            return
        }

        if activeVoiceCaptureTarget == target {
            stopVoiceCapture()
            return
        }

        if pendingVoiceAudioSourceSelection == target {
            dismissVoiceAudioSourceSelection()
            return
        }

        pendingVoiceAudioSourceSelection = target
        status = "Choose an audio source"
    }

    func selectVoiceAudioSource(_ source: VoiceAudioSource, for target: VoiceCaptureTarget? = nil) {
        let resolvedTarget = target ?? pendingVoiceAudioSourceSelection
        guard let resolvedTarget else { return }

        withAnimation(.easeInOut(duration: 0.32)) {
            pendingVoiceAudioSourceSelection = nil
        }
        Task {
            await startVoiceCapture(target: resolvedTarget, source: source)
        }
    }

    func dismissVoiceAudioSourceSelection() {
        withAnimation(.easeInOut(duration: 0.28)) {
            pendingVoiceAudioSourceSelection = nil
        }
        if restorePendingVoiceAppendDraftIfNeeded(statusText: "Ready") {
            return
        }
        if activeVoiceCaptureTarget == nil, !isFinalizingVoiceTranscript {
            status = "Ready"
        }
    }

    func dismissVoiceTranscriptionNotice() {
        voiceTranscriptionNotice = nil
        if activeVoiceCaptureTarget == nil,
           !isFinalizingVoiceTranscript,
           pendingVoiceTranscriptDraft == nil,
           pendingVoiceAudioSourceSelection == nil {
            status = "Ready"
        }
    }

    /// Continues dictation from an existing review draft. New speech is appended and pushed as a revision.
    func continueVoiceCaptureAppendingToPendingDraft() {
        guard let draft = pendingVoiceTranscriptDraft, !isEnhancingVoiceTranscript else { return }
        guard activeVoiceCaptureTarget == nil, !isFinalizingVoiceTranscript else { return }

        voiceEnhanceTask?.cancel()
        voiceEnhanceTask = nil
        isEnhancingVoiceTranscript = false
        voiceTranscriptionNotice = nil

        // Callers should wrap in withAnimation(.easeInOut); keep transitions here too for shortcut paths.
        withAnimation(.easeInOut(duration: 0.32)) {
            pendingVoiceAppendContext = PendingVoiceAppendContext(draft: draft)
            pendingVoiceTranscriptDraft = nil
            pendingVoiceAudioSourceSelection = draft.target
        }
        status = "Choose an audio source to continue dictation"
    }

    private func restorePendingVoiceAppendDraftIfNeeded(statusText: String) -> Bool {
        guard let appendContext = pendingVoiceAppendContext else { return false }
        withAnimation(.easeInOut(duration: 0.32)) {
            pendingVoiceAppendContext = nil
            pendingVoiceTranscriptDraft = appendContext.draft
        }
        status = statusText
        return true
    }

    private func startVoiceCapture(target: VoiceCaptureTarget, source: VoiceAudioSource) async {
        await ensureWhisperSmallModelInstalledForCurrentUser(reportReadyStatus: true)

        do {
            try await startNativeSpeechTranscription(target: target, source: source)
        } catch {
            status = "Voice transcription failed: \(error.localizedDescription)"
            activeVoiceCaptureTarget = nil
            activeVoiceAudioSource = nil
            voiceCaptureDestinationTitle = nil
            resetVoiceCaptureTimer()
            isVoiceCapturePaused = false
            isFinalizingVoiceTranscript = false
            voiceTranscriptionProgress = 0
            liveVoiceTranscript = ""
            voiceTranscriptionNotice = nil
            isVoiceInputLikelyUserSpeech = false
        }
    }

    func stopVoiceCapture() {
        guard let target = activeVoiceCaptureTarget,
              let controller = voiceTranscriptionController
        else { return }
        voiceTranscriptionController = nil
        finalizingVoiceTranscriptionController = controller
        activeVoiceCaptureTarget = nil
        activeVoiceAudioSource = nil
        pendingVoiceAudioSourceSelection = nil
        resetVoiceCaptureTimer()
        isVoiceCapturePaused = false
        isFinalizingVoiceTranscript = true
        voiceTranscriptionProgress = 0.06
        voiceTranscriptionNotice = nil
        isVoiceInputLikelyUserSpeech = false
        status = "Transcribing voice"
        startVoiceTranscriptionProgress()

        Task { @MainActor in
            let transcript = await controller.finish()
            let finalTranscript = Self.normalizedVoiceTranscript(
                transcript.isEmpty ? liveVoiceTranscript : transcript
            )
            guard finalizingVoiceTranscriptionController === controller else { return }
            finalizingVoiceTranscriptionController = nil
            voiceTranscriptionProgressTask?.cancel()
            voiceTranscriptionProgressTask = nil
            voiceTranscriptionProgress = 1
            liveVoiceTranscript = ""
            isFinalizingVoiceTranscript = false
            handleCompletedVoiceTranscript(finalTranscript, target: target, source: .manualStop)
        }
    }

    func cancelVoiceCapture() {
        guard !isFinalizingVoiceTranscript else {
            cancelFinalizingVoiceTranscription()
            return
        }

        if pendingVoiceAudioSourceSelection != nil {
            dismissVoiceAudioSourceSelection()
            return
        }

        guard activeVoiceCaptureTarget != nil else {
            discardPendingVoiceTranscript()
            return
        }
        voiceTranscriptionController?.cancel()
        voiceTranscriptionController = nil
        activeVoiceCaptureTarget = nil
        activeVoiceAudioSource = nil
        voiceCaptureDestinationTitle = nil
        resetVoiceCaptureTimer()
        isVoiceCapturePaused = false
        isFinalizingVoiceTranscript = false
        voiceTranscriptionProgress = 0
        liveVoiceTranscript = ""
        voiceTranscriptionNotice = nil
        isVoiceInputLikelyUserSpeech = false
        if restorePendingVoiceAppendDraftIfNeeded(statusText: "Voice append cancelled") {
            return
        }
        pendingVoiceTranscriptDraft = nil
        status = "Voice capture cancelled"
    }

    func cancelFinalizingVoiceTranscription() {
        finalizingVoiceTranscriptionController?.cancel()
        finalizingVoiceTranscriptionController = nil
        voiceTranscriptionProgressTask?.cancel()
        voiceTranscriptionProgressTask = nil
        isFinalizingVoiceTranscript = false
        voiceTranscriptionProgress = 0
        liveVoiceTranscript = ""
        voiceTranscriptionNotice = nil
        isVoiceInputLikelyUserSpeech = false
        activeVoiceAudioSource = nil
        voiceCaptureDestinationTitle = nil
        resetVoiceCaptureTimer()
        if restorePendingVoiceAppendDraftIfNeeded(statusText: "Voice append cancelled") {
            return
        }
        status = "Voice transcription cancelled"
    }

    func stopVoiceCaptureForNavigation(destinationTitle: String) {
        guard let target = activeVoiceCaptureTarget,
              let controller = voiceTranscriptionController
        else { return }
        voiceTranscriptionController = nil
        finalizingVoiceTranscriptionController = controller
        activeVoiceCaptureTarget = nil
        activeVoiceAudioSource = nil
        pendingVoiceAudioSourceSelection = nil
        resetVoiceCaptureTimer()
        isVoiceCapturePaused = false
        isFinalizingVoiceTranscript = true
        voiceTranscriptionProgress = 0.06
        voiceTranscriptionNotice = nil
        isVoiceInputLikelyUserSpeech = false
        status = "Transcribing voice for page switch"
        startVoiceTranscriptionProgress()

        Task { @MainActor in
            let transcript = await controller.finish()
            let finalTranscript = Self.normalizedVoiceTranscript(
                transcript.isEmpty ? liveVoiceTranscript : transcript
            )
            guard finalizingVoiceTranscriptionController === controller else { return }
            finalizingVoiceTranscriptionController = nil
            voiceTranscriptionProgressTask?.cancel()
            voiceTranscriptionProgressTask = nil
            voiceTranscriptionProgress = 1
            liveVoiceTranscript = ""
            isFinalizingVoiceTranscript = false
            pendingVoiceClippingConfirmation = VoiceClippingConfirmation(
                target: target,
                destinationTitle: destinationTitle,
                transcript: finalTranscript
            )
        }
    }

    func toggleVoiceCapturePaused() {
        guard activeVoiceCaptureTarget != nil else { return }
        isVoiceCapturePaused.toggle()
        if isVoiceCapturePaused {
            voiceTranscriptionController?.pause()
            isVoiceInputLikelyUserSpeech = false
            voiceCapturePauseStartedAt = Date()
        } else {
            if let pauseStarted = voiceCapturePauseStartedAt {
                voiceCapturePausedAccumulated += Date().timeIntervalSince(pauseStarted)
                voiceCapturePauseStartedAt = nil
            }
            Task {
                do {
                    try voiceTranscriptionController?.resume()
                } catch {
                    status = "Voice resume failed: \(error.localizedDescription)"
                }
            }
        }
        status = isVoiceCapturePaused ? "Voice capture paused" : "Voice capture resumed"
    }

    /// Elapsed recording time, freezing while paused.
    func voiceCaptureElapsed(at date: Date = Date()) -> TimeInterval {
        guard let started = voiceCaptureStartedAt else { return 0 }
        var elapsed = date.timeIntervalSince(started) - voiceCapturePausedAccumulated
        if let pauseStarted = voiceCapturePauseStartedAt {
            elapsed -= date.timeIntervalSince(pauseStarted)
        }
        return max(0, elapsed)
    }

    static func formattedVoiceCaptureElapsed(_ elapsed: TimeInterval) -> String {
        let total = Int(elapsed.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Writes transcript text to the general pasteboard. Safe to call from a nonactivating Island panel.
    @discardableResult
    func copyVoiceTranscriptToPasteboard(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // Prefer writeObjects — more reliable from non-key / nonactivating panels than setString alone.
        let wroteObjects = pasteboard.writeObjects([trimmed as NSString])
        if !wroteObjects {
            pasteboard.declareTypes([.string], owner: nil)
            return pasteboard.setString(trimmed, forType: .string)
        }
        return true
    }

    private func resetVoiceCaptureTimer() {
        voiceCaptureStartedAt = nil
        voiceCapturePausedAccumulated = 0
        voiceCapturePauseStartedAt = nil
    }

    private func beginVoiceCaptureTimer() {
        voiceCaptureStartedAt = Date()
        voiceCapturePausedAccumulated = 0
        voiceCapturePauseStartedAt = nil
    }

    func confirmAddVoiceClipping() {
        guard let confirmation = pendingVoiceClippingConfirmation else { return }
        pendingVoiceClippingConfirmation = nil
        handleCompletedVoiceTranscript(confirmation.transcript, target: confirmation.target, source: .navigationConfirmation)
    }

    func discardVoiceClipping() {
        pendingVoiceClippingConfirmation = nil
        if restorePendingVoiceAppendDraftIfNeeded(statusText: "Voice clipping discarded — previous transcript kept") {
            return
        }
        status = "Voice clipping discarded"
    }

    func confirmPendingVoiceTranscript(dismissAfterInsert: Bool = true) {
        guard let draft = pendingVoiceTranscriptDraft, !isEnhancingVoiceTranscript else { return }
        voiceEnhanceTask?.cancel()
        voiceEnhanceTask = nil
        isEnhancingVoiceTranscript = false
        pendingVoiceAppendContext = nil
        if dismissAfterInsert {
            // Clear editor drafts first so the composer layout settles before disk writes.
            pendingVoiceTranscriptDraft = nil
            voiceCaptureDestinationTitle = nil
        }
        insertVoiceTranscript(draft)
    }

    func discardPendingVoiceTranscript() {
        voiceEnhanceTask?.cancel()
        voiceEnhanceTask = nil
        isEnhancingVoiceTranscript = false
        pendingVoiceAppendContext = nil
        pendingVoiceTranscriptDraft = nil
        voiceCaptureDestinationTitle = nil
        status = "Voice transcript discarded"
    }

    /// Compact path for voice review chrome: `Vault > Folder > Note` (folder omitted when none).
    func voiceTranscriptBreadcrumb(noteID: Note.ID?, noteTitle: String) -> String {
        voiceTranscriptBreadcrumb(
            for: VoiceTranscriptDraft(
                target: .editor,
                text: "",
                noteID: noteID,
                noteTitle: noteTitle
            )
        )
    }

    func voiceTranscriptBreadcrumb(for draft: VoiceTranscriptDraft) -> String {
        voiceTranscriptBreadcrumbSegments(for: draft)
            .map(\.title)
            .joined(separator: " > ")
    }

    func voiceTranscriptBreadcrumbSegments(for draft: VoiceTranscriptDraft) -> [VoiceTranscriptBreadcrumbSegment] {
        var segments: [String] = [voiceTranscriptVaultLabel]
        switch draft.destinationKind {
        case .note:
            if let folderLabel = voiceTranscriptFolderLabel(noteID: draft.noteID) {
                segments.append(folderLabel)
            }
            let cleanedTitle = draft.noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            segments.append(cleanedTitle.isEmpty ? displayTitle(for: title) : cleanedTitle)
        case .folder:
            let cleanedTitle = draft.noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            segments.append(cleanedTitle.isEmpty ? "Notes" : cleanedTitle)
        }
        return segments.enumerated().map { index, title in
            VoiceTranscriptBreadcrumbSegment(
                id: index,
                title: title,
                isDestinationPicker: index > 0
            )
        }
    }

    func voiceTranscriptDestinations() -> [VoiceTranscriptDestination] {
        let vaultLabel = voiceTranscriptVaultLabel
        // Notes only — folders are not offered as insert destinations.
        var destinations: [VoiceTranscriptDestination] = []
        var seenNoteIDs = Set<Note.ID>()

        for item in sidebarItems {
            guard item.kind == .note,
                  let noteID = item.noteID,
                  !seenNoteIDs.contains(noteID)
            else { continue }
            seenNoteIDs.insert(noteID)
            let noteTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanTitle = noteTitle.isEmpty ? "Untitled" : noteTitle
            let breadcrumb: String
            if let folderLabel = voiceTranscriptFolderLabel(noteID: noteID) {
                breadcrumb = "\(vaultLabel) > \(folderLabel) > \(cleanTitle)"
            } else {
                breadcrumb = "\(vaultLabel) > \(cleanTitle)"
            }
            destinations.append(
                VoiceTranscriptDestination(
                    id: "note-\(noteID)",
                    kind: .note,
                    noteID: noteID,
                    groupID: nil,
                    title: cleanTitle,
                    breadcrumb: breadcrumb
                )
            )
        }

        for note in notes where !seenNoteIDs.contains(note.id) {
            let noteTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanTitle = noteTitle.isEmpty ? "Untitled" : noteTitle
            destinations.append(
                VoiceTranscriptDestination(
                    id: "note-\(note.id)",
                    kind: .note,
                    noteID: note.id,
                    groupID: nil,
                    title: cleanTitle,
                    breadcrumb: "\(vaultLabel) > \(cleanTitle)"
                )
            )
        }

        return destinations
    }

    func selectPendingVoiceTranscriptDestination(_ destination: VoiceTranscriptDestination) {
        guard var draft = pendingVoiceTranscriptDraft, draft.target == .editor else { return }
        guard destination.kind == .note else { return }
        draft.destinationKind = .note
        draft.noteID = destination.noteID
        draft.noteTitle = destination.title
        draft.destinationGroupID = nil
        pendingVoiceTranscriptDraft = draft
        status = "Voice destination set to \(destination.title)"
    }

    private var voiceTranscriptVaultLabel: String {
        let vault = activeBrain?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (vault?.isEmpty == false) ? vault! : "Brain"
    }

    private func voiceTranscriptFolderLabel(noteID: Note.ID?) -> String? {
        guard let noteID,
              let groupID = sidebarItems.first(where: { $0.kind == .note && $0.noteID == noteID })?.groupID,
              let group = sidebarItems.first(where: { $0.kind == .group && $0.id == groupID })
        else { return nil }
        let title = group.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    func enhancePendingVoiceTranscript() {
        guard let draft = pendingVoiceTranscriptDraft, !isEnhancingVoiceTranscript else { return }
        let sourceText = Self.normalizedVoiceTranscript(draft.text)
        guard !sourceText.isEmpty else { return }

        isEnhancingVoiceTranscript = true
        status = "\(selectedAssistantModel.title) is refining transcript"

        voiceEnhanceTask?.cancel()
        voiceEnhanceTask = Task { @MainActor in
            defer {
                isEnhancingVoiceTranscript = false
                voiceEnhanceTask = nil
            }
            do {
                let result = try await generateWithSelectedAssistantModel(
                    system: Self.voiceTranscriptRefineInstructions,
                    user: sourceText,
                    maxTokens: 4_096
                )
                guard !Task.isCancelled else { return }
                let refined = Self.normalizedVoiceTranscript(cleanedAssistantMarkdown(result.content))
                guard !refined.isEmpty else {
                    status = "Refine produced no text"
                    return
                }
                guard var updated = pendingVoiceTranscriptDraft else { return }
                // Drop any redo branch, then push the refined text as a new revision.
                if updated.revisionIndex < updated.revisionHistory.count - 1 {
                    updated.revisionHistory = Array(updated.revisionHistory.prefix(updated.revisionIndex + 1))
                }
                updated.revisionHistory.append(refined)
                updated.revisionIndex = updated.revisionHistory.count - 1
                updated.text = refined
                pendingVoiceTranscriptDraft = updated
                status = "Voice transcript refined"
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                status = "Refine failed: \(error.localizedDescription)"
            }
        }
    }

    func undoPendingVoiceTranscriptRevision() {
        guard var draft = pendingVoiceTranscriptDraft,
              !isEnhancingVoiceTranscript,
              draft.canUndoRevision
        else { return }
        draft.revisionIndex -= 1
        draft.text = draft.revisionHistory[draft.revisionIndex]
        pendingVoiceTranscriptDraft = draft
        status = "Restored revision \(draft.revisionCounterLabel)"
    }

    func redoPendingVoiceTranscriptRevision() {
        guard var draft = pendingVoiceTranscriptDraft,
              !isEnhancingVoiceTranscript,
              draft.canRedoRevision
        else { return }
        draft.revisionIndex += 1
        draft.text = draft.revisionHistory[draft.revisionIndex]
        pendingVoiceTranscriptDraft = draft
        status = "Restored revision \(draft.revisionCounterLabel)"
    }

    private static let voiceTranscriptRefineInstructions = """
    You refine voice transcriptions for a markdown notes app.
    Clean up filler words, fix obvious ASR mistakes, and improve punctuation and readability.
    Preserve the speaker's meaning, tone, and level of detail.
    Do not add headings, bullet lists, markdown fencing, labels, or commentary.
    Return only the refined transcript as plain prose.
    """

    private enum VoiceTranscriptCompletionSource {
        case manualStop
        case navigationConfirmation
    }

    private struct PendingVoiceAppendContext {
        let draft: VoiceTranscriptDraft
        var baseText: String { draft.text }
    }

    private func startNativeSpeechTranscription(target: VoiceCaptureTarget, source: VoiceAudioSource) async throws {
        let authorizationStatus = await VoiceTranscriptionController.requestSpeechAuthorization()
        guard authorizationStatus == .authorized else {
            throw VoiceTranscriptionError.speechRecognitionNotAuthorized
        }

        let controller = VoiceTranscriptionController(
            source: source,
            onTranscript: { [weak self] transcript in
                Task { @MainActor in
                    self?.liveVoiceTranscript = transcript
                }
            },
            onUserSpeechActivityChanged: { [weak self] isLikelyUserSpeech in
                Task { @MainActor in
                    self?.isVoiceInputLikelyUserSpeech = isLikelyUserSpeech
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.status = "Voice transcription failed: \(error.localizedDescription)"
                }
            },
            onProgress: { [weak self] value in
                Task { @MainActor in
                    guard let self, self.isFinalizingVoiceTranscript else { return }
                    // Real decode progress dominates the warm-up crawl; stay monotonic.
                    self.voiceTranscriptionProgress = min(1.0, max(self.voiceTranscriptionProgress, value))
                }
            }
        )
        try await controller.start()
        voiceTranscriptionController = controller
        activeVoiceCaptureTarget = target
        activeVoiceAudioSource = source
        beginVoiceCaptureTimer()
        if target == .editor {
            activeVoiceEditorNoteID = currentNoteID
            let noteTitle = displayTitle(for: title)
            activeVoiceEditorNoteTitle = noteTitle
            voiceCaptureDestinationTitle = noteTitle
        } else {
            activeVoiceEditorNoteID = nil
            activeVoiceEditorNoteTitle = nil
            voiceCaptureDestinationTitle = nil
        }
        pendingVoiceAudioSourceSelection = nil
        isVoiceCapturePaused = false
        isFinalizingVoiceTranscript = false
        voiceTranscriptionProgress = 0
        liveVoiceTranscript = ""
        voiceTranscriptionNotice = nil
        isVoiceInputLikelyUserSpeech = false
        switch (target, source) {
        case (.editor, .microphone):
            status = "Listening to microphone in \(voiceCaptureDestinationTitle ?? "note")"
        case (.editor, .systemAudio):
            status = "Listening to on-screen audio in \(voiceCaptureDestinationTitle ?? "note")"
        case (.helpDesk, .microphone):
            status = "Listening to microphone in Zirn Chat"
        case (.helpDesk, .systemAudio):
            status = "Listening to on-screen audio in Zirn Chat"
        }
    }

    private func startVoiceTranscriptionProgress() {
        voiceTranscriptionProgressTask?.cancel()
        voiceTranscriptionProgressTask = Task { @MainActor in
            // Gentle warm-up ONLY — never fake past ~12%. Real whisper-cli progress
            // (routed through the controller's onProgress) takes over via max() the moment
            // decoding starts, so the number reflects actual transcription instead of
            // asymptoting to 95% and freezing.
            var tick = 0
            while !Task.isCancelled, isFinalizingVoiceTranscript {
                try? await Task.sleep(nanoseconds: 250_000_000)
                tick += 1
                let warmup = min(0.12, 0.06 + Double(tick) * 0.012)
                voiceTranscriptionProgress = max(voiceTranscriptionProgress, warmup)
            }
        }
    }

    private func currentVoiceTranscript() -> String {
        let controllerTranscript = voiceTranscriptionController?.transcript ?? ""
        let liveTranscript = liveVoiceTranscript
        return Self.normalizedVoiceTranscript(controllerTranscript.isEmpty ? liveTranscript : controllerTranscript)
    }

    private func handleCompletedVoiceTranscript(
        _ transcript: String,
        target: VoiceCaptureTarget,
        source: VoiceTranscriptCompletionSource
    ) {
        let cleanTranscript = Self.normalizedVoiceTranscript(transcript)
        guard !cleanTranscript.isEmpty else {
            if restorePendingVoiceAppendDraftIfNeeded(statusText: "No audio — previous transcript kept") {
                voiceTranscriptionNotice = "No audio"
                return
            }
            voiceTranscriptionNotice = "No audio"
            status = "No audio"
            return
        }

        voiceTranscriptionNotice = nil

        if let appendContext = pendingVoiceAppendContext, appendContext.draft.target == target {
            pendingVoiceAppendContext = nil
            activeVoiceEditorNoteID = nil
            activeVoiceEditorNoteTitle = nil
            var draft = appendContext.draft
            let combined = Self.concatenatedVoiceTranscript(
                base: appendContext.baseText,
                addition: cleanTranscript
            )
            if draft.revisionIndex < draft.revisionHistory.count - 1 {
                draft.revisionHistory = Array(draft.revisionHistory.prefix(draft.revisionIndex + 1))
            }
            draft.revisionHistory.append(combined)
            draft.revisionIndex = draft.revisionHistory.count - 1
            draft.text = combined
            pendingVoiceTranscriptDraft = draft
            status = "Voice transcript appended"
            return
        }

        switch target {
        case .editor:
            pendingVoiceTranscriptDraft = VoiceTranscriptDraft(
                target: target,
                text: cleanTranscript,
                noteID: activeVoiceEditorNoteID ?? currentNoteID,
                noteTitle: activeVoiceEditorNoteTitle ?? displayTitle(for: title)
            )
            activeVoiceEditorNoteID = nil
            activeVoiceEditorNoteTitle = nil
            status = source == .navigationConfirmation
                ? "Voice clipping ready to add"
                : "Voice transcript ready"
        case .helpDesk:
            helpDeskInput = cleanTranscript
            status = "Sending voice message to Zirn Chat"
            submitHelpDeskPrompt()
        }
    }

    private func insertVoiceTranscript(_ draft: VoiceTranscriptDraft) {
        let cleanTranscript = Self.normalizedVoiceTranscript(draft.text)
        guard !cleanTranscript.isEmpty else {
            status = "Voice transcript is empty"
            return
        }

        let revisionCount = max(draft.revisionHistory.count, 1)
        switch draft.target {
        case .editor:
            switch draft.destinationKind {
            case .note:
                insertVoiceTranscript(
                    cleanTranscript,
                    noteID: draft.noteID,
                    noteTitle: draft.noteTitle,
                    revisionCount: revisionCount
                )
            case .folder:
                insertVoiceTranscript(
                    cleanTranscript,
                    groupID: draft.destinationGroupID,
                    folderTitle: draft.noteTitle,
                    revisionCount: revisionCount
                )
            }
        case .helpDesk:
            helpDeskInput = cleanTranscript
            submitHelpDeskPrompt()
        }
    }

    private func insertVoiceTranscript(
        _ transcript: String,
        groupID: SidebarItem.ID?,
        folderTitle: String,
        revisionCount: Int
    ) {
        withActiveBrainAccess {
            do {
                guard let brain = activeBrain else {
                    let insertion = Self.markdownByAppendingTranscript(transcript, to: content)
                    updateContentFromEditor(insertion.markdown)
                    saveCurrentNote(statusText: "Voice transcript added")
                    if let noteID = currentNoteID {
                        recordVoiceConversationEntry(
                            transcript: transcript,
                            revisionCount: revisionCount,
                            noteID: noteID,
                            noteTitle: title,
                            notePath: nil,
                            characterStart: insertion.characterStart,
                            characterEnd: insertion.characterEnd
                        )
                    }
                    return
                }

                let now = Date()
                let noteTitle = uniqueTitle(for: "Voice Transcript")
                let noteBody = contentBySettingDocumentTitle(noteTitle, in: transcript)
                let note = Note(
                    id: UUID().uuidString,
                    title: noteTitle,
                    content: noteBody,
                    createdAt: now,
                    updatedAt: now
                )

                let destinationFolder: URL
                if let groupID, let group = sidebarGroup(for: groupID) {
                    destinationFolder = sidebarGroupFolderURL(for: group, in: brain)
                } else {
                    destinationFolder = notesFolderURL(for: brain)
                }
                try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                let targetURL = markdownNoteURL(for: note, inFolder: destinationFolder)
                try writeMarkdownNote(note, to: targetURL)
                let relativePath = relativeNoteFileName(for: targetURL, in: brain)
                try noteIdentityDatabase?.upsert(
                    noteID: note.id,
                    title: note.title,
                    fileName: relativePath,
                    updatedAt: note.updatedAt
                )

                let summary = NoteSummary(id: note.id, title: note.title, updatedAt: note.updatedAt)
                sidebarItems.append(SidebarItem(note: summary, groupID: groupID))
                try persistSidebarLayoutNoAccess()
                try loadNotes()
                try syncBrainMetadata()
                scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds)
                markUnreadVoiceInsert(for: note.id)

                let transcriptStart = max(0, noteBody.utf16.count - transcript.utf16.count - 1)
                recordVoiceConversationEntry(
                    transcript: transcript,
                    revisionCount: revisionCount,
                    noteID: note.id,
                    noteTitle: note.title,
                    notePath: relativePath,
                    characterStart: transcriptStart,
                    characterEnd: transcriptStart + transcript.utf16.count
                )

                let cleanFolderTitle = folderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                status = "Voice transcript added to \(cleanFolderTitle.isEmpty ? "Notes" : cleanFolderTitle)"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func insertVoiceTranscript(
        _ transcript: String,
        noteID: Note.ID?,
        noteTitle: String,
        revisionCount: Int
    ) {
        guard let noteID, noteID != currentNoteID else {
            let insertion = Self.markdownByAppendingTranscript(transcript, to: content)
            updateContentFromEditor(insertion.markdown)
            saveCurrentNote(statusText: "Voice transcript added")
            let resolvedNoteID = noteID ?? currentNoteID
            if let resolvedNoteID {
                let path = activeBrain.flatMap { brain in
                    noteURL(for: resolvedNoteID, in: brain).map { relativeNoteFileName(for: $0, in: brain) }
                }
                recordVoiceConversationEntry(
                    transcript: transcript,
                    revisionCount: revisionCount,
                    noteID: resolvedNoteID,
                    noteTitle: noteTitle.isEmpty ? title : noteTitle,
                    notePath: path,
                    characterStart: insertion.characterStart,
                    characterEnd: insertion.characterEnd
                )
            }
            return
        }

        withActiveBrainAccess {
            do {
                guard let brain = activeBrain,
                      let url = noteURL(for: noteID, in: brain)
                else {
                    let insertion = Self.markdownByAppendingTranscript(transcript, to: content)
                    updateContentFromEditor(insertion.markdown)
                    saveCurrentNote(statusText: "Voice transcript added")
                    if let currentNoteID {
                        recordVoiceConversationEntry(
                            transcript: transcript,
                            revisionCount: revisionCount,
                            noteID: currentNoteID,
                            noteTitle: title,
                            notePath: nil,
                            characterStart: insertion.characterStart,
                            characterEnd: insertion.characterEnd
                        )
                    }
                    return
                }

                var note = try readNote(from: url)
                let insertion = Self.markdownByAppendingTranscript(transcript, to: note.content)
                note = Note(
                    id: note.id,
                    title: note.title,
                    content: insertion.markdown,
                    createdAt: note.createdAt,
                    updatedAt: Date()
                )
                try writeMarkdownNote(note, to: url)
                let relativePath = relativeNoteFileName(for: url, in: brain)
                try noteIdentityDatabase?.upsert(
                    noteID: note.id,
                    title: note.title,
                    fileName: relativePath,
                    updatedAt: note.updatedAt
                )
                try loadNotes()
                try syncBrainMetadata()
                scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds)
                markUnreadVoiceInsert(for: note.id)
                recordVoiceConversationEntry(
                    transcript: transcript,
                    revisionCount: revisionCount,
                    noteID: note.id,
                    noteTitle: noteTitle.isEmpty ? note.title : noteTitle,
                    notePath: relativePath,
                    characterStart: insertion.characterStart,
                    characterEnd: insertion.characterEnd
                )
                let cleanTitle = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                status = "Voice transcript added to \(cleanTitle.isEmpty ? note.title : cleanTitle)"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func markUnreadVoiceInsert(for noteID: Note.ID) {
        guard noteID != currentNoteID else { return }
        unreadVoiceInsertNoteIDs.insert(noteID)
    }

    private func clearUnreadVoiceInsert(for noteID: Note.ID) {
        unreadVoiceInsertNoteIDs.remove(noteID)
    }

    /// Compact recent voice history for writing assistant / Zirn chat context. Callers opt in; not injected by default.
    func loadVoiceHistoryContext(limit: Int = 6, maxCharacters: Int = 2_400) -> String {
        let entries = recentVoiceConversationEntries(limit: limit)
        guard !entries.isEmpty else { return "" }

        var remaining = max(400, maxCharacters)
        var lines: [String] = ["Recent voice inserts (from .convo):"]
        for entry in entries {
            let stamp = Self.voiceHistoryTimestampFormatter.string(from: entry.createdAt)
            let snippet = String(entry.transcript.prefix(280))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let line = "- \(stamp) · \(entry.revisionCount) rev · \(entry.noteTitle): \(snippet)"
            if line.count > remaining { break }
            lines.append(line)
            remaining -= line.count + 1
        }
        return lines.joined(separator: "\n")
    }

    func recentVoiceConversationEntries(limit: Int = 2) -> [VoiceConversationEntry] {
        Array(voiceConversationHistory.prefix(max(0, limit)))
    }

    func openVoiceConversationEntry(_ entry: VoiceConversationEntry) {
        openNote(id: entry.noteID)
        let query = Self.voiceHistorySearchQuery(from: entry.transcript)
        guard !query.isEmpty else { return }
        let normalizedQuery = normalizedSearchText(query)
        let blockIndex = markdownSearchBlocks(from: content)
            .first { block in
                normalizedSearchText(block.text).contains(normalizedQuery)
            }?
            .index ?? 0
        activeSearchHighlight = SearchHighlight(
            noteID: entry.noteID,
            query: query,
            blockIndex: blockIndex
        )
    }

    private func recordVoiceConversationEntry(
        transcript: String,
        revisionCount: Int,
        noteID: Note.ID,
        noteTitle: String,
        notePath: String?,
        characterStart: Int?,
        characterEnd: Int?
    ) {
        let resolved = resolveVoiceDestinationPresentation(
            noteID: noteID,
            fallbackTitle: noteTitle,
            notePath: notePath
        )
        let entry = VoiceConversationEntry(
            id: UUID().uuidString,
            createdAt: Date(),
            revisionCount: max(revisionCount, 1),
            transcript: transcript,
            noteID: noteID,
            noteTitle: resolved.title,
            notePath: resolved.path,
            characterStart: characterStart,
            characterEnd: characterEnd,
            shortTitle: VoiceConversationEntry.fallbackShortTitle(from: transcript)
        )
        voiceConversationHistory.insert(entry, at: 0)
        persistVoiceConversationHistory()
        scheduleVoiceHistoryShortTitleGeneration(for: entry.id)
    }

    /// Resolve a human note title + relative path from live vault state (avoids Untitled.md chips).
    private func resolveVoiceDestinationPresentation(
        noteID: Note.ID,
        fallbackTitle: String,
        notePath: String?
    ) -> (title: String, path: String?) {
        let liveTitle = notes.first(where: { $0.id == noteID })?.title
            ?? sidebarItems.first(where: { $0.noteID == noteID })?.title
            ?? (noteID == currentNoteID ? title : nil)

        let resolvedPath: String? = {
            if let notePath, !notePath.isEmpty { return notePath }
            guard let brain = activeBrain,
                  let url = noteURL(for: noteID, in: brain)
            else { return nil }
            return relativeNoteFileName(for: url, in: brain)
        }()

        let pathBaseTitle: String? = {
            guard let resolvedPath, !resolvedPath.isEmpty else { return nil }
            let fileName = (resolvedPath as NSString).lastPathComponent
            let base = (fileName as NSString).deletingPathExtension
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !base.isEmpty, base.caseInsensitiveCompare("Untitled") != .orderedSame else {
                return nil
            }
            return base
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
        }()

        let candidates = [liveTitle, pathBaseTitle, fallbackTitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let preferred = candidates.first {
            $0.caseInsensitiveCompare("Untitled") != .orderedSame
        } ?? candidates.first ?? "Untitled"

        return (preferred, resolvedPath)
    }

    private func scheduleVoiceHistoryShortTitleGeneration(for entryID: String) {
        voiceHistoryShortTitleTask?.cancel()
        voiceHistoryShortTitleTask = Task { @MainActor [weak self] in
            // Small delay so insert UI settles before the network call.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.ensureVoiceHistoryShortTitles(preferring: entryID)
        }
    }

    /// Fills missing / legacy 3-letter titles with 3-word titles (AI when possible, word fallback). Persists into `.convo`.
    func ensureVoiceHistoryShortTitles(preferring preferredID: String? = nil) async {
        var didChange = false
        let targets: [VoiceConversationEntry] = {
            let missing = voiceConversationHistory.filter {
                VoiceConversationEntry.needsShortTitleRefresh($0.shortTitle)
            }
            if let preferredID,
               let preferred = voiceConversationHistory.first(where: { $0.id == preferredID }) {
                return [preferred] + missing.filter { $0.id != preferredID }
            }
            return missing
        }()

        for entry in targets.prefix(8) {
            guard !Task.isCancelled else { return }
            let generated = await generateVoiceHistoryShortTitle(from: entry.transcript)
                ?? VoiceConversationEntry.fallbackShortTitle(from: entry.transcript)
            guard let index = voiceConversationHistory.firstIndex(where: { $0.id == entry.id }) else {
                continue
            }
            if voiceConversationHistory[index].shortTitle == generated { continue }
            voiceConversationHistory[index].shortTitle = generated
            didChange = true
        }

        if didChange {
            persistVoiceConversationHistory()
        }
    }

    private func generateVoiceHistoryShortTitle(from transcript: String) async -> String? {
        let snippet = String(transcript.prefix(480))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return nil }

        do {
            let result = try await generateWithSelectedAssistantModel(
                system: """
                You invent compact 3-word titles for voice notes.
                Reply with EXACTLY three English words separated by single spaces and nothing else.
                Use Title Case. No punctuation, digits, quotes, or explanation.
                The three words should summarize the transcript topic (example style: Debt Service Plan).
                """,
                user: snippet,
                maxTokens: 24
            )
            let words = result.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .components(separatedBy: .whitespaces)
                .map { word in
                    word.filter { $0.isLetter || $0.isNumber }
                }
                .filter { !$0.isEmpty }
            guard words.count >= 3 else { return nil }
            let titled = words.prefix(3).map { word -> String in
                let lower = word.lowercased()
                guard let first = lower.first else { return word }
                return String(first).uppercased() + lower.dropFirst()
            }
            return titled.joined(separator: " ")
        } catch {
            return nil
        }
    }

    private func loadVoiceConversationHistory() throws {
        guard let activeBrain else {
            voiceConversationHistory = []
            return
        }
        let url = voiceConversationURL(for: activeBrain)
        guard FileManager.default.fileExists(atPath: url.path) else {
            voiceConversationHistory = []
            return
        }
        let data = try Data(contentsOf: url)
        let file = try decoder.decode(VoiceConversationFile.self, from: data)
        voiceConversationHistory = file.entries.sorted { $0.createdAt > $1.createdAt }

        // Backfill missing / legacy letter titles once per vault open (persisted after generation).
        if voiceConversationHistory.contains(where: {
            VoiceConversationEntry.needsShortTitleRefresh($0.shortTitle)
        }) {
            Task { @MainActor [weak self] in
                await self?.ensureVoiceHistoryShortTitles()
            }
        }
    }

    private func persistVoiceConversationHistory() {
        withActiveBrainAccess {
            do {
                guard let activeBrain else { return }
                let url = voiceConversationURL(for: activeBrain)
                let file = VoiceConversationFile(
                    version: VoiceConversationFile.currentVersion,
                    vaultID: activeBrain.id,
                    brainFileName: activeBrain.brainURL.lastPathComponent,
                    entries: voiceConversationHistory
                )
                let data = try encoder.encode(file)
                try data.write(to: url, options: .atomic)
            } catch {
                status = "Could not save voice history: \(error.localizedDescription)"
            }
        }
    }

    private func voiceConversationURL(for brain: BrainSummary) -> URL {
        brain.folderURL.appendingPathComponent(".convo")
    }

    private static func voiceHistorySearchQuery(from transcript: String) -> String {
        let words = transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return "" }
        return words.prefix(12).joined(separator: " ")
    }

    private static let voiceHistoryTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func markdownByAppendingTranscript(
        _ transcript: String,
        to markdown: String
    ) -> (markdown: String, characterStart: Int, characterEnd: Int) {
        let separator: String
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            separator = ""
        } else if markdown.hasSuffix("\n\n") {
            separator = ""
        } else if markdown.hasSuffix("\n") {
            separator = "\n"
        } else {
            separator = "\n\n"
        }
        let prefix = markdown + separator
        let characterStart = prefix.utf16.count
        let characterEnd = characterStart + transcript.utf16.count
        return (prefix + transcript + "\n", characterStart, characterEnd)
    }

    private static func normalizedVoiceTranscript(_ transcript: String) -> String {
        transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func concatenatedVoiceTranscript(base: String, addition: String) -> String {
        let baseClean = normalizedVoiceTranscript(base)
        let additionClean = normalizedVoiceTranscript(addition)
        if baseClean.isEmpty { return additionClean }
        if additionClean.isEmpty { return baseClean }
        return baseClean + " " + additionClean
    }

    func ensureWhisperSmallModelInstalledForCurrentUser(reportReadyStatus: Bool = true) async {
        if case .ready = whisperSmallModelInstallState {
            return
        }

        if let installTask = whisperSmallModelInstallTask {
            if reportReadyStatus {
                status = "Installing local Whisper small model"
            }
            do {
                let modelURL = try await installTask.value
                whisperSmallModelInstallState = .ready(modelURL.path)
                if reportReadyStatus {
                    status = "Local Whisper small model ready"
                }
            } catch {
                let message = error.localizedDescription
                whisperSmallModelInstallState = .failed(message)
                status = "Whisper small install failed: \(message)"
            }
            return
        }

        whisperSmallModelInstallState = .checking
        if reportReadyStatus {
            status = "Checking local Whisper small model"
        }

        do {
            whisperSmallModelInstallState = .installing
            if reportReadyStatus {
                status = "Installing local Whisper small model"
            }

            let installTask = Task {
                try await WhisperSmallModelInstaller.ensureInstalled()
            }
            whisperSmallModelInstallTask = installTask
            let modelURL = try await installTask.value
            whisperSmallModelInstallTask = nil
            whisperSmallModelInstallState = .ready(modelURL.path)
            if reportReadyStatus {
                status = "Local Whisper small model ready"
            }
        } catch {
            whisperSmallModelInstallTask = nil
            let message = error.localizedDescription
            whisperSmallModelInstallState = .failed(message)
            status = "Whisper small install failed: \(message)"
        }
    }

    func exitAssistantConversation() {
        assistantConversationResponse = nil
        assistantConversationMemory.clear()
        status = "Conversation closed"
    }

    func addAssistantConversationResponseToCurrentNote() {
        guard let response = assistantConversationResponse,
              !isGeneratingAssistantResponse
        else { return }

        isGeneratingAssistantResponse = true
        assistantGenerationPhase = .requesting
        isUsingWebSearch = false
        status = "\(response.providerTitle) is adding the answer to the page"

        assistantGenerationTask?.cancel()
        assistantGenerationTask = Task {
            await generateAssistantConversationInsertion(from: response)
        }
    }

    func acceptAssistantPreview() {
        guard let preview = pendingAssistantPreview else { return }
        applyAssistantDocumentOutput(preview.markdown, prompt: preview.prompt)
        try? updateStyleMemory(with: content)
        pendingAssistantPreview = nil
        status = "\(preview.providerTitle) inserted Markdown"
    }

    func rejectAssistantPreview() {
        guard let preview = pendingAssistantPreview else { return }
        pendingAssistantPreview = nil
        status = "\(preview.providerTitle) output rejected"
    }

    func saveVault() {
        withActiveBrainAccess {
            do {
                try syncBrainMetadata()
                status = "Vault saved"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func deleteCurrentNote() {
        guard let id = currentNoteID else { return }
        deleteNote(id: id)
    }

    func deleteSelectedNote() {
        guard let id = selectedNoteID ?? currentNoteID else { return }
        deleteNote(id: id)
    }

    func deleteSelectedSidebarItem() {
        if let selectedSidebarGroupID {
            deleteSidebarGroup(id: selectedSidebarGroupID)
        } else {
            deleteSelectedNote()
        }
    }

    func deleteNote(id: Note.ID) {
        autosaveTask?.cancel()
        autosaveTask = nil
        withActiveBrainAccess {
            do {
                let deletedCurrentNote = currentNoteID == id
                clearUnreadVoiceInsert(for: id)
                try learnFromDeletionIfNeeded(noteID: id)
                if let noteURL = noteURL(for: id), FileManager.default.fileExists(atPath: noteURL.path) {
                    try FileManager.default.removeItem(at: noteURL)
                }
                try noteIdentityDatabase?.remove(noteID: id)
                try loadNotes()
                if deletedCurrentNote {
                    if let nextNote = notes.first,
                       let noteURL = noteURL(for: nextNote.id) {
                        let note = try readNote(from: noteURL)
                        currentNoteID = note.id
                        selectedNoteID = note.id
                        title = note.title
                        content = note.content
                    } else {
                        resetDraft()
                    }
                } else if selectedNoteID == id {
                    selectedNoteID = currentNoteID
                }
                try syncBrainMetadata()
                status = "Deleted"
                scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds, force: true)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func createSidebarGroup() {
        guard let activeBrain else {
            status = "Open or create a brain first"
            return
        }

        let group = SidebarItem(
            id: UUID().uuidString,
            kind: .group,
            noteID: nil,
            title: nextSidebarGroupTitle(),
            groupID: nil,
            isExpanded: true
        )
        if let selectedNoteID,
           let selectedIndex = sidebarItems.firstIndex(where: { $0.noteID == selectedNoteID }) {
            sidebarItems.insert(group, at: selectedIndex)
        } else {
            sidebarItems.append(group)
        }
        withSecurityScopedAccess(to: activeBrain.folderURL) {
            do {
                try FileManager.default.createDirectory(
                    at: sidebarGroupFolderURL(for: group, in: activeBrain),
                    withIntermediateDirectories: true
                )
                try persistSidebarLayoutNoAccess()
                status = "\(group.title) created"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func selectSidebarGroup(id: SidebarItem.ID) {
        guard sidebarItems.contains(where: { $0.id == id && $0.kind == .group }) else { return }
        selectedSidebarGroupID = id
        selectedNoteID = nil
    }

    func renameSidebarGroup(id: SidebarItem.ID, to title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              let activeBrain,
              let index = sidebarItems.firstIndex(where: { $0.id == id && $0.kind == .group })
        else { return }

        withSecurityScopedAccess(to: activeBrain.folderURL) {
            do {
                let oldGroup = sidebarItems[index]
                let oldFolderURL = sidebarGroupFolderURL(for: oldGroup, in: activeBrain)
                let requestedTitle = sanitizedSidebarGroupTitle(cleanTitle)
                let uniqueTitle = uniqueSidebarGroupTitle(requestedTitle, excluding: id)
                sidebarItems[index] = SidebarItem(
                    id: oldGroup.id,
                    kind: .group,
                    noteID: nil,
                    title: uniqueTitle,
                    groupID: nil,
                    isExpanded: oldGroup.isExpanded
                )
                let newFolderURL = sidebarGroupFolderURL(for: sidebarItems[index], in: activeBrain)
                try moveSidebarGroupFolder(from: oldFolderURL, to: newFolderURL)
                try moveNotesInGroupToFilesystem(groupID: id, in: activeBrain)
                try persistSidebarLayoutNoAccess()
                try loadNotes()
                status = uniqueTitle == requestedTitle ? "Group renamed" : "Group renamed to \(uniqueTitle)"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func deleteSidebarGroup(id: SidebarItem.ID) {
        guard let activeBrain,
              let groupIndex = sidebarItems.firstIndex(where: { $0.id == id && $0.kind == .group })
        else { return }
        let groupTitle = sidebarItems[groupIndex].title
        let childNoteIDs = sidebarItems
            .filter { $0.groupID == id && $0.kind == .note }
            .compactMap(\.noteID)

        let deletionChoice: SidebarGroupDeletionChoice
        if childNoteIDs.isEmpty {
            deletionChoice = .deleteGroupOnly
        } else {
            deletionChoice = confirmSidebarGroupDeletion(title: groupTitle, childCount: childNoteIDs.count)
        }

        guard deletionChoice != .dismiss else {
            status = "Group kept"
            return
        }

        withActiveBrainAccess {
            do {
                let deletedCurrentNote = currentNoteID.map { childNoteIDs.contains($0) } ?? false

                if deletionChoice == .deleteGroupAndPages {
                    for noteID in childNoteIDs {
                        try learnFromDeletionIfNeeded(noteID: noteID)
                        if let noteURL = noteURL(for: noteID), FileManager.default.fileExists(atPath: noteURL.path) {
                            try FileManager.default.removeItem(at: noteURL)
                        }
                        try noteIdentityDatabase?.remove(noteID: noteID)
                    }
                    sidebarItems.removeAll { item in
                        item.id == id || (item.groupID == id && item.noteID.map { childNoteIDs.contains($0) } == true)
                    }
                } else {
                    sidebarItems.remove(at: groupIndex)
                    for index in sidebarItems.indices where sidebarItems[index].groupID == id {
                        sidebarItems[index].groupID = nil
                    }
                    for noteID in childNoteIDs {
                        try moveNoteFile(noteID: noteID, toGroupID: nil, in: activeBrain)
                    }
                }

                try removeSidebarGroupFolderIfEmpty(title: groupTitle, in: activeBrain)

                if selectedSidebarGroupID == id {
                    selectedSidebarGroupID = nil
                }

                try persistSidebarLayoutNoAccess()
                try loadNotes()

                if deletedCurrentNote {
                    if let nextNote = notes.first,
                       let noteURL = noteURL(for: nextNote.id) {
                        let note = try readNote(from: noteURL)
                        currentNoteID = note.id
                        selectedNoteID = note.id
                        title = note.title
                        content = note.content
                    } else {
                        resetDraft()
                    }
                } else if let selectedNoteID, childNoteIDs.contains(selectedNoteID) {
                    self.selectedNoteID = currentNoteID
                }

                try syncBrainMetadata()
                status = deletionChoice == .deleteGroupAndPages ? "Group and pages deleted" : "Group deleted"
                if deletionChoice == .deleteGroupAndPages {
                    scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds, force: true)
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func toggleSidebarGroup(id: SidebarItem.ID) {
        guard let index = sidebarItems.firstIndex(where: { $0.id == id && $0.kind == .group }) else { return }
        sidebarItems[index].isExpanded.toggle()
        persistSidebarLayout()
    }

    func moveSidebarItem(id draggedID: SidebarItem.ID, before targetID: SidebarItem.ID) {
        guard draggedID != targetID,
              let activeBrain,
              let sourceIndex = sidebarItems.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = sidebarItems.firstIndex(where: { $0.id == targetID })
        else { return }

        let targetGroupID = sidebarItems[targetIndex].kind == .group ? nil : sidebarItems[targetIndex].groupID
        var item = sidebarItems.remove(at: sourceIndex)
        item.groupID = item.kind == .note ? targetGroupID : nil
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        sidebarItems.insert(item, at: adjustedTargetIndex)
        notes = orderedNotesForSidebar()
        persistSidebarLayoutAndFilesystem(for: item, in: activeBrain)
    }

    func moveSidebarItemToEnd(id draggedID: SidebarItem.ID) {
        guard let activeBrain,
              let sourceIndex = sidebarItems.firstIndex(where: { $0.id == draggedID })
        else { return }
        var item = sidebarItems.remove(at: sourceIndex)
        item.groupID = nil
        sidebarItems.append(item)
        notes = orderedNotesForSidebar()
        persistSidebarLayoutAndFilesystem(for: item, in: activeBrain)
    }

    func moveSidebarItem(id draggedID: SidebarItem.ID, intoGroup groupID: SidebarItem.ID) {
        guard draggedID != groupID,
              let activeBrain,
              let sourceIndex = sidebarItems.firstIndex(where: { $0.id == draggedID }),
              sidebarItems.contains(where: { $0.id == groupID && $0.kind == .group }),
              sidebarItems[sourceIndex].kind == .note
        else { return }

        var item = sidebarItems.remove(at: sourceIndex)
        item.groupID = groupID
        guard let currentGroupIndex = sidebarItems.firstIndex(where: { $0.id == groupID && $0.kind == .group }) else {
            sidebarItems.insert(item, at: sourceIndex)
            return
        }
        sidebarItems[currentGroupIndex].isExpanded = true

        let insertionIndex = sidebarItems.lastIndex(where: { $0.groupID == groupID }).map { $0 + 1 } ?? min(currentGroupIndex + 1, sidebarItems.endIndex)
        sidebarItems.insert(item, at: min(insertionIndex, sidebarItems.endIndex))
        notes = orderedNotesForSidebar()
        persistSidebarLayoutAndFilesystem(for: item, in: activeBrain)
    }

    func noteSummary(for id: Note.ID) -> NoteSummary? {
        notes.first { $0.id == id }
    }

    func visibleSidebarItems() -> [SidebarItem] {
        var output: [SidebarItem] = []
        for item in sidebarItems where item.groupID == nil {
            output.append(item)
            if item.kind == .group, item.isExpanded {
                output.append(contentsOf: sidebarItems.filter { $0.groupID == item.id })
            }
        }
        return output
    }

    func markdownRelevanceCandidates(excluding noteID: Note.ID?) -> [MarkdownRelevanceCandidate] {
        searchIndex
            .filter { entry in
                if let noteID {
                    return entry.noteID != noteID
                }
                return true
            }
            .sorted {
                if $0.rank != $1.rank {
                    return $0.rank < $1.rank
                }
                return $0.updatedAt > $1.updatedAt
            }
            .prefix(320)
            .map { entry in
                MarkdownRelevanceCandidate(
                    id: "\(entry.noteID)-\(entry.kind)-\(entry.blockIndex ?? -1)",
                    noteID: entry.noteID,
                    title: entry.title,
                    text: entry.displayText,
                    kind: entry.kind,
                    rank: entry.rank,
                    updatedAt: entry.updatedAt
                )
            }
    }

    private func scheduleAutosave() {
        guard activeBrain != nil else { return }
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.saveCurrentNote(statusText: "Autosaved")
            }
        }
    }

    func renameNoteFromUser(id: Note.ID) {
        let currentTitle = notes.first(where: { $0.id == id })?.title ?? "Untitled"
        guard let newTitle = requestText(
            title: "Rename Page",
            message: "Choose the title that appears in the sidebar.",
            placeholder: "Page title",
            initialValue: currentTitle
        ) else { return }

        renameNote(id: id, to: newTitle)
    }

    func showNoteNutshell(id: Note.ID) {
        guard let noteURL = noteURL(for: id) else { return }

        withActiveBrainAccess {
            do {
                let note = try readNote(from: noteURL)
                let plainText = plainText(fromMarkdown: note.content)
                let wordCount = plainText.split { $0.isWhitespace || $0.isNewline }.count
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short

                let preview = plainText.isEmpty
                    ? "No body text yet."
                    : String(plainText.prefix(240))

                let alert = NSAlert()
                alert.messageText = note.title
                alert.informativeText = """
                File: \(noteURL.lastPathComponent)
                Updated: \(formatter.string(from: note.updatedAt))
                Words: \(wordCount)

                \(preview)
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Done")
                alert.runModal()
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func renameNote(id: Note.ID, to newTitle: String) {
        let cleanTitle = uniqueTitle(for: newTitle, excluding: id)

        withActiveBrainAccess {
            do {
                guard let brain = activeBrain,
                      let oldURL = noteURL(for: id)
                else { return }

                let oldNote = try readNote(from: oldURL)
                let renamedNote = Note(
                    id: oldNote.id,
                    title: cleanTitle,
                    content: contentBySettingDocumentTitle(cleanTitle, in: oldNote.content),
                    createdAt: oldNote.createdAt,
                    updatedAt: Date()
                )
                let newURL = markdownNoteURL(for: renamedNote, in: brain, allowing: oldURL)

                try FileManager.default.createDirectory(
                    at: newURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try writeMarkdownNote(renamedNote, to: newURL)
                try noteIdentityDatabase?.upsert(
                    noteID: renamedNote.id,
                    title: renamedNote.title,
                    fileName: relativeNoteFileName(for: newURL, in: brain),
                    updatedAt: renamedNote.updatedAt
                )
                if oldURL != newURL, FileManager.default.fileExists(atPath: oldURL.path) {
                    try FileManager.default.removeItem(at: oldURL)
                }

                if currentNoteID == id {
                    title = renamedNote.title
                    content = renamedNote.content
                    selectedNoteID = id
                }

                try loadNotes()
                try syncBrainMetadata()
                recordRecentVault(
                    note: NoteSummary(
                        id: renamedNote.id,
                        title: renamedNote.title,
                        updatedAt: renamedNote.updatedAt
                    )
                )
                status = "Renamed"
                scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func searchNotes(matching query: String) -> [NoteSearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return notes.map {
                NoteSearchResult(
                    id: $0.id,
                    noteID: $0.id,
                    title: $0.title,
                    preview: "Recently updated",
                    query: "",
                    blockIndex: nil
                )
            }
        }

        let queryTokens = searchTokens(in: cleanQuery)
        guard !queryTokens.isEmpty else { return [] }

        let lexicalResults = searchIndex
            .filter { entry in
                queryTokens.allSatisfy { entry.normalizedText.contains($0) }
            }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(120)
            .enumerated()
            .map { offset, entry in
                NoteSearchResult(
                    id: "\(entry.noteID)-\(entry.kind)-\(entry.blockIndex ?? -1)-\(offset)",
                    noteID: entry.noteID,
                    title: entry.title,
                    preview: searchResultPreview(for: cleanQuery, tokens: queryTokens, in: entry.displayText),
                    query: cleanQuery,
                    blockIndex: entry.blockIndex
                )
            }

        guard let queryVector = semanticVector(for: cleanQuery) else {
            return Array(lexicalResults)
        }

        var seenResultKeys = Set(lexicalResults.map { "\($0.noteID)-\($0.blockIndex ?? -1)" })
        let semanticResults = semanticSearchIndex
            .compactMap { entry -> (SemanticSearchIndexEntry, Double)? in
                let similarity = cosineSimilarity(queryVector, entry.vector)
                guard similarity >= Self.semanticSearchMinimumSimilarity else { return nil }
                return (entry, similarity)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.updatedAt != rhs.0.updatedAt { return lhs.0.updatedAt > rhs.0.updatedAt }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }
            .compactMap { entry, _ -> NoteSearchResult? in
                let key = "\(entry.noteID)-\(entry.blockIndex ?? -1)"
                guard !seenResultKeys.contains(key) else { return nil }
                seenResultKeys.insert(key)
                return NoteSearchResult(
                    id: "\(entry.noteID)-semantic-\(entry.blockIndex ?? -1)",
                    noteID: entry.noteID,
                    title: entry.title,
                    preview: String(entry.displayText.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines),
                    query: cleanQuery,
                    blockIndex: entry.blockIndex
                )
            }

        return Array((lexicalResults + semanticResults).prefix(120))
    }

    func openSearchResult(_ result: NoteSearchResult) {
        openNote(id: result.noteID)
        if let blockIndex = result.blockIndex, !result.query.isEmpty {
            activeSearchHighlight = SearchHighlight(
                noteID: result.noteID,
                query: result.query,
                blockIndex: blockIndex
            )
        } else {
            activeSearchHighlight = nil
        }
    }

    func clearSearchHighlight() {
        activeSearchHighlight = nil
    }

    func attachPromptDocument(from url: URL) {
        attachDocument(from: url, target: .assistant)
    }

    func attachPromptImage(data: Data, suggestedFileName: String? = nil, storedFileURL: URL? = nil) {
        guard !mistralAPIKey.isEmpty || requestAndSaveMistralAPIKey(
            title: "Mistral API Key",
            message: "Mistral OCR needs your Mistral API key before reading this image."
        ) else {
            status = "Mistral API key required for OCR"
            return
        }

        let storedURL: URL
        do {
            if let storedFileURL {
                storedURL = storedFileURL
            } else {
                storedURL = try storeAttachmentDataInWorkspace(data, suggestedFileName: suggestedFileName, kind: .images)
            }
        } catch {
            status = error.localizedDescription
            return
        }

        let fileName = storedURL.lastPathComponent
        guard !exceedsMistralUploadLimit(byteCount: data.count) else {
            status = mistralUploadLimitStatusMessage(forFileName: fileName)
            return
        }

        let mimeType = imageMimeType(forFileName: fileName)
        status = "OCR reading \(fileName)"

        Task {
            do {
                let extractedText = try await extractImageTextWithMistralOCR(data: data, mimeType: mimeType)
                assistantAttachment = PromptAttachment(
                    fileName: fileName,
                    fileExtension: (fileName as NSString).pathExtension.lowercased(),
                    extractedText: extractedText,
                    storedFileURL: storedURL
                )
                status = "\(fileName) attached · OCRed"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func choosePromptAttachmentFromUser() {
        let panel = NSOpenPanel()
        panel.title = "Attach File"
        panel.message = "Choose a PDF, Word document, PowerPoint, or image."
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .pdf,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "ppt") ?? .data,
            UTType(filenameExtension: "pptx") ?? .data,
            .image
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        attachPromptDocument(from: url)
    }

    func attachHelpDeskDocument(from url: URL) {
        attachDocument(from: url, target: .helpDesk)
    }

    private func attachDocument(from url: URL, target: AttachmentTarget) {
        guard isSupportedPromptDocument(url) else {
            status = supportedAttachmentStatusMessage
            return
        }

        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let storedFileURL: URL
        do {
            storedFileURL = try copyAttachmentToWorkspace(from: url)
        } catch {
            status = error.localizedDescription
            return
        }

        switch url.pathExtension.lowercased() {
        case "pdf":
            setAttachment(
                PromptAttachment(
                    fileName: storedFileURL.lastPathComponent,
                    fileExtension: storedFileURL.pathExtension.lowercased(),
                    extractedText: extractedPromptDocumentText(from: url),
                    storedFileURL: storedFileURL
                ),
                for: target
            )
            status = "\(storedFileURL.lastPathComponent) attached"
            attachPDFWithMistralOCRIfAvailable(from: url, storedFileURL: storedFileURL, target: target)
        case "doc", "docx":
            let extractedText = extractedPromptDocumentText(from: url)
            setAttachment(
                PromptAttachment(
                    fileName: storedFileURL.lastPathComponent,
                    fileExtension: storedFileURL.pathExtension.lowercased(),
                    extractedText: extractedText,
                    storedFileURL: storedFileURL
                ),
                for: target
            )
            status = "\(storedFileURL.lastPathComponent) attached"
        case "ppt", "pptx":
            setAttachment(
                PromptAttachment(
                    fileName: storedFileURL.lastPathComponent,
                    fileExtension: storedFileURL.pathExtension.lowercased(),
                    extractedText: "",
                    storedFileURL: storedFileURL
                ),
                for: target
            )
            status = "\(storedFileURL.lastPathComponent) attached"
            attachDocumentWithMistralOCRIfAvailable(from: url, storedFileURL: storedFileURL, target: target)
        case let ext where Self.supportedImageAttachmentExtensions.contains(ext):
            guard let data = try? Data(contentsOf: url) else {
                status = "Could not read \(url.lastPathComponent)"
                return
            }

            let fileName = storedFileURL.lastPathComponent
            setAttachment(
                PromptAttachment(
                    fileName: fileName,
                    fileExtension: (fileName as NSString).pathExtension.lowercased(),
                    extractedText: "",
                    storedFileURL: storedFileURL
                ),
                for: target
            )
            status = "\(fileName) attached"
            attachImageWithMistralOCRIfAvailable(data: data, storedFileURL: storedFileURL, target: target)
        default:
            status = supportedAttachmentStatusMessage
        }
    }

    func insertMarkdownImage(from url: URL) {
        guard isSupportedImageFile(url) else {
            status = "Only image files can be inserted into the page"
            return
        }

        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            status = "Could not read \(url.lastPathComponent)"
            return
        }

        insertMarkdownImage(data: data, suggestedFileName: url.lastPathComponent)
    }

    func generateFormulaLatex(from description: String) async -> String? {
        let prompt = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return nil }

        do {
            let result = try await generateWithSelectedAssistantModel(
                system: formulaLatexInstructions(),
                user: prompt,
                maxTokens: 512
            )
            recordUsage(
                for: selectedAssistantModel,
                result: result,
                fallbackInputTokens: estimatedTokenCount(for: prompt),
                fallbackOutputTokens: estimatedTokenCount(for: result.content)
            )
            let latex = cleanedFormulaLatex(result.content)
            return latex.isEmpty ? nil : latex
        } catch {
            status = error.localizedDescription
            return nil
        }
    }

    func insertMarkdownImage(data: Data, suggestedFileName: String? = nil) {
        guard let activeBrain else {
            status = "Open or create a brain first"
            return
        }

        withSecurityScopedAccess(to: activeBrain.folderURL) {
            do {
                let imagesFolder = imagesFolderURL(for: activeBrain)
                try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true)

                let fileName = uniqueImageFileName(suggestedFileName: suggestedFileName, in: imagesFolder)
                let imageURL = imagesFolder.appendingPathComponent(fileName)
                try data.write(to: imageURL, options: .atomic)

                let imageMarkdown = "![\(imageAltText(from: fileName))](../Images/\(fileName))"
                appendMarkdownBlock(imageMarkdown)
                assistantAttachment = nil
                helpDeskAttachment = nil
                status = "\(fileName) inserted"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func markdownImageURL(for path: String) -> URL? {
        if let url = URL(string: path), url.scheme?.hasPrefix("http") == true {
            return url
        }

        guard let activeBrain else { return nil }
        return resolvedMarkdownImageURL(for: path, brain: activeBrain)
    }

    func markdownImageData(for path: String) -> Data? {
        guard let activeBrain else { return nil }

        var imageData: Data?
        withSecurityScopedAccess(to: activeBrain.folderURL) {
            guard let url = resolvedMarkdownImageURL(for: path, brain: activeBrain),
                  url.isFileURL
            else { return }

            imageData = try? Data(contentsOf: url)
        }

        return imageData
    }

    func openFilesFolder() {
        guard let activeBrain else {
            status = "Open or create a brain first"
            return
        }

        withSecurityScopedAccess(to: activeBrain.folderURL) {
            do {
                try createWorkspaceFileFolders(in: activeBrain)
                NSWorkspace.shared.open(filesFolderURL(for: activeBrain))
                status = "Opened Files folder"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func removePromptAttachment() {
        assistantAttachment = nil
        status = "Attachment removed"
    }

    func openRecentVault(_ recentVault: RecentVault) {
        if let folderURL = resolvedRecentFolderURL(for: recentVault) {
            withSecurityScopedAccess(to: folderURL) {
                openBrain(fileURL: folderURL, showsInvalidVaultAlert: true, restoring: recentVault)
            }
            return
        }

        requestAccessToRecentVault(recentVault)
    }

    private func openPreviousBrainOnLaunch() {
        guard activeBrain == nil,
              let recentVault = recentVaults.first,
              let folderURL = resolvedRecentFolderURL(for: recentVault)
        else { return }

        withSecurityScopedAccess(to: folderURL) {
            openBrain(fileURL: folderURL, restoring: recentVault)
        }
    }

    private func resolvedRecentFolderURL(for recentVault: RecentVault) -> URL? {
        guard let bookmarkData = recentVault.bookmarkData else {
            return nil
        }

        do {
            var isStale = false
            let folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return isStale ? nil : folderURL
        } catch {
            status = error.localizedDescription
            return nil
        }
    }

    private func requestAccessToRecentVault(_ recentVault: RecentVault) {
        removeRecentVault(for: URL(fileURLWithPath: recentVault.brainPath))
        status = "Open that vault once to add it back to Recents"
    }

    func renameBrainFromUser() {
        guard let activeBrain else {
            status = "Open or create a brain first"
            return
        }

        guard let name = requestText(
            title: "Rename Brain",
            message: "Choose a new name for this brain.",
            placeholder: "Brain name",
            initialValue: activeBrain.name
        ) else { return }

        renameBrain(to: name)
    }

    func showBrainInfo() {
        guard let activeBrain else {
            status = "Open or create a brain first"
            return
        }

        withActiveBrainAccess {
            do {
                let brain = try readBrain(from: activeBrain.brainURL)
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short

                let alert = NSAlert()
                alert.messageText = brain.vault.name
                alert.informativeText = """
                Location: \(activeBrain.folderURL.path)
                Created: \(formatter.string(from: brain.vault.createdAt))
                Updated: \(formatter.string(from: brain.vault.updatedAt))
                Notes: \(notes.count)
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Done")
                alert.runModal()
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func confirmDeleteBrain() {
        guard let activeBrain else {
            status = "Open or create a brain first"
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete \(activeBrain.name)?"
        alert.informativeText = "The vault folder will be moved to Trash. You can recover it from Trash if needed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        deleteActiveBrain()
    }

    private func renameBrain(to name: String) {
        guard let cleanName = cleanBrainName(name) else {
            status = "Brain name cannot be empty"
            return
        }

        withActiveBrainAccess {
            do {
                guard let activeBrain else { return }
                var brain = try readBrain(from: activeBrain.brainURL)
                brain.vault.name = cleanName
                brain.vault.updatedAt = Date()
                try writeBrain(brain, to: activeBrain.brainURL)
                self.activeBrain = BrainSummary(
                    id: brain.vault.id,
                    name: brain.vault.name,
                    folderURL: activeBrain.folderURL,
                    brainURL: activeBrain.brainURL,
                    updatedAt: brain.vault.updatedAt
                )
                recordRecentVault(note: notes.first)
                status = "Brain renamed"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func deleteActiveBrain() {
        guard let activeBrain else { return }

        withSecurityScopedAccess(to: activeBrain.folderURL) {
            do {
                try FileManager.default.trashItem(at: activeBrain.folderURL, resultingItemURL: nil)
                closeBrain()
                removeRecentVault(for: activeBrain.brainURL)
                status = "Brain moved to Trash"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func loadNotes() throws {
        guard let brain = activeBrain else { return }
        let folder = notesFolderURL(for: brain)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let noteURLs = try noteFileURLs(in: brain)

        var seenIDs = Set<Note.ID>()
        var reservedTitles = Set<String>()
        var discoveredGroupTitlesByNoteID: [Note.ID: String] = [:]
        var noteLoadFailures: [(URL, Error)] = []
        var loadedNotes: [Note] = []

        for url in noteURLs {
            do {
                var note = try readNote(from: url)
                var noteURL = url
                var fileName = relativeNoteFileName(for: noteURL, in: brain)
                let originalFolderURL = noteURL.deletingLastPathComponent()
                let metadataID = note.id.trimmingCharacters(in: .whitespacesAndNewlines)
                let indexedID = noteIdentityDatabase?.noteID(forFileName: fileName)
                    ?? noteIdentityDatabase?.noteID(forFileName: noteURL.lastPathComponent)
                let candidateID = indexedID ?? (metadataID.isEmpty ? nil : note.id)
                let finalID: Note.ID

                if let candidateID, !seenIDs.contains(candidateID) {
                    finalID = candidateID
                } else {
                    finalID = UUID().uuidString
                }

                let uniqueTitle = uniqueTitle(for: note.title, reserving: &reservedTitles)
                if finalID != note.id || uniqueTitle != note.title {
                    note = Note(
                        id: finalID,
                        title: uniqueTitle,
                        content: contentBySettingDocumentTitle(uniqueTitle, in: note.content),
                        createdAt: note.createdAt,
                        updatedAt: Date()
                    )
                    let updatedURL = markdownNoteURL(for: note, inFolder: originalFolderURL, allowing: noteURL)
                    try FileManager.default.createDirectory(
                        at: updatedURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try writeMarkdownNote(note, to: updatedURL)
                    if updatedURL != noteURL, FileManager.default.fileExists(atPath: noteURL.path) {
                        try? FileManager.default.removeItem(at: noteURL)
                    }
                    noteURL = updatedURL
                    fileName = relativeNoteFileName(for: noteURL, in: brain)
                }

                try noteIdentityDatabase?.upsert(
                    noteID: note.id,
                    title: note.title,
                    fileName: fileName,
                    updatedAt: note.updatedAt
                )
                if let groupTitle = sidebarGroupTitle(fromRelativeFileName: fileName) {
                    discoveredGroupTitlesByNoteID[note.id] = groupTitle
                }
                seenIDs.insert(note.id)
                loadedNotes.append(note)
            } catch {
                noteLoadFailures.append((url, error))
            }
        }
        let loadedSummaries = loadedNotes
            .map { NoteSummary(id: $0.id, title: $0.title, updatedAt: $0.updatedAt) }
            .sorted { $0.updatedAt > $1.updatedAt }
        syncSidebarItems(with: loadedSummaries, discoveredGroupTitlesByNoteID: discoveredGroupTitlesByNoteID)
        notes = orderedNotesForSidebar(from: loadedSummaries)
        graphLinks = buildGraphLinks(from: loadedNotes)
        rebuildSearchIndex(from: loadedNotes, in: brain)
        cacheHomeSourceNotes(from: loadedNotes)

        if let firstFailure = noteLoadFailures.first {
            let count = noteLoadFailures.count
            let fileName = firstFailure.0.lastPathComponent
            status = count == 1
                ? "\(fileName) could not be read: \(firstFailure.1.localizedDescription)"
                : "\(count) pages could not be read. First: \(fileName) - \(firstFailure.1.localizedDescription)"
        }
    }

    private func loadHomePageSourceNotes() throws -> [HomePageSourceNote] {
        if let cachedHomeSourceNotes {
            return cachedHomeSourceNotes
        }

        guard let brain = activeBrain else { return [] }

        var sourceNotes: [HomePageSourceNote] = []
        var capturedError: Error?
        withSecurityScopedAccess(to: brain.folderURL) {
            do {
                sourceNotes = try loadSourceNotesFromVaultNoAccess(brain)
            } catch {
                capturedError = error
            }
        }

        if let capturedError {
            throw capturedError
        }
        cachedHomeSourceNotes = sourceNotes
        invalidateHomePagePresentationCache()
        return sourceNotes
    }

    private func refreshVaultNotesForHome() throws {
        guard let brain = activeBrain else { return }

        var capturedError: Error?
        withSecurityScopedAccess(to: brain.folderURL) {
            do {
                try loadNotes()
            } catch {
                capturedError = error
            }
        }

        if let capturedError {
            throw capturedError
        }
    }

    private func loadSourceNotesFromVaultNoAccess(_ brain: BrainSummary) throws -> [HomePageSourceNote] {
        let fileNotes = ((try? noteFileURLs(in: brain)) ?? [])
            .compactMap { try? readNote(from: $0) }

        let fileNotesByID = Dictionary(grouping: fileNotes, by: \.id)
            .compactMapValues { $0.first }
        let fileNotesByTitle = Dictionary(grouping: fileNotes) { normalizedLinkTitle($0.title) }
            .compactMapValues { $0.first }

        var sourceNotes: [HomePageSourceNote] = []
        var seenIDs = Set<Note.ID>()
        var seenTitles = Set<String>()

        func append(_ note: Note) {
            let normalizedTitle = normalizedLinkTitle(note.title)
            guard !seenIDs.contains(note.id),
                  !seenTitles.contains(normalizedTitle)
            else { return }

            sourceNotes.append(
                HomePageSourceNote(
                    id: note.id,
                    title: note.title,
                    content: note.content,
                    updatedAt: note.updatedAt
                )
            )
            seenIDs.insert(note.id)
            seenTitles.insert(normalizedTitle)
        }

        func appendSummaryOnly(_ summary: NoteSummary) {
            let normalizedTitle = normalizedLinkTitle(summary.title)
            guard !seenIDs.contains(summary.id),
                  !seenTitles.contains(normalizedTitle)
            else { return }

            sourceNotes.append(
                HomePageSourceNote(
                    id: summary.id,
                    title: summary.title,
                    content: "",
                    updatedAt: summary.updatedAt
                )
            )
            seenIDs.insert(summary.id)
            seenTitles.insert(normalizedTitle)
        }

        for summary in notes {
            if let note = fileNotesByID[summary.id] ?? fileNotesByTitle[normalizedLinkTitle(summary.title)] {
                append(note)
            } else {
                appendSummaryOnly(summary)
            }
        }

        for note in fileNotes.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            append(note)
        }

        return sourceNotes
    }

    private func cacheHomeSourceNotes(from loadedNotes: [Note]) {
        let loadedNotesByID = Dictionary(grouping: loadedNotes, by: \.id)
            .compactMapValues { $0.first }
        let loadedNotesByTitle = Dictionary(grouping: loadedNotes) { normalizedLinkTitle($0.title) }
            .compactMapValues { $0.first }

        var sourceNotes: [HomePageSourceNote] = []
        var seenIDs = Set<Note.ID>()
        var seenTitles = Set<String>()

        func append(_ note: Note) {
            let normalizedTitle = normalizedLinkTitle(note.title)
            guard !seenIDs.contains(note.id),
                  !seenTitles.contains(normalizedTitle)
            else { return }

            sourceNotes.append(
                HomePageSourceNote(
                    id: note.id,
                    title: note.title,
                    content: note.content,
                    updatedAt: note.updatedAt
                )
            )
            seenIDs.insert(note.id)
            seenTitles.insert(normalizedTitle)
        }

        for summary in notes {
            if let note = loadedNotesByID[summary.id] ?? loadedNotesByTitle[normalizedLinkTitle(summary.title)] {
                append(note)
            }
        }

        for note in loadedNotes.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            append(note)
        }

        cachedHomeSourceNotes = sourceNotes
        invalidateHomePagePresentationCache()
    }

    private func updateCachedHomeSourceNoteForCurrentEditor() {
        guard let currentNoteID,
              var cachedHomeSourceNotes,
              let index = cachedHomeSourceNotes.firstIndex(where: { $0.id == currentNoteID })
        else {
            invalidateHomePagePresentationCache()
            return
        }

        cachedHomeSourceNotes[index] = HomePageSourceNote(
            id: currentNoteID,
            title: title,
            content: content,
            updatedAt: Date()
        )
        self.cachedHomeSourceNotes = cachedHomeSourceNotes
        invalidateHomePagePresentationCache()
    }

    private func invalidateHomePagePresentationCache() {
        cachedHomePagePresentationMarkdown = nil
        cachedHomePagePresentationSourceSignature = nil
        cachedHomePagePresentation = nil
    }

    private func homePresentationSourceSignature(_ sourceNotes: [HomePageSourceNote]) -> String {
        sourceNotes
            .map { note in
                "\(note.id)|\(note.title)|\(note.updatedAt.timeIntervalSince1970)|\(note.content.count)"
            }
            .joined(separator: "\n")
    }

    private func syncSidebarItems(
        with loadedSummaries: [NoteSummary],
        discoveredGroupTitlesByNoteID: [Note.ID: String] = [:]
    ) {
        let storedItems: [SidebarItem]
        if let activeBrain,
           let brain = try? readBrain(from: activeBrain.brainURL),
           let sidebarItems = brain.sidebar?.items {
            storedItems = sidebarItems.map(\.sidebarItem)
        } else {
            storedItems = []
        }

        let notesByID = Dictionary(uniqueKeysWithValues: loadedSummaries.map { ($0.id, $0) })
        var seenNoteIDs = Set<Note.ID>()
        var mergedItems: [SidebarItem] = []
        let storedGroupIDs = Set(storedItems.filter { $0.kind == .group }.map(\.id))
        var groupIDsByNormalizedTitle: [String: SidebarItem.ID] = [:]
        var normalizedGroupTitles = Set<String>()

        for item in storedItems {
            switch item.kind {
            case .group:
                var groupItem = item
                groupItem.title = sanitizedSidebarGroupTitle(groupItem.title)
                mergedItems.append(groupItem)
                let normalizedTitle = normalizedLinkTitle(groupItem.title)
                groupIDsByNormalizedTitle[normalizedTitle] = groupItem.id
                normalizedGroupTitles.insert(normalizedTitle)
            case .note:
                guard let noteID = item.noteID,
                      let note = notesByID[noteID],
                      !seenNoteIDs.contains(noteID)
                else { continue }
                let groupID = item.groupID.flatMap { storedGroupIDs.contains($0) ? $0 : nil }
                mergedItems.append(SidebarItem(note: note, groupID: groupID))
                seenNoteIDs.insert(noteID)
            }
        }

        func groupID(forDiscoveredTitle rawTitle: String) -> SidebarItem.ID {
            let cleanTitle = sanitizedSidebarGroupTitle(rawTitle)
            let normalizedTitle = normalizedLinkTitle(cleanTitle)
            if let existingID = groupIDsByNormalizedTitle[normalizedTitle] {
                return existingID
            }

            var finalTitle = cleanTitle
            var suffix = 2
            while normalizedGroupTitles.contains(normalizedLinkTitle(finalTitle)) {
                finalTitle = "\(cleanTitle) \(suffix)"
                suffix += 1
            }

            let groupItem = SidebarItem(
                id: UUID().uuidString,
                kind: .group,
                noteID: nil,
                title: finalTitle,
                groupID: nil,
                isExpanded: true
            )
            mergedItems.append(groupItem)
            let finalNormalizedTitle = normalizedLinkTitle(finalTitle)
            groupIDsByNormalizedTitle[finalNormalizedTitle] = groupItem.id
            normalizedGroupTitles.insert(finalNormalizedTitle)
            return groupItem.id
        }

        for note in loadedSummaries where !seenNoteIDs.contains(note.id) {
            if let groupTitle = discoveredGroupTitlesByNoteID[note.id] {
                mergedItems.append(SidebarItem(note: note, groupID: groupID(forDiscoveredTitle: groupTitle)))
            } else {
                mergedItems.append(SidebarItem(note: note))
            }
        }

        sidebarItems = mergedItems
    }

    private func orderedNotesForSidebar(from sourceNotes: [NoteSummary]? = nil) -> [NoteSummary] {
        let notesByID = Dictionary(uniqueKeysWithValues: (sourceNotes ?? notes).map { ($0.id, $0) })
        var orderedNotes: [NoteSummary] = []
        var seenNoteIDs = Set<Note.ID>()

        for item in sidebarItems where item.kind == .note {
            guard let noteID = item.noteID,
                  let note = notesByID[noteID],
                  !seenNoteIDs.contains(noteID)
            else { continue }
            orderedNotes.append(note)
            seenNoteIDs.insert(noteID)
        }

        let remainingNotes = notesByID.values
            .filter { !seenNoteIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
        return orderedNotes + remainingNotes
    }

    private func persistSidebarLayout() {
        withActiveBrainAccess {
            do {
                try persistSidebarLayoutNoAccess()
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func persistSidebarLayoutNoAccess() throws {
        guard let activeBrain else { return }
        var brain = try readBrain(from: activeBrain.brainURL)
        brain.sidebar = BrainSidebarLayout(items: sidebarItems.map(BrainSidebarItem.init))
        brain.vault.updatedAt = Date()
        try writeBrain(brain, to: activeBrain.brainURL)
        self.activeBrain = BrainSummary(
            id: brain.vault.id,
            name: brain.vault.name,
            folderURL: activeBrain.folderURL,
            brainURL: activeBrain.brainURL,
            updatedAt: brain.vault.updatedAt
        )
    }

    private func nextSidebarGroupTitle() -> String {
        let existingTitles = Set(sidebarItems.filter { $0.kind == .group }.map { $0.title.lowercased() })
        var counter = 1
        while existingTitles.contains("Group \(counter)".lowercased()) {
            counter += 1
        }
        return "Group \(counter)"
    }

    private func syncBrainMetadata() throws {
        guard let activeBrain else { return }
        var brain = try readBrain(from: activeBrain.brainURL)
        brain.vault.updatedAt = Date()
        brain.rootNoteID = notes.first?.id
        brain.graph.notes = notes.map {
            BrainNoteReference(id: $0.id, title: $0.title, updatedAt: $0.updatedAt)
        }
        brain.graph.links = graphLinks
        brain.sidebar = BrainSidebarLayout(items: sidebarItems.map(BrainSidebarItem.init))
        brain.app.lastOpenedWith = "1.0"
        try writeBrain(brain, to: activeBrain.brainURL)
        self.activeBrain = BrainSummary(
            id: brain.vault.id,
            name: brain.vault.name,
            folderURL: activeBrain.folderURL,
            brainURL: activeBrain.brainURL,
            updatedAt: brain.vault.updatedAt
        )
    }

    private func updateStyleMemory(with markdown: String) throws {
        guard let activeBrain else { return }
        let sample = styleSample(from: markdown)
        guard !sample.isEmpty else { return }

        var brain = try readBrain(from: activeBrain.brainURL)
        brain.styleMemory.removeAll { $0 == sample }
        brain.styleMemory.insert(sample, at: 0)
        brain.styleMemory = Array(brain.styleMemory.prefix(6))
        var memory = brain.memory ?? BrainMemory(writingArtifacts: [], preferences: [], updatedAt: nil)
        memory.writingArtifacts.removeAll { $0.excerpt == sample }
        memory.writingArtifacts.insert(
            WritingArtifact(
                id: UUID().uuidString,
                sourceNoteID: currentNoteID,
                sourceTitle: displayTitle(for: title),
                excerpt: sample,
                wordCount: sample.split { $0.isWhitespace || $0.isNewline }.count,
                createdAt: Date()
            ),
            at: 0
        )
        memory.writingArtifacts = Array(memory.writingArtifacts.prefix(12))
        memory.updatedAt = Date()
        brain.memory = memory
        brain.vault.updatedAt = Date()
        try writeBrain(brain, to: activeBrain.brainURL)
    }

    private func learnFromUserCorrectionIfNeeded(revisedContent: String) {
        guard !isApplyingAssistantOutput,
              let pendingAssistantInsertion,
              pendingAssistantInsertion.noteID == currentNoteID
        else { return }

        let signals = CorrectionLearningEngine.signals(
            from: pendingAssistantInsertion,
            revisedContent: revisedContent
        )
        guard !signals.isEmpty else { return }

        do {
            try recordCorrectionSignals(signals)
            self.pendingAssistantInsertion = nil
            status = "Learned from correction"
        } catch {
            status = error.localizedDescription
        }
    }

    private func learnFromDeletionIfNeeded(noteID: Note.ID) throws {
        guard let pendingAssistantInsertion,
              pendingAssistantInsertion.noteID == noteID
        else { return }

        let signals = CorrectionLearningEngine.signals(
            from: pendingAssistantInsertion,
            revisedContent: ""
        )
        guard !signals.isEmpty else { return }

        try recordCorrectionSignals(signals)
        self.pendingAssistantInsertion = nil
    }

    private func recordCorrectionSignals(_ signals: [CorrectionSignal]) throws {
        guard let activeBrain else { return }

        var brain = try readBrain(from: activeBrain.brainURL)
        var memory = brain.memory ?? BrainMemory(writingArtifacts: [], preferences: [], updatedAt: nil)

        var correctionSignals = memory.correctionSignals ?? []
        correctionSignals.insert(contentsOf: signals, at: 0)
        memory.correctionSignals = Array(correctionSignals.prefix(48))
        memory.correctionPreferences = CorrectionLearningEngine.mergedPreferences(
            existing: memory.correctionPreferences ?? [],
            signals: signals
        )
        memory.updatedAt = Date()
        brain.memory = memory
        brain.vault.updatedAt = Date()
        try writeBrain(brain, to: activeBrain.brainURL)
    }

    private func styleSample(from markdown: String) -> String {
        plainText(fromMarkdown: markdown)
            .split(separator: "\n")
            .joined(separator: " ")
            .split(separator: " ")
            .prefix(90)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func learnedStyleMemory() -> String {
        guard let activeBrain,
              let brain = try? readBrain(from: activeBrain.brainURL)
        else {
            return styleSample(from: content)
        }

        let artifacts = brain.memory?.writingArtifacts.map(\.excerpt) ?? []
        let samples = ([styleSample(from: content)] + brain.styleMemory + artifacts)
            .filter { !$0.isEmpty }
            .prefix(4)

        return samples.joined(separator: "\n\n")
    }

    private func learnedCorrectionMemory() -> String {
        guard let activeBrain,
              let brain = try? readBrain(from: activeBrain.brainURL),
              let memory = brain.memory
        else {
            return ""
        }

        return CorrectionLearningEngine.promptContext(
            preferences: memory.correctionPreferences ?? [],
            signals: memory.correctionSignals ?? []
        )
    }

    private func userPersonalizationContext() -> String {
        userProfile.personalizationContext()
    }

    private func userPersonalizationPromptSection() -> String {
        let context = userPersonalizationContext()
        guard !context.isEmpty else { return "" }
        return """

        User personalization:
        \(context)
        """
    }

    private func personalizedSystemInstructions(_ base: String) -> String {
        let context = userPersonalizationContext()
        guard !context.isEmpty else { return base }
        return """
        \(base)

        User personalization:
        \(context)
        """
    }

    private func buildGraphLinks(from loadedNotes: [Note]) -> [BrainLinkReference] {
        var notesByTitle: [String: [Note.ID]] = [:]
        for note in loadedNotes {
            notesByTitle[normalizedLinkTitle(note.title), default: []].append(note.id)
        }

        var seen = Set<String>()
        var links: [BrainLinkReference] = []

        for note in loadedNotes {
            for targetTitle in wikiLinks(in: note.content) {
                guard let targetID = notesByTitle[normalizedLinkTitle(targetTitle)]?.first(where: { $0 != note.id }),
                      targetID != note.id
                else { continue }

                let key = "\(note.id)->\(targetID)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                links.append(BrainLinkReference(from: note.id, to: targetID, kind: "wiki"))
            }
        }

        return links
    }

    private func normalizedLinkTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func wikiLinks(in markdown: String) -> [String] {
        let pattern = #"\[\[([^\]\|]+)(?:\|[^\]]+)?\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)

        return regex.matches(in: markdown, range: range).compactMap { match in
            guard let titleRange = Range(match.range(at: 1), in: markdown) else { return nil }
            let title = markdown[titleRange].trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        }
    }

    private func readBrain(from url: URL) throws -> BrainFile {
        try decoder.decode(BrainFile.self, from: Data(contentsOf: url))
    }

    private func writeBrain(_ brain: BrainFile, to url: URL) throws {
        try encoder.encode(brain).write(to: url, options: .atomic)
    }

    private func readNote(from url: URL) throws -> Note {
        try ensureReadableNoteFile(at: url)
        return try readNote(from: url, data: Data(contentsOf: url))
    }

    private func readNote(from url: URL, data: Data) throws -> Note {
        if url.pathExtension == "md" {
            return try readMarkdownNote(from: url, data: data)
        }

        return try decoder.decode(Note.self, from: data)
    }

    private func ensureReadableNoteFile(at url: URL) throws {
        guard let byteCount = fileByteCount(at: url) else { return }
        guard byteCount <= Self.maxNoteFileBytes else {
            throw FileSafetyError.noteTooLarge(
                fileName: url.lastPathComponent,
                size: byteCount,
                limit: Self.maxNoteFileBytes
            )
        }
    }

    private func formattedByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    private func readMarkdownNote(from url: URL, data: Data) throws -> Note {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard text.hasPrefix("---\n"),
              let metadataEnd = text.range(
                of: "\n---\n",
                range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex
              )
        else {
            return inferredMarkdownNote(from: text, url: url)
        }

        let metadataText = String(text[text.index(text.startIndex, offsetBy: 4)..<metadataEnd.lowerBound])
        let metadata = try decoder.decode(
            MarkdownNoteMetadata.self,
            from: Data(metadataText.utf8)
        )
        var body = String(text[metadataEnd.upperBound...])
        if body.hasPrefix("\n") {
            body.removeFirst()
        }

        return Note(
            id: metadata.id,
            title: metadata.title,
            content: body,
            createdAt: metadata.createdAt,
            updatedAt: metadata.updatedAt
        )
    }

    private func inferredMarkdownNote(from text: String, url: URL) -> Note {
        let title = text
            .split(separator: "\n")
            .first { $0.hasPrefix("#") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespacesAndNewlines)) }
        let fileName = url.deletingPathExtension().lastPathComponent
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? Date()

        return Note(
            id: fileName,
            title: title?.isEmpty == false ? title! : fileName,
            content: text,
            createdAt: date,
            updatedAt: date
        )
    }

    private func writeMarkdownNote(_ note: Note, to url: URL) throws {
        let metadata = MarkdownNoteMetadata(
            id: note.id,
            title: note.title,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt
        )
        let metadataData = try encoder.encode(metadata)
        guard let metadataText = String(data: metadataData, encoding: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let markdown = "---\n\(metadataText)\n---\n\n\(note.content)"
        try Data(markdown.utf8).write(to: url, options: .atomic)
    }

    private func writeNote(_ note: Note, to url: URL) throws {
        if url.pathExtension == "md" {
            try writeMarkdownNote(note, to: url)
        } else {
            try encoder.encode(note).write(to: url, options: .atomic)
        }
    }

    private func brainURL(from url: URL) -> URL? {
        if isBrainFile(url), FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return findBrainFile(in: url)
    }

    private func findBrainFile(in folderURL: URL) -> URL? {
        let hiddenBrainURL = folderURL.appendingPathComponent(".brain")
        if FileManager.default.fileExists(atPath: hiddenBrainURL.path) {
            return hiddenBrainURL
        }

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsSubdirectoryDescendants]
        ) else {
            return nil
        }

        return urls
            .filter { $0.pathExtension == "brain" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .first
    }

    private func isBrainFile(_ url: URL) -> Bool {
        url.lastPathComponent == ".brain" || url.pathExtension == "brain"
    }

    private func brainFileName(for name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let fileName = name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return fileName.isEmpty ? "Untitled Brain" : fileName
    }

    private func cleanBrainName(_ name: String?) -> String? {
        guard let name else { return nil }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanName.isEmpty ? nil : cleanName
    }

    private func requestText(
        title: String,
        message: String,
        placeholder: String,
        initialValue: String
    ) -> String? {
        let field = NSTextField(string: initialValue)
        field.placeholderString = placeholder
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = field
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestSecureText(
        title: String,
        message: String,
        placeholder: String
    ) -> String? {
        let field = NSSecureTextField(string: "")
        field.placeholderString = placeholder
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = field
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestAndSaveMistralAPIKey(title: String, message: String) -> Bool {
        guard let apiKey = requestSecureText(
            title: title,
            message: message,
            placeholder: "MISTRAL_API_KEY"
        ) else {
            return false
        }

        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAPIKey.isEmpty {
            mistralAPIKey = cleanAPIKey
            try? saveAssistantConfiguration()
            status = "Mistral API key saved"
        }
        return true
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func confirmSidebarGroupDeletion(title: String, childCount: Int) -> SidebarGroupDeletionChoice {
        let alert = NSAlert()
        alert.messageText = "Delete \(title)?"
        alert.informativeText = "This group contains \(childCount) page\(childCount == 1 ? "" : "s"). Choose whether to keep those pages or delete them too."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Dismiss")
        alert.addButton(withTitle: "Delete Group Without Deleting Pages")
        alert.addButton(withTitle: "Delete Group With Everything In It")

        switch alert.runModal() {
        case .alertSecondButtonReturn:
            return .deleteGroupOnly
        case .alertThirdButtonReturn:
            return .deleteGroupAndPages
        default:
            return .dismiss
        }
    }

    private func generateAssistantResponse(for prompt: String, linkedPageTitles: [String]) async {
        defer {
            isGeneratingAssistantResponse = false
            isUsingWebSearch = false
            assistantGenerationPhase = .idle
            assistantGenerationTask = nil
        }

        do {
            let assistantInput = assistantInput(for: prompt, linkedPageTitles: linkedPageTitles)
            let result = try await generateWithSelectedAssistantModel(
                system: assistantInstructions(),
                user: assistantInput,
                maxTokens: Self.maxAssistantOutputTokens
            )
            recordUsage(
                for: selectedAssistantModel,
                result: result,
                fallbackInputTokens: estimatedTokenCount(for: assistantInput),
                fallbackOutputTokens: estimatedTokenCount(for: result.content)
            )
            let providerTitle = selectedAssistantModel.title
            let output = result.content

            guard !cleanedAssistantMarkdown(output).isEmpty else {
                throw AssistantError.requestFailed("The model returned no Markdown.")
            }

            applyAssistantDocumentOutput(output, prompt: prompt)
            try? updateStyleMemory(with: content)
            pendingAssistantPreview = nil
            clearSubmittedAssistantPromptIfUnchanged(prompt: prompt, linkedPageTitles: linkedPageTitles)
            status = "\(providerTitle) updated Markdown"
        } catch {
            status = error.localizedDescription
        }
    }

    private func generateAssistantConversationResponse(for prompt: String, linkedPageTitles: [String]) async {
        defer {
            isGeneratingAssistantResponse = false
            isUsingWebSearch = false
            if case .timedOut = assistantGenerationPhase {
            } else if case .failed = assistantGenerationPhase {
            } else {
                assistantGenerationPhase = .idle
            }
            assistantGenerationTask = nil
        }

        do {
            let providerTitle = selectedAssistantModel.title
            let startedAt = Date()
            let answer: String
            switch selectedAssistantModel {
            case .mistral:
                answer = try await streamAssistantConversationAnswer(
                    prompt: prompt,
                    linkedPageTitles: linkedPageTitles,
                    providerTitle: providerTitle,
                    contextBudget: Self.assistantConversationContextBudget,
                    retryOnTimeout: true,
                    startedAt: startedAt
                )
            case .deepseek:
                let context = assistantConversationContext(
                    for: prompt,
                    linkedPageTitles: linkedPageTitles,
                    characterBudget: Self.assistantConversationContextBudget
                )
                let messages = assistantConversationMessages(currentUserInput: context.input)
                lastAssistantGenerationDiagnostics = AssistantGenerationDiagnostics(
                    contextBuildSeconds: context.buildDuration,
                    requestByteCount: try deepSeekRequestBodyByteCount(
                        system: assistantConversationInstructions(),
                        messages: messages,
                        maxTokens: Self.assistantConversationOutputTokens,
                        stream: false
                    ),
                    estimatedInputTokens: context.estimatedTokens + estimatedTokenCount(for: assistantConversationTranscript()),
                    responseSeconds: 0,
                    includedSources: context.includedSources,
                    errorType: nil
                )
                assistantGenerationPhase = .requesting
                status = "Sending to DeepSeek · ~\(lastAssistantGenerationDiagnostics?.estimatedInputTokens ?? context.estimatedTokens) tokens"
                let responseStartedAt = Date()
                let result = try await generateWithDeepSeek(
                    system: assistantConversationInstructions(),
                    messages: messages,
                    maxTokens: Self.assistantConversationOutputTokens
                )
                recordUsage(
                    for: AssistantModel.deepseek,
                    result: result,
                    fallbackInputTokens: context.estimatedTokens,
                    fallbackOutputTokens: estimatedTokenCount(for: result.content)
                )
                let cleanAnswer = cleanedAssistantMarkdown(result.content)
                lastAssistantGenerationDiagnostics = AssistantGenerationDiagnostics(
                    contextBuildSeconds: context.buildDuration,
                    requestByteCount: lastAssistantGenerationDiagnostics?.requestByteCount ?? 0,
                    estimatedInputTokens: result.inputTokens ?? context.estimatedTokens,
                    responseSeconds: Date().timeIntervalSince(responseStartedAt),
                    includedSources: context.includedSources,
                    errorType: nil
                )
                answer = cleanAnswer
            }
            guard !answer.isEmpty else {
                throw AssistantError.requestFailed("The model returned no answer.")
            }

            let response = AssistantConversationResponse(
                prompt: prompt,
                answer: answer,
                providerTitle: providerTitle,
                createdAt: Date()
            )
            assistantConversationResponse = response
            assistantConversationMemory.append(response)
            clearSubmittedAssistantPromptIfUnchanged(prompt: prompt, linkedPageTitles: linkedPageTitles)
            status = "\(providerTitle) answered"
        } catch is CancellationError {
            status = "Answer cancelled"
        } catch let error as URLError where error.code == .timedOut {
            assistantGenerationPhase = .timedOut
            status = "Response timed out. Try again with shorter context or switch to quick answer mode."
        } catch {
            assistantGenerationPhase = .failed(error.localizedDescription)
            status = error.localizedDescription
        }
    }

    private func generateAssistantConversationInsertion(from response: AssistantConversationResponse) async {
        defer {
            isGeneratingAssistantResponse = false
            isUsingWebSearch = false
            assistantGenerationPhase = .idle
            assistantGenerationTask = nil
        }

        do {
            let prompt = assistantConversationInsertionInput(for: response)
            let result = try await generateWithSelectedAssistantModel(
                system: assistantConversationInsertionInstructions(),
                user: prompt,
                maxTokens: Self.assistantConversationInsertionOutputTokens
            )
            recordUsage(
                for: selectedAssistantModel,
                result: result,
                fallbackInputTokens: estimatedTokenCount(for: prompt),
                fallbackOutputTokens: estimatedTokenCount(for: result.content)
            )

            let markdown = cleanedWritingAssistantMarkdown(result.content)
            guard !markdown.isEmpty else {
                throw AssistantError.requestFailed("The model returned no Markdown.")
            }

            applyAssistantDocumentOutput(markdown, prompt: "Add conversation answer to the page")
            try? updateStyleMemory(with: content)
            status = "\(response.providerTitle) added the answer to the page"
        } catch {
            status = error.localizedDescription
        }
    }

    private func generateHelpDeskResponse(
        for userMessage: HelpDeskMessage,
        attachment: PromptAttachment?,
        vaultID: String,
        conversationID: HelpDeskConversation.ID
    ) async {
        defer {
            isGeneratingHelpDeskResponse = false
        }

        do {
            guard activeBrain?.id == vaultID else {
                return
            }
            guard helpDeskDatabase.vaultID == vaultID,
                  helpDeskDatabase.conversations.contains(where: { $0.id == conversationID }) else {
                throw AssistantError.requestFailed("No Zirn Chat conversation is selected.")
            }

            let history = helpDeskMessages(for: conversationID)
                .filter { $0.id != userMessage.id }
            let vaultContext = try helpDeskVaultContext(for: userMessage.content, history: history)
            let attachmentContext = helpDeskAttachmentContext(
                attachment,
                question: userMessage.content,
                vaultContext: vaultContext
            )
            let currentInput = """
            User question:
            \(userMessage.content)

            Attached file:
            \(attachmentContext)

            Vault context:
            \(vaultContext)

            Required output:
            Answer like a vault-aware Zirn Chat assistant. Use the vault and conversation history. If the answer depends on a page, mention the page title naturally.
            """
            var messages = history.suffix(Self.helpDeskHistoryMessageLimit).map { message in
                [
                    "role": message.role.chatRole,
                    "content": promptExcerpt(message.content, characterLimit: 1_200)
                ]
            }
            messages.append(
                [
                    "role": "user",
                    "content": currentInput
                ]
            )

            let result = try await generateWithSelectedAssistantModel(
                system: helpDeskInstructions(),
                messages: messages,
                maxTokens: Self.maxAssistantOutputTokens
            )
            let estimatedInput = messages.reduce(helpDeskInstructions().count) { total, message in
                total + (message["content"]?.count ?? 0)
            }
            recordUsage(
                for: selectedAssistantModel,
                result: result,
                fallbackInputTokens: estimatedTokenCount(forCharacterCount: estimatedInput),
                fallbackOutputTokens: estimatedTokenCount(for: result.content)
            )

            let answer = cleanedAssistantMarkdown(result.content)
            guard !answer.isEmpty else {
                throw AssistantError.requestFailed("The model returned no answer.")
            }

            let assistantMessageID = UUID().uuidString
            appendHelpDeskMessage(
                HelpDeskMessage(
                    id: assistantMessageID,
                    role: .assistant,
                    content: answer,
                    attachmentName: nil,
                    createdAt: Date()
                ),
                conversationID: conversationID
            )
            updateHelpDeskConversationTitleIfNeeded(conversationID: conversationID, prompt: userMessage.content)
            status = "\(selectedAssistantModel.title) answered Zirn Chat"
            beginHelpDeskMarkdownSuggestion(
                messageID: assistantMessageID,
                conversationID: conversationID,
                answer: answer
            )
        } catch {
            appendHelpDeskMessage(
                HelpDeskMessage(
                    id: UUID().uuidString,
                    role: .assistant,
                    content: "I could not answer because \(error.localizedDescription)",
                    attachmentName: nil,
                    createdAt: Date()
                ),
                conversationID: conversationID
            )
            status = error.localizedDescription
        }
    }

    private func clearSubmittedAssistantPromptIfUnchanged(prompt: String, linkedPageTitles: [String]) {
        let currentPrompt = assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentLinkedPageTitles = assistantPromptLinkedPages.map(\.title)
        guard currentPrompt == prompt,
              currentLinkedPageTitles == linkedPageTitles
        else { return }

        assistantPrompt = ""
        assistantPromptLinkedPages = []
        assistantAttachment = nil
    }

    private func generateHighlightSummary(
        sourceNoteID: Note.ID,
        sourceTitle: String,
        highlights: [String],
        model: HighlightSummaryModel,
        generationID: UUID
    ) async {
        let startedAt = Date()
        defer {
            if activeHighlightGenerationID == generationID {
                activeHighlightGenerationID = nil
                isCompilingHighlightSummary = activeHomeGenerationID != nil
                if needsHomeRegenerationAfterCurrentCompile {
                    let shouldForce = needsForcedHomeRegenerationAfterCurrentCompile
                    needsHomeRegenerationAfterCurrentCompile = false
                    needsForcedHomeRegenerationAfterCurrentCompile = false
                    if shouldForce {
                        compileHomePageSummary(force: true)
                    } else {
                        scheduleLiveHomePageCompilation()
                    }
                }
            }
        }

        do {
            let prompt = highlightSummaryPrompt(
                sourceTitle: sourceTitle,
                highlights: highlights
            )
            let result: ChatCompletionResult
            switch model {
            case .mistral:
                result = try await generateWithMistral(
                    system: highlightSummaryInstructions(),
                    user: prompt,
                    maxTokens: Self.maxAssistantOutputTokens
                )
            case .deepseek:
                result = try await generateWithDeepSeek(
                    system: highlightSummaryInstructions(),
                    user: prompt,
                    maxTokens: Self.maxAssistantOutputTokens
                )
            case .ollama:
                result = try await generateWithOllama(
                    system: highlightSummaryInstructions(),
                    user: prompt
                )
            }
            recordUsage(
                for: model,
                result: result,
                fallbackInputTokens: estimatedTokenCount(for: prompt),
                fallbackOutputTokens: estimatedTokenCount(for: result.content)
            )

            let duration = Date().timeIntervalSince(startedAt)
            let markdown = normalizedHighlightSummaryMarkdown(
                result.content,
                sourceTitle: sourceTitle
            )
            let summary = HighlightSummary(
                id: "summary-\(sourceNoteID)",
                sourceNoteID: sourceNoteID,
                sourceTitle: sourceTitle,
                title: "Summary of \(sourceTitle)",
                markdown: markdown,
                compiledAt: Date(),
                compileDuration: duration,
                modelTitle: model.displayModelName(
                    mistralModel: mistralModel,
                    deepSeekModel: deepSeekModel,
                    ollamaModel: ollamaModel
                ),
                sourceFingerprint: nil,
                sourceDiceTokens: nil
            )

            try persistHighlightSummary(summary)
            upsertHighlightSummary(summary)
            openHighlightSummary(id: summary.id)
            status = "Summary compiled"
        } catch {
            if activeHighlightGenerationID == generationID {
                status = error.localizedDescription
            }
        }
    }

    private func generateHomePageSummary(
        vaultName: String,
        sourceNotes: [HomePageSourceNote],
        sourceFingerprint: String,
        sourceDiceTokens: [String],
        model: HighlightSummaryModel,
        generationID: UUID? = nil
    ) async {
        let startedAt = Date()
        defer {
            if generationID == nil || activeHomeGenerationID == generationID {
                isCompilingHighlightSummary = activeHighlightGenerationID != nil
                isGeneratingHomePage = false
                if activeHomeGenerationID == generationID {
                    activeHomeGenerationID = nil
                    homeCompilationTask = nil
                }
                if needsHomeRegenerationAfterCurrentCompile {
                    let shouldForce = needsForcedHomeRegenerationAfterCurrentCompile
                    needsHomeRegenerationAfterCurrentCompile = false
                    needsForcedHomeRegenerationAfterCurrentCompile = false
                    if shouldForce {
                        compileHomePageSummary(force: true)
                    } else {
                        scheduleLiveHomePageCompilation()
                    }
                }
            }
        }

        do {
            let preparedNotes = try await preparedHomePageNotes(from: sourceNotes, model: model)
            let prompt = homePageSummaryPrompt(vaultName: vaultName, sourceNotes: preparedNotes)
            let result: ChatCompletionResult
            switch model {
            case .mistral:
                result = try await generateWithMistral(
                    system: homePageSummaryInstructions(),
                    user: prompt,
                    maxTokens: Self.maxAssistantOutputTokens
                )
            case .deepseek:
                result = try await generateWithDeepSeek(
                    system: homePageSummaryInstructions(),
                    user: prompt,
                    maxTokens: Self.maxAssistantOutputTokens
                )
            case .ollama:
                result = try await generateWithOllama(
                    system: homePageSummaryInstructions(),
                    user: prompt
                )
            }
            recordUsage(
                for: model,
                result: result,
                fallbackInputTokens: estimatedTokenCount(for: prompt),
                fallbackOutputTokens: estimatedTokenCount(for: result.content)
            )

            if let generationID, activeHomeGenerationID != generationID {
                return
            }

            let duration = Date().timeIntervalSince(startedAt)
            let fallbackMarkdown = localHomePageMarkdown(vaultName: vaultName, sourceNotes: sourceNotes)
            let markdown = normalizedHomePageMarkdown(
                result.content,
                fallbackMarkdown: fallbackMarkdown,
                sourceNotes: sourceNotes
            )
            let summary = HighlightSummary(
                id: homeSummaryID,
                sourceNoteID: "vault",
                sourceTitle: vaultName,
                title: "Home",
                markdown: markdown,
                compiledAt: Date(),
                compileDuration: duration,
                modelTitle: model.displayModelName(
                    mistralModel: mistralModel,
                    deepSeekModel: deepSeekModel,
                    ollamaModel: ollamaModel
                ),
                sourceFingerprint: sourceFingerprint,
                sourceDiceTokens: sourceDiceTokens
            )

            try persistHighlightSummary(summary)
            upsertHighlightSummary(summary)
            lastHomeSourceDiceTokensForSimilarityCheck = sourceDiceTokens
            if isShowingHomePage {
                title = "Home"
                content = markdown
            }
            status = "Home page generated"
        } catch {
            if generationID == nil || activeHomeGenerationID == generationID {
                status = error.localizedDescription
            }
        }
    }

    private func applyAssistantDocumentOutput(_ output: String, prompt: String) {
        let cleanOutput = cleanedWritingAssistantMarkdown(output)
        guard !cleanOutput.isEmpty else { return }

        let contentBeforeInsertion = content
        isApplyingAssistantOutput = true
        defer { isApplyingAssistantOutput = false }
        withAnimation(.easeInOut(duration: 0.24)) {
            updateContentFromEditor(cleanOutput)
        }
        saveCurrentNote(statusText: "AI updated")
        pendingAssistantInsertion = CorrectionLearningEngine.makePendingInsertion(
            noteID: currentNoteID,
            noteTitle: displayTitle(for: title),
            prompt: prompt,
            contentBeforeInsertion: contentBeforeInsertion,
            insertedMarkdown: cleanOutput,
            contentAfterInsertion: cleanOutput
        )
    }

    private func generateWithMistral(prompt: String, linkedPageTitles: [String]) async throws -> ChatCompletionResult {
        try await generateWithMistral(
            system: assistantInstructions(),
            user: assistantInput(for: prompt, linkedPageTitles: linkedPageTitles),
            maxTokens: Self.maxAssistantOutputTokens
        )
    }

    private func generateWithSelectedAssistantModel(
        system: String,
        user: String,
        maxTokens: Int
    ) async throws -> ChatCompletionResult {
        switch selectedAssistantModel {
        case .mistral:
            return try await generateWithMistral(system: system, user: user, maxTokens: maxTokens)
        case .deepseek:
            return try await generateWithDeepSeek(system: system, user: user, maxTokens: maxTokens)
        }
    }

    private func generateWithSelectedAssistantModel(
        system: String,
        messages: [[String: String]],
        maxTokens: Int
    ) async throws -> ChatCompletionResult {
        switch selectedAssistantModel {
        case .mistral:
            return try await generateWithMistral(system: system, messages: messages, maxTokens: maxTokens)
        case .deepseek:
            return try await generateWithDeepSeek(system: system, messages: messages, maxTokens: maxTokens)
        }
    }

    private func streamAssistantConversationAnswer(
        prompt: String,
        linkedPageTitles: [String],
        providerTitle: String,
        contextBudget: Int,
        retryOnTimeout: Bool,
        startedAt: Date
    ) async throws -> String {
        assistantGenerationPhase = .preparingContext
        status = "Preparing context"
        let context = assistantConversationContext(
            for: prompt,
            linkedPageTitles: linkedPageTitles,
            characterBudget: contextBudget
        )
        let messages = assistantConversationMessages(currentUserInput: context.input)
        let requestByteCount = try mistralRequestBodyByteCount(
            system: assistantConversationInstructions(),
            messages: messages,
            maxTokens: Self.assistantConversationOutputTokens,
            stream: true
        )
        lastAssistantGenerationDiagnostics = AssistantGenerationDiagnostics(
            contextBuildSeconds: context.buildDuration,
            requestByteCount: requestByteCount,
            estimatedInputTokens: context.estimatedTokens + estimatedTokenCount(for: assistantConversationTranscript()),
            responseSeconds: 0,
            includedSources: context.includedSources,
            errorType: nil
        )

        assistantGenerationPhase = .requesting
        status = "Sending to Mistral · ~\(lastAssistantGenerationDiagnostics?.estimatedInputTokens ?? context.estimatedTokens) tokens"
        var streamedAnswer = ""
        let responseStartedAt = Date()
        var streamingResponse: AssistantConversationResponse?

        do {
            try await generateWithMistralStreaming(
                system: assistantConversationInstructions(),
                messages: messages,
                maxTokens: Self.assistantConversationOutputTokens
            ) { delta in
                guard !delta.isEmpty else { return }
                if assistantGenerationPhase != .streaming {
                    assistantGenerationPhase = .streaming
                    status = "Answering..."
                }
                streamedAnswer += delta
                let cleanedAnswer = cleanedAssistantMarkdown(streamedAnswer)
                guard !cleanedAnswer.isEmpty else { return }
                var updated = streamingResponse ?? AssistantConversationResponse(
                    prompt: prompt,
                    answer: cleanedAnswer,
                    providerTitle: providerTitle,
                    createdAt: Date()
                )
                updated.answer = cleanedAnswer
                streamingResponse = updated
                assistantConversationResponse = updated
            }
        } catch let error as URLError where error.code == .timedOut && retryOnTimeout {
            assistantGenerationPhase = .timedOut
            status = "Response timed out. Retrying with shorter context..."
            lastAssistantGenerationDiagnostics = AssistantGenerationDiagnostics(
                contextBuildSeconds: context.buildDuration,
                requestByteCount: requestByteCount,
                estimatedInputTokens: context.estimatedTokens,
                responseSeconds: Date().timeIntervalSince(responseStartedAt),
                includedSources: context.includedSources,
                errorType: "timedOut"
            )
            assistantConversationResponse = nil
            return try await streamAssistantConversationAnswer(
                prompt: prompt,
                linkedPageTitles: linkedPageTitles,
                providerTitle: providerTitle,
                contextBudget: Self.assistantConversationRetryContextBudget,
                retryOnTimeout: false,
                startedAt: startedAt
            )
        }

        let answer = cleanedAssistantMarkdown(streamedAnswer)
        lastAssistantGenerationDiagnostics = AssistantGenerationDiagnostics(
            contextBuildSeconds: context.buildDuration,
            requestByteCount: requestByteCount,
            estimatedInputTokens: context.estimatedTokens,
            responseSeconds: Date().timeIntervalSince(responseStartedAt),
            includedSources: context.includedSources,
            errorType: nil
        )
        recordMistralUsage(
            inputTokens: context.estimatedTokens,
            outputTokens: estimatedTokenCount(for: answer)
        )
        status = "\(providerTitle) answered · \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s"
        return answer
    }

    private func generateWithMistral(
        system: String,
        user: String,
        maxTokens: Int
    ) async throws -> ChatCompletionResult {
        try await generateWithMistral(
            system: system,
            messages: [
                [
                    "role": "user",
                    "content": user
                ]
            ],
            maxTokens: maxTokens
        )
    }

    private func mistralRequestBody(
        system: String,
        messages: [[String: String]],
        maxTokens: Int,
        stream: Bool
    ) -> [String: Any] {
        var requestMessages = [
            [
                "role": "system",
                "content": system
            ]
        ]
        requestMessages.append(contentsOf: messages)

        return [
            "model": mistralModel,
            "messages": requestMessages,
            "temperature": 0.35,
            "max_tokens": maxTokens,
            "stream": stream
        ]
    }

    private func mistralRequestBodyByteCount(
        system: String,
        messages: [[String: String]],
        maxTokens: Int,
        stream: Bool
    ) throws -> Int {
        try JSONSerialization.data(
            withJSONObject: mistralRequestBody(
                system: system,
                messages: messages,
                maxTokens: maxTokens,
                stream: stream
            )
        ).count
    }

    private func deepSeekRequestBody(
        system: String,
        messages: [[String: String]],
        maxTokens: Int,
        stream: Bool
    ) -> [String: Any] {
        var requestMessages = [
            [
                "role": "system",
                "content": system
            ]
        ]
        requestMessages.append(contentsOf: messages)

        return [
            "model": deepSeekModel,
            "messages": requestMessages,
            "temperature": 0.35,
            "max_tokens": maxTokens,
            "stream": stream,
            "thinking": ["type": "disabled"]
        ]
    }

    private func deepSeekRequestBodyByteCount(
        system: String,
        messages: [[String: String]],
        maxTokens: Int,
        stream: Bool
    ) throws -> Int {
        try JSONSerialization.data(
            withJSONObject: deepSeekRequestBody(
                system: system,
                messages: messages,
                maxTokens: maxTokens,
                stream: stream
            )
        ).count
    }

    private func generateWithMistral(
        system: String,
        messages: [[String: String]],
        maxTokens: Int
    ) async throws -> ChatCompletionResult {
        guard !mistralAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add a Mistral API key in Settings > Configure Models.")
        }

        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.mistralChatTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(mistralAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: mistralRequestBody(
                system: system,
                messages: messages,
                maxTokens: maxTokens,
                stream: false
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try processMistralHTTPResponse(response, data: data)
        return try extractChatCompletionResult(from: data)
    }

    private func generateWithMistralStreaming(
        system: String,
        messages: [[String: String]],
        maxTokens: Int,
        onDelta: (String) -> Void
    ) async throws {
        guard !mistralAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add a Mistral API key in Settings > Configure Models.")
        }

        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.mistralChatTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(mistralAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: mistralRequestBody(
                system: system,
                messages: messages,
                maxTokens: maxTokens,
                stream: true
            )
        )

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try processMistralHTTPResponse(response, data: Data())
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line
                .dropFirst(5)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let delta = try? extractChatCompletionDelta(from: data),
                  !delta.isEmpty
            else { continue }
            onDelta(delta)
        }
    }

    private func verifyMistralAPIKey(_ apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try processMistralHTTPResponse(response, data: data)
    }

    private func generateWithDeepSeek(
        system: String,
        user: String,
        maxTokens: Int
    ) async throws -> ChatCompletionResult {
        try await generateWithDeepSeek(
            system: system,
            messages: [
                [
                    "role": "user",
                    "content": user
                ]
            ],
            maxTokens: maxTokens
        )
    }

    private func generateWithDeepSeek(
        system: String,
        messages: [[String: String]],
        maxTokens: Int
    ) async throws -> ChatCompletionResult {
        guard !deepSeekAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add a DeepSeek API key in Settings > Configure Models.")
        }

        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.mistralChatTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(deepSeekAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: deepSeekRequestBody(
                system: system,
                messages: messages,
                maxTokens: maxTokens,
                stream: false
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try extractChatCompletionResult(from: data)
    }

    private func verifyDeepSeekAPIKey(_ apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
    }

    private func refreshMistralAccountLimitsIfNeeded() {
        guard !mistralAPIKey.isEmpty else { return }
        Task {
            try? await verifyMistralAPIKey(mistralAPIKey)
        }
    }

    private func generateWithOllama(system: String, user: String) async throws -> ChatCompletionResult {
        let base = cleanOllamaURL(ollamaURL)
        guard let url = URL(string: base)?.appendingPathComponent("api/chat") else {
            throw AssistantError.missingConfiguration("Set a valid Ollama URL in Settings > Configure Models.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": ollamaModel,
            "messages": [
                [
                    "role": "system",
                    "content": system
                ],
                [
                    "role": "user",
                    "content": user
                ]
            ],
            "stream": false,
            "options": [
                "temperature": 0.35
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AssistantError.requestFailed("Ollama returned no Markdown.")
        }

        return ChatCompletionResult(content: content, inputTokens: nil, outputTokens: nil)
    }

    private func assistantInstructions() -> String {
        """
        You are Zirn's writing assistant. You edit the user's current Markdown document in place.
        You will receive the full current document and a user request. Return the complete revised Markdown document, not a patch, diff, explanation, or separate suggestion.
        The user may type quickly and make spelling mistakes, missing spaces, or phonetic typos. Infer the intended meaning from context instead of rejecting the request for spelling.
        If the user asks to add, include the original document plus the addition in the best location.
        If the user asks to edit, rewrite only the needed parts and preserve everything else.
        If the user asks to delete, remove the requested text or section and keep the remaining document coherent.
        If the user asks to organize, restructure the whole document cleanly while preserving meaning.
        Do not wrap the answer in code fences unless the user specifically asks for code.
        Do not include meta commentary, apologies, or explanations of what you changed.
        Do not add conversational follow-up questions, offers, invitations, or tutoring prompts, such as "Would you like..." or "Do you want...".
        Match the user's writing pattern, vocabulary, rhythm, heading style, and density when possible.
        Treat correction-derived preferences as stronger than passive style samples.
        Preserve the user's existing edits. Make the smallest useful change unless the user asks for a larger rewrite.
        Output polished Markdown with clear headings, short paragraphs, and useful lists only when lists are natural.
        Use Obsidian-style wiki links like [[Page Title]] only when linking is genuinely useful.
        For displayed equations, use inline /formula{} blocks instead of $$...$$:
        /formula{E = mc^2}
        Put valid LaTeX math inside the braces. Multi-line LaTeX can span multiple lines between /formula{ and }.
        """
    }

    private func formulaLatexInstructions() -> String {
        """
        You convert natural-language math descriptions into LaTeX only.
        Return only valid LaTeX math content without delimiters, without code fences, and without explanation.
        Do not wrap in $$, \\[ \\], or /formula{ } blocks.
        Use standard LaTeX commands such as \\frac, \\sqrt, \\sum, \\int, Greek letters, subscripts, and superscripts.
        """
    }

    private func cleanedFormulaLatex(_ markdown: String) -> String {
        var text = cleanedAssistantMarkdown(markdown)
        if text.hasPrefix("```"), let closing = text.range(of: "```", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) {
            text = String(text[text.index(text.startIndex, offsetBy: 3)..<closing.lowerBound])
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("/formula{"), text.hasSuffix("}") {
            text = String(text.dropFirst("/formula{".count).dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if text.hasPrefix("formula {"), text.hasSuffix("}") {
            text = String(text.dropFirst("formula {".count).dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while (text.hasPrefix("$") && text.hasSuffix("$")) || (text.hasPrefix("\\(") && text.hasSuffix("\\)")) {
            if text.hasPrefix("$"), text.hasSuffix("$"), text.count >= 2 {
                text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if text.hasPrefix("\\("), text.hasSuffix("\\)"), text.count >= 4 {
                text = String(text.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                break
            }
        }
        return text
    }

    private func assistantConversationInstructions() -> String {
        """
        You are Zirn's conversational assistant. Answer the user's question without editing, rewriting, or replacing the Markdown document.
        Use the current Markdown document and any attached document as context when relevant.
        The user may type quickly and make spelling mistakes, missing spaces, or phonetic typos. Infer the intended meaning from context instead of rejecting the question for spelling.
        Return Markdown only. Do not claim you changed the file.
        If the user asks you to edit the note, briefly tell them to turn on writing mode with the pen icon.
        When your answer would fit naturally on the current page, end with one short offer such as "Want me to add this to your page?" or "I can write that down on the page if you want." Do not edit the page yourself.
        Keep answers concise, useful, and grounded in the supplied context.
        """
    }

    private func assistantConversationInsertionInstructions() -> String {
        """
        You are Zirn's Markdown editor. Weave a conversation-mode answer into the user's current Markdown document.
        Return the complete revised Markdown document only, not a patch, explanation, transcript, or separate answer.
        Read the current document, the recent conversation, the user's latest question, and the assistant's answer.
        Insert the answer where it belongs in the document. Blend it into existing prose, headings, lists, or examples so it feels intentionally written there.
        Preserve the user's existing edits, title, voice, structure, and Markdown style.
        Do not append a raw chat log. Do not add "User:", "Assistant:", "Question:", or "Answer:" labels unless the document already uses that format.
        Do not add conversational follow-up questions, offers, invitations, or meta commentary.
        When inserting equations, use inline /formula{} blocks with LaTeX inside:
        /formula{E = mc^2}
        """
    }

    private func helpDeskInstructions() -> String {
        personalizedSystemInstructions(
            """
            You are Zirn Chat, a ChatGPT-style assistant for the user's entire vault.
            Answer questions using the supplied vault context and the prior conversation turns.
            The user may type quickly and make spelling mistakes, missing spaces, or phonetic typos. Infer the intended meaning from vault titles, page content, and conversation history instead of rejecting the question for spelling.
            Resolve pronouns and follow-up phrases like "it", "that", and "what was it" from conversation history.
            Be direct, useful, and grounded. If the vault does not contain enough information, say what is missing.
            Return Markdown only. Do not edit the user's Markdown files.
            """
        )
    }

    private func helpDeskMarkdownPlacementInstructions() -> String {
        """
        You place Zirn Chat answers into the user's vault pages.
        Return JSON only with these keys: action, noteTitle, suggestedPageTitle, formattedMarkdown.
        action must be "append" when an existing page is the best fit, or "create" when no page matches.
        noteTitle must exactly match one supplied vault page title when action is append.
        suggestedPageTitle is required when action is create.
        formattedMarkdown is the Markdown body to append or use for the new page, without a top-level H1.
        """
    }

    private func highlightSummaryInstructions() -> String {
        """
        You are Zirn's highlight compiler. You turn selected highlighted excerpts into one coherent non-editable Markdown summary.
        Use only the supplied highlighted excerpts as factual source material.
        Preserve the user's writing style, rhythm, density, and vocabulary when possible.
        Return Markdown only. Do not include meta commentary, apologies, or code fences.
        """
    }

    private func homePageSummaryInstructions() -> String {
        personalizedSystemInstructions(
            """
            You are Zirn's Home page compiler. You synthesize every page in the user's vault into one read-only Home document.
            Use the supplied page contents or condensed page notes for summaries.
            Preserve the user's writing style, rhythm, density, and vocabulary when possible.
            Every sentence must be complete. Remove fragments, dangling clauses, placeholder text, artifacts, and unfinished thoughts.
            Strict length limits: Summary max 100 words. Each page summary max 100 words when previewed.
            Write the Summary as one compact paragraph, not bullets. Use compact bullet lists only for page summaries. Do not use tables, numbered lists, code blocks, divider lines, separator lines, or lines made only from repeated punctuation.
            Return Markdown only. Do not include meta commentary, apologies, or code fences.
            """
        )
    }

    private func pageFlashcardInstructions() -> String {
        """
        You create study flashcards for exactly one Markdown page.
        Use only the supplied page. Do not use the rest of the vault.
        Return JSON only with a top-level "cards" array.
        Each card must have "question", "answer", and "anchor" strings.
        Create 3 to 6 concise cards. Answers should be direct and useful.
        The anchor should be a short exact phrase from the source page that helps jump back to the idea.
        Do not include Markdown fences, commentary, or divider lines.
        """
    }

    private func homePageCondenseInstructions() -> String {
        """
        You condense one Markdown page for a later whole-vault summary.
        Preserve the page's concrete claims, important details, decisions, names, definitions, questions, and unresolved threads.
        Keep the user's terminology. Return compact Markdown notes only.
        """
    }

    private func highlightSummaryPrompt(sourceTitle: String, highlights: [String]) -> String {
        let highlightBody = pageHighlightChunk(title: sourceTitle, highlights: highlights)
            ?? "No highlighted data was found."

        return """
        Source session title:
        \(sourceTitle)

        Required heading:
        # Summary of \(sourceTitle)

        Assembled highlighted data:
        \(highlightBody)

        Task:
        Compile the assembled highlighted data into a coherent document with the required heading. Do not repeat the page title for every highlighted item. Prefer polished prose over a mechanical list unless a list is genuinely clearer.

        Learned user writing samples:
        \(learnedStyleMemory())

        Correction-derived preferences, strongest first:
        \(learnedCorrectionMemory())
        """
    }

    private func homePageSummaryPrompt(vaultName: String, sourceNotes: [HomePagePreparedNote]) -> String {
        let pageBody = sourceNotes.enumerated()
            .map { index, note in
                """
                ### Page \(index + 1): \(note.title)
                \(note.preparedMarkdown)
                """
            }
            .joined(separator: "\n\n")

        return """
        Vault:
        \(vaultName)

        Required structure:
        # Home

        ## Summary
        Write a coherent vault overview as one compact paragraph, max 100 words total. Combine related ideas across pages instead of listing pages one by one. Do not use bullets here.

        ## Page Summaries
        For each page, add a ### heading with the exact page title, then 2-4 short bullet points, max 100 words total for that page. No tables, numbered lists, code, divider lines, separator lines, or lines made only from repeated punctuation.
        Treat any "Top-priority highlighted excerpts" section as the strongest source for that page's summary before using the remaining page content.

        Page contents or condensed page notes:
        \(pageBody)

        Learned user writing samples:
        \(learnedStyleMemory())

        Correction-derived preferences, strongest first:
        \(learnedCorrectionMemory())\(userPersonalizationPromptSection())
        """
    }

    private func pageFlashcardPrompt(note: Note) -> String {
        """
        Page title:
        \(note.title)

        Markdown page content:
        \(note.content)
        """
    }

    private func parsePageFlashcards(from response: String, fallbackNote note: Note) throws -> [PageFlashcard] {
        let cleaned = cleanedAssistantMarkdown(response)
        let jsonText: String
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            jsonText = String(cleaned[start...end])
        } else {
            jsonText = cleaned
        }

        if let data = jsonText.data(using: .utf8),
           let payload = try? decoder.decode(PageFlashcardResponse.self, from: data) {
            let cards = payload.cards
                .map { card in
                    let answer = cleanedFlashcardText(card.answer)
                    return PageFlashcard(
                        id: UUID().uuidString,
                        question: cleanedFlashcardText(card.question, preservingLineBreaks: false),
                        answer: answer,
                        anchor: cleanedFlashcardText(card.anchor.isEmpty ? answer : card.anchor, preservingLineBreaks: false)
                    )
                }
                .filter { !$0.question.isEmpty && !$0.answer.isEmpty }
            if !cards.isEmpty {
                return cards
            }
        }

        let summary = cleanedFlashcardText(
            localPageSummary(for: HomePageSourceNote(
                id: note.id,
                title: note.title,
                content: note.content,
                updatedAt: note.updatedAt
            ))
        )
        return [
            PageFlashcard(
                id: UUID().uuidString,
                question: "What is the main idea of \(note.title)?",
                answer: summary,
                anchor: summary
            )
        ]
    }

    private func homePageSidebarGroupsDescription(sourceNotes: [HomePagePreparedNote]) -> String {
        var grouped: [String: [String]] = [:]
        var order: [String] = []

        for note in sourceNotes {
            let groupTitle = sidebarGroupTitle(forNoteID: note.id)
            if grouped[groupTitle] == nil {
                order.append(groupTitle)
                grouped[groupTitle] = []
            }
            grouped[groupTitle]?.append(note.title)
        }

        if order.isEmpty {
            return "No sidebar groups yet."
        }

        return order.map { groupTitle in
            let pages = grouped[groupTitle]?.joined(separator: ", ") ?? ""
            return "- \(groupTitle): \(pages.isEmpty ? "No pages" : pages)"
        }.joined(separator: "\n")
    }

    private func sidebarGroupTitle(forNoteID noteID: Note.ID) -> String {
        guard let groupID = sidebarGroupID(forNoteID: noteID),
              let group = sidebarGroup(for: groupID)
        else { return "Ungrouped" }
        return group.title
    }

    private func preparedHomePageNotes(
        from sourceNotes: [HomePageSourceNote],
        model: HighlightSummaryModel
    ) async throws -> [HomePagePreparedNote] {
        let totalCharacters = sourceNotes.reduce(0) { $0 + $1.content.count }
        let shouldCondenseVault = totalCharacters > Self.homeDirectCharacterBudget

        var prepared: [HomePagePreparedNote] = []
        for note in sourceNotes {
            let highlights = highlightedTextFragments(in: note.content)
            let cleanContent = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldCondenseNote = shouldCondenseVault || cleanContent.count > Self.homeNoteCondenseCharacterLimit
            let preparedMarkdown: String

            if shouldCondenseNote {
                let cacheKey = homePreparedNoteCacheKey(for: note)
                if let cached = homePreparedNoteCache[cacheKey] {
                    preparedMarkdown = cached.preparedMarkdown
                } else {
                    preparedMarkdown = try await condensedHomePageNote(
                        note: note,
                        highlights: highlights,
                        model: model
                    )
                    homePreparedNoteCache[cacheKey] = HomePreparedNoteCacheEntry(
                        preparedMarkdown: preparedMarkdown
                    )
                }
            } else {
                preparedMarkdown = homePageSourceMarkdownWithHighlightPriority(
                    note: note,
                    highlights: highlights,
                    content: cleanContent
                )
            }

            prepared.append(
                HomePagePreparedNote(
                    id: note.id,
                    title: note.title,
                    preparedMarkdown: preparedMarkdown,
                    highlights: highlights
                )
            )
        }

        return prepared
    }

    private func homePreparedNoteCacheKey(for note: HomePageSourceNote) -> String {
        stableFingerprint(for: "\(note.id)\u{1F}\(note.title)\u{1F}\(note.content)")
    }

    private func condensedHomePageNote(
        note: HomePageSourceNote,
        highlights: [String],
        model: HighlightSummaryModel
    ) async throws -> String {
        let prompt = homePageCondensePrompt(note: note, highlights: highlights)
        let result: ChatCompletionResult

        switch model {
        case .mistral:
            result = try await generateWithMistral(
                system: homePageCondenseInstructions(),
                user: prompt,
                maxTokens: 1_500
            )
        case .deepseek:
            result = try await generateWithDeepSeek(
                system: homePageCondenseInstructions(),
                user: prompt,
                maxTokens: 1_500
            )
        case .ollama:
            result = try await generateWithOllama(
                system: homePageCondenseInstructions(),
                user: prompt
            )
        }
        recordUsage(
            for: model,
            result: result,
            fallbackInputTokens: estimatedTokenCount(for: prompt),
            fallbackOutputTokens: estimatedTokenCount(for: result.content)
        )

        let clean = cleanedAssistantMarkdown(result.content)
        return clean.isEmpty ? promptExcerpt(note.content) : clean
    }

    private func homePageCondensePrompt(note: HomePageSourceNote, highlights: [String]) -> String {
        let highlightBody = pageHighlightChunk(title: note.title, highlights: highlights)
            ?? "No highlighted excerpts in this page."

        return """
        Page title:
        \(note.title)

        Assembled highlighted data to preserve:
        \(highlightBody)

        Full Markdown page:
        \(note.content)

        Task:
        Condense this page into compact Markdown notes for a whole-vault Home summary. Treat the assembled highlighted data as the top priority before the rest of the page. Preserve all important details and do not invent anything.
        """
    }

    private func homePageSourceMarkdownWithHighlightPriority(
        note: HomePageSourceNote,
        highlights: [String],
        content: String
    ) -> String {
        guard let highlightBody = pageHighlightChunk(title: note.title, highlights: highlights) else {
            return content
        }

        return """
        Top-priority highlighted excerpts:
        \(highlightBody)

        Remaining page content:
        \(content)
        """
    }

    private func persistImmediateHomeSummary(
        vaultName: String,
        sourceNotes: [HomePageSourceNote],
        modelTitle: String,
        sourceFingerprint: String,
        sourceDiceTokens: [String]
    ) {
        let markdown = localHomePageMarkdown(vaultName: vaultName, sourceNotes: sourceNotes)
        let summary = HighlightSummary(
            id: homeSummaryID,
            sourceNoteID: "vault",
            sourceTitle: vaultName,
            title: "Home",
            markdown: markdown,
            compiledAt: Date(),
            compileDuration: 0,
            modelTitle: modelTitle,
            sourceFingerprint: sourceFingerprint,
            sourceDiceTokens: sourceDiceTokens
        )

        do {
            try persistHighlightSummary(summary)
            upsertHighlightSummary(summary)
            if isShowingHomePage {
                title = "Home"
                content = markdown
            }
        } catch {
            status = error.localizedDescription
        }
    }

    private func localHomePageMarkdown(vaultName: String, sourceNotes: [HomePageSourceNote]) -> String {
        let vaultSummary = plainHomePageSummaryText(localVaultSummary(from: sourceNotes), maxWords: 100)
        let pageSummarySection = localPageCards(from: sourceNotes)
            .map { card in
                """
                ### \(card.title)

                \(card.summary)
                """
            }
            .joined(separator: "\n\n")
        let pageCardsBody = pageSummarySection.isEmpty
            ? "No pages yet. Press Cmd N to start a new page."
            : pageSummarySection

        return """
        # Home

        ## Summary

        \(vaultSummary)

        ## Page Summaries

        \(pageCardsBody)
        """
    }

    private func localVaultSummary(from sourceNotes: [HomePageSourceNote]) -> String {
        let pageCount = sourceNotes.count
        let titles = sourceNotes.map(\.title).joined(separator: ", ")
        let combinedPreview = sourceNotes
            .map { localPageSummary(for: $0, sentenceLimit: 1, wordLimit: 24) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if combinedPreview.isEmpty {
            return wordLimited("This vault has \(pageCount) page\(pageCount == 1 ? "" : "s"): \(titles). Add body text to the pages and Home will summarize them automatically.", maxWords: 100)
        }

        return wordLimited("This vault has \(pageCount) page\(pageCount == 1 ? "" : "s"): \(titles). \(combinedPreview)", maxWords: 100)
    }

    private func localPageSummary(
        for note: HomePageSourceNote,
        sentenceLimit: Int = 4,
        wordLimit: Int = 100
    ) -> String {
        let plain = plainText(fromMarkdown: note.content)
        let prioritizedHighlights = highlightedTextFragments(in: note.content)
            .map { plainText(fromMarkdown: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        let withoutTitle = plain
            .replacingOccurrences(of: note.title, with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let bodySource = withoutTitle.isEmpty ? plain : withoutTitle
        let source = prioritizedHighlights.isEmpty
            ? bodySource
            : "\(prioritizedHighlights). \(bodySource)"
        guard !source.isEmpty else {
            return "No body text yet."
        }

        let sentences = source
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let selected = sentences.isEmpty
            ? String(source.prefix(220))
            : sentences.prefix(sentenceLimit).joined(separator: ". ")

        let clean = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        let punctuated = clean.hasSuffix(".") ? clean : "\(clean)."
        return wordLimited(punctuated, maxWords: wordLimit)
    }

    private func localPageCards(from sourceNotes: [HomePageSourceNote]) -> [HomePagePageCard] {
        sourceNotes.map { note in
            let summary = localPageSummary(for: note, sentenceLimit: 8, wordLimit: 100)
            return HomePagePageCard(
                id: note.id,
                title: note.title,
                summary: bulletedHomePageSummary(summary, maxWords: 100),
                noteID: note.id
            )
        }
    }

    private func localFlashcardGroups(from sourceNotes: [HomePageSourceNote]) -> [HomePageFlashcardGroup] {
        var groupedCards: [String: [HomePageFlashcard]] = [:]
        var order: [String] = []

        for note in sourceNotes {
            let highlights = highlightedTextFragments(in: note.content)
                .map { cleanedFlashcardText($0) }
                .filter { !$0.isEmpty }
            guard !highlights.isEmpty else { continue }

            let groupTitle = sidebarGroupTitle(forNoteID: note.id)
            if groupedCards[groupTitle] == nil {
                order.append(groupTitle)
                groupedCards[groupTitle] = []
            }

            for (index, highlight) in highlights.enumerated() {
                groupedCards[groupTitle]?.append(
                    HomePageFlashcard(
                        id: "\(note.id)-\(index)",
                        question: localFlashcardQuestion(for: highlight, pageTitle: note.title),
                        answer: lineLimited(highlight, maxLines: 4)
                    )
                )
            }
        }

        return order.compactMap { title in
            guard let cards = groupedCards[title], !cards.isEmpty else { return nil }
            return HomePageFlashcardGroup(id: title, title: title, cards: cards)
        }
    }

    private func localFlashcardQuestion(for highlight: String, pageTitle: String) -> String {
        let trimmed = cleanedFlashcardText(highlight, preservingLineBreaks: false)
            .replacingOccurrences(of: "• ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 {
            return "What key idea from \(pageTitle) is captured here?"
        }
        let preview = String(trimmed.prefix(90)).trimmingCharacters(in: .whitespacesAndNewlines)
        return "Explain the highlighted concept from \(pageTitle): \"\(preview)...\""
    }

    private func cleanedFlashcardText(_ text: String, preservingLineBreaks: Bool = true) -> String {
        var output = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let replacements: [(pattern: String, template: String)] = [
            (#"(?s)%%.*?%%"#, ""),
            (#"\[\[([^\]\|]+)\|([^\]]+)\]\]"#, "$2"),
            (#"\[\[([^\]]+)\]\]"#, "$1"),
            (#"!\[([^\]]*)\]\([^)]+\)"#, "$1"),
            (#"\[([^\]]+)\]\([^)]+\)"#, "$1"),
            (#"(?s)==(.+?)=="#, "$1"),
            (#"</?u>"#, ""),
            (#"(?s)\*\*(.+?)\*\*"#, "$1"),
            (#"(?s)__(.+?)__"#, "$1"),
            (#"(?s)~~(.+?)~~"#, "$1"),
            (#"`([^`]+)`"#, "$1"),
            (#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, "$1"),
            (#"(?<!_)_([^_\n]+)_(?!_)"#, "$1")
        ]

        for replacement in replacements {
            output = output.replacingOccurrences(
                of: replacement.pattern,
                with: replacement.template,
                options: .regularExpression
            )
        }

        let lines = output
            .components(separatedBy: .newlines)
            .map { rawLine -> String in
                var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                line = line.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
                line = line.replacingOccurrences(of: #"^>\s?"#, with: "", options: .regularExpression)
                line = line.replacingOccurrences(of: #"^[-*+]\s+"#, with: "• ", options: .regularExpression)
                line = line.replacingOccurrences(of: #"^\d+[\.)]\s+"#, with: "", options: .regularExpression)
                return line
            }
            .filter { !$0.isEmpty }

        if preservingLineBreaks {
            return lines.joined(separator: "\n")
        }

        return lines.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func flashcardErrorMessage(from error: Error) -> String {
        let rawMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if rawMessage.localizedCaseInsensitiveContains("rate_limited")
            || rawMessage.localizedCaseInsensitiveContains("rate limit")
            || rawMessage.contains("\"429\"")
            || rawMessage.contains(":429") {
            return "Rate limit hit. Showing local flashcards; try regenerate again in a moment."
        }

        if let data = rawMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }

            if let object = json["object"] as? String,
               object == "error",
               let code = json["code"] as? String,
               !code.isEmpty {
                return "Flashcard generation failed: \(code)."
            }
        }

        return rawMessage.isEmpty ? "Flashcard generation failed." : rawMessage
    }

    private func lineLimited(_ text: String, maxLines: Int) -> String {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !lines.isEmpty else { return text }
        guard lines.count > maxLines else { return lines.joined(separator: "\n") }
        return lines.prefix(maxLines).joined(separator: "\n")
    }

    private func wordLimited(_ text: String, maxWords: Int) -> String {
        let words = text
            .split { $0.isWhitespace || $0.isNewline }
            .map(String.init)
        guard words.count > maxWords else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        let limited = words.prefix(maxWords).joined(separator: " ")
        let trimmed = limited.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-"))
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            return trimmed
        }
        return "\(trimmed)..."
    }

    private func bulletedHomePageSummary(_ text: String, maxWords: Int = 100) -> String {
        let limited = wordLimited(plainText(fromMarkdown: text), maxWords: maxWords)
        let sentences = limited
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let items = sentences.isEmpty ? [limited] : Array(sentences.prefix(4))
        return items
            .map { item in
                let clean = item.trimmingCharacters(in: .whitespacesAndNewlines)
                return clean.hasSuffix(".") || clean.hasSuffix("!") || clean.hasSuffix("?")
                    ? "- \(clean)"
                    : "- \(clean)."
            }
            .joined(separator: "\n")
    }

    private func plainHomePageSummaryText(
        _ markdown: String,
        maxWords: Int = 100,
        preserveBullets: Bool = true
    ) -> String {
        let cleanedLines = markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard !isMarkdownDividerLine(trimmed) else { return nil }
                if trimmed.contains("|") {
                    let pipeCount = trimmed.filter { $0 == "|" }.count
                    if pipeCount >= 2 || trimmed.hasPrefix("|") {
                        return nil
                    }
                }
                if trimmed.hasPrefix("```") {
                    return nil
                }
                if preserveBullets,
                   trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                    let body = String(trimmed.dropFirst(2))
                    let clean = plainText(fromMarkdown: body)
                    return clean.isEmpty ? nil : "- \(clean)"
                }
                return plainText(fromMarkdown: trimmed)
            }
            .joined(separator: "\n")

        return wordLimitedMarkdownLines(cleanedLines, maxWords: maxWords)
    }

    private func wordLimitedMarkdownLines(_ text: String, maxWords: Int) -> String {
        var remaining = maxWords
        var output: [String] = []

        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            guard remaining > 0 else { break }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let marker: String
            let body: String
            if trimmed.hasPrefix("- ") {
                marker = "- "
                body = String(trimmed.dropFirst(2))
            } else {
                marker = ""
                body = trimmed
            }

            let words = body.split { $0.isWhitespace || $0.isNewline }.map(String.init)
            guard !words.isEmpty else { continue }
            let takeCount = min(remaining, words.count)
            remaining -= takeCount
            var limited = words.prefix(takeCount).joined(separator: " ")
            if takeCount < words.count {
                limited = limited.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-")) + "..."
            }
            output.append("\(marker)\(limited)")
        }

        return output.joined(separator: "\n")
    }

    private func isMarkdownDividerLine(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 2 else { return false }
        return compact.allSatisfy { character in
            character == "=" || character == "-" || character == "_" || character == "*"
        }
    }

    private func extractHomeSummarySection(from markdown: String) -> String? {
        extractHomeSection("Summary", from: markdown)
            ?? extractHomeSection("Vault Summary", from: markdown)
    }

    private func parseHomePagePresentation(from markdown: String) -> HomePagePresentation {
        let vaultSummary = plainHomePageSummaryText(
            lineLimited(
                extractHomeSummarySection(from: markdown) ?? "",
                maxLines: 7
            ),
            maxWords: 100,
            preserveBullets: false
        )
        let pageCards = parsePageSummaryCards(from: extractHomeSection("Page Summaries", from: markdown) ?? "")

        return HomePagePresentation(
            vaultSummary: vaultSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            pageCards: pageCards,
            flashcardGroups: []
        )
    }

    private func enrichHomePagePresentation(_ presentation: HomePagePresentation) -> HomePagePresentation {
        let enrichedCards = presentation.pageCards.map { card in
            HomePagePageCard(
                id: card.id,
                title: card.title,
                summary: plainHomePageSummaryText(card.summary),
                noteID: card.noteID ?? notes.first(where: {
                    normalizedLinkTitle($0.title) == normalizedLinkTitle(card.title)
                })?.id
            )
        }

        return HomePagePresentation(
            vaultSummary: plainHomePageSummaryText(
                lineLimited(presentation.vaultSummary, maxLines: 7),
                maxWords: 100,
                preserveBullets: false
            ),
            pageCards: enrichedCards,
            flashcardGroups: []
        )
    }

    private func homePresentationEnsuringAllPages(
        _ presentation: HomePagePresentation,
        sourceNotes: [HomePageSourceNote]
    ) -> HomePagePresentation {
        let existingTitles = Set(presentation.pageCards.map { normalizedLinkTitle($0.title) })
        let missingCards = localPageCards(from: sourceNotes).filter { card in
            !existingTitles.contains(normalizedLinkTitle(card.title))
        }

        guard !missingCards.isEmpty else { return presentation }

        return HomePagePresentation(
            vaultSummary: presentation.vaultSummary,
            pageCards: presentation.pageCards + missingCards,
            flashcardGroups: []
        )
    }

    private func extractHomeSection(_ name: String, from markdown: String) -> String? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let heading = "## \(name)"
        guard let startIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == heading
        }) else {
            return nil
        }

        var endIndex = lines.count
        for index in (startIndex + 1)..<lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("## ") {
                endIndex = index
                break
            }
        }

        let body = lines[(startIndex + 1)..<endIndex].joined(separator: "\n")
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsePageSummaryCards(from section: String) -> [HomePagePageCard] {
        guard !section.isEmpty else { return [] }

        var cards: [HomePagePageCard] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flushCard() {
            guard let title = currentTitle else { return }
            let summary = plainHomePageSummaryText(
                currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard !summary.isEmpty else { return }
            cards.append(
                HomePagePageCard(
                    id: title,
                    title: title,
                    summary: summary,
                    noteID: nil
                )
            )
        }

        for line in section.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("### ") {
                flushCard()
                currentTitle = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentLines = []
            } else if currentTitle != nil {
                currentLines.append(line)
            }
        }

        flushCard()
        return cards
    }

    private func parseFlashcardGroups(from section: String) -> [HomePageFlashcardGroup] {
        guard !section.isEmpty else { return [] }

        var groups: [HomePageFlashcardGroup] = []
        let chunks = section.components(separatedBy: "### Group:")
        for chunk in chunks.dropFirst() {
            let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard let firstLine = lines.first else { continue }
            let groupTitle = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = lines.dropFirst().joined(separator: "\n")
            let cards = parseFlashcards(from: body, groupID: groupTitle)
            guard !cards.isEmpty else { continue }
            groups.append(
                HomePageFlashcardGroup(
                    id: groupTitle,
                    title: groupTitle,
                    cards: cards
                )
            )
        }
        return groups
    }

    private func parseFlashcards(from body: String, groupID: String) -> [HomePageFlashcard] {
        var cards: [HomePageFlashcard] = []
        var currentQuestion: String?
        var cardIndex = 0

        for line in body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("Q:") {
                currentQuestion = cleanedFlashcardText(
                    String(trimmed.dropFirst(2)),
                    preservingLineBreaks: false
                )
            } else if trimmed.hasPrefix("A:"), let question = currentQuestion {
                let answer = lineLimited(
                    cleanedFlashcardText(String(trimmed.dropFirst(2))),
                    maxLines: 4
                )
                cards.append(
                    HomePageFlashcard(
                        id: "\(groupID)-\(cardIndex)",
                        question: question,
                        answer: answer
                    )
                )
                cardIndex += 1
                currentQuestion = nil
            }
        }

        return cards
    }

    private func pageHighlightChunk(title: String, highlights: [String]) -> String? {
        let cleanHighlights = highlights
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanHighlights.isEmpty else { return nil }

        let body = cleanHighlights
            .map { "- \($0)" }
            .joined(separator: "\n")

        return """
        ### \(title)

        \(body)
        """
    }

    private func homeSourceFingerprint(for sourceNotes: [HomePageSourceNote]) -> String {
        let source = sourceNotes
            .sorted { $0.id < $1.id }
            .map { note in
                "\(note.id)\u{1F}\(note.title)\u{1F}\(note.content)"
            }
            .joined(separator: "\u{1E}")
        return stableFingerprint(for: source)
    }

    private func homeSourceText(for sourceNotes: [HomePageSourceNote]) -> String {
        sourceNotes
            .sorted { $0.id < $1.id }
            .map { note in
                "\(note.title)\n\(plainText(fromMarkdown: note.content))"
            }
            .joined(separator: "\n\n")
    }

    private func homeSourceDiceTokens(for sourceNotes: [HomePageSourceNote]) -> [String] {
        let tokenCharacters = CharacterSet.alphanumerics.inverted
        let tokens = homeSourceText(for: sourceNotes)
            .lowercased()
            .components(separatedBy: tokenCharacters)
            .filter { $0.count >= 2 }
        return Array(Set(tokens)).sorted()
    }

    private func pageFlashcardDiceTokens(for content: String) -> [String] {
        let tokenCharacters = CharacterSet.alphanumerics.inverted
        let tokens = plainText(fromMarkdown: content)
            .lowercased()
            .components(separatedBy: tokenCharacters)
            .filter { $0.count >= 2 }
        return Array(Set(tokens)).sorted()
    }

    private func homeSourceDiceSimilarity(_ previousTokens: [String], _ currentTokens: [String]) -> Double? {
        if previousTokens.isEmpty && currentTokens.isEmpty {
            return 1
        }

        guard !previousTokens.isEmpty, !currentTokens.isEmpty else { return nil }

        let previous = Set(previousTokens)
        let current = Set(currentTokens)
        let intersectionCount = previous.intersection(current).count
        return (2 * Double(intersectionCount)) / Double(previous.count + current.count)
    }

    private func refreshHomeSummarySourceSignature(
        _ fingerprint: String,
        sourceDiceTokens: [String],
        sourceNotes: [HomePageSourceNote]? = nil
    ) {
        guard let existing = latestHomeSummary else { return }
        let markdown: String
        if let sourceNotes {
            markdown = homeMarkdownEnsuringAllPages(existing.markdown, sourceNotes: sourceNotes)
        } else {
            markdown = existing.markdown
        }
        let updated = HighlightSummary(
            id: existing.id,
            sourceNoteID: existing.sourceNoteID,
            sourceTitle: existing.sourceTitle,
            title: existing.title,
            markdown: markdown,
            compiledAt: existing.compiledAt,
            compileDuration: existing.compileDuration,
            modelTitle: existing.modelTitle,
            sourceFingerprint: fingerprint,
            sourceDiceTokens: sourceDiceTokens
        )
        do {
            try persistHighlightSummary(updated)
            upsertHighlightSummary(updated)
        } catch {
            status = error.localizedDescription
        }
    }

    private func loadPageFlashcardCache(noteID: Note.ID) throws -> PageFlashcardCacheFile? {
        guard let brain = activeBrain else { return nil }
        let url = pageFlashcardURL(noteID: noteID, in: brain)
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            if let cache = try? decoder.decode(PageFlashcardCacheFile.self, from: data) {
                return isGeneratedPageFlashcardBundle(cache.bundle) ? cache : nil
            }

            let legacyBundle = try decoder.decode(PageFlashcardBundle.self, from: data)
            guard isGeneratedPageFlashcardBundle(legacyBundle) else { return nil }
            let migrated = initialPageFlashcardCache(for: legacyBundle)
            try persistPageFlashcardCache(migrated)
            return migrated
        }

        let legacyURL = legacyPageFlashcardURL(noteID: noteID, in: brain)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return nil }
        let legacyBundle = try decoder.decode(PageFlashcardBundle.self, from: Data(contentsOf: legacyURL))
        guard isGeneratedPageFlashcardBundle(legacyBundle) else { return nil }
        let migrated = initialPageFlashcardCache(for: legacyBundle)
        try persistPageFlashcardCache(migrated)
        return migrated
    }

    private func persistPageFlashcardCache(_ cache: PageFlashcardCacheFile) throws {
        guard let brain = activeBrain else { return }
        let folder = pageFlashcardsFolderURL(for: brain)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try ensureVaultGitignoreHidesPageFlashcards(in: brain)
        let url = pageFlashcardURL(noteID: cache.bundle.noteID, in: brain)
        try encoder.encode(cache).write(to: url, options: .atomic)
    }

    private func initialPageFlashcardCache(for bundle: PageFlashcardBundle) -> PageFlashcardCacheFile {
        PageFlashcardCacheFile(
            version: PageFlashcardCacheFile.currentVersion,
            bundle: bundle,
            pinnedCardIDs: [],
            previousSimilarityScore: nil,
            latestSimilarityScore: 1,
            similarityThreshold: Self.pageFlashcardSimilarityRegenerateThreshold,
            lastCheckedAt: Date()
        )
    }

    private func refreshedPageFlashcardCache(
        _ cache: PageFlashcardCacheFile,
        latestSimilarityScore: Double?
    ) -> PageFlashcardCacheFile {
        PageFlashcardCacheFile(
            version: PageFlashcardCacheFile.currentVersion,
            bundle: pageFlashcardBundle(cache.bundle, sortingPinnedCardIDs: pinnedPageFlashcardIDs(in: cache)),
            pinnedCardIDs: cache.pinnedCardIDs ?? [],
            previousSimilarityScore: cache.latestSimilarityScore,
            latestSimilarityScore: latestSimilarityScore,
            similarityThreshold: Self.pageFlashcardSimilarityRegenerateThreshold,
            lastCheckedAt: Date()
        )
    }

    private func existingGeneratedPageFlashcardBundle(for noteID: Note.ID) -> PageFlashcardBundle? {
        guard let bundle = pageFlashcardStates[noteID]?.bundle,
              isGeneratedPageFlashcardBundle(bundle)
        else { return nil }
        return bundle
    }

    private func existingPinnedPageFlashcardIDs(for noteID: Note.ID) -> Set<String> {
        pageFlashcardStates[noteID]?.pinnedCardIDs ?? []
    }

    private func pinnedPageFlashcardIDs(in cache: PageFlashcardCacheFile) -> Set<String> {
        Set(cache.pinnedCardIDs ?? [])
    }

    private func pageFlashcardBundle(
        _ bundle: PageFlashcardBundle,
        sortingPinnedCardIDs pinnedIDs: Set<String>
    ) -> PageFlashcardBundle {
        guard !pinnedIDs.isEmpty else { return bundle }
        let pinnedCards = bundle.cards.filter { pinnedIDs.contains($0.id) }
        let unpinnedCards = bundle.cards.filter { !pinnedIDs.contains($0.id) }
        return PageFlashcardBundle(
            noteID: bundle.noteID,
            noteTitle: bundle.noteTitle,
            sourceFingerprint: bundle.sourceFingerprint,
            sourceDiceTokens: bundle.sourceDiceTokens,
            generatedAt: bundle.generatedAt,
            modelTitle: bundle.modelTitle,
            cards: pinnedCards + unpinnedCards
        )
    }

    private func pageFlashcardBundle(
        _ generated: PageFlashcardBundle,
        preservingPinnedCardsFrom cache: PageFlashcardCacheFile?
    ) -> PageFlashcardBundle {
        guard let cache else { return generated }
        let cachedCards = pageFlashcardBundle(
            cache.bundle,
            sortingPinnedCardIDs: pinnedPageFlashcardIDs(in: cache)
        ).cards
        guard !cachedCards.isEmpty else { return generated }

        var seenKeys = Set(cachedCards.map { pageFlashcardQuestionKey($0.question) })
        let regeneratedCards = generated.cards.filter { card in
            let key = pageFlashcardQuestionKey(card.question)
            guard !seenKeys.contains(key) else { return false }
            seenKeys.insert(key)
            return true
        }

        return PageFlashcardBundle(
            noteID: generated.noteID,
            noteTitle: generated.noteTitle,
            sourceFingerprint: generated.sourceFingerprint,
            sourceDiceTokens: generated.sourceDiceTokens,
            generatedAt: generated.generatedAt,
            modelTitle: generated.modelTitle,
            cards: cachedCards + regeneratedCards
        )
    }

    private func pageFlashcardQuestionKey(_ question: String) -> String {
        question
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func isGeneratedPageFlashcardBundle(_ bundle: PageFlashcardBundle) -> Bool {
        bundle.modelTitle != "Local instant flashcards"
    }

    private func ensureVaultGitignoreHidesPageFlashcards(in brain: BrainSummary) throws {
        let gitignoreURL = brain.folderURL.appendingPathComponent(".gitignore")
        let existing = (try? String(contentsOf: gitignoreURL, encoding: .utf8)) ?? ""
        let lines = existing
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !lines.contains(".fcard/") else { return }

        let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
        let updated = "\(existing)\(separator).fcard/\n"
        try Data(updated.utf8).write(to: gitignoreURL, options: .atomic)
    }

    private func pageFlashcardURL(noteID: Note.ID, in brain: BrainSummary) -> URL {
        pageFlashcardsFolderURL(for: brain)
            .appendingPathComponent("\(stableFingerprint(for: noteID)).flshcrd")
    }

    private func legacyPageFlashcardURL(noteID: Note.ID, in brain: BrainSummary) -> URL {
        pageFlashcardsFolderURL(for: brain)
            .appendingPathComponent("\(stableFingerprint(for: noteID)).json")
    }

    private func stableFingerprint(for text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func normalizedHighlightSummaryMarkdown(_ markdown: String, sourceTitle: String) -> String {
        let clean = cleanedAssistantMarkdown(markdown)
        let requiredHeading = "# Summary of \(sourceTitle)"
        guard !clean.isEmpty else { return requiredHeading }

        let lines = clean.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first else { return requiredHeading }
        if first.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("# ") {
            return ([requiredHeading] + lines.dropFirst().map(String.init)).joined(separator: "\n")
        }
        return "\(requiredHeading)\n\n\(clean)"
    }

    private func normalizedHomePageMarkdown(
        _ markdown: String,
        fallbackMarkdown: String? = nil,
        sourceNotes: [HomePageSourceNote]? = nil
    ) -> String {
        let clean = sanitizedHomePageMarkdown(cleanedAssistantMarkdown(markdown))
        guard !clean.isEmpty else {
            return fallbackMarkdown ?? """
            # Home

            ## Summary

            No Home summary generated yet.

            ## Page Summaries

            No pages yet.
            """
        }

        let lines = clean.split(separator: "\n", omittingEmptySubsequences: false)
        let normalized: String
        guard let first = lines.first else { return "# Home" }
        if first.trimmingCharacters(in: .whitespacesAndNewlines) == "# Home" {
            normalized = clean
        } else if first.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("# ") {
            normalized = (["# Home"] + lines.dropFirst().map(String.init)).joined(separator: "\n")
        } else {
            normalized = "# Home\n\n\(clean)"
        }

        guard let sourceNotes else { return normalized }
        return homeMarkdownEnsuringAllPages(normalized, sourceNotes: sourceNotes)
    }

    private func homeMarkdownEnsuringAllPages(
        _ markdown: String,
        sourceNotes: [HomePageSourceNote]
    ) -> String {
        let existingCards = parsePageSummaryCards(from: extractHomeSection("Page Summaries", from: markdown) ?? "")
        let existingTitles = Set(existingCards.map { normalizedLinkTitle($0.title) })
        let missingCards = localPageCards(from: sourceNotes).filter { card in
            !existingTitles.contains(normalizedLinkTitle(card.title))
        }

        guard !missingCards.isEmpty else { return markdown }

        let missingMarkdown = missingCards
            .map { card in
                """
                ### \(card.title)

                \(card.summary)
                """
            }
            .joined(separator: "\n\n")

        if markdown.range(of: "\n## Page Summaries\n") == nil {
            return "\(markdown)\n\n## Page Summaries\n\n\(missingMarkdown)"
        }

        return "\(markdown)\n\n\(missingMarkdown)"
    }

    private func sanitizedHomePageMarkdown(_ markdown: String) -> String {
        let lines = markdown
            .replacingOccurrences(of: "\u{FFFD}", with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = clean.lowercased()
                return !isMarkdownDividerLine(clean)
                    && !lower.hasPrefix("artifact:")
                    && !lower.hasPrefix("incomplete")
                    && !lower.contains("undefined")
                    && !lower.contains("<|")
                    && !lower.contains("|>")
            }

        var sanitized = lines
        while let last = sanitized.last {
            let clean = last.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty {
                sanitized.removeLast()
                continue
            }
            if isCompleteHomeMarkdownLine(clean) {
                break
            }
            sanitized.removeLast()
        }

        let text = sanitized.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let requiredSections = ["## Summary", "## Page Summaries"]
        let legacySections = [
            ["## Summary", "## Page Summaries", "## Highlight Flashcards"],
            ["## Vault Summary", "## Page Summaries", "## Highlight Flashcards"],
            ["## Vault Summary", "## Highlighted Text Summary"]
        ]
        guard requiredSections.allSatisfy({ text.contains($0) })
            || legacySections.contains(where: { sections in sections.allSatisfy { text.contains($0) } })
        else { return "" }
        return text
    }

    private func isCompleteHomeMarkdownLine(_ line: String) -> Bool {
        if line.hasPrefix("#") { return true }
        if line.hasSuffix("```") { return true }
        if line.hasSuffix(")") || line.hasSuffix("]") { return true }
        if line.hasSuffix(".") || line.hasSuffix("!") || line.hasSuffix("?") || line.hasSuffix(":") { return true }
        if line.count < 32 { return true }
        return false
    }

    private func promptExcerpt(_ markdown: String, characterLimit: Int = 3_500) -> String {
        let clean = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > characterLimit else { return clean }
        return "\(clean.prefix(characterLimit))\n..."
    }

    private func assistantInput(for prompt: String, linkedPageTitles: [String]) -> String {
        """
        User request:
        \(prompt.isEmpty && linkedPageTitles.isEmpty ? "Use the attached document to update or extend the current Markdown document." : prompt)

        Linked Markdown pages selected in the prompt:
        \(assistantPromptLinksContext(linkedPageTitles))

        Attached document:
        \(assistantAttachmentContext(for: prompt, linkedPageTitles: linkedPageTitles, intent: .writing))

        Current document title:
        \(title)

        Current Markdown document:
        \(content)

        Required output:
        Return the complete revised Markdown document only.
        If the user request has typos or missing spaces, silently infer the intended words from context.
        When referring to any selected linked page, use its exact Obsidian wiki link form, such as [[Page Title]].
        Do not end with a follow-up question, offer, invitation, or line like "Would you like an example...?"

        Learned user writing samples:
        \(learnedStyleMemory())

        Correction-derived preferences, strongest first:
        \(learnedCorrectionMemory())
        """
    }

    private func assistantConversationInput(for prompt: String, linkedPageTitles: [String]) -> String {
        assistantConversationContext(
            for: prompt,
            linkedPageTitles: linkedPageTitles,
            characterBudget: Self.assistantConversationContextBudget
        ).input
    }

    private func assistantConversationContext(
        for prompt: String,
        linkedPageTitles: [String],
        characterBudget: Int
    ) -> AssistantConversationContext {
        let startedAt = Date()
        var remainingBudget = characterBudget
        var includedSources: [String] = []
        var sections: [String] = []

        func appendSection(_ title: String, _ body: String) {
            guard remainingBudget > 0 else { return }
            let section = "\(title):\n\(body.trimmingCharacters(in: .whitespacesAndNewlines))"
            let excerpt = promptExcerpt(section, characterLimit: remainingBudget)
            remainingBudget -= excerpt.count
            sections.append(excerpt)
        }

        let linkedPages = assistantPromptLinksContext(linkedPageTitles)
        appendSection("Linked Markdown pages selected in the prompt", linkedPages)
        if linkedPages != "None" {
            includedSources.append("linked pages")
        }

        let attachmentLimit = min(3_500, max(1_200, characterBudget / 3))
        let attachmentContext = assistantAttachmentContext(
            for: prompt,
            linkedPageTitles: linkedPageTitles,
            intent: .conversation,
            characterLimit: attachmentLimit
        )
        appendSection("Attached document", attachmentContext)
        if !attachmentContext.hasPrefix("None") {
            includedSources.append("attachment")
        }

        let currentPageContext = currentPageConversationContext(
            prompt: prompt,
            characterBudget: max(1_200, remainingBudget)
        )
        appendSection("Current Markdown document", currentPageContext.text)
        includedSources.append(currentPageContext.sourceSummary)

        let input = """
        User question:
        \(prompt.isEmpty && linkedPageTitles.isEmpty ? "Answer using the attached document and current note as context." : prompt)

        Current document title:
        \(title)

        Context:
        \(sections.joined(separator: "\n\n"))

        Required output:
        Answer the user. Do not rewrite the Markdown file.
        If the question has typos or missing spaces, silently infer the intended words from context.
        """

        return AssistantConversationContext(
            input: input,
            estimatedTokens: estimatedTokenCount(for: input),
            includedSources: includedSources.joined(separator: ", "),
            buildDuration: Date().timeIntervalSince(startedAt),
            characterBudget: characterBudget
        )
    }

    private func currentPageConversationContext(prompt: String, characterBudget: Int) -> (text: String, sourceSummary: String) {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanContent.count <= min(Self.assistantConversationSmallPageCharacterLimit, characterBudget) {
            return (cleanContent, "full current page")
        }

        var remainingBudget = characterBudget
        var sections: [String] = []

        func appendChunk(_ chunk: String) {
            guard remainingBudget > 0 else { return }
            let excerpt = promptExcerpt(chunk, characterLimit: remainingBudget)
            remainingBudget -= excerpt.count
            sections.append(excerpt)
        }

        let headings = markdownHeadings(in: content).prefix(24).joined(separator: "\n")
        if !headings.isEmpty {
            appendChunk("Page outline:\n\(headings)")
        }

        let rankedBlocks = rankedCurrentPageBlocks(for: prompt)
        let selectedBlocks = rankedBlocks.isEmpty
            ? markdownSearchBlocks(from: content).prefix(5).map { $0.text }
            : rankedBlocks.prefix(8).map { $0.text }

        for block in selectedBlocks {
            appendChunk(block)
        }

        let summary = rankedBlocks.isEmpty
            ? "current page outline + opening blocks"
            : "current page outline + \(min(8, rankedBlocks.count)) ranked blocks"
        return (sections.joined(separator: "\n\n"), summary)
    }

    private func rankedCurrentPageBlocks(for prompt: String) -> [HelpDeskContextCandidate] {
        let tokens = helpDeskRetrievalTokens(in: prompt)
        guard !tokens.isEmpty else { return [] }
        let normalizedQuery = normalizedSearchText(prompt)
        return markdownSearchBlocks(from: content).compactMap { block -> HelpDeskContextCandidate? in
            let blockText = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !blockText.isEmpty else { return nil }
            let normalizedBlock = normalizedSearchText(blockText)
            let blockTokens = searchTokens(in: blockText)
            var score = 0.0
            for token in tokens {
                if normalizedBlock.contains(token) {
                    score += 5
                } else if blockTokens.contains(where: { helpDeskTokensMatch(token, $0) }) {
                    score += 3
                }
            }
            if !normalizedQuery.isEmpty, normalizedBlock.contains(normalizedQuery) {
                score += 18
            }
            guard score > 0 else { return nil }
            return HelpDeskContextCandidate(
                noteID: currentNoteID ?? "current",
                title: title,
                text: blockText,
                score: score,
                updatedAt: Date()
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.text.count > rhs.text.count
        }
    }

    private func markdownHeadings(in markdown: String) -> [String] {
        markdown
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("#") else { return nil }
                return trimmed
            }
    }

    private func assistantConversationInsertionInput(for response: AssistantConversationResponse) -> String {
        """
        Current document title:
        \(title)

        Current Markdown document:
        \(content)

        Recent conversation:
        \(assistantConversationTranscript())

        Latest user question:
        \(response.prompt)

        Conversation-mode answer to weave into the document:
        \(response.answer)

        Required output:
        Return the complete revised Markdown document only.
        Add the answer at the most relevant place in the Markdown. If the answer belongs inside an existing section, revise that section instead of appending a new block.
        Keep the result readable as a normal note, not as a conversation transcript.
        """
    }

    private func assistantConversationMessages(currentUserInput: String) -> [[String: String]] {
        var messages = assistantConversationMemory.chatMessages { promptExcerpt($0, characterLimit: 2_000) }
        messages.append(
            [
                "role": "user",
                "content": currentUserInput
            ]
        )
        return messages
    }

    private func helpDeskMessages(for conversationID: HelpDeskConversation.ID) -> [HelpDeskMessage] {
        helpDeskDatabase.conversations.first { $0.id == conversationID }?.messages ?? []
    }

    private func helpDeskMarkdownSuggestion(for messageID: String) -> HelpDeskMarkdownSuggestion? {
        helpDeskMarkdownSuggestions.first { $0.messageID == messageID }
    }

    private func upsertHelpDeskMarkdownSuggestion(_ suggestion: HelpDeskMarkdownSuggestion) {
        helpDeskMarkdownSuggestions.removeAll { $0.messageID == suggestion.messageID }
        helpDeskMarkdownSuggestions.append(suggestion)
    }

    private func beginHelpDeskMarkdownSuggestion(
        messageID: String,
        conversationID: HelpDeskConversation.ID,
        answer: String
    ) {
        guard areHelpDeskSuggestionsEnabled(for: conversationID) else { return }

        upsertHelpDeskMarkdownSuggestion(
            HelpDeskMarkdownSuggestion(
                messageID: messageID,
                conversationID: conversationID,
                action: .appendToExisting,
                pageTitle: "",
                formattedMarkdown: "",
                isLoading: true
            )
        )

        Task {
            await refreshHelpDeskMarkdownSuggestion(
                messageID: messageID,
                conversationID: conversationID,
                answer: answer
            )
        }
    }

    private func refreshHelpDeskMarkdownSuggestion(
        messageID: String,
        conversationID: HelpDeskConversation.ID,
        answer: String
    ) async {
        do {
            guard activeBrain != nil,
                  areHelpDeskSuggestionsEnabled(for: conversationID),
                  helpDeskMessages(for: conversationID).contains(where: { $0.id == messageID })
            else {
                helpDeskMarkdownSuggestions.removeAll { $0.messageID == messageID }
                return
            }

            let resolution = try await resolveHelpDeskMarkdownPlacement(for: answer)
            let suggestion: HelpDeskMarkdownSuggestion
            switch resolution.action {
            case .append:
                guard let noteTitle = resolution.noteTitle else {
                    throw AssistantError.requestFailed("The model did not name a page to append to.")
                }
                suggestion = HelpDeskMarkdownSuggestion(
                    messageID: messageID,
                    conversationID: conversationID,
                    action: .appendToExisting,
                    pageTitle: noteTitle,
                    formattedMarkdown: resolution.formattedMarkdown,
                    isLoading: false
                )
            case .create:
                suggestion = HelpDeskMarkdownSuggestion(
                    messageID: messageID,
                    conversationID: conversationID,
                    action: .createNew,
                    pageTitle: resolution.suggestedPageTitle ?? "Untitled",
                    formattedMarkdown: resolution.formattedMarkdown,
                    isLoading: false
                )
            }
            upsertHelpDeskMarkdownSuggestion(suggestion)
        } catch {
            helpDeskMarkdownSuggestions.removeAll { $0.messageID == messageID }
        }
    }

    private func resolveAndApplyHelpDeskMarkdown(
        assistantMessage: HelpDeskMessage,
        conversationID: HelpDeskConversation.ID
    ) async {
        await refreshHelpDeskMarkdownSuggestion(
            messageID: assistantMessage.id,
            conversationID: conversationID,
            answer: assistantMessage.content
        )
        applyHelpDeskMarkdownSuggestion(messageID: assistantMessage.id)
    }

    private func resolveHelpDeskMarkdownPlacement(
        for assistantAnswer: String
    ) async throws -> HelpDeskMarkdownPlacementResolution {
        let pageTitles = notes.map(\.title)
        let prompt = """
        Vault pages:
        \(pageTitles.isEmpty ? "No pages yet." : pageTitles.map { "- \($0)" }.joined(separator: "\n"))

        Zirn Chat answer to place in the vault:
        \(assistantAnswer)

        Task:
        Pick the best existing page to append this answer to, or recommend creating a new page.
        Format the content so it fits naturally in Markdown.
        """

        let result = try await generateWithMistral(
            system: helpDeskMarkdownPlacementInstructions(),
            user: prompt,
            maxTokens: Self.maxAssistantOutputTokens
        )
        recordMistralUsage(
            inputTokens: result.inputTokens ?? estimatedTokenCount(for: prompt),
            outputTokens: result.outputTokens ?? estimatedTokenCount(for: result.content)
        )

        return try parseHelpDeskMarkdownPlacementResolution(from: result.content)
    }

    private func parseHelpDeskMarkdownPlacementResolution(
        from rawResponse: String
    ) throws -> HelpDeskMarkdownPlacementResolution {
        let cleaned = cleanedAssistantMarkdown(rawResponse)
        let jsonCandidate: String
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            jsonCandidate = String(cleaned[start...end])
        } else {
            jsonCandidate = cleaned
        }

        guard let data = jsonCandidate.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let actionRaw = (json["action"] as? String)?.lowercased(),
              let formattedMarkdown = json["formattedMarkdown"] as? String,
              !formattedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AssistantError.requestFailed("The model did not return a valid page placement.")
        }

        switch actionRaw {
        case "append":
            guard let noteTitle = json["noteTitle"] as? String,
                  !noteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw AssistantError.requestFailed("The model did not name a page to append to.")
            }
            return HelpDeskMarkdownPlacementResolution(
                action: .append,
                noteTitle: noteTitle,
                suggestedPageTitle: nil,
                formattedMarkdown: formattedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case "create":
            let suggestedTitle = (json["suggestedPageTitle"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return HelpDeskMarkdownPlacementResolution(
                action: .create,
                noteTitle: nil,
                suggestedPageTitle: suggestedTitle?.isEmpty == false ? suggestedTitle : "Untitled",
                formattedMarkdown: formattedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        default:
            throw AssistantError.requestFailed("The model returned an unknown placement action.")
        }
    }

    private func noteSummary(matchingTitle title: String) -> NoteSummary? {
        let normalized = normalizedLinkTitle(title)
        return notes.first { normalizedLinkTitle($0.title) == normalized }
    }

    private func appendMarkdownToNote(noteID: Note.ID, markdown: String) throws {
        guard let brain = activeBrain,
              let noteURL = noteURL(for: noteID, in: brain)
        else {
            throw AssistantError.requestFailed("Could not open the target page.")
        }

        var note = try readNote(from: noteURL)
        let trimmedExisting = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = trimmedExisting.isEmpty ? "" : "\n\n"
        let updatedContent = trimmedExisting + separator + markdown
        let now = Date()
        note = Note(
            id: note.id,
            title: note.title,
            content: updatedContent,
            createdAt: note.createdAt,
            updatedAt: now
        )

        try writeMarkdownNote(note, to: noteURL)
        try noteIdentityDatabase?.upsert(
            noteID: note.id,
            title: note.title,
            fileName: activeBrain.map { relativeNoteFileName(for: noteURL, in: $0) } ?? noteURL.lastPathComponent,
            updatedAt: note.updatedAt
        )
        try loadNotes()
        try syncBrainMetadata()
        scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds)
    }

    private func createNoteFromHelpDesk(title: String, bodyMarkdown: String) throws -> Note {
        guard let brain = activeBrain else {
            throw AssistantError.missingConfiguration("Open or create a brain first")
        }

        let id = UUID().uuidString
        let resolvedTitle = uniqueTitle(for: title)
        let now = Date()
        let content = contentBySettingDocumentTitle(resolvedTitle, in: bodyMarkdown)
        let note = Note(
            id: id,
            title: resolvedTitle,
            content: content,
            createdAt: now,
            updatedAt: now
        )

        try FileManager.default.createDirectory(
            at: notesFolderURL(for: brain),
            withIntermediateDirectories: true
        )
        let targetURL = markdownNoteURL(for: note, in: brain)
        try FileManager.default.createDirectory(
            at: targetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeMarkdownNote(note, to: targetURL)
        try noteIdentityDatabase?.upsert(
            noteID: note.id,
            title: note.title,
            fileName: relativeNoteFileName(for: targetURL, in: brain),
            updatedAt: note.updatedAt
        )
        try loadNotes()
        try syncBrainMetadata()
        try updateStyleMemory(with: note.content)
        recordRecentVault(
            note: NoteSummary(
                id: note.id,
                title: note.title,
                updatedAt: note.updatedAt
            )
        )
        scheduleLiveHomePageCompilation(delay: Self.homeCompilationAfterAutosaveNanoseconds)
        return note
    }

    private func appendHelpDeskMessage(
        _ message: HelpDeskMessage,
        conversationID explicitConversationID: HelpDeskConversation.ID? = nil
    ) {
        guard let conversationID = explicitConversationID ?? selectedHelpDeskConversationID,
              let index = helpDeskDatabase.conversations.firstIndex(where: { $0.id == conversationID })
        else { return }

        helpDeskDatabase.conversations[index].messages.append(message)
        helpDeskDatabase.conversations[index].updatedAt = message.createdAt
        let conversation = helpDeskDatabase.conversations[index]
        syncHelpDeskConversations()
        persistHelpDeskMessageQuietly(message, conversation: conversation)
    }

    private func updateHelpDeskConversationTitleIfNeeded(conversationID: HelpDeskConversation.ID, prompt: String) {
        guard let index = helpDeskDatabase.conversations.firstIndex(where: { $0.id == conversationID }),
              helpDeskDatabase.conversations[index].title == "New conversation"
        else { return }

        helpDeskDatabase.conversations[index].title = helpDeskConversationTitle(from: prompt)
        let conversation = helpDeskDatabase.conversations[index]
        syncHelpDeskConversations()
        persistHelpDeskConversationQuietly(conversation)
    }

    private func helpDeskConversationTitle(from prompt: String) -> String {
        let clean = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "Attached file" }
        let words = clean.split(separator: " ").prefix(7).joined(separator: " ")
        return words.count > 54 ? "\(words.prefix(54))..." : words
    }

    private func helpDeskVaultContext(for question: String, history: [HelpDeskMessage]) throws -> String {
        if let indexedContext = helpDeskIndexedVaultContext(for: question, history: history) {
            return indexedContext
        }

        let sourceNotes: [HomePageSourceNote]
        do {
            sourceNotes = try loadHomePageSourceNotes()
        } catch {
            status = error.localizedDescription
            sourceNotes = notes.compactMap { summary in
                guard let url = noteURL(for: summary.id),
                      let note = try? readNote(from: url)
                else { return nil }
                return HomePageSourceNote(
                    id: note.id,
                    title: note.title,
                    content: note.content,
                    updatedAt: note.updatedAt
                )
            }
        }

        guard !sourceNotes.isEmpty else {
            return "The vault has no pages yet."
        }

        let query = helpDeskRetrievalQuery(question: question, history: history)
        let tokens = helpDeskRetrievalTokens(in: query)
        guard !tokens.isEmpty else {
            return compactHelpDeskVaultContext(from: sourceNotes)
        }

        let candidates = helpDeskContextCandidates(from: sourceNotes, tokens: tokens, query: query)
        let titleMatchedNotes = sourceNotes.filter { note in
            let titleTokens = helpDeskRetrievalTokens(in: note.title)
            return !titleTokens.isEmpty && titleTokens.allSatisfy { titleToken in
                tokens.contains { helpDeskTokensMatch($0, titleToken) }
            }
        }

        var remainingBudget = Self.helpDeskContextCharacterBudget
        var chunks: [String] = []

        func appendChunk(_ chunk: String) {
            guard remainingBudget > 0 else { return }
            let excerpt = promptExcerpt(chunk, characterLimit: remainingBudget)
            remainingBudget -= excerpt.count
            chunks.append(excerpt)
        }

        let pageList = sourceNotes
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { "- \($0.title)" }
            .joined(separator: "\n")
        appendChunk(
            """
            Vault pages:
            \(pageList)
            """
        )

        var includedNoteIDs = Set<String>()
        var fullIncludedNoteIDs = Set<String>()
        for note in titleMatchedNotes.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard remainingBudget > 0 else { break }
            includedNoteIDs.insert(note.id)
            fullIncludedNoteIDs.insert(note.id)
            appendChunk(
                """
                ### \(note.title)
                \(note.content.trimmingCharacters(in: .whitespacesAndNewlines))
                """
            )
        }

        var blockCountsByNoteID: [String: Int] = [:]
        for candidate in candidates.prefix(Self.helpDeskRelevantBlockLimit) {
            guard remainingBudget > 0 else { break }
            guard !fullIncludedNoteIDs.contains(candidate.noteID) else { continue }
            guard (blockCountsByNoteID[candidate.noteID] ?? 0) < 3 else { continue }
            appendChunk(
                """
                ### \(candidate.title)
                \(candidate.text)
                """
            )
            includedNoteIDs.insert(candidate.noteID)
            blockCountsByNoteID[candidate.noteID, default: 0] += 1
        }

        let remainingNotes = sourceNotes
            .filter { !includedNoteIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
        for note in remainingNotes {
            guard remainingBudget > 1_000 else { break }
            appendChunk(
                """
                ### \(note.title)
                \(plainText(fromMarkdown: note.content).prefix(700))
                """
            )
        }

        if chunks.count <= 1 {
            return compactHelpDeskVaultContext(from: sourceNotes)
        }
        return chunks.joined(separator: "\n\n")
    }

    private func helpDeskIndexedVaultContext(for question: String, history: [HelpDeskMessage]) -> String? {
        guard !searchIndex.isEmpty else { return nil }

        let query = helpDeskRetrievalQuery(question: question, history: history)
        let tokens = helpDeskRetrievalTokens(in: query)
        let queryVector = semanticVector(for: query)
        if tokens.isEmpty, queryVector == nil {
            return compactIndexedHelpDeskVaultContext()
        }

        var remainingBudget = Self.helpDeskContextCharacterBudget
        var chunks: [String] = []

        func appendChunk(_ chunk: String) {
            guard remainingBudget > 0 else { return }
            let excerpt = promptExcerpt(chunk, characterLimit: remainingBudget)
            remainingBudget -= excerpt.count
            chunks.append(excerpt)
        }

        let pageList = notes
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { "- \($0.title)" }
            .joined(separator: "\n")
        appendChunk(
            """
            Vault pages:
            \(pageList)
            """
        )

        var includedNoteIDs = Set<String>()
        var fullyIncludedNoteIDs = Set<String>()
        let titleMatchedNotes = notes.filter { note in
            let titleTokens = helpDeskRetrievalTokens(in: note.title)
            return !titleTokens.isEmpty && titleTokens.allSatisfy { titleToken in
                tokens.contains { helpDeskTokensMatch($0, titleToken) }
            }
        }

        for note in titleMatchedNotes.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard remainingBudget > 0 else { break }
            let noteBlocks = indexedBodyBlocks(for: note.id)
            guard !noteBlocks.isEmpty else { continue }
            includedNoteIDs.insert(note.id)
            fullyIncludedNoteIDs.insert(note.id)
            appendChunk(
                """
                ### \(note.title)
                \(noteBlocks.map(\.displayText).joined(separator: "\n\n"))
                """
            )
        }

        let candidates = helpDeskIndexedContextCandidates(tokens: tokens, query: query, queryVector: queryVector)
        var blockCountsByNoteID: [String: Int] = [:]
        for candidate in candidates.prefix(Self.helpDeskRelevantBlockLimit) {
            guard remainingBudget > 0 else { break }
            guard !fullyIncludedNoteIDs.contains(candidate.noteID) else { continue }
            guard (blockCountsByNoteID[candidate.noteID] ?? 0) < 3 else { continue }
            appendChunk(
                """
                ### \(candidate.title)
                \(candidate.text)
                """
            )
            includedNoteIDs.insert(candidate.noteID)
            blockCountsByNoteID[candidate.noteID, default: 0] += 1
        }

        for note in notes.filter({ !includedNoteIDs.contains($0.id) }).sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard remainingBudget > 1_000 else { break }
            let preview = indexedBodyBlocks(for: note.id)
                .map(\.displayText)
                .joined(separator: " ")
                .prefix(700)
            guard !preview.isEmpty else { continue }
            appendChunk(
                """
                ### \(note.title)
                \(preview)
                """
            )
        }

        if chunks.count <= 1 {
            return compactIndexedHelpDeskVaultContext()
        }
        return chunks.joined(separator: "\n\n")
    }

    private func helpDeskRetrievalQuery(question: String, history: [HelpDeskMessage]) -> String {
        let recentConversation = history
            .suffix(4)
            .map { $0.content }
            .joined(separator: " ")
        return "\(recentConversation) \(question)"
    }

    private func helpDeskRetrievalTokens(in text: String) -> [String] {
        let stopwords: Set<String> = [
            "a", "an", "and", "are", "as", "at", "be", "but", "by", "can", "did", "do", "does",
            "for", "from", "had", "has", "have", "how", "i", "if", "in", "is", "it", "its",
            "me", "my", "of", "on", "or", "so", "that", "the", "their", "there", "this", "to",
            "was", "were", "what", "when", "where", "which", "who", "why", "with", "you"
        ]
        var seen = Set<String>()
        return searchTokens(in: text).filter { token in
            guard token.count > 2 || token.allSatisfy(\.isNumber) else { return false }
            guard !stopwords.contains(token), !seen.contains(token) else { return false }
            seen.insert(token)
            return true
        }
    }

    private func helpDeskTokensMatch(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        if lhs.count < 4 || rhs.count < 4 { return false }
        if lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs) {
            return min(lhs.count, rhs.count) >= 5
        }

        let distanceLimit = lhs.count >= 8 && rhs.count >= 8 ? 2 : 1
        guard abs(lhs.count - rhs.count) <= distanceLimit else { return false }
        return boundedEditDistance(lhs, rhs, limit: distanceLimit) <= distanceLimit
    }

    private func boundedEditDistance(_ lhs: String, _ rhs: String, limit: Int) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        guard abs(left.count - right.count) <= limit else { return limit + 1 }
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
        var current = Array(repeating: 0, count: right.count + 1)

        for leftIndex in 1...left.count {
            current[0] = leftIndex
            var rowMinimum = current[0]

            for rightIndex in 1...right.count {
                let substitutionCost = left[leftIndex - 1] == right[rightIndex - 1] ? 0 : 1
                current[rightIndex] = min(
                    previous[rightIndex] + 1,
                    current[rightIndex - 1] + 1,
                    previous[rightIndex - 1] + substitutionCost
                )
                rowMinimum = min(rowMinimum, current[rightIndex])
            }

            if rowMinimum > limit {
                return limit + 1
            }
            swap(&previous, &current)
        }

        return previous[right.count]
    }

    private func helpDeskContextCandidates(
        from sourceNotes: [HomePageSourceNote],
        tokens: [String],
        query: String
    ) -> [HelpDeskContextCandidate] {
        let normalizedQuery = normalizedSearchText(query)
        return sourceNotes.flatMap { note -> [HelpDeskContextCandidate] in
            let titleText = normalizedSearchText(note.title)
            return markdownSearchBlocks(from: note.content).compactMap { block -> HelpDeskContextCandidate? in
                let blockText = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !blockText.isEmpty else { return nil }
                let normalizedBlock = normalizedSearchText(blockText)
                let blockTokens = searchTokens(in: blockText)
                let noteTitleTokens = searchTokens(in: note.title)
                var score = 0.0
                for token in tokens {
                    if titleText.contains(token) {
                        score += 10
                    } else if noteTitleTokens.contains(where: { helpDeskTokensMatch(token, $0) }) {
                        score += 7
                    }

                    if normalizedBlock.contains(token) {
                        score += 5
                    } else if blockTokens.contains(where: { helpDeskTokensMatch(token, $0) }) {
                        score += 3
                    }
                }
                if !titleText.isEmpty, normalizedQuery.contains(titleText) {
                    score += 16
                }
                guard score > 0 else { return nil }
                return HelpDeskContextCandidate(
                    noteID: note.id,
                    title: note.title,
                    text: blockText,
                    score: score,
                    updatedAt: note.updatedAt
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func helpDeskIndexedContextCandidates(
        tokens: [String],
        query: String,
        queryVector: [Double]?
    ) -> [HelpDeskContextCandidate] {
        let normalizedQuery = normalizedSearchText(query)
        let lexicalCandidates = searchIndex.compactMap { entry -> HelpDeskContextCandidate? in
            guard entry.kind == "block" else { return nil }
            let titleText = normalizedSearchText(entry.title)
            let blockTokens = searchTokens(in: entry.displayText)
            let noteTitleTokens = searchTokens(in: entry.title)
            var score = 0.0
            for token in tokens {
                if titleText.contains(token) {
                    score += 10
                } else if noteTitleTokens.contains(where: { helpDeskTokensMatch(token, $0) }) {
                    score += 7
                }

                if entry.normalizedText.contains(token) {
                    score += 5
                } else if blockTokens.contains(where: { helpDeskTokensMatch(token, $0) }) {
                    score += 3
                }
            }
            if !titleText.isEmpty, normalizedQuery.contains(titleText) {
                score += 16
            }
            guard score > 0 else { return nil }
            return HelpDeskContextCandidate(
                noteID: entry.noteID,
                title: entry.title,
                text: entry.displayText,
                score: score,
                updatedAt: entry.updatedAt
            )
        }

        let semanticCandidates = (queryVector == nil ? [] : semanticSearchIndex.compactMap { entry -> HelpDeskContextCandidate? in
            guard entry.kind == "block", let queryVector else { return nil }
            let similarity = cosineSimilarity(queryVector, entry.vector)
            guard similarity >= Self.semanticSearchMinimumSimilarity else { return nil }
            return HelpDeskContextCandidate(
                noteID: entry.noteID,
                title: entry.title,
                text: entry.displayText,
                score: 6 + (similarity * 16),
                updatedAt: entry.updatedAt
            )
        })

        var bestByBlock: [String: HelpDeskContextCandidate] = [:]
        for candidate in lexicalCandidates + semanticCandidates {
            let key = "\(candidate.noteID)-\(candidate.text)"
            if let current = bestByBlock[key], current.score >= candidate.score {
                continue
            }
            bestByBlock[key] = candidate
        }

        return bestByBlock.values.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func compactHelpDeskVaultContext(from sourceNotes: [HomePageSourceNote]) -> String {
        var remainingBudget = Self.helpDeskContextCharacterBudget / 2
        var chunks: [String] = []
        for note in sourceNotes.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard remainingBudget > 0 else { break }
            let preview = String(plainText(fromMarkdown: note.content).prefix(900))
            let chunk = """
            ### \(note.title)
            \(preview)
            """
            let excerpt = promptExcerpt(chunk, characterLimit: remainingBudget)
            remainingBudget -= excerpt.count
            chunks.append(excerpt)
        }
        return chunks.joined(separator: "\n\n")
    }

    private func compactIndexedHelpDeskVaultContext() -> String {
        var remainingBudget = Self.helpDeskContextCharacterBudget / 2
        var chunks: [String] = []
        for note in notes.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard remainingBudget > 0 else { break }
            let preview = indexedBodyBlocks(for: note.id)
                .map(\.displayText)
                .joined(separator: " ")
                .prefix(900)
            guard !preview.isEmpty else { continue }
            let chunk = """
            ### \(note.title)
            \(preview)
            """
            let excerpt = promptExcerpt(chunk, characterLimit: remainingBudget)
            remainingBudget -= excerpt.count
            chunks.append(excerpt)
        }
        return chunks.isEmpty ? nilIndexedHelpDeskContext() : chunks.joined(separator: "\n\n")
    }

    private func nilIndexedHelpDeskContext() -> String {
        notes.isEmpty
            ? "The vault has no pages yet."
            : "Vault pages:\n\(notes.map { "- \($0.title)" }.joined(separator: "\n"))"
    }

    private func indexedBodyBlocks(for noteID: Note.ID) -> [NoteSearchIndexEntry] {
        searchIndex
            .filter { $0.noteID == noteID && $0.kind == "block" }
            .sorted { lhs, rhs in
                (lhs.blockIndex ?? Int.max) < (rhs.blockIndex ?? Int.max)
            }
    }

    private func helpDeskAttachmentContext(_ attachment: PromptAttachment?, question: String, vaultContext: String) -> String {
        guard let attachment else { return "None" }
        guard shouldUseAttachmentContext(prompt: question, markdownContext: vaultContext, attachment: attachment) else {
            return "\(attachment.fileName) is attached and stored at \(attachmentFileLink(attachment)), but Zirn should prefer the vault Markdown context because the question does not appear file-specific."
        }
        return attachmentContext(attachment, characterLimit: 12_000)
    }

    private func assistantPromptLinksContext(_ titles: [String]) -> String {
        guard !titles.isEmpty else { return "None" }
        return titles.map { "- [[\($0)]]" }.joined(separator: "\n")
    }

    private func assistantConversationTranscript() -> String {
        assistantConversationMemory.transcript { promptExcerpt($0, characterLimit: 2_000) }
    }

    private func assistantIntent(for _: String) -> AssistantPromptIntent {
        isAssistantWritingMode ? .writing : .conversation
    }

    private func assistantAttachmentContext(
        for prompt: String,
        linkedPageTitles: [String],
        intent: AssistantPromptIntent,
        characterLimit: Int? = nil
    ) -> String {
        guard let assistantAttachment else { return "None" }
        let markdownContext = "\(title)\n\(content)\n\(linkedPageTitles.joined(separator: " "))"
        guard shouldUseAttachmentContext(prompt: prompt, markdownContext: markdownContext, attachment: assistantAttachment) else {
            return "None. Prefer the current Markdown and linked pages; the attached file was not needed for this request."
        }
        let limit = characterLimit ?? (intent == .writing ? 24_000 : 12_000)
        return attachmentContext(assistantAttachment, characterLimit: limit)
    }

    private func attachmentContext(_ attachment: PromptAttachment, characterLimit: Int) -> String {
        let text = attachment.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let clippedText = String(text.prefix(characterLimit))
        let fileLink = attachmentFileLink(attachment)
        if clippedText.isEmpty {
            return "\(attachment.fileName) (\(attachment.fileExtension.uppercased())) attached, but no readable text could be extracted.\nFile link: \(fileLink)"
        }
        return """
        File: \(attachment.fileName)
        Type: \(attachment.fileExtension.uppercased())
        File link: \(fileLink)
        Use this file context only if it is directly relevant. If you rely on it in a conversational answer, include the file link briefly.
        Text:
        \(clippedText)
        """
    }

    private func attachmentFileLink(_ attachment: PromptAttachment) -> String {
        guard let storedFileURL = attachment.storedFileURL else {
            return attachment.fileName
        }
        return "[\(attachment.fileName)](\(storedFileURL.absoluteString))"
    }

    private func shouldUseAttachmentContext(prompt: String, markdownContext: String, attachment: PromptAttachment) -> Bool {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPrompt.isEmpty { return true }

        let lowerPrompt = cleanPrompt.lowercased()
        let lowerFileName = attachment.fileName.lowercased()
        let fileBaseName = (lowerFileName as NSString).deletingPathExtension
        let fileTerms = [
            "file", "attachment", "attached", "pdf", "document", "docx", "word",
            "powerpoint", "ppt", "slide", "image", "picture", "photo", "screenshot",
            "scan", "ocr", "handwriting", "handwritten", "from this", "in this"
        ]

        if lowerPrompt.contains(lowerFileName) || (!fileBaseName.isEmpty && lowerPrompt.contains(fileBaseName)) {
            return true
        }
        if fileTerms.contains(where: { lowerPrompt.contains($0) }) {
            return true
        }

        let promptTokens = searchTokens(in: cleanPrompt)
            .filter { $0.count > 3 }
            .prefix(12)
        guard !promptTokens.isEmpty else { return false }

        let normalizedMarkdown = normalizedSearchText(markdownContext)
        let markdownMatches = promptTokens.filter { normalizedMarkdown.contains($0) }.count
        return markdownMatches < min(2, promptTokens.count)
    }

    private func promptSuggestsWebSearch(_ prompt: String) -> Bool {
        let lowercasedPrompt = prompt.lowercased()
        let webTerms = [
            "web",
            "search",
            "internet",
            "online",
            "latest",
            "current",
            "today",
            "news",
            "browse",
            "browser",
            "recent",
            "url",
            "http",
            "website"
        ]
        return webTerms.contains { lowercasedPrompt.contains($0) }
    }

    private func cleanedAssistantMarkdown(_ markdown: String) -> String {
        var output = stripDeepSeekThinkingArtifacts(from: markdown)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if output.hasPrefix("```markdown") {
            output.removeFirst("```markdown".count)
        } else if output.hasPrefix("```") {
            output.removeFirst(3)
        }
        if output.hasSuffix("```") {
            output.removeLast(3)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripDeepSeekThinkingArtifacts(from text: String) -> String {
        let lt = "\u{003C}"
        let gt = "\u{003E}"
        var output = text
        for (open, close) in [
            (lt + "think" + gt, lt + "/think" + gt),
            (lt + "redacted_thinking" + gt, lt + "/redacted_thinking" + gt)
        ] {
            output = stripDelimitedBlocks(from: output, open: open, close: close)
        }
        return output
    }

    private func stripDelimitedBlocks(from text: String, open: String, close: String) -> String {
        var output = text
        while let start = output.range(of: open) {
            if let end = output.range(of: close, range: start.upperBound..<output.endIndex) {
                output.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                output.removeSubrange(start.lowerBound..<output.endIndex)
                break
            }
        }
        return output
    }

    private func cleanedWritingAssistantMarkdown(_ markdown: String) -> String {
        let cleaned = cleanedAssistantMarkdown(markdown)
        var lines = cleaned.components(separatedBy: .newlines)

        while let index = lines.lastIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              isConversationalFollowUpLine(lines[index]) {
            lines.removeSubrange(index..<lines.endIndex)
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isConversationalFollowUpLine(_ line: String) -> Bool {
        var cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanLine = cleanLine.trimmingCharacters(in: CharacterSet(charactersIn: "*_`~"))
        cleanLine = cleanLine.replacingOccurrences(
            of: #"^\s*(?:[-*+]\s+|>\s*)+"#,
            with: "",
            options: .regularExpression
        )
        cleanLine = cleanLine.trimmingCharacters(in: .whitespacesAndNewlines)

        let lowercased = cleanLine
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let questionStarters = [
            "would you like",
            "do you want",
            "want me to",
            "should i",
            "shall i",
            "can i",
            "would it help",
            "need me to"
        ]
        let offerStarters = [
            "let me know if you want",
            "let me know if you'd like",
            "let me know if you would like",
            "i can also",
            "i could also"
        ]

        return questionStarters.contains { lowercased.hasPrefix($0) }
            || offerStarters.contains { lowercased.hasPrefix($0) }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            let message = String(data: data, encoding: .utf8) ?? "Model request failed."
            throw AssistantError.requestFailed(message)
        }
    }

    private func processMistralHTTPResponse(_ response: URLResponse, data: Data) throws {
        if let httpResponse = response as? HTTPURLResponse {
            updateMistralRateLimits(from: httpResponse)
        }
        try validateHTTPResponse(response, data: data)
    }

    private func updateMistralRateLimits(from response: HTTPURLResponse) {
        if let limit = mistralHeaderInt(in: response, named: "x-ratelimit-limit-tokens") {
            mistralRateLimitTokens = limit
        }
        if let remaining = mistralHeaderInt(in: response, named: "x-ratelimit-remaining-tokens") {
            mistralRateLimitTokensRemaining = remaining
        }
    }

    private func mistralHeaderInt(in response: HTTPURLResponse, named headerName: String) -> Int? {
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String,
                  key.compare(headerName, options: .caseInsensitive) == .orderedSame,
                  let rawValue = value as? String
            else { continue }
            return Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func exceedsMistralUploadLimit(byteCount: Int) -> Bool {
        byteCount > Self.mistralMaxUploadFileBytes
    }

    private func mistralUploadLimitStatusMessage(forFileName fileName: String) -> String {
        "Exceeds Mistral’s 512 MB upload limit · \(fileName)"
    }

    private func fileByteCount(at url: URL) -> Int? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize
        else { return nil }
        return size
    }

    private func extractChatCompletionResult(from data: Data) throws -> ChatCompletionResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any]
        else {
            throw AssistantError.requestFailed("The model returned no Markdown.")
        }

        let content: String?
        if let text = message["content"] as? String {
            content = text
        } else if let chunks = message["content"] as? [[String: Any]] {
            content = chunks.compactMap { chunk in
                chunk["text"] as? String ?? chunk["content"] as? String
            }
            .joined()
        } else {
            content = nil
        }

        let cleanedContent = content.map(stripDeepSeekThinkingArtifacts(from:)).flatMap { text in
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
        }

        guard let cleanedContent else {
            throw AssistantError.requestFailed("The model returned no Markdown.")
        }

        let usage = json["usage"] as? [String: Any]
        return ChatCompletionResult(
            content: cleanedContent,
            inputTokens: usage?["prompt_tokens"] as? Int
                ?? usage?["input_tokens"] as? Int,
            outputTokens: usage?["completion_tokens"] as? Int
                ?? usage?["output_tokens"] as? Int,
            cachedInputTokens: usage?["prompt_cache_hit_tokens"] as? Int
        )
    }

    private func extractChatCompletionDelta(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any]
        else {
            return ""
        }

        if let text = delta["content"] as? String {
            return text
        }
        if let chunks = delta["content"] as? [[String: Any]] {
            return chunks.compactMap { chunk in
                chunk["text"] as? String ?? chunk["content"] as? String
            }
            .joined()
        }
        return ""
    }

    private func recordUsage(
        for model: AssistantModel,
        result: ChatCompletionResult,
        fallbackInputTokens: Int,
        fallbackOutputTokens: Int
    ) {
        switch model {
        case .mistral:
            recordMistralUsage(
                inputTokens: result.inputTokens ?? fallbackInputTokens,
                outputTokens: result.outputTokens ?? fallbackOutputTokens
            )
        case .deepseek:
            recordDeepSeekUsage(
                inputTokens: result.inputTokens ?? fallbackInputTokens,
                outputTokens: result.outputTokens ?? fallbackOutputTokens,
                cachedInputTokens: result.cachedInputTokens
            )
        }
    }

    private func recordUsage(
        for model: HighlightSummaryModel,
        result: ChatCompletionResult,
        fallbackInputTokens: Int,
        fallbackOutputTokens: Int
    ) {
        switch model {
        case .mistral:
            recordMistralUsage(
                inputTokens: result.inputTokens ?? fallbackInputTokens,
                outputTokens: result.outputTokens ?? fallbackOutputTokens
            )
        case .deepseek:
            recordDeepSeekUsage(
                inputTokens: result.inputTokens ?? fallbackInputTokens,
                outputTokens: result.outputTokens ?? fallbackOutputTokens,
                cachedInputTokens: result.cachedInputTokens
            )
        case .ollama:
            break
        }
    }

    private func recordMistralUsage(inputTokens: Int, outputTokens: Int) {
        let cost = Self.mistralCostUSD(inputTokens: inputTokens, outputTokens: outputTokens)
        mistralBudgetSpentUSD += cost
        mistralTokensConsumed += max(0, inputTokens) + max(0, outputTokens)
        UserDefaults.standard.set(mistralBudgetSpentUSD, forKey: mistralBudgetSpentUSDKey)
        UserDefaults.standard.set(mistralTokensConsumed, forKey: mistralTokensConsumedKey)
    }

    private func recordDeepSeekUsage(inputTokens: Int, outputTokens: Int, cachedInputTokens: Int?) {
        let cost = Self.deepSeekCostUSD(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cachedInputTokens: cachedInputTokens
        )
        deepSeekBudgetSpentUSD += cost
        deepSeekTokensConsumed += max(0, inputTokens) + max(0, outputTokens)
        UserDefaults.standard.set(deepSeekBudgetSpentUSD, forKey: deepSeekBudgetSpentUSDKey)
        UserDefaults.standard.set(deepSeekTokensConsumed, forKey: deepSeekTokensConsumedKey)
    }

    private func recordMistralOCRUpload(pageCount: Int) {
        let cleanPageCount = max(0, pageCount)
        mistralOCRPagesUsed += cleanPageCount
        mistralOCRBudgetSpentUSD += Self.mistralOCRCostUSD(pageCount: cleanPageCount)
        UserDefaults.standard.set(mistralOCRPagesUsed, forKey: mistralOCRPagesUsedKey)
        UserDefaults.standard.set(mistralOCRBudgetSpentUSD, forKey: mistralOCRBudgetSpentUSDKey)
    }

    private func recordMistralOCRUsage(from data: Data, fallbackPageCount: Int? = nil) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let usageInfo = json["usage_info"] as? [String: Any],
           let pagesProcessed = usageInfo["pages_processed"] as? Int,
           pagesProcessed > 0 {
            recordMistralOCRUpload(pageCount: pagesProcessed)
            return
        }
        if let fallbackPageCount, fallbackPageCount > 0 {
            recordMistralOCRUpload(pageCount: fallbackPageCount)
        }
    }

    private func estimatedTokenCount(for text: String) -> Int {
        estimatedTokenCount(forCharacterCount: text.count)
    }

    private func estimatedTokenCount(forCharacterCount characterCount: Int) -> Int {
        max(1, Int(ceil(Double(characterCount) / Double(Self.estimatedCharactersPerToken))))
    }

    private static func mistralCostUSD(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = (Double(inputTokens) / 1_000_000) * mistralInputPricePerMillionTokens
        let outputCost = (Double(outputTokens) / 1_000_000) * mistralOutputPricePerMillionTokens
        return inputCost + outputCost
    }

    private static func mistralOCRCostUSD(pageCount: Int) -> Double {
        (Double(max(0, pageCount)) / 1_000) * mistralOCRPricePerThousandPages
    }

    private static func deepSeekCostUSD(inputTokens: Int, outputTokens: Int, cachedInputTokens: Int?) -> Double {
        let cleanInputTokens = max(0, inputTokens)
        let cleanOutputTokens = max(0, outputTokens)
        let cleanCachedInputTokens = min(max(0, cachedInputTokens ?? 0), cleanInputTokens)
        let cacheMissInputTokens = cleanInputTokens - cleanCachedInputTokens
        let cacheHitInputCost = (Double(cleanCachedInputTokens) / 1_000_000) * deepSeekInputCacheHitPricePerMillionTokens
        let cacheMissInputCost = (Double(cacheMissInputTokens) / 1_000_000) * deepSeekInputCacheMissPricePerMillionTokens
        let outputCost = (Double(cleanOutputTokens) / 1_000_000) * deepSeekOutputPricePerMillionTokens
        return cacheHitInputCost + cacheMissInputCost + outputCost
    }

    private func formatUSD(_ value: Double) -> String {
        if value < 0.01 {
            return String(format: "$%.4f", value)
        }
        return String(format: "$%.2f", value)
    }

    private func cleanOllamaURL(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? Self.defaultOllamaURL : clean.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func loadAssistantConfiguration() {
        let defaults = UserDefaults.standard
        if let rawModel = defaults.string(forKey: selectedAssistantModelKey),
           let model = AssistantModel(rawValue: rawModel) {
            selectedAssistantModel = model
        } else {
            selectedAssistantModel = .mistral
        }
        let legacyGenerationModel = defaults.string(forKey: selectedHighlightSummaryModelKey)
            .flatMap(HighlightSummaryModel.init(rawValue:))
            .flatMap { $0 == .ollama ? nil : $0 }
        selectedHomeGenerationModel = defaults.string(forKey: selectedHomeGenerationModelKey)
            .flatMap(HighlightSummaryModel.init(rawValue:))
            .flatMap { $0 == .ollama ? nil : $0 }
            ?? legacyGenerationModel
            ?? .mistral
        selectedFlashcardGenerationModel = defaults.string(forKey: selectedFlashcardGenerationModelKey)
            .flatMap(HighlightSummaryModel.init(rawValue:))
            .flatMap { $0 == .ollama ? nil : $0 }
            ?? legacyGenerationModel
            ?? .mistral
        isAppleCalendarSyncEnabled = defaults.bool(forKey: appleCalendarSyncEnabledKey)
        recommendedPageHintDismissed = defaults.bool(forKey: recommendedPageHintDismissedKey)
        if let data = defaults.data(forKey: nextClassNoteMapKey),
           let decoded = try? decoder.decode([String: Note.ID].self, from: data) {
            nextClassNoteIDsByEventKey = decoded
        }
        mistralAPIKey = defaults.string(forKey: mistralAPIKeyKey) ?? ""
        mistralModel = defaults.string(forKey: mistralModelKey) ?? Self.defaultMistralModel
        deepSeekAPIKey = defaults.string(forKey: deepSeekAPIKeyKey) ?? ""
        deepSeekModel = defaults.string(forKey: deepSeekModelKey) ?? Self.defaultDeepSeekModel
        mistralBudgetSpentUSD = defaults.double(forKey: mistralBudgetSpentUSDKey)
        mistralOCRBudgetSpentUSD = defaults.double(forKey: mistralOCRBudgetSpentUSDKey)
        mistralOCRPagesUsed = defaults.integer(forKey: mistralOCRPagesUsedKey)
        mistralTokensConsumed = defaults.integer(forKey: mistralTokensConsumedKey)
        deepSeekBudgetSpentUSD = defaults.double(forKey: deepSeekBudgetSpentUSDKey)
        deepSeekTokensConsumed = defaults.integer(forKey: deepSeekTokensConsumedKey)
        defaults.removeObject(forKey: openAIAPIKeyKey)
        defaults.removeObject(forKey: openAIModelKey)
        defaults.removeObject(forKey: "Assistant.GroqAPIKey")
        defaults.removeObject(forKey: "Assistant.GroqModel")
        ollamaModel = defaults.string(forKey: ollamaModelKey) ?? Self.defaultOllamaModel
        ollamaURL = cleanOllamaURL(defaults.string(forKey: ollamaURLKey) ?? Self.defaultOllamaURL)
        userName = defaults.string(forKey: userNameKey) ?? ""
        if let data = defaults.data(forKey: userProfileKey),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            userProfile = profile
            if !profile.greetingName.isEmpty {
                userName = profile.greetingName
            }
        } else if !userName.isEmpty {
            userProfile.firstName = userName
        }
        refreshMistralAccountLimitsIfNeeded()
    }

    private func saveAssistantConfiguration() throws {
        let defaults = UserDefaults.standard
        defaults.set(selectedAssistantModel.rawValue, forKey: selectedAssistantModelKey)
        defaults.set(selectedHomeGenerationModel.rawValue, forKey: selectedHomeGenerationModelKey)
        defaults.set(selectedFlashcardGenerationModel.rawValue, forKey: selectedFlashcardGenerationModelKey)
        defaults.set(isAppleCalendarSyncEnabled, forKey: appleCalendarSyncEnabledKey)
        defaults.set(recommendedPageHintDismissed, forKey: recommendedPageHintDismissedKey)
        if let data = try? encoder.encode(nextClassNoteIDsByEventKey) {
            defaults.set(data, forKey: nextClassNoteMapKey)
        }
        defaults.set(selectedFlashcardGenerationModel.rawValue, forKey: selectedHighlightSummaryModelKey)
        defaults.set(mistralAPIKey, forKey: mistralAPIKeyKey)
        defaults.set(mistralModel, forKey: mistralModelKey)
        defaults.set(deepSeekAPIKey, forKey: deepSeekAPIKeyKey)
        defaults.set(deepSeekModel, forKey: deepSeekModelKey)
        defaults.set(mistralBudgetSpentUSD, forKey: mistralBudgetSpentUSDKey)
        defaults.set(mistralOCRBudgetSpentUSD, forKey: mistralOCRBudgetSpentUSDKey)
        defaults.set(mistralOCRPagesUsed, forKey: mistralOCRPagesUsedKey)
        defaults.set(mistralTokensConsumed, forKey: mistralTokensConsumedKey)
        defaults.set(deepSeekBudgetSpentUSD, forKey: deepSeekBudgetSpentUSDKey)
        defaults.set(deepSeekTokensConsumed, forKey: deepSeekTokensConsumedKey)
        defaults.set(ollamaModel, forKey: ollamaModelKey)
        defaults.set(cleanOllamaURL(ollamaURL), forKey: ollamaURLKey)
        defaults.removeObject(forKey: openAIAPIKeyKey)
        defaults.removeObject(forKey: openAIModelKey)
        try syncBrainAIPreferencesIfPossible()
    }

    private func syncBrainAIPreferencesIfPossible() throws {
        guard activeBrain != nil else { return }
        try withActiveBrainAccessThrowing {
            guard let activeBrain else { return }
            var brain = try readBrain(from: activeBrain.brainURL)
            brain.ai.provider = selectedAssistantModel.rawValue
            brain.ai.mistralModel = mistralModel
            brain.ai.deepSeekModel = deepSeekModel
            brain.ai.ollamaModel = ollamaModel
            brain.ai.ollamaURL = cleanOllamaURL(ollamaURL)
            brain.vault.updatedAt = Date()
            try writeBrain(brain, to: activeBrain.brainURL)
        }
    }

    private func searchPreview(
        query: String,
        note: Note,
        plainContent: String,
        fileName: String,
        titleMatches: Bool,
        fileNameMatches: Bool,
        matchingBlockText: String?
    ) -> String {
        if let matchingBlockText,
           let blockPreview = preview(for: query, in: matchingBlockText) {
            return blockPreview
        }

        if let contentPreview = preview(for: query, in: plainContent)
            ?? preview(for: query, in: note.content) {
            return contentPreview
        }

        if titleMatches {
            return "Title: \(note.title)"
        }

        if fileNameMatches {
            return "File: \(fileName)"
        }

        return "Matching page"
    }

    private func rebuildSearchIndex(from loadedNotes: [Note], in brain: BrainSummary) {
        let entries = loadedNotes.flatMap { note in
            let fileName = noteIdentityDatabase?.fileName(forNoteID: note.id)
                ?? markdownFileName(for: note.title)
            return searchIndexEntries(for: note, fileName: fileName)
        }
        searchIndex = entries
        semanticSearchIndex = semanticSearchEntries(from: entries)
    }

    private func searchIndexEntries(for note: Note, fileName: String) -> [NoteSearchIndexEntry] {
        var entries: [NoteSearchIndexEntry] = [
            NoteSearchIndexEntry(
                noteID: note.id,
                title: note.title,
                displayText: "Title: \(note.title)",
                normalizedText: normalizedSearchText("\(note.title) \(fileName)"),
                blockIndex: 0,
                kind: "title",
                rank: 0,
                updatedAt: note.updatedAt
            )
        ]

        let blocks = markdownSearchBlocks(from: note.content)
        entries.append(contentsOf: blocks.compactMap { block in
            let normalizedText = normalizedSearchText(block.text)
            guard !normalizedText.isEmpty else { return nil }
            return NoteSearchIndexEntry(
                noteID: note.id,
                title: note.title,
                displayText: block.text,
                normalizedText: normalizedText,
                blockIndex: block.index,
                kind: "block",
                rank: 1,
                updatedAt: note.updatedAt
            )
        })

        return entries
    }

    private func semanticSearchEntries(from entries: [NoteSearchIndexEntry]) -> [SemanticSearchIndexEntry] {
        guard semanticSearchEmbedding != nil else { return [] }
        return entries.compactMap { entry in
            let vectorSource = entry.kind == "title"
                ? entry.normalizedText
                : "\(entry.title) \(entry.displayText)"
            guard let vector = semanticVector(for: vectorSource) else { return nil }
            return SemanticSearchIndexEntry(
                noteID: entry.noteID,
                title: entry.title,
                displayText: entry.displayText,
                blockIndex: entry.blockIndex,
                kind: entry.kind,
                updatedAt: entry.updatedAt,
                vector: vector
            )
        }
    }

    private func semanticVector(for text: String) -> [Double]? {
        guard let embedding = semanticSearchEmbedding else { return nil }

        var accumulator: [Double]?
        var vectorCount = 0
        let tokens = helpDeskRetrievalTokens(in: text)
        for token in tokens.prefix(96) {
            guard let tokenVector = embedding.vector(for: token) else { continue }
            if accumulator == nil {
                accumulator = Array(repeating: 0, count: tokenVector.count)
            }
            guard accumulator?.count == tokenVector.count else { continue }
            for index in tokenVector.indices {
                accumulator?[index] += tokenVector[index]
            }
            vectorCount += 1
        }

        guard var vector = accumulator, vectorCount > 0 else { return nil }
        let scale = 1.0 / Double(vectorCount)
        for index in vector.indices {
            vector[index] *= scale
        }
        return normalizedVector(vector)
    }

    private func normalizedVector(_ vector: [Double]) -> [Double]? {
        let magnitude = sqrt(vector.reduce(0) { $0 + ($1 * $1) })
        guard magnitude > 0 else { return nil }
        return vector.map { $0 / magnitude }
    }

    private func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count else { return 0 }
        return zip(lhs, rhs).reduce(0) { $0 + ($1.0 * $1.1) }
    }

    private func searchTokens(in query: String) -> [String] {
        normalizedSearchText(query)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9_]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func searchResultPreview(for query: String, tokens: [String], in text: String) -> String {
        preview(for: query, in: text)
            ?? tokens.compactMap { preview(for: $0, in: text) }.first
            ?? String(text.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func plainText(fromMarkdown markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"(?m)^---[\s\S]*?^---"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^#{1,6}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*[-*]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*\d+\.\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*>\s?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"`{1,3}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[*_~\[\]()>#]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func markdownSearchBlocks(from markdown: String) -> [(index: Int, text: String)] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [(Int, String)] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var isInCodeBlock = false

        func append(_ text: String) {
            blocks.append((blocks.count, plainText(fromMarkdown: text)))
        }

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            append(paragraph.joined(separator: " "))
            paragraph.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    append(codeLines.joined(separator: "\n"))
                    codeLines.removeAll()
                } else {
                    flushParagraph()
                }
                isInCodeBlock.toggle()
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
                continue
            }

            guard !trimmed.isEmpty else {
                flushParagraph()
                continue
            }

            if trimmed.hasPrefix("#"),
               trimmed.drop(while: { $0 == "#" }).first == " " {
                flushParagraph()
                append(trimmed)
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                append(trimmed)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                flushParagraph()
                append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                append(String(trimmed.dropFirst()))
            } else if let markerIndex = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }),
                      Int(trimmed[..<markerIndex]) != nil {
                flushParagraph()
                append(String(trimmed[trimmed.index(after: markerIndex)...]))
            } else {
                paragraph.append(trimmed)
            }
        }

        flushParagraph()
        if isInCodeBlock, !codeLines.isEmpty {
            append(codeLines.joined(separator: "\n"))
        }
        return blocks
    }

    private func isSupportedPromptDocument(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.supportedDocumentAttachmentExtensions.contains(ext)
            || Self.supportedImageAttachmentExtensions.contains(ext)
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        Self.supportedImageAttachmentExtensions.contains(url.pathExtension.lowercased())
    }

    private var supportedAttachmentStatusMessage: String {
        "Only PDFs, Word documents, PowerPoint files, and images are supported"
    }

    private func attachPDFWithMistralOCR(from url: URL, storedFileURL: URL, target: AttachmentTarget) {
        guard !mistralAPIKey.isEmpty else {
            return
        }

        if let byteCount = fileByteCount(at: url),
           exceedsMistralUploadLimit(byteCount: byteCount) {
            status = "\(storedFileURL.lastPathComponent) attached · too large for OCR (\(formattedByteCount(byteCount)))"
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            status = "\(storedFileURL.lastPathComponent) attached · OCR could not read file"
            return
        }

        guard !exceedsMistralUploadLimit(byteCount: data.count) else {
            status = "\(storedFileURL.lastPathComponent) attached · too large for OCR"
            return
        }

        let pageCount = PDFDocument(data: data)?.pageCount ?? 0
        let pageLimit = pageCount == 0
            ? Self.mistralMaxOCRPagesPerRequest
            : min(pageCount, Self.mistralMaxOCRPagesPerRequest)
        let pages = Array(0..<pageLimit)
        status = "OCR reading \(pageLimit) page\(pageLimit == 1 ? "" : "s")"

        Task {
            do {
                let extractedText = try await extractPDFTextWithMistralOCR(data: data, pages: pages)
                setAttachment(
                    PromptAttachment(
                        fileName: storedFileURL.lastPathComponent,
                        fileExtension: storedFileURL.pathExtension.lowercased(),
                        extractedText: extractedText,
                        storedFileURL: storedFileURL
                    ),
                    for: target
                )

                if pageCount > pageLimit {
                    status = "\(storedFileURL.lastPathComponent) attached · first \(pageLimit) pages OCRed"
                } else {
                    status = "\(storedFileURL.lastPathComponent) attached"
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func attachDocumentWithMistralOCR(from url: URL, storedFileURL: URL, target: AttachmentTarget) {
        guard !mistralAPIKey.isEmpty else {
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            status = "\(storedFileURL.lastPathComponent) attached · OCR could not read file"
            return
        }

        guard !exceedsMistralUploadLimit(byteCount: data.count) else {
            status = "\(storedFileURL.lastPathComponent) attached · too large for OCR"
            return
        }

        let mimeType = documentMimeType(forFileName: storedFileURL.lastPathComponent)
        status = "OCR reading \(storedFileURL.lastPathComponent)"

        Task {
            do {
                let extractedText = try await extractDocumentTextWithMistralOCR(data: data, mimeType: mimeType)
                setAttachment(
                    PromptAttachment(
                        fileName: storedFileURL.lastPathComponent,
                        fileExtension: storedFileURL.pathExtension.lowercased(),
                        extractedText: extractedText,
                        storedFileURL: storedFileURL
                    ),
                    for: target
                )
                status = "\(storedFileURL.lastPathComponent) attached · OCRed"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func attachPDFWithMistralOCRIfAvailable(from url: URL, storedFileURL: URL, target: AttachmentTarget) {
        guard !mistralAPIKey.isEmpty else { return }
        attachPDFWithMistralOCR(from: url, storedFileURL: storedFileURL, target: target)
    }

    private func attachDocumentWithMistralOCRIfAvailable(from url: URL, storedFileURL: URL, target: AttachmentTarget) {
        guard !mistralAPIKey.isEmpty else { return }
        attachDocumentWithMistralOCR(from: url, storedFileURL: storedFileURL, target: target)
    }

    private func attachImageWithMistralOCRIfAvailable(data: Data, storedFileURL: URL, target: AttachmentTarget) {
        guard !mistralAPIKey.isEmpty else { return }

        let fileName = storedFileURL.lastPathComponent
        guard !exceedsMistralUploadLimit(byteCount: data.count) else {
            status = "\(fileName) attached · too large for OCR"
            return
        }

        let mimeType = imageMimeType(forFileName: fileName)
        status = "OCR reading \(fileName)"
        Task {
            do {
                let extractedText = try await extractImageTextWithMistralOCR(data: data, mimeType: mimeType)
                setAttachment(
                    PromptAttachment(
                        fileName: fileName,
                        fileExtension: (fileName as NSString).pathExtension.lowercased(),
                        extractedText: extractedText,
                        storedFileURL: storedFileURL
                    ),
                    for: target
                )
                status = "\(fileName) attached · OCRed"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func setAttachment(_ attachment: PromptAttachment, for target: AttachmentTarget) {
        switch target {
        case .assistant:
            assistantAttachment = attachment
        case .helpDesk:
            helpDeskAttachment = attachment
        }
    }

    private func extractPDFTextWithMistralOCR(data: Data, pages: [Int]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/ocr")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(mistralAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.mistralOCRModel,
            "document": [
                "type": "document_url",
                "document_url": "data:application/pdf;base64,\(data.base64EncodedString())"
            ],
            "pages": pages,
            "include_image_base64": false,
            "table_format": "markdown"
        ])

        let (responseData, response) = try await URLSession.shared.data(for: request)
        try processMistralHTTPResponse(response, data: responseData)
        recordMistralOCRUsage(from: responseData, fallbackPageCount: pages.count)
        return try extractOCRMarkdown(from: responseData)
    }

    private func extractDocumentTextWithMistralOCR(data: Data, mimeType: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/ocr")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(mistralAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.mistralOCRModel,
            "document": [
                "type": "document_url",
                "document_url": "data:\(mimeType);base64,\(data.base64EncodedString())"
            ],
            "include_image_base64": false,
            "table_format": "markdown"
        ])

        let (responseData, response) = try await URLSession.shared.data(for: request)
        try processMistralHTTPResponse(response, data: responseData)
        recordMistralOCRUsage(from: responseData, fallbackPageCount: 1)
        return try extractOCRMarkdown(from: responseData)
    }

    private func extractImageTextWithMistralOCR(data: Data, mimeType: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/ocr")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(mistralAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.mistralOCRModel,
            "document": [
                "type": "image_url",
                "image_url": "data:\(mimeType);base64,\(data.base64EncodedString())"
            ],
            "include_image_base64": false,
            "table_format": "markdown"
        ])

        let (responseData, response) = try await URLSession.shared.data(for: request)
        try processMistralHTTPResponse(response, data: responseData)
        recordMistralOCRUsage(from: responseData, fallbackPageCount: 1)
        return try extractOCRMarkdown(from: responseData)
    }

    private func extractOCRMarkdown(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pages = json["pages"] as? [[String: Any]]
        else {
            throw AssistantError.requestFailed("Mistral OCR returned no pages.")
        }

        return pages
            .sorted { lhs, rhs in
                (lhs["index"] as? Int ?? 0) < (rhs["index"] as? Int ?? 0)
            }
            .compactMap { page in
                let pageIndex = page["index"] as? Int
                let markdown = (page["markdown"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let markdown, !markdown.isEmpty else { return nil }
                if let pageIndex {
                    return "<!-- OCR page \(pageIndex + 1) -->\n\(markdown)"
                }
                return markdown
            }
            .joined(separator: "\n\n")
    }

    private func extractedPromptDocumentText(from url: URL) -> String {
        if let byteCount = fileByteCount(at: url),
           exceedsMistralUploadLimit(byteCount: byteCount) {
            return ""
        }

        switch url.pathExtension.lowercased() {
        case "pdf":
            return PDFDocument(url: url)?.string ?? ""
        case "docx", "doc":
            return (try? NSAttributedString(url: url, options: [:], documentAttributes: nil).string) ?? ""
        default:
            return ""
        }
    }

    private func preview(for query: String, in content: String) -> String? {
        guard let range = content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }

        let lowerBound = content.index(range.lowerBound, offsetBy: -48, limitedBy: content.startIndex) ?? content.startIndex
        let upperBound = content.index(range.upperBound, offsetBy: 96, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[lowerBound..<upperBound])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func notesFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL.appendingPathComponent("Notes", isDirectory: true)
    }

    private func filesFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL.appendingPathComponent("Files", isDirectory: true)
    }

    private func attachmentFolderURL(forExtension fileExtension: String, in brain: BrainSummary) -> URL {
        let ext = fileExtension.lowercased()
        let folderName: String
        if ext == "pdf" {
            folderName = "PDFs"
        } else if Self.supportedImageAttachmentExtensions.contains(ext) {
            folderName = "Images"
        } else {
            folderName = "Documents"
        }
        return filesFolderURL(for: brain).appendingPathComponent(folderName, isDirectory: true)
    }

    private func createWorkspaceFileFolders(in brain: BrainSummary) throws {
        try FileManager.default.createDirectory(at: filesFolderURL(for: brain), withIntermediateDirectories: true)
        for folderName in ["PDFs", "Images", "Documents"] {
            try FileManager.default.createDirectory(
                at: filesFolderURL(for: brain).appendingPathComponent(folderName, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    private func copyAttachmentToWorkspace(from sourceURL: URL) throws -> URL {
        guard let activeBrain else {
            throw AssistantError.missingConfiguration("Open or create a brain first")
        }

        return try withActiveBrainAccessThrowing {
            let destinationFolder = attachmentFolderURL(forExtension: sourceURL.pathExtension, in: activeBrain)
            try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            let destinationURL = uniqueFileURL(named: sourceURL.lastPathComponent, in: destinationFolder)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        }
    }

    private func storeAttachmentDataInWorkspace(_ data: Data, suggestedFileName: String?, kind: WorkspaceFileKind) throws -> URL {
        guard let activeBrain else {
            throw AssistantError.missingConfiguration("Open or create a brain first")
        }

        return try withActiveBrainAccessThrowing {
            let folder = filesFolderURL(for: activeBrain).appendingPathComponent(kind.folderName, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileName = kind == .images
                ? promptImageFileName(suggestedFileName: suggestedFileName)
                : ((suggestedFileName?.isEmpty == false ? suggestedFileName : nil) ?? "attached-file")
            let destinationURL = uniqueFileURL(named: fileName, in: folder)
            try data.write(to: destinationURL, options: .atomic)
            return destinationURL
        }
    }

    private func noteFileURLs(in brain: BrainSummary) throws -> [URL] {
        let folder = notesFolderURL(for: brain)
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { item in
            guard let url = item as? URL,
                  url.pathExtension == "md" || url.pathExtension == "json",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            else { return nil }
            return url
        }
    }

    private func imagesFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL.appendingPathComponent("Images", isDirectory: true)
    }

    private func resolvedMarkdownImageURL(for path: String, brain: BrainSummary) -> URL? {
        let trimmedPath = path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let decodedPath = trimmedPath.removingPercentEncoding ?? trimmedPath

        if let url = URL(string: decodedPath),
           let scheme = url.scheme,
           scheme.hasPrefix("http") || scheme == "file" {
            return url
        }

        if decodedPath.hasPrefix("/") {
            return URL(fileURLWithPath: decodedPath)
        }

        let notesFolder = notesFolderURL(for: brain)
        let imagesFolder = imagesFolderURL(for: brain)
        let fileName = (decodedPath as NSString).lastPathComponent
        let candidates = [
            notesFolder.appendingPathComponent(decodedPath).standardizedFileURL,
            brain.folderURL.appendingPathComponent(decodedPath).standardizedFileURL,
            imagesFolder.appendingPathComponent(fileName).standardizedFileURL
        ]

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) ?? candidates.first
    }

    private func hiddenHighlightsFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL
            .appendingPathComponent(".zirn", isDirectory: true)
            .appendingPathComponent("Highlights", isDirectory: true)
    }

    private func hiddenSummariesFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL
            .appendingPathComponent(".zirn", isDirectory: true)
            .appendingPathComponent("Summaries", isDirectory: true)
    }

    private func hiddenHelpDeskFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL
            .appendingPathComponent(".zirn", isDirectory: true)
            .appendingPathComponent("HelpDesk", isDirectory: true)
    }

    private func pageFlashcardsFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL
            .appendingPathComponent(".fcard", isDirectory: true)
    }

    private func helpDeskDatabaseURL(for brain: BrainSummary) -> URL {
        hiddenHelpDeskFolderURL(for: brain)
            .appendingPathComponent("conversations.json")
    }

    private func loadHelpDeskDatabase() throws {
        guard let brain = activeBrain else { return }
        let sessionDatabase = try HelpDeskSessionDatabase(vaultFolderURL: brain.folderURL, vaultID: brain.id)
        helpDeskSessionDatabase = sessionDatabase
        helpDeskDatabase = try sessionDatabase.loadDatabase()

        if helpDeskDatabase.conversations.isEmpty,
           let legacyDatabase = try loadLegacyHelpDeskDatabase(for: brain),
           !legacyDatabase.conversations.isEmpty {
            helpDeskDatabase = legacyDatabase
            try sessionDatabase.replaceAll(with: legacyDatabase)
        }

        syncHelpDeskConversations()
        selectedHelpDeskConversationID = helpDeskConversations.first?.id
    }

    private func loadLegacyHelpDeskDatabase(for brain: BrainSummary) throws -> HelpDeskDatabase? {
        let url = helpDeskDatabaseURL(for: brain)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        var database = try decoder.decode(HelpDeskDatabase.self, from: data)
        if let databaseVaultID = database.vaultID, databaseVaultID != brain.id {
            return nil
        }
        database.vaultID = brain.id
        return database
    }

    private func persistHelpDeskDatabaseQuietly() {
        do {
            try persistHelpDeskDatabase()
        } catch {
            status = error.localizedDescription
        }
    }

    private func persistHelpDeskDatabase() throws {
        guard let brain = activeBrain else { return }
        let folder = hiddenHelpDeskFolderURL(for: brain)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        helpDeskDatabase.vaultID = brain.id
        if helpDeskSessionDatabase == nil {
            helpDeskSessionDatabase = try HelpDeskSessionDatabase(vaultFolderURL: brain.folderURL, vaultID: brain.id)
        }
        try helpDeskSessionDatabase?.replaceAll(with: helpDeskDatabase)
    }

    private func persistHelpDeskConversationQuietly(_ conversation: HelpDeskConversation) {
        do {
            if helpDeskSessionDatabase == nil, let brain = activeBrain {
                helpDeskSessionDatabase = try HelpDeskSessionDatabase(vaultFolderURL: brain.folderURL, vaultID: brain.id)
            }
            try helpDeskSessionDatabase?.upsertConversation(conversation)
        } catch {
            status = error.localizedDescription
        }
    }

    private func persistHelpDeskMessageQuietly(
        _ message: HelpDeskMessage,
        conversation: HelpDeskConversation
    ) {
        do {
            if helpDeskSessionDatabase == nil, let brain = activeBrain {
                helpDeskSessionDatabase = try HelpDeskSessionDatabase(vaultFolderURL: brain.folderURL, vaultID: brain.id)
            }
            try helpDeskSessionDatabase?.upsertConversation(conversation)
            try helpDeskSessionDatabase?.insertMessage(message, conversationID: conversation.id)
        } catch {
            status = error.localizedDescription
        }
    }

    private func deleteHelpDeskConversationFromStoreQuietly(id: HelpDeskConversation.ID) {
        do {
            try helpDeskSessionDatabase?.deleteConversation(id: id)
        } catch {
            status = error.localizedDescription
        }
    }

    private func syncHelpDeskConversations() {
        helpDeskDatabase.conversations.sort { $0.updatedAt > $1.updatedAt }
        helpDeskConversations = helpDeskDatabase.conversations
        if let selectedHelpDeskConversationID,
           !helpDeskConversations.contains(where: { $0.id == selectedHelpDeskConversationID }) {
            self.selectedHelpDeskConversationID = helpDeskConversations.first?.id
        }
    }

    private func loadHighlightSummaries() throws {
        guard let brain = activeBrain else { return }
        let folder = hiddenSummariesFolderURL(for: brain)
        guard FileManager.default.fileExists(atPath: folder.path) else {
            generatedSummaries = []
            invalidateHomePagePresentationCache()
            return
        }

        let summaryURLs = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }

        generatedSummaries = try summaryURLs
            .compactMap { try readHighlightSummary(from: $0) }
            .sorted { $0.compiledAt > $1.compiledAt }
        invalidateHomePagePresentationCache()
    }

    private func upsertHighlightSummary(_ summary: HighlightSummary) {
        generatedSummaries.removeAll { $0.id == summary.id }
        generatedSummaries.insert(summary, at: 0)
        generatedSummaries.sort { $0.compiledAt > $1.compiledAt }
        invalidateHomePagePresentationCache()
    }

    private func persistHighlightSummary(_ summary: HighlightSummary) throws {
        guard activeBrain != nil else { return }
        try withActiveBrainAccessThrowing {
            guard let brain = activeBrain else { return }
            let folder = hiddenSummariesFolderURL(for: brain)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let metadata = HighlightSummaryMetadata(
                id: summary.id,
                sourceNoteID: summary.sourceNoteID,
                sourceTitle: summary.sourceTitle,
                title: summary.title,
                compiledAt: summary.compiledAt,
                compileDuration: summary.compileDuration,
                modelTitle: summary.modelTitle,
                sourceFingerprint: summary.sourceFingerprint,
                sourceDiceTokens: summary.sourceDiceTokens
            )
            let metadataData = try encoder.encode(metadata)
            guard let metadataText = String(data: metadataData, encoding: .utf8) else {
                throw CocoaError(.fileWriteUnknown)
            }

            let fileURL = folder.appendingPathComponent("\(summary.id).md")
            let markdown = "---\n\(metadataText)\n---\n\n\(summary.markdown)"
            try Data(markdown.utf8).write(to: fileURL, options: .atomic)
        }
    }

    private func readHighlightSummary(from url: URL) throws -> HighlightSummary? {
        guard let text = String(data: try Data(contentsOf: url), encoding: .utf8),
              text.hasPrefix("---\n"),
              let metadataEnd = text.range(
                of: "\n---\n",
                range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex
              )
        else {
            return nil
        }

        let metadataText = String(text[text.index(text.startIndex, offsetBy: 4)..<metadataEnd.lowerBound])
        let metadata = try decoder.decode(
            HighlightSummaryMetadata.self,
            from: Data(metadataText.utf8)
        )
        var body = String(text[metadataEnd.upperBound...])
        if body.hasPrefix("\n") {
            body.removeFirst()
        }

        return HighlightSummary(
            id: metadata.id,
            sourceNoteID: metadata.sourceNoteID,
            sourceTitle: metadata.sourceTitle,
            title: metadata.title,
            markdown: body,
            compiledAt: metadata.compiledAt,
            compileDuration: metadata.compileDuration,
            modelTitle: metadata.modelTitle,
            sourceFingerprint: metadata.sourceFingerprint,
            sourceDiceTokens: metadata.sourceDiceTokens
        )
    }

    private func persistHighlightedText(from note: Note, in brain: BrainSummary) throws {
        let highlights = highlightedTextFragments(in: note.content)
        let folder = hiddenHighlightsFolderURL(for: brain)
        let fileURL = folder.appendingPathComponent("\(note.id).md")

        guard !highlights.isEmpty else {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            return
        }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let body = pageHighlightChunk(title: note.title, highlights: highlights) ?? "No highlighted text."
        let markdown = """
        # Highlights for \(note.title)

        Source note: \(note.id)
        Updated: \(ISO8601DateFormatter().string(from: note.updatedAt))

        \(body)
        """
        try Data(markdown.utf8).write(to: fileURL, options: .atomic)
    }

    private func highlightedTextFragments(in markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"==(.+?)=="#,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }
        let nsMarkdown = markdown as NSString
        let fullRange = NSRange(location: 0, length: nsMarkdown.length)

        return regex.matches(in: markdown, range: fullRange).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let text = nsMarkdown.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    private func appendMarkdownBlock(_ markdown: String) {
        let separator = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
        updateContentFromEditor(content + separator + markdown + "\n")
    }

    private func uniqueImageFileName(suggestedFileName: String?, in folder: URL) -> String {
        let cleanBase = (suggestedFileName as NSString?)?.deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fallbackBase = "image-\(formatter.string(from: Date()))"
        let base = imageSafeFileName(cleanBase?.isEmpty == false ? cleanBase! : fallbackBase)
        let rawExtension = (suggestedFileName as NSString?)?.pathExtension.lowercased()
        let fileExtension = rawExtension?.isEmpty == false ? rawExtension! : "png"

        var candidate = "\(base).\(fileExtension)"
        var counter = 2
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(counter).\(fileExtension)"
            counter += 1
        }
        return candidate
    }

    private func promptImageFileName(suggestedFileName: String?) -> String {
        let cleanBase = (suggestedFileName as NSString?)?.deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fallbackBase = "pasted-image-\(formatter.string(from: Date()))"
        let base = imageSafeFileName(cleanBase?.isEmpty == false ? cleanBase! : fallbackBase)
        let rawExtension = (suggestedFileName as NSString?)?.pathExtension.lowercased()
        let fileExtension = rawExtension?.isEmpty == false ? rawExtension! : "png"
        return "\(base).\(fileExtension)"
    }

    private func imageMimeType(forFileName fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "heic":
            return "image/heic"
        case "tif", "tiff":
            return "image/tiff"
        case "webp":
            return "image/webp"
        case "avif":
            return "image/avif"
        default:
            return "image/png"
        }
    }

    private func documentMimeType(forFileName fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default:
            return "application/octet-stream"
        }
    }

    private func imageSafeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let output = name
            .lowercased()
            .map { character -> Character in
                let scalar = character.unicodeScalars.first
                return scalar.map { allowed.contains($0) } == true ? character : "-"
            }
        let cleanName = String(output)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return cleanName.isEmpty ? "image" : cleanName
    }

    private func imageAltText(from fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return base
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    private func noteURL(for id: Note.ID) -> URL? {
        guard let activeBrain else { return nil }
        return noteURL(for: id, in: activeBrain)
    }

    private func noteURL(for id: Note.ID, in brain: BrainSummary) -> URL? {
        let folder = notesFolderURL(for: brain)
        if let indexedFileName = noteIdentityDatabase?.fileName(forNoteID: id) {
            let indexedURL = folder.appendingPathComponent(indexedFileName)
            if FileManager.default.fileExists(atPath: indexedURL.path) {
                return indexedURL
            }
        }

        let markdownURL = folder.appendingPathComponent("\(id).md")
        if FileManager.default.fileExists(atPath: markdownURL.path) {
            return markdownURL
        }

        if let urls = try? noteFileURLs(in: brain),
           let matchingMarkdown = urls.first(where: { url in
               guard let note = try? readNote(from: url) else { return false }
               return note.id == id
           }) {
            return matchingMarkdown
        }

        let jsonURL = folder.appendingPathComponent("\(id).json")
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            return jsonURL
        }

        return nil
    }

    private func relativeNoteFileName(for url: URL, in brain: BrainSummary) -> String {
        let folderPath = notesFolderURL(for: brain).standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        let prefix = folderPath.hasSuffix("/") ? folderPath : "\(folderPath)/"
        guard filePath.hasPrefix(prefix) else { return url.lastPathComponent }
        return String(filePath.dropFirst(prefix.count))
    }

    private func sidebarGroupTitle(fromRelativeFileName fileName: String) -> String? {
        let components = fileName
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard components.count > 1 else { return nil }
        return sanitizedSidebarGroupTitle(components[0])
    }

    private func markdownNoteURL(for note: Note, in brain: BrainSummary, allowing existingURL: URL? = nil) -> URL {
        let folder = sidebarGroupID(forNoteID: note.id)
            .flatMap { sidebarGroup(for: $0) }
            .map { sidebarGroupFolderURL(for: $0, in: brain) }
            ?? notesFolderURL(for: brain)
        return markdownNoteURL(for: note, inFolder: folder, allowing: existingURL)
    }

    private func markdownNoteURL(for note: Note, inFolder folder: URL, allowing existingURL: URL? = nil) -> URL {
        uniqueFileURL(
            named: markdownFileName(for: note.title),
            in: folder,
            allowing: existingURL
        )
    }

    private func sidebarGroup(for id: SidebarItem.ID) -> SidebarItem? {
        sidebarItems.first { $0.id == id && $0.kind == .group }
    }

    private func sidebarGroupID(forNoteID noteID: Note.ID) -> SidebarItem.ID? {
        sidebarItems.first { $0.kind == .note && $0.noteID == noteID }?.groupID
    }

    private func sidebarGroupFolderURL(for group: SidebarItem, in brain: BrainSummary) -> URL {
        sidebarGroupFolderURL(forTitle: group.title, in: brain)
    }

    private func sidebarGroupFolderURL(forTitle title: String, in brain: BrainSummary) -> URL {
        notesFolderURL(for: brain)
            .appendingPathComponent(sidebarGroupFolderName(for: title), isDirectory: true)
    }

    private func sidebarGroupFolderName(for title: String) -> String {
        let clean = title
            .components(separatedBy: CharacterSet(charactersIn: "/:\\"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return clean.isEmpty ? "Group" : clean
    }

    private func sanitizedSidebarGroupTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !looksLikeGeneratedSidebarID(clean) else {
            return nextSidebarGroupTitle()
        }
        return clean
    }

    private func looksLikeGeneratedSidebarID(_ title: String) -> Bool {
        let uuidPattern = #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#
        if title.range(of: uuidPattern, options: .regularExpression) != nil {
            return true
        }
        return title.hasPrefix("group-") && title.count > 18
    }

    private func uniqueSidebarGroupTitle(_ title: String, excluding excludedID: SidebarItem.ID? = nil) -> String {
        let baseTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExisting = Set(
            sidebarItems
                .filter { $0.kind == .group && $0.id != excludedID }
                .map { normalizedLinkTitle($0.title) }
        )
        guard normalizedExisting.contains(normalizedLinkTitle(baseTitle)) else {
            return baseTitle
        }

        var suffix = 2
        while true {
            let candidate = "\(baseTitle) \(suffix)"
            if !normalizedExisting.contains(normalizedLinkTitle(candidate)) {
                return candidate
            }
            suffix += 1
        }
    }

    private func persistSidebarLayoutAndFilesystem(for item: SidebarItem, in brain: BrainSummary) {
        withSecurityScopedAccess(to: brain.folderURL) {
            do {
                if item.kind == .note, let noteID = item.noteID {
                    try moveNoteFile(noteID: noteID, toGroupID: item.groupID, in: brain)
                }
                try persistSidebarLayoutNoAccess()
                try loadNotes()
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func moveNotesInGroupToFilesystem(groupID: SidebarItem.ID, in brain: BrainSummary) throws {
        let childNoteIDs = sidebarItems
            .filter { $0.kind == .note && $0.groupID == groupID }
            .compactMap(\.noteID)
        for noteID in childNoteIDs {
            try moveNoteFile(noteID: noteID, toGroupID: groupID, in: brain)
        }
    }

    private func moveNoteFile(noteID: Note.ID, toGroupID groupID: SidebarItem.ID?, in brain: BrainSummary) throws {
        guard let sourceURL = noteURL(for: noteID, in: brain),
              FileManager.default.fileExists(atPath: sourceURL.path)
        else { return }

        let note = try readNote(from: sourceURL)
        let destinationFolder: URL
        if let groupID, let group = sidebarGroup(for: groupID) {
            destinationFolder = sidebarGroupFolderURL(for: group, in: brain)
        } else {
            destinationFolder = notesFolderURL(for: brain)
        }
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let destinationURL = uniqueFileURL(
            named: sourceURL.lastPathComponent,
            in: destinationFolder,
            allowing: sourceURL
        )
        if sourceURL.standardizedFileURL != destinationURL.standardizedFileURL {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            try removeEmptyNoteSubfolder(containing: sourceURL, in: brain)
        }

        try noteIdentityDatabase?.upsert(
            noteID: note.id,
            title: note.title,
            fileName: relativeNoteFileName(for: destinationURL, in: brain),
            updatedAt: note.updatedAt
        )
    }

    private func moveSidebarGroupFolder(from oldURL: URL, to newURL: URL) throws {
        if oldURL.standardizedFileURL == newURL.standardizedFileURL {
            try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
            return
        }

        if FileManager.default.fileExists(atPath: oldURL.path) {
            if FileManager.default.fileExists(atPath: newURL.path) {
                try mergeDirectoryContents(from: oldURL, into: newURL)
            } else {
                try FileManager.default.createDirectory(
                    at: newURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        } else {
            try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
        }
    }

    private func mergeDirectoryContents(from source: URL, into destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let children = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for child in children {
            let target = uniqueFileURL(named: child.lastPathComponent, in: destination, allowing: child)
            try FileManager.default.moveItem(at: child, to: target)
        }
        try? FileManager.default.removeItem(at: source)
    }

    private func removeSidebarGroupFolderIfEmpty(title: String, in brain: BrainSummary) throws {
        let folder = sidebarGroupFolderURL(forTitle: title, in: brain)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        let children = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        if children.isEmpty {
            try FileManager.default.removeItem(at: folder)
        }
    }

    private func removeEmptyNoteSubfolder(containing fileURL: URL, in brain: BrainSummary) throws {
        let notesFolder = notesFolderURL(for: brain).standardizedFileURL
        let parent = fileURL.deletingLastPathComponent().standardizedFileURL
        guard parent != notesFolder,
              parent.path.hasPrefix(notesFolder.path)
        else { return }

        let children = try FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)
        if children.isEmpty {
            try FileManager.default.removeItem(at: parent)
        }
    }

    private func uniqueFileURL(named fileName: String, in folder: URL, allowing existingURL: URL? = nil) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = folder.appendingPathComponent(fileName)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path),
              candidate.standardizedFileURL != existingURL?.standardizedFileURL {
            let nextName = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
            candidate = folder.appendingPathComponent(nextName)
            suffix += 1
        }
        return candidate
    }

    private func existingCreatedAt(for id: Note.ID) -> Date? {
        guard let noteURL = noteURL(for: id),
              let data = try? Data(contentsOf: noteURL),
              let note = try? readNote(from: noteURL, data: data)
        else {
            return nil
        }
        return note.createdAt
    }

    private func markdownFileName(for title: String) -> String {
        markdownDisplayFileName(for: title)
    }

    private func markdownDisplayFileName(for title: String) -> String {
        let cleanName = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\((cleanName.isEmpty ? "Untitled" : cleanName)).md"
    }

    private func markdownDocumentTitle(in markdown: String) -> String? {
        markdown
            .components(separatedBy: .newlines)
            .first { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("# ")
            }
            .map { line in
                line
                    .trimmingCharacters(in: .whitespaces)
                    .dropFirst(2)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private func contentBySettingDocumentTitle(_ title: String, in markdown: String) -> String {
        let cleanTitle = displayTitle(for: title)
        var lines = markdown.components(separatedBy: .newlines)

        if let headingIndex = lines.firstIndex(where: { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("# ")
        }) {
            lines[headingIndex] = "# \(cleanTitle)"
            return lines.joined(separator: "\n")
        }

        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "# \(cleanTitle)\n\n"
        }

        return "# \(cleanTitle)\n\n\(markdown)"
    }

    private func displayTitle(for title: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanTitle.isEmpty ? "Untitled" : cleanTitle
    }

    private func uniqueTitle(for proposedTitle: String, excluding excludedID: Note.ID? = nil) -> String {
        let baseTitle = displayTitle(for: proposedTitle)
        let takenTitles = Set(
            notes
                .filter { $0.id != excludedID }
                .map { normalizedLinkTitle($0.title) }
        )
        return uniqueTitle(baseTitle, isTaken: { takenTitles.contains(normalizedLinkTitle($0)) })
    }

    private func uniqueTitle(for proposedTitle: String, reserving reservedTitles: inout Set<String>) -> String {
        let baseTitle = displayTitle(for: proposedTitle)
        let resolvedTitle = uniqueTitle(baseTitle) { candidate in
            reservedTitles.contains(normalizedLinkTitle(candidate))
        }
        reservedTitles.insert(normalizedLinkTitle(resolvedTitle))
        return resolvedTitle
    }

    private func uniqueTitle(_ baseTitle: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(baseTitle) else { return baseTitle }

        var suffix = 1
        while true {
            let candidate = "\(baseTitle)_(\(suffix))"
            if !isTaken(candidate) {
                return candidate
            }
            suffix += 1
        }
    }

    private func updateCurrentNoteSummaryTitle(to title: String) {
        guard let currentNoteID,
              let index = notes.firstIndex(where: { $0.id == currentNoteID })
        else { return }

        notes[index] = NoteSummary(
            id: notes[index].id,
            title: title,
            updatedAt: notes[index].updatedAt
        )
    }

    private func loadRecentVaults() {
        guard let data = UserDefaults.standard.data(forKey: recentVaultsKey),
              let recentVaults = try? decoder.decode([RecentVault].self, from: data)
        else {
            return
        }

        self.recentVaults = recentVaults.filter { $0.bookmarkData != nil }
        if self.recentVaults.count != recentVaults.count {
            saveRecentVaults()
        }
    }

    private func saveRecentVaults() {
        guard let data = try? encoder.encode(recentVaults) else { return }
        UserDefaults.standard.set(data, forKey: recentVaultsKey)
    }

    private func recordRecentVault(note: NoteSummary?) {
        guard let activeBrain else { return }

        let updatedAt = note?.updatedAt ?? activeBrain.updatedAt
        let noteFileName = note
            .flatMap { noteURL(for: $0.id, in: activeBrain) }
            .map { relativeNoteFileName(for: $0, in: activeBrain) }
            ?? note.map { markdownDisplayFileName(for: $0.title) }
        let entry = RecentVault(
            folderPath: activeBrain.folderURL.path,
            brainPath: activeBrain.brainURL.path,
            brainFileName: activeBrain.brainURL.lastPathComponent,
            noteFileName: noteFileName,
            updatedAt: updatedAt,
            bookmarkData: securityScopedBookmarkData(for: activeBrain.folderURL)
        )

        recentVaults.removeAll { $0.brainPath == entry.brainPath }
        recentVaults.insert(entry, at: 0)
        recentVaults = Array(recentVaults.prefix(6))
        saveRecentVaults()
    }

    private func noteID(forRecentNoteFileName fileName: String, in brain: BrainSummary) -> Note.ID? {
        if let indexedID = noteIdentityDatabase?.noteID(forFileName: fileName) {
            return indexedID
        }

        let notesFolder = notesFolderURL(for: brain)
        let directURL = notesFolder.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: directURL.path),
           let note = try? readNote(from: directURL) {
            return note.id
        }

        guard let urls = try? noteFileURLs(in: brain) else { return nil }
        return urls.compactMap { url -> Note.ID? in
            let relativeName = relativeNoteFileName(for: url, in: brain)
            guard relativeName == fileName || url.lastPathComponent == fileName else { return nil }
            return (try? readNote(from: url))?.id
        }.first
    }

    private func removeRecentVault(for brainURL: URL) {
        recentVaults.removeAll { $0.brainPath == brainURL.path }
        saveRecentVaults()
    }

    private func securityScopedBookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func withActiveBrainAccess(_ action: () throws -> Void) {
        guard let folderURL = activeBrain?.folderURL else {
            status = "Open or create a brain first"
            return
        }

        withSecurityScopedAccess(to: folderURL) {
            do {
                try action()
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func withActiveBrainAccessThrowing<T>(_ action: () throws -> T) throws -> T {
        guard let folderURL = activeBrain?.folderURL else {
            throw AssistantError.missingConfiguration("Open or create a brain first")
        }

        var result: Result<T, Error>?
        withSecurityScopedAccess(to: folderURL) {
            result = Result { try action() }
        }
        guard let result else {
            throw AssistantError.requestFailed("Could not access the active brain folder.")
        }
        return try result.get()
    }

    private func withSecurityScopedAccess(to url: URL, _ action: () -> Void) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        action()
    }

    private static let starterMarkdown = """
    # Untitled

    Start writing your note here.
    """
}

let starterMarkdown = """
# Untitled

Start writing your note here.
"""

struct BrainSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let folderURL: URL
    let brainURL: URL
    let updatedAt: Date
}

struct NoteSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let updatedAt: Date
}

struct SidebarItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case note
        case group
    }

    var id: String
    var kind: Kind
    var noteID: String?
    var title: String
    var groupID: String?
    var isExpanded: Bool

    init(
        id: String,
        kind: Kind,
        noteID: String?,
        title: String,
        groupID: String? = nil,
        isExpanded: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.noteID = noteID
        self.title = title
        self.groupID = groupID
        self.isExpanded = isExpanded
    }

    init(note: NoteSummary, groupID: String? = nil) {
        id = "note-\(note.id)"
        kind = .note
        noteID = note.id
        title = note.title
        self.groupID = groupID
        isExpanded = true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case noteID
        case title
        case groupID
        case isExpanded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        noteID = try container.decodeIfPresent(String.self, forKey: .noteID)
        title = try container.decode(String.self, forKey: .title)
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID)
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
    }
}

struct NoteSearchResult: Identifiable, Equatable {
    let id: String
    let noteID: String
    let title: String
    let preview: String
    let query: String
    let blockIndex: Int?
}

struct MarkdownRelevanceCandidate: Identifiable, Equatable {
    let id: String
    let noteID: String
    let title: String
    let text: String
    let kind: String
    let rank: Int
    let updatedAt: Date
}

private struct NoteSearchIndexEntry {
    let noteID: String
    let title: String
    let displayText: String
    let normalizedText: String
    let blockIndex: Int?
    let kind: String
    let rank: Int
    let updatedAt: Date
}

private struct SemanticSearchIndexEntry {
    let noteID: String
    let title: String
    let displayText: String
    let blockIndex: Int?
    let kind: String
    let updatedAt: Date
    let vector: [Double]
}

struct SearchHighlight: Equatable {
    let noteID: String
    let query: String
    let blockIndex: Int
}

struct PromptAttachment: Equatable {
    let fileName: String
    let fileExtension: String
    let extractedText: String
    let storedFileURL: URL?

    init(fileName: String, fileExtension: String, extractedText: String, storedFileURL: URL? = nil) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.extractedText = extractedText
        self.storedFileURL = storedFileURL
    }
}

struct PromptLinkedPage: Identifiable, Equatable {
    let id = UUID()
    let title: String
}

struct HelpDeskDatabase: Codable, Equatable {
    var vaultID: String?
    var conversations: [HelpDeskConversation]
}

struct HelpDeskConversation: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var messages: [HelpDeskMessage]
    let createdAt: Date
    var updatedAt: Date
}

struct HelpDeskMessage: Identifiable, Codable, Equatable {
    let id: String
    let role: HelpDeskMessageRole
    let content: String
    let attachmentName: String?
    let createdAt: Date
}

struct HelpDeskMarkdownSuggestion: Identifiable, Equatable {
    let messageID: String
    let conversationID: String
    let action: Action
    let pageTitle: String
    let formattedMarkdown: String
    let isLoading: Bool

    var id: String { messageID }

    enum Action: Equatable {
        case appendToExisting
        case createNew
    }
}

private struct HelpDeskMarkdownPlacementResolution {
    enum Action {
        case append
        case create
    }

    let action: Action
    let noteTitle: String?
    let suggestedPageTitle: String?
    let formattedMarkdown: String
}

enum HelpDeskMessageRole: String, Codable, Equatable {
    case user
    case assistant

    var chatRole: String {
        switch self {
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        }
    }
}

struct RecentVault: Identifiable, Codable, Equatable {
    var id: String { brainPath }

    let folderPath: String?
    let brainPath: String
    let brainFileName: String
    let noteFileName: String?
    let updatedAt: Date
    let bookmarkData: Data?
}

struct AssistantConfiguration: Equatable {
    let mistralAPIKey: String
    let mistralModel: String
    let deepSeekAPIKey: String
    let deepSeekModel: String
}

struct OllamaConfiguration: Equatable {
    let model: String
    let baseURL: String
}

struct AssistantPreview: Identifiable, Equatable {
    let id = UUID()
    let prompt: String
    let markdown: String
    let providerTitle: String
    let createdAt: Date
}

struct AssistantConversationResponse: Identifiable, Equatable {
    let id = UUID()
    let prompt: String
    var answer: String
    let providerTitle: String
    let createdAt: Date

    var offersPageInsertion: Bool {
        Self.detectsPageInsertionOffer(in: answer)
    }

    static func detectsPageInsertionOffer(in answer: String) -> Bool {
        let normalized = answer
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let offerPhrases = [
            "want me to add",
            "want me to write",
            "would you like me to add",
            "would you like me to write",
            "should i add",
            "should i write",
            "shall i add",
            "shall i write",
            "like me to add this",
            "like me to write this",
            "i can add this",
            "i can write this",
            "i can write that",
            "add this to your page",
            "add this to the page",
            "add it to your page",
            "add it to the page",
            "add this to your note",
            "add this to the note",
            "write that down",
            "write this down",
            "write it down",
            "put this on the page",
            "put this in your note",
            "put that on the page",
            "drop this into your page",
            "save this to your page",
            "on the page if you want",
            "to your page if you want",
            "in the paper if you want",
            "on the paper if you want",
            "use the + button",
            "plus button",
            "tap +",
            "click +",
        ]

        if offerPhrases.contains(where: { normalized.contains($0) }) {
            return true
        }

        let questionOfferPatterns = [
            "add this to",
            "add it to",
            "write this on",
            "write that on",
            "put this in",
            "put that in",
        ]
        return normalized.contains("?")
            && questionOfferPatterns.contains { normalized.contains($0) }
    }
}

private struct LangChainConversationMemory {
    private var turns: [AssistantConversationResponse] = []
    private let maxTurns = 8

    mutating func append(_ turn: AssistantConversationResponse) {
        turns.append(turn)
        if turns.count > maxTurns {
            turns.removeFirst(turns.count - maxTurns)
        }
    }

    mutating func clear() {
        turns.removeAll()
    }

    func transcript(clipping: (String) -> String) -> String {
        guard !turns.isEmpty else { return "None" }

        return turns.map { turn in
            """
            User:
            \(turn.prompt)

            Assistant:
            \(clipping(turn.answer))
            """
        }
        .joined(separator: "\n\n")
    }

    func chatMessages(clipping: (String) -> String) -> [[String: String]] {
        turns.flatMap { turn in
            [
                [
                    "role": "user",
                    "content": turn.prompt
                ],
                [
                    "role": "assistant",
                    "content": clipping(turn.answer)
                ]
            ]
        }
    }
}

private enum AssistantPromptIntent {
    case writing
    case conversation
}

private struct ChatCompletionResult {
    let content: String
    let inputTokens: Int?
    let outputTokens: Int?
    let cachedInputTokens: Int?

    init(content: String, inputTokens: Int?, outputTokens: Int?, cachedInputTokens: Int? = nil) {
        self.content = content
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
    }
}

struct AssistantGenerationDiagnostics: Equatable {
    let contextBuildSeconds: TimeInterval
    let requestByteCount: Int
    let estimatedInputTokens: Int
    let responseSeconds: TimeInterval
    let includedSources: String
    let errorType: String?
}

private struct AssistantConversationContext {
    let input: String
    let estimatedTokens: Int
    let includedSources: String
    let buildDuration: TimeInterval
    let characterBudget: Int
}

private struct HomePageSourceNote {
    let id: String
    let title: String
    let content: String
    let updatedAt: Date
}

private struct HelpDeskContextCandidate {
    let noteID: String
    let title: String
    let text: String
    let score: Double
    let updatedAt: Date
}

private struct HomePagePreparedNote {
    let id: String
    let title: String
    let preparedMarkdown: String
    let highlights: [String]
}

private struct HomePreparedNoteCacheEntry {
    let preparedMarkdown: String
}

private struct CalendarRecommendationCandidate {
    let noteID: Note.ID
    let title: String
    let excerpt: String
    let updatedAt: Date
}

private struct CalendarPageRecommendationResponse: Decodable {
    let noteID: Note.ID
    let reasoning: String
}

private struct SmartFeatureBlob: Codable {
    let version: Int
    let vaultID: String
    let brainFileName: String
    let brainPath: String
    let feature: String
    let createdAt: Date
    let event: CalendarRecommendationEvent
    let selectedNoteID: Note.ID
    let selectedTitle: String
    let reasoning: String
    let usedAI: Bool
    let candidateTitles: [String]
}

struct NextCalendarClassOverview: Equatable {
    let event: CalendarRecommendationEvent
    let title: String
    let timingText: String?
    let locationText: String?
    let continueNoteID: Note.ID?
}

struct PageFlashcardState: Equatable {
    let isLoading: Bool
    let bundle: PageFlashcardBundle?
    let pinnedCardIDs: Set<String>
    let errorMessage: String?

    static let idle = PageFlashcardState(isLoading: false, bundle: nil, pinnedCardIDs: [], errorMessage: nil)
}

struct PageFlashcardBundle: Codable, Equatable {
    let noteID: Note.ID
    let noteTitle: String
    let sourceFingerprint: String
    let sourceDiceTokens: [String]
    let generatedAt: Date
    let modelTitle: String
    let cards: [PageFlashcard]
}

struct PageFlashcardCacheFile: Codable, Equatable {
    static let currentVersion = 2

    let version: Int
    let bundle: PageFlashcardBundle
    let pinnedCardIDs: [String]?
    let previousSimilarityScore: Double?
    let latestSimilarityScore: Double?
    let similarityThreshold: Double
    let lastCheckedAt: Date
}

struct PageFlashcard: Identifiable, Codable, Equatable {
    let id: String
    let question: String
    let answer: String
    let anchor: String
}

private struct PageFlashcardResponse: Codable {
    let cards: [Card]

    struct Card: Codable {
        let question: String
        let answer: String
        let anchor: String
    }
}

struct HomePagePresentation: Equatable {
    let vaultSummary: String
    let pageCards: [HomePagePageCard]
    let flashcardGroups: [HomePageFlashcardGroup]
}

struct HomePagePageCard: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let noteID: Note.ID?
}

struct HomePageFlashcardGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let cards: [HomePageFlashcard]
}

struct HomePageFlashcard: Identifiable, Equatable {
    let id: String
    let question: String
    let answer: String
}

struct HighlightSummary: Identifiable, Equatable {
    let id: String
    let sourceNoteID: String
    let sourceTitle: String
    let title: String
    let markdown: String
    let compiledAt: Date
    let compileDuration: TimeInterval
    let modelTitle: String
    let sourceFingerprint: String?
    let sourceDiceTokens: [String]?
}

private struct HighlightSummaryMetadata: Codable {
    let id: String
    let sourceNoteID: String
    let sourceTitle: String
    let title: String
    let compiledAt: Date
    let compileDuration: TimeInterval
    let modelTitle: String
    let sourceFingerprint: String?
    let sourceDiceTokens: [String]?
}

enum HighlightSummaryModel: String, CaseIterable, Identifiable {
    case mistral
    case deepseek
    case ollama

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mistral:
            return "Mistral"
        case .deepseek:
            return "DeepSeek (beta)"
        case .ollama:
            return "Ollama"
        }
    }

    func displayModelName(mistralModel: String, deepSeekModel: String, ollamaModel: String) -> String {
        switch self {
        case .mistral:
            return "Mistral \(mistralModel)"
        case .deepseek:
            return "DeepSeek \(deepSeekModel)"
        case .ollama:
            return "Ollama \(ollamaModel)"
        }
    }
}

enum AssistantModel: String, CaseIterable, Identifiable {
    case mistral
    case deepseek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mistral:
            return "Mistral"
        case .deepseek:
            return "DeepSeek (beta)"
        }
    }

    var supportsWebSearch: Bool {
        false
    }
}

enum AssistantConnectionStatus {
    case online
    case offline
    case local

    var helpText: String {
        switch self {
        case .online:
            return "API status is good and online"
        case .offline:
            return "API status is offline. Add or verify an API key."
        case .local:
            return "Using a local model"
        }
    }
}

enum AssistantError: LocalizedError {
    case missingConfiguration(String)
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let message), .requestFailed(let message):
            message
        }
    }
}

private enum FileSafetyError: LocalizedError {
    case noteTooLarge(fileName: String, size: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .noteTooLarge(let fileName, let size, let limit):
            let sizeText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            let limitText = ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)
            return "\(fileName) is too large to open (\(sizeText)). Split it into pages under \(limitText)."
        }
    }
}

private enum SidebarGroupDeletionChoice {
    case dismiss
    case deleteGroupOnly
    case deleteGroupAndPages
}

struct Note: Identifiable, Codable {
    let id: String
    let title: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
}

private struct MarkdownNoteMetadata: Codable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
}

struct BrainFile: Codable {
    var schemaVersion: Int
    var vault: VaultIdentity
    var rootNoteID: String?
    var graph: BrainGraph
    var sidebar: BrainSidebarLayout? = nil
    var sourceRegistry: SourceRegistryPointer
    var ai: BrainAIPreferences
    var styleMemory: [String]
    var memory: BrainMemory?
    var app: BrainAppCompatibility
}

struct BrainMemory: Codable {
    var writingArtifacts: [WritingArtifact]
    var preferences: [String]
    var correctionSignals: [CorrectionSignal]? = nil
    var correctionPreferences: [CorrectionPreference]? = nil
    var updatedAt: Date?
}

struct WritingArtifact: Codable, Identifiable {
    let id: String
    let sourceNoteID: String?
    let sourceTitle: String
    let excerpt: String
    let wordCount: Int
    let createdAt: Date
}

struct VaultIdentity: Codable {
    var id: String
    var name: String
    var createdAt: Date
    var updatedAt: Date
}

struct BrainGraph: Codable {
    var notes: [BrainNoteReference]
    var links: [BrainLinkReference]
}

struct BrainSidebarLayout: Codable {
    var items: [BrainSidebarItem]
}

struct BrainSidebarItem: Codable {
    var id: String
    var kind: SidebarItem.Kind
    var noteID: String?
    var title: String
    var groupID: String? = nil
    var isExpanded: Bool = true

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case noteID
        case title
        case groupID
        case isExpanded
    }

    init(_ item: SidebarItem) {
        id = item.id
        kind = item.kind
        noteID = item.noteID
        title = item.title
        groupID = item.groupID
        isExpanded = item.isExpanded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(SidebarItem.Kind.self, forKey: .kind)
        noteID = try container.decodeIfPresent(String.self, forKey: .noteID)
        title = try container.decode(String.self, forKey: .title)
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID)
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
    }

    var sidebarItem: SidebarItem {
        SidebarItem(
            id: id,
            kind: kind,
            noteID: noteID,
            title: title,
            groupID: groupID,
            isExpanded: isExpanded
        )
    }
}

struct BrainNoteReference: Codable {
    var id: String
    var title: String
    var updatedAt: Date
}

struct BrainLinkReference: Codable {
    var from: String
    var to: String
    var kind: String
}

struct SourceRegistryPointer: Codable {
    var path: String
}

struct BrainAIPreferences: Codable {
    var provider: String
    var mistralModel: String? = nil
    var deepSeekModel: String? = nil
    var openaiModel: String? = nil
    var ollamaModel: String? = nil
    var ollamaURL: String? = nil
    var appleModel: String? = nil
}

struct BrainAppCompatibility: Codable {
    var appID: String
    var minAppVersion: String
    var lastOpenedWith: String
}

private struct ShareExportDocument {
    let title: String
    let markdown: String

    var fileName: String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let clean = title
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Untitled" : String(clean.prefix(96))
    }
}

private final class MarkdownPDFRenderer: NSObject, WKNavigationDelegate {
    private enum ExportError: LocalizedError {
        case loadFailed
        case printFailed
        case pdfMissing

        var errorDescription: String? {
            switch self {
            case .loadFailed:
                return "Could not prepare the PDF."
            case .printFailed:
                return "Could not write the PDF."
            case .pdfMissing:
                return "The PDF export did not finish."
            }
        }
    }

    private var continuation: CheckedContinuation<Void, Error>?

    @MainActor
    func writePDF(
        markdown: String,
        title: String,
        to url: URL,
        imageData: @escaping (String) -> Data?
    ) async throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 794, height: 1123))
        webView.navigationDelegate = self

        let html = MarkdownExportHTMLBuilder(
            title: title,
            markdown: markdown,
            imageData: imageData
        ).html()

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
        }

        try await Task.sleep(nanoseconds: 220_000_000)

        let heightValue = try await webView.evaluateJavaScript(
            "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
        )
        let contentHeight = max(1123, CGFloat((heightValue as? NSNumber)?.doubleValue ?? 1123))
        webView.frame = CGRect(x: 0, y: 0, width: 794, height: contentHeight)

        let configuration = WKPDFConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: 794, height: contentHeight)
        let data = try await webView.pdf(configuration: configuration)
        try data.write(to: url, options: .atomic)
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            self?.finishLoading()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            self?.failLoading(error)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            self?.failLoading(error)
        }
    }

    @MainActor
    private func finishLoading() {
        continuation?.resume()
        continuation = nil
    }

    @MainActor
    private func failLoading(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private struct MarkdownExportHTMLBuilder {
    let title: String
    let markdown: String
    let imageData: (String) -> Data?

    func html() -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body {
          color: #111;
          font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
          font-size: 14px;
          line-height: 1.55;
          margin: 0;
        }
        h1, h2, h3, h4, h5, h6 { line-height: 1.18; margin: 0.82em 0 0.32em; }
        h1 { font-size: 28px; }
        h2 { font-size: 23px; }
        h3 { font-size: 19px; }
        p { margin: 0 0 10px; }
        ul, ol { margin: 0 0 12px; padding-left: 24px; }
        li { margin: 4px 0; }
        blockquote { border-left: 3px solid #c9ced6; color: #4a4f57; margin: 12px 0; padding: 2px 0 2px 13px; }
        pre { background: #f3f5f7; border: 1px solid #dfe3e8; border-radius: 6px; font-size: 12px; line-height: 1.45; overflow-wrap: anywhere; padding: 11px 12px; white-space: pre-wrap; }
        code { background: #eef1f4; border-radius: 4px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 0.92em; padding: 1px 4px; }
        pre code { background: transparent; padding: 0; }
        mark { background: rgba(255, 224, 102, 0.62); border-radius: 3px; padding: 0 2px; }
        table { border-collapse: collapse; margin: 12px 0 16px; width: 100%; }
        th, td { border: 1px solid #d9dde3; padding: 7px 8px; text-align: left; vertical-align: top; }
        th { background: #f2f4f6; font-weight: 600; }
        hr { border: 0; border-top: 1px solid #d9dde3; margin: 18px 0; }
        img { display: block; height: auto; margin: 12px auto; max-width: 100%; }
        figcaption { color: #666; font-size: 12px; margin-top: -5px; text-align: center; }
        a { color: #1f66d1; text-decoration: underline; }
        .task-marker { color: #3f8f46; font-weight: 600; }
        </style>
        </head>
        <body>
        \(bodyHTML())
        </body>
        </html>
        """
    }

    private func bodyHTML() -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var output: [String] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var isInCodeBlock = false
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            output.append("<p>\(paragraph.map(inlineHTML).joined(separator: "<br>"))</p>")
            paragraph.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    output.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                    codeLines.removeAll()
                } else {
                    flushParagraph()
                }
                isInCodeBlock.toggle()
                index += 1
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
                index += 1
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if let table = tableHTML(startingAt: index, in: lines) {
                flushParagraph()
                output.append(table.html)
                index += table.consumed
                continue
            }

            if let heading = headingHTML(trimmed) {
                flushParagraph()
                output.append(heading)
            } else if let image = imageHTML(trimmed) {
                flushParagraph()
                output.append(image)
            } else if isDivider(trimmed) {
                flushParagraph()
                output.append("<hr>")
            } else if let task = taskHTML(trimmed) {
                flushParagraph()
                output.append("<ul><li>\(task)</li></ul>")
            } else if let bullet = bulletText(trimmed) {
                flushParagraph()
                output.append("<ul><li>\(inlineHTML(bullet))</li></ul>")
            } else if let numbered = numberedText(trimmed) {
                flushParagraph()
                output.append("<ol start=\"\(numbered.number)\"><li>\(inlineHTML(numbered.text))</li></ol>")
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                output.append("<blockquote>\(inlineHTML(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))</blockquote>")
            } else {
                paragraph.append(trimmed)
            }

            index += 1
        }

        flushParagraph()
        if isInCodeBlock, !codeLines.isEmpty {
            output.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
        }

        return output.joined(separator: "\n")
    }

    private func headingHTML(_ line: String) -> String? {
        let markers = line.prefix { $0 == "#" }
        guard !markers.isEmpty, markers.count <= 6 else { return nil }
        let rest = line.dropFirst(markers.count)
        guard rest.first == " " else { return nil }
        let level = markers.count
        return "<h\(level)>\(inlineHTML(rest.trimmingCharacters(in: .whitespaces)))</h\(level)>"
    }

    private func imageHTML(_ line: String) -> String? {
        guard line.hasPrefix("!["),
              let altEnd = line.range(of: "]("),
              line.hasSuffix(")")
        else { return nil }

        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<altEnd.lowerBound])
        let path = String(line[altEnd.upperBound..<line.index(before: line.endIndex)])
        let source: String

        if let data = imageData(path) {
            source = "data:\(imageMimeType(for: path, data: data));base64,\(data.base64EncodedString())"
        } else {
            source = path
        }

        let caption = alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "<figcaption>\(escapeHTML(alt))</figcaption>"
        return "<figure><img src=\"\(escapeAttribute(source))\" alt=\"\(escapeAttribute(alt))\">\(caption)</figure>"
    }

    private func tableHTML(startingAt index: Int, in lines: [String]) -> (html: String, consumed: Int)? {
        guard index + 1 < lines.count else { return nil }
        let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
        let separatorLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard headerLine.contains("|") else { return nil }

        let headers = splitTableRow(headerLine)
        let separators = splitTableRow(separatorLine)
        guard headers.count >= 2,
              separators.count >= 2,
              separators.allSatisfy({ $0.replacingOccurrences(of: ":", with: "").allSatisfy { $0 == "-" } })
        else { return nil }

        var rows: [[String]] = []
        var cursor = index + 2
        while cursor < lines.count {
            let line = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard line.contains("|"), !line.isEmpty else { break }
            rows.append(splitTableRow(line))
            cursor += 1
        }

        let headerHTML = headers.map { "<th>\(inlineHTML($0))</th>" }.joined()
        let rowsHTML = rows
            .map { row in
                "<tr>\(row.map { "<td>\(inlineHTML($0))</td>" }.joined())</tr>"
            }
            .joined(separator: "\n")
        return ("<table><thead><tr>\(headerHTML)</tr></thead><tbody>\(rowsHTML)</tbody></table>", cursor - index)
    }

    private func splitTableRow(_ line: String) -> [String] {
        var clean = line
        if clean.hasPrefix("|") { clean.removeFirst() }
        if clean.hasSuffix("|") { clean.removeLast() }
        return clean.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func taskHTML(_ line: String) -> String? {
        if line.hasPrefix("- [x] ") || line.hasPrefix("* [x] ") {
            return "<span class=\"task-marker\">☑</span> \(inlineHTML(String(line.dropFirst(6))))"
        }
        if line.hasPrefix("- [ ] ") || line.hasPrefix("* [ ] ") {
            return "<span class=\"task-marker\">☐</span> \(inlineHTML(String(line.dropFirst(6))))"
        }
        return nil
    }

    private func bulletText(_ line: String) -> String? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") else { return nil }
        return String(line.dropFirst(2))
    }

    private func numberedText(_ line: String) -> (number: Int, text: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let numberText = String(line[..<dotIndex])
        guard let number = Int(numberText) else { return nil }
        let textStart = line.index(after: dotIndex)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }
        return (number, String(line[line.index(after: textStart)...]))
    }

    private func isDivider(_ line: String) -> Bool {
        let clean = line.replacingOccurrences(of: " ", with: "")
        return clean.count >= 3 && Set(clean).isSubset(of: Set<Character>(["-", "*", "_"]))
    }

    private func inlineHTML(_ markdown: String) -> String {
        var html = escapeHTML(markdown)
        html = replacePattern(#"`([^`]+)`"#, in: html, template: "<code>$1</code>")
        html = replacePattern(#"==(.+?)=="#, in: html, template: "<mark>$1</mark>")
        html = replacePattern(#"\*\*(.+?)\*\*"#, in: html, template: "<strong>$1</strong>")
        html = replacePattern(#"__(.+?)__"#, in: html, template: "<strong>$1</strong>")
        html = replacePattern(#"(?<!\*)\*([^*]+)\*(?!\*)"#, in: html, template: "<em>$1</em>")
        html = replacePattern(#"~~(.+?)~~"#, in: html, template: "<s>$1</s>")
        html = replacePattern(#"&lt;u&gt;(.+?)&lt;/u&gt;"#, in: html, template: "<u>$1</u>")
        html = linkHTML(in: html)
        html = wikiLinkHTML(in: html)
        html = html.replacingOccurrences(of: "%%", with: "")
        return html
    }

    private func linkHTML(in html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(location: 0, length: (html as NSString).length),
            withTemplate: #"<a href="$2">$1</a>"#
        )
    }

    private func wikiLinkHTML(in html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(location: 0, length: (html as NSString).length),
            withTemplate: "<strong>$1</strong>"
        )
    }

    private func replacePattern(_ pattern: String, in text: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: template
        )
    }

    private func imageMimeType(for path: String, data: Data) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        if ext == "jpg" || ext == "jpeg" { return "image/jpeg" }
        if ext == "gif" { return "image/gif" }
        if ext == "webp" { return "image/webp" }
        if data.starts(with: [0xFF, 0xD8]) { return "image/jpeg" }
        if data.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        return "image/png"
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func escapeAttribute(_ text: String) -> String {
        escapeHTML(text).replacingOccurrences(of: "'", with: "&#39;")
    }
}

private enum WhisperSmallModelInstaller {
    private static let fileName = "ggml-small.bin"
    private static let minimumUsableByteCount: UInt64 = 450_000_000
    private static let downloadURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!

    static func ensureInstalled() async throws -> URL {
        let targetURL = try modelFileURL()
        if isUsableModel(at: targetURL) {
            return targetURL
        }

        if let bundledURL = bundledModelURL() {
            try installModel(from: bundledURL, to: targetURL)
            if isUsableModel(at: targetURL) {
                return targetURL
            }
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: downloadURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw WhisperModelInstallError.downloadFailed(statusCode: httpResponse.statusCode)
        }

        try installModel(from: temporaryURL, to: targetURL)
        guard isUsableModel(at: targetURL) else {
            throw WhisperModelInstallError.invalidModel
        }
        return targetURL
    }

    static func installedModelFileURL() throws -> URL {
        let targetURL = try modelFileURL()
        guard isUsableModel(at: targetURL) else {
            throw WhisperModelInstallError.invalidModel
        }
        return targetURL
    }

    private static func modelFileURL() throws -> URL {
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw WhisperModelInstallError.missingApplicationSupportDirectory
        }

        let directoryURL = applicationSupportURL
            .appendingPathComponent("Zirn", isDirectory: true)
            .appendingPathComponent("Whisper", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent(fileName)
    }

    private static func bundledModelURL() -> URL? {
        Bundle.main.url(forResource: "ggml-small", withExtension: "bin")
            ?? Bundle.main.url(forResource: fileName, withExtension: nil)
    }

    private static func installModel(from sourceURL: URL, to targetURL: URL) throws {
        let fileManager = FileManager.default
        let directoryURL = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let stagingURL = directoryURL.appendingPathComponent(".\(UUID().uuidString)-\(fileName)")
        if fileManager.fileExists(atPath: stagingURL.path) {
            try fileManager.removeItem(at: stagingURL)
        }
        try fileManager.copyItem(at: sourceURL, to: stagingURL)

        guard isUsableModel(at: stagingURL) else {
            try? fileManager.removeItem(at: stagingURL)
            throw WhisperModelInstallError.invalidModel
        }

        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: stagingURL, to: targetURL)
    }

    private static func isUsableModel(at url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let byteCount = attributes[.size] as? NSNumber
        else {
            return false
        }
        return byteCount.uint64Value >= minimumUsableByteCount
    }
}

private final class VoiceTranscriptionController: NSObject, SCStreamOutput, SCStreamDelegate {
    private let audioEngine = AVAudioEngine()
    private let source: VoiceAudioSource
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?
    private var latestTranscript = ""
    private var isPaused = false
    private var consecutiveSpeechFrames = 0
    private var consecutiveQuietFrames = 0
    private var isGateOpen = false
    private var finishTask: Task<String, Never>?
    private var systemAudioStream: SCStream?
    private let systemAudioQueue = DispatchQueue(label: "noortech.Zirn.system-audio")
    private let processLock = NSLock()
    private var activeProcess: Process?

    private let onTranscript: (String) -> Void
    private let onUserSpeechActivityChanged: (Bool) -> Void
    private let onError: (Error) -> Void
    private let onProgress: @Sendable (Double) -> Void

    var transcript: String {
        latestTranscript
    }

    init(
        source: VoiceAudioSource,
        onTranscript: @escaping (String) -> Void,
        onUserSpeechActivityChanged: @escaping (Bool) -> Void,
        onError: @escaping (Error) -> Void,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) {
        self.source = source
        self.onTranscript = onTranscript
        self.onUserSpeechActivityChanged = onUserSpeechActivityChanged
        self.onError = onError
        self.onProgress = onProgress
        super.init()
    }

    static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        .authorized
    }

    func start() async throws {
        switch source {
        case .microphone:
            try startMicrophoneRecordingSession()
        case .systemAudio:
            try await startSystemAudioRecordingSession()
        }
    }

    func pause() {
        isPaused = true
        onUserSpeechActivityChanged(false)
    }

    func resume() throws {
        isPaused = false
    }

    func stop() {
        cancel()
    }

    func cancel() {
        isPaused = false
        finishTask?.cancel()
        finishTask = nil
        terminateActiveProcess()
        stopAudioCapture()
        recordingFile = nil
        resetSpeechActivity()
        onUserSpeechActivityChanged(false)
    }

    func finish() async -> String {
        isPaused = true
        onUserSpeechActivityChanged(false)
        stopAudioCapture()
        recordingFile = nil

        guard let recordingURL else { return latestTranscript }
        let task = Task<String, Never> { [weak self] in
            guard let self else { return "" }
            do {
                try Task.checkCancellation()
                let wavURL = try await Self.convertRecordingToWhisperWAV(recordingURL)
                try Task.checkCancellation()
                let modelURL = try WhisperSmallModelInstaller.installedModelFileURL()
                let transcript = try await self.runWhisperCLI(audioURL: wavURL, modelURL: modelURL)
                return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch is CancellationError {
                return ""
            } catch {
                await MainActor.run {
                    self.onError(error)
                }
                return ""
            }
        }
        finishTask = task
        let transcript = await task.value
        finishTask = nil
        latestTranscript = transcript
        if !transcript.isEmpty {
            onTranscript(transcript)
        }
        try? FileManager.default.removeItem(at: recordingURL)
        return transcript
    }

    private func startMicrophoneRecordingSession() throws {
        cancel()

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            let granted = requestMicrophoneAccessSynchronously()
            guard granted else { throw VoiceTranscriptionError.microphoneNotAuthorized }
        default:
            throw VoiceTranscriptionError.microphoneNotAuthorized
        }

        let inputNode = audioEngine.inputNode
        if #available(macOS 13.0, *) {
            try? inputNode.setVoiceProcessingEnabled(false)
        }

        let format = inputNode.outputFormat(forBus: 0)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zirn-voice-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        recordingURL = url
        recordingFile = try AVAudioFile(forWriting: url, settings: format.settings)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.handleAudioBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func startSystemAudioRecordingSession() async throws {
        cancel()

        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw VoiceTranscriptionError.screenCaptureNotAuthorized
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw VoiceTranscriptionError.systemAudioUnavailable
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 1
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.showsCursor = false
        configuration.queueDepth = 3

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )
        guard let format else {
            throw VoiceTranscriptionError.systemAudioUnavailable
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zirn-system-audio-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        recordingURL = url
        recordingFile = try AVAudioFile(forWriting: url, settings: format.settings)

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: systemAudioQueue)
        try await stream.startCapture()
        systemAudioStream = stream
    }

    private func stopAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        if let systemAudioStream {
            let stream = systemAudioStream
            self.systemAudioStream = nil
            Task {
                try? await stream.stopCapture()
            }
        }
    }

    private func resetSpeechActivity() {
        consecutiveSpeechFrames = 0
        consecutiveQuietFrames = 0
        isGateOpen = false
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard !isPaused else { return }
        do {
            try recordingFile?.write(from: buffer)
        } catch {
            onError(error)
        }

        let decibels = averagePowerDecibels(buffer)
        let likelyUserSpeech = decibels > -34

        if likelyUserSpeech {
            consecutiveSpeechFrames += 1
            consecutiveQuietFrames = 0
        } else {
            consecutiveQuietFrames += 1
            consecutiveSpeechFrames = 0
        }

        if consecutiveSpeechFrames >= 2 {
            isGateOpen = true
        } else if consecutiveQuietFrames >= 14 {
            isGateOpen = false
        }

        onUserSpeechActivityChanged(isGateOpen)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, !isPaused else { return }
        guard let buffer = pcmBuffer(from: sampleBuffer) else { return }
        handleAudioBuffer(buffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onError(error)
    }

    private func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = sampleBuffer.formatDescription else { return nil }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        guard let asbd else { return nil }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: asbd.mSampleRate,
            channels: AVAudioChannelCount(max(1, asbd.mChannelsPerFrame)),
            interleaved: false
        ) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else {
            return nil
        }
        buffer.frameLength = frameCount

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer, length > 0 else { return nil }

        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            dataPointer.withMemoryRebound(to: Float.self, capacity: length / MemoryLayout<Float>.size) { floatPointer in
                if format.channelCount == 1, let channel = buffer.floatChannelData?[0] {
                    let sampleCount = Int(frameCount)
                    for index in 0..<sampleCount {
                        channel[index] = floatPointer[index]
                    }
                } else if let channels = buffer.floatChannelData {
                    let channelCount = Int(format.channelCount)
                    let sampleCount = Int(frameCount)
                    for frame in 0..<sampleCount {
                        for channel in 0..<channelCount {
                            channels[channel][frame] = floatPointer[frame * channelCount + channel]
                        }
                    }
                }
            }
            return buffer
        }

        return nil
    }

    private static func convertRecordingToWhisperWAV(_ recordingURL: URL) async throws -> URL {
        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zirn-whisper-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        _ = try await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/afconvert"),
            arguments: [
                "-f", "WAVE",
                "-d", "LEI16@16000",
                "-c", "1",
                recordingURL.path,
                wavURL.path
            ],
            processStore: nil
        )
        return wavURL
    }

    private func runWhisperCLI(audioURL: URL, modelURL: URL) async throws -> String {
        let executableURL = try Self.whisperCLIURL()
        let outputBaseURL = audioURL.deletingPathExtension()
        let progressCallback = onProgress
        let output = try await Self.runProcess(
            executableURL: executableURL,
            arguments: [
                "-m", modelURL.path,
                "-f", audioURL.path,
                "--no-timestamps",
                "--no-gpu",
                "--print-progress",
                "--output-txt",
                "--output-file", outputBaseURL.path,
                "--language", "en"
            ],
            processStore: { [weak self] process in
                self?.setActiveProcess(process)
            },
            progressHandler: { value in
                progressCallback(value)
            }
        )

        let transcriptURL = outputBaseURL.appendingPathExtension("txt")
        if let transcript = try? String(contentsOf: transcriptURL, encoding: .utf8) {
            try? FileManager.default.removeItem(at: transcriptURL)
            try? FileManager.default.removeItem(at: audioURL)
            return transcript
        }

        try? FileManager.default.removeItem(at: audioURL)
        return output
    }

    private static func whisperCLIURL() throws -> URL {
        let candidates = [
            Bundle.main.url(forResource: "WhisperRuntime/bin/whisper-cli", withExtension: nil),
            Bundle.main.url(forResource: "whisper-cli", withExtension: nil),
            URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"),
            URL(fileURLWithPath: "/usr/local/bin/whisper-cli"),
            URL(fileURLWithPath: "/tmp/zirn-whisper.cpp/build/bin/whisper-cli")
        ].compactMap { $0 }

        if let candidate = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return candidate
        }

        throw VoiceTranscriptionError.whisperCLIMissing
    }

    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        processStore: ((Process) -> Void)?,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> String {
        try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                processStore?(process)

                let output: String
                let errorOutput: String

                if let progressHandler {
                    // Stream both pipes so real whisper-cli progress (printed to stderr as
                    // "progress =  NN%") can drive an honest indicator. Draining both pipes
                    // concurrently also prevents a full-pipe deadlock during long decodes.
                    let outCollector = ProcessOutputCollector(onProgress: nil)
                    let errCollector = ProcessOutputCollector(onProgress: progressHandler)
                    outputPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty else { return }
                        outCollector.append(data, scanProgress: false)
                    }
                    errorPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty else { return }
                        errCollector.append(data, scanProgress: true)
                    }

                    try process.run()
                    process.waitUntilExit()

                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    let remainingOut = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remainingOut.isEmpty { outCollector.append(remainingOut, scanProgress: false) }
                    let remainingErr = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remainingErr.isEmpty { errCollector.append(remainingErr, scanProgress: false) }

                    output = outCollector.string
                    errorOutput = errCollector.string
                } else {
                    try process.run()
                    process.waitUntilExit()

                    output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                }

                if Task.isCancelled {
                    throw CancellationError()
                }

                guard process.terminationStatus == 0 else {
                    if process.terminationReason == .uncaughtSignal {
                        throw CancellationError()
                    }
                    throw VoiceTranscriptionError.processFailed(errorOutput.isEmpty ? output : errorOutput)
                }
                return output
            }.value
        } onCancel: {
            // Termination is handled via processStore / activeProcess.
        }
    }

    private func setActiveProcess(_ process: Process?) {
        processLock.lock()
        activeProcess = process
        processLock.unlock()
    }

    private func terminateActiveProcess() {
        processLock.lock()
        let process = activeProcess
        activeProcess = nil
        processLock.unlock()
        process?.terminate()
    }

    private func averagePowerDecibels(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return -100 }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return -100 }

        var sum: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sum += sample * sample
            }
        }

        let mean = sum / Float(channelCount * frameLength)
        guard mean > 0 else { return -100 }
        return 10 * log10(mean)
    }

    private func requestMicrophoneAccessSynchronously() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        AVCaptureDevice.requestAccess(for: .audio) { allowed in
            granted = allowed
            semaphore.signal()
        }
        semaphore.wait()
        return granted
    }
}

/// Thread-safe accumulator for a child process pipe. Optionally scans streamed text for
/// whisper-cli progress notifications ("progress =  NN%") and reports monotonic 0...1 values.
private final class ProcessOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var progressScan = Data()
    private var lastPercent = -1
    private let onProgress: (@Sendable (Double) -> Void)?
    private static let progressRegex = try! NSRegularExpression(
        pattern: #"progress\s*=\s*(\d{1,3})\s*%"#,
        options: [.caseInsensitive]
    )

    init(onProgress: (@Sendable (Double) -> Void)?) {
        self.onProgress = onProgress
    }

    func append(_ data: Data, scanProgress: Bool) {
        lock.lock()
        buffer.append(data)
        var emit: Double?
        if scanProgress, onProgress != nil {
            progressScan.append(data)
            if let text = String(data: progressScan, encoding: .utf8) {
                let ns = text as NSString
                let matches = Self.progressRegex.matches(
                    in: text,
                    range: NSRange(location: 0, length: ns.length)
                )
                if let last = matches.last,
                   let percent = Int(ns.substring(with: last.range(at: 1))),
                   percent > lastPercent {
                    lastPercent = percent
                    emit = min(1.0, Double(percent) / 100.0)
                }
                if progressScan.count > 8192 {
                    progressScan = Data(progressScan.suffix(2048))
                }
            }
        }
        lock.unlock()
        if let emit { onProgress?(emit) }
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: buffer, encoding: .utf8) ?? ""
    }
}

private enum VoiceTranscriptionError: LocalizedError {
    case speechRecognitionNotAuthorized
    case microphoneNotAuthorized
    case screenCaptureNotAuthorized
    case systemAudioUnavailable
    case speechRecognizerUnavailable
    case whisperCLIMissing
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .speechRecognitionNotAuthorized:
            return "Speech recognition permission is required."
        case .microphoneNotAuthorized:
            return "Microphone permission is required."
        case .screenCaptureNotAuthorized:
            return "Screen Recording permission is required for on-screen audio."
        case .systemAudioUnavailable:
            return "On-screen audio capture is unavailable right now."
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available right now."
        case .whisperCLIMissing:
            return "Whisper decoder is missing. Bundle whisper-cli or install whisper.cpp."
        case .processFailed(let message):
            return message.isEmpty ? "Whisper transcription failed." : message
        }
    }
}

private enum WhisperModelInstallError: LocalizedError {
    case missingApplicationSupportDirectory
    case downloadFailed(statusCode: Int)
    case invalidModel

    var errorDescription: String? {
        switch self {
        case .missingApplicationSupportDirectory:
            return "Could not find Application Support."
        case .downloadFailed(let statusCode):
            return "Download failed with HTTP \(statusCode)."
        case .invalidModel:
            return "Downloaded model file is incomplete."
        }
    }
}

private extension String {
    func removingFirstMarkdownHeading() -> String {
        var lines = split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let firstLine = lines.first,
           firstLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("# ") {
            lines.removeFirst()
            while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                lines.removeFirst()
            }
        }
        return lines.joined(separator: "\n")
    }
}
