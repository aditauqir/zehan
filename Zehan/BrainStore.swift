//
//  BrainStore.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import Combine
import Foundation
import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let brainFile = UTType(filenameExtension: "brain") ?? .json
}

@MainActor
final class BrainStore: ObservableObject {
    @Published var activeBrain: BrainSummary?
    @Published var notes: [NoteSummary] = []
    @Published var selectedNoteID: Note.ID?
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
    @Published var isGeneratingAssistantResponse = false
    @Published var isUsingWebSearch = false
    @Published var isShowingModelConfiguration = false
    @Published var isShowingMarkdownHelp = false
    @Published var pendingAssistantPreview: AssistantPreview?
    @Published var activeSearchHighlight: SearchHighlight?
    @Published var assistantAttachment: PromptAttachment?
    @Published private(set) var mistralBudgetSpentUSD = 0.0
    @Published private(set) var mistralOCRPagesUsed = 0

    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let recentVaultsKey = "RecentVaults"
    private let openAIAPIKeyKey = "Assistant.OpenAIAPIKey"
    private let openAIModelKey = "Assistant.OpenAIModel"
    private let mistralAPIKeyKey = "Assistant.MistralAPIKey"
    private let mistralModelKey = "Assistant.MistralModel"
    private let mistralBudgetSpentUSDKey = "Assistant.MistralBudgetSpentUSD"
    private let mistralOCRPagesUsedKey = "Assistant.MistralOCRPagesUsed"
    private let groqAPIKeyKey = "Assistant.GroqAPIKey"
    private let groqModelKey = "Assistant.GroqModel"
    private let selectedAssistantModelKey = "Assistant.SelectedModel"
    private var mistralAPIKey = ""
    private var mistralModel = BrainStore.defaultMistralModel
    private var groqAPIKey = ""
    private var groqModel = BrainStore.defaultGroqModel
    private var autosaveTask: Task<Void, Never>?
    private var pendingAssistantInsertion: PendingAssistantInsertion?
    private var isApplyingAssistantOutput = false
    private var noteIdentityDatabase: NoteIdentityDatabase?
    private var searchIndex: [NoteSearchIndexEntry] = []

    static let defaultMistralModel = "mistral-large-latest"
    static let defaultGroqModel = "llama-3.3-70b-versatile"

    private static let mistralBudgetUSD = 10.0
    private static let mistralInputPricePerMillionTokens = 0.50
    private static let mistralOutputPricePerMillionTokens = 1.50
    private static let maxAssistantOutputTokens = 4096
    private static let estimatedCharactersPerToken = 4
    private static let mistralOCRModel = "mistral-ocr-latest"
    private static let mistralOCRPageLimit = 100
    private static var mistralBudgetTokenEquivalent: Int {
        Int((mistralBudgetUSD / ((mistralInputPricePerMillionTokens + mistralOutputPricePerMillionTokens) / 2)) * 1_000_000)
    }

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadRecentVaults()
        loadAssistantConfiguration()
    }

    var documentStats: String {
        let wordCount = content
            .split { $0.isWhitespace || $0.isNewline }
            .count
        return "\(wordCount) words · \(content.count.formatted()) characters"
    }

    var contextUsageFraction: Double {
        min(1, estimatedMistralBudgetUSD / Self.mistralBudgetUSD)
    }

    var contextUsagePercent: Int {
        Int((contextUsageFraction * 100).rounded())
    }

    var contextUsageLabel: String {
        "\(formatUSD(estimatedMistralBudgetUSD)) / \(formatUSD(Self.mistralBudgetUSD))"
    }

    var contextUsageDetail: String {
        "~\(Self.mistralBudgetTokenEquivalent.formatted()) blended tokens"
    }

    var ocrUploadsRemaining: Int {
        max(0, Self.mistralOCRPageLimit - mistralOCRPagesUsed)
    }

    var ocrUploadUsageFraction: Double {
        min(1, Double(mistralOCRPagesUsed) / Double(Self.mistralOCRPageLimit))
    }

    var ocrUploadCounterLabel: String {
        "\(ocrUploadsRemaining) left"
    }

    var ocrUploadCounterDetail: String {
        "\(mistralOCRPagesUsed) of \(Self.mistralOCRPageLimit) OCR pages used"
    }

    var assistantConnectionStatus: AssistantConnectionStatus {
        switch selectedAssistantModel {
        case .mistral:
            return mistralAPIKey.isEmpty ? .offline : .online
        case .groq:
            return groqAPIKey.isEmpty ? .offline : .online
        }
    }

    private var estimatedMistralBudgetUSD: Double {
        min(Self.mistralBudgetUSD, mistralBudgetSpentUSD + estimatedCurrentMistralRequestCostUSD)
    }

    private var estimatedCurrentMistralRequestCostUSD: Double {
        let attachmentCount = assistantAttachment?.extractedText.count ?? 0
        let inputTokens = estimatedTokenCount(forCharacterCount: content.count + assistantPrompt.count + attachmentCount)
        let outputTokens = min(Self.maxAssistantOutputTokens, max(512, inputTokens / 5))
        return Self.mistralCostUSD(inputTokens: inputTokens, outputTokens: outputTokens)
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
        panel.message = "Select a folder. Zirn will create a visible .brain vault file in that folder."
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
                    status = "That folder already contains a .brain vault file"
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
                        groqModel: Self.defaultGroqModel,
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

    func openBrain(fileURL: URL, showsInvalidVaultAlert: Bool = false) {
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
                recordRecentVault(note: notes.first)
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
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        noteIdentityDatabase = nil
        activeBrain = nil
        notes = []
        selectedNoteID = nil
        graphLinks = []
        searchIndex = []
        resetDraft()
        status = "Choose a brain"
    }

    func newDraft() {
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        currentNoteID = nil
        selectedNoteID = nil
        title = uniqueTitle(for: "Untitled")
        content = contentBySettingDocumentTitle(title, in: Self.starterMarkdown)
        if activeBrain != nil {
            saveCurrentNote(statusText: "Page created")
        }
    }

    private func resetDraft() {
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        currentNoteID = nil
        selectedNoteID = nil
        title = "Untitled"
        content = Self.starterMarkdown
    }

    func updateTitleFromEditor(_ newTitle: String) {
        let uniqueTitle = uniqueTitle(for: newTitle, excluding: currentNoteID)
        title = uniqueTitle
        content = contentBySettingDocumentTitle(uniqueTitle, in: content)
        updateCurrentNoteSummaryTitle(to: uniqueTitle)
        scheduleAutosave()
    }

    func updateContentFromEditor(_ newContent: String) {
        if let documentTitle = markdownDocumentTitle(in: newContent) {
            let uniqueTitle = uniqueTitle(for: documentTitle, excluding: currentNoteID)
            content = contentBySettingDocumentTitle(uniqueTitle, in: newContent)
            if uniqueTitle != title {
                title = uniqueTitle
                updateCurrentNoteSummaryTitle(to: uniqueTitle)
            }
        } else {
            content = newContent
        }
        learnFromUserCorrectionIfNeeded(revisedContent: newContent)
        scheduleAutosave()
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
        if let currentNoteID, currentNoteID != id {
            autosaveTask?.cancel()
            autosaveTask = nil
            saveCurrentNote()
        }

        guard let noteURL = noteURL(for: id) else { return }
        withActiveBrainAccess {
            do {
                let note = try readNote(from: noteURL)
                currentNoteID = note.id
                selectedNoteID = note.id
                pendingAssistantInsertion = nil
                title = note.title
                content = note.content
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

    func saveCurrentNote() {
        saveCurrentNote(statusText: "Autosaved")
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
                try writeMarkdownNote(note, to: targetURL)
                try noteIdentityDatabase?.upsert(
                    noteID: note.id,
                    title: note.title,
                    fileName: targetURL.lastPathComponent,
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
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func configureModelFromUser() {
        isShowingModelConfiguration = true
    }

    var assistantConfigurationSnapshot: AssistantConfiguration {
        AssistantConfiguration(
            mistralAPIKey: mistralAPIKey,
            mistralModel: mistralModel,
            groqAPIKey: groqAPIKey,
            groqModel: groqModel
        )
    }

    func saveModelConfiguration(
        mistralAPIKey: String,
        mistralModel: String,
        groqAPIKey: String,
        groqModel: String
    ) {
        self.mistralAPIKey = mistralAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mistralModel = mistralModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.groqAPIKey = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.groqModel = groqModel.trimmingCharacters(in: .whitespacesAndNewlines)

        if self.mistralModel.isEmpty { self.mistralModel = Self.defaultMistralModel }
        if self.groqModel.isEmpty { self.groqModel = Self.defaultGroqModel }

        do {
            try saveAssistantConfiguration()
            isShowingModelConfiguration = false
            status = "Model settings saved"
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
        selectedAssistantModel = .mistral
        try saveAssistantConfiguration()
        status = "Mistral API key verified"
    }

    func selectAssistantModel(_ model: AssistantModel) {
        selectedAssistantModel = model
        UserDefaults.standard.set(model.rawValue, forKey: selectedAssistantModelKey)
    }

    func submitAssistantPrompt() {
        let prompt = assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!prompt.isEmpty || assistantAttachment != nil), !isGeneratingAssistantResponse else { return }

        assistantPrompt = ""
        pendingAssistantPreview = nil
        isGeneratingAssistantResponse = true
        isUsingWebSearch = selectedAssistantModel.supportsWebSearch && promptSuggestsWebSearch(prompt)
        status = "\(selectedAssistantModel.title) is writing"

        Task {
            await generateAssistantResponse(for: prompt)
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

    func deleteNote(id: Note.ID) {
        autosaveTask?.cancel()
        autosaveTask = nil
        withActiveBrainAccess {
            do {
                let deletedCurrentNote = currentNoteID == id
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
            } catch {
                status = error.localizedDescription
            }
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
                let newURL = markdownNoteURL(for: renamedNote, in: brain)

                try writeMarkdownNote(renamedNote, to: newURL)
                try noteIdentityDatabase?.upsert(
                    noteID: renamedNote.id,
                    title: renamedNote.title,
                    fileName: newURL.lastPathComponent,
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

        return searchIndex
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
        guard isSupportedPromptDocument(url) else {
            status = "Only PDFs, Word documents, and images are supported"
            return
        }

        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        switch url.pathExtension.lowercased() {
        case "pdf":
            attachPDFWithMistralOCR(from: url)
        case "doc", "docx":
            let extractedText = extractedPromptDocumentText(from: url)
            assistantAttachment = PromptAttachment(
                fileName: url.lastPathComponent,
                fileExtension: url.pathExtension.lowercased(),
                extractedText: extractedText
            )
            status = "\(url.lastPathComponent) attached"
        case "png", "jpg", "jpeg", "gif", "heic", "tiff", "webp":
            assistantAttachment = PromptAttachment(
                fileName: url.lastPathComponent,
                fileExtension: url.pathExtension.lowercased(),
                extractedText: "Image attached. Visual content is available in the source file, but no text was extracted."
            )
            status = "\(url.lastPathComponent) attached"
        default:
            status = "Only PDFs, Word documents, and images are supported"
        }
    }

    func choosePromptAttachmentFromUser() {
        let panel = NSOpenPanel()
        panel.title = "Attach File"
        panel.message = "Choose a PDF, Word document, or image."
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .pdf,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "docx") ?? .data,
            .image
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        attachPromptDocument(from: url)
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
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        return notesFolderURL(for: activeBrain)
            .appendingPathComponent(path)
            .standardizedFileURL
    }

    func removePromptAttachment() {
        assistantAttachment = nil
        status = "Attachment removed"
    }

    func openRecentVault(_ recentVault: RecentVault) {
        if let folderURL = resolvedRecentFolderURL(for: recentVault) {
            withSecurityScopedAccess(to: folderURL) {
                openBrain(fileURL: folderURL, showsInvalidVaultAlert: true)
            }
            return
        }

        requestAccessToRecentVault(recentVault)
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

        let noteURLs = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" || $0.pathExtension == "json" }

        var seenIDs = Set<Note.ID>()
        var reservedTitles = Set<String>()
        let loadedNotes = try noteURLs.map { url in
            var note = try readNote(from: url)
            var noteURL = url
            var fileName = noteURL.lastPathComponent
            let metadataID = note.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let indexedID = noteIdentityDatabase?.noteID(forFileName: fileName)
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
                let updatedURL = markdownNoteURL(for: note, in: brain)
                try writeMarkdownNote(note, to: updatedURL)
                if updatedURL != noteURL, FileManager.default.fileExists(atPath: noteURL.path) {
                    try? FileManager.default.removeItem(at: noteURL)
                }
                noteURL = updatedURL
                fileName = noteURL.lastPathComponent
            }

            try noteIdentityDatabase?.upsert(
                noteID: note.id,
                title: note.title,
                fileName: fileName,
                updatedAt: note.updatedAt
            )
            seenIDs.insert(note.id)
            return note
        }
        notes = loadedNotes
            .map { NoteSummary(id: $0.id, title: $0.title, updatedAt: $0.updatedAt) }
            .sorted { $0.updatedAt > $1.updatedAt }
        graphLinks = buildGraphLinks(from: loadedNotes)
        rebuildSearchIndex(from: loadedNotes, in: brain)
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
        try readNote(from: url, data: Data(contentsOf: url))
    }

    private func readNote(from url: URL, data: Data) throws -> Note {
        if url.pathExtension == "md" {
            return try readMarkdownNote(from: url, data: data)
        }

        return try decoder.decode(Note.self, from: data)
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

    private func generateAssistantResponse(for prompt: String) async {
        defer {
            isGeneratingAssistantResponse = false
            isUsingWebSearch = false
        }

        do {
            let result: ChatCompletionResult
            let providerTitle = selectedAssistantModel.title
            switch selectedAssistantModel {
            case .mistral:
                result = try await generateWithMistral(prompt: prompt)
                recordMistralUsage(
                    inputTokens: result.inputTokens ?? estimatedTokenCount(for: assistantInput(for: prompt)),
                    outputTokens: result.outputTokens ?? estimatedTokenCount(for: result.content)
                )
            case .groq:
                result = try await generateWithGroq(prompt: prompt)
            }
            let output = result.content

            guard !cleanedAssistantMarkdown(output).isEmpty else {
                throw AssistantError.requestFailed("The model returned no Markdown.")
            }

            applyAssistantDocumentOutput(output, prompt: prompt)
            try? updateStyleMemory(with: content)
            pendingAssistantPreview = nil
            status = "\(providerTitle) updated Markdown"
        } catch {
            status = error.localizedDescription
        }
    }

    private func applyAssistantDocumentOutput(_ output: String, prompt: String) {
        let cleanOutput = cleanedAssistantMarkdown(output)
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

    private func generateWithMistral(prompt: String) async throws -> ChatCompletionResult {
        guard !mistralAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add a Mistral API key in Settings > Configure Model.")
        }

        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(mistralAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": mistralModel,
            "messages": [
                [
                    "role": "system",
                    "content": assistantInstructions()
                ],
                [
                    "role": "user",
                    "content": assistantInput(for: prompt)
                ]
            ],
            "temperature": 0.35,
            "max_tokens": Self.maxAssistantOutputTokens,
            "stream": false
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try extractChatCompletionResult(from: data)
    }

    private func verifyMistralAPIKey(_ apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
    }

    private func generateWithGroq(prompt: String) async throws -> ChatCompletionResult {
        guard !groqAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add a Groq API key in Settings > Configure Model.")
        }

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": groqModel,
            "messages": [
                [
                    "role": "system",
                    "content": assistantInstructions()
                ],
                [
                    "role": "user",
                    "content": assistantInput(for: prompt)
                ]
            ],
            "temperature": 0.35,
            "max_completion_tokens": Self.maxAssistantOutputTokens,
            "stream": false
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try extractChatCompletionResult(from: data)
    }

    private func assistantInstructions() -> String {
        """
        You are Zirn's writing assistant. You edit the user's current Markdown document in place.
        You will receive the full current document and a user request. Return the complete revised Markdown document, not a patch, diff, explanation, or separate suggestion.
        If the user asks to add, include the original document plus the addition in the best location.
        If the user asks to edit, rewrite only the needed parts and preserve everything else.
        If the user asks to delete, remove the requested text or section and keep the remaining document coherent.
        If the user asks to organize, restructure the whole document cleanly while preserving meaning.
        Do not wrap the answer in code fences unless the user specifically asks for code.
        Do not include meta commentary, apologies, or explanations of what you changed.
        Match the user's writing pattern, vocabulary, rhythm, heading style, and density when possible.
        Treat correction-derived preferences as stronger than passive style samples.
        Preserve the user's existing edits. Make the smallest useful change unless the user asks for a larger rewrite.
        Output polished Markdown with clear headings, short paragraphs, and useful lists only when lists are natural.
        Use Obsidian-style wiki links like [[Page Title]] only when linking is genuinely useful.
        """
    }

    private func assistantInput(for prompt: String) -> String {
        """
        User request:
        \(prompt.isEmpty ? "Use the attached document to update or extend the current Markdown document." : prompt)

        Attached document:
        \(assistantAttachmentContext())

        Current document title:
        \(title)

        Current Markdown document:
        \(content)

        Required output:
        Return the complete revised Markdown document only.

        Learned user writing samples:
        \(learnedStyleMemory())

        Correction-derived preferences, strongest first:
        \(learnedCorrectionMemory())
        """
    }

    private func assistantAttachmentContext() -> String {
        guard let assistantAttachment else { return "None" }
        let text = assistantAttachment.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let clippedText = String(text.prefix(24_000))
        if clippedText.isEmpty {
            return "\(assistantAttachment.fileName) (\(assistantAttachment.fileExtension.uppercased())) attached, but no readable text could be extracted."
        }
        return """
        File: \(assistantAttachment.fileName)
        Type: \(assistantAttachment.fileExtension.uppercased())
        Text:
        \(clippedText)
        """
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
        var output = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            let message = String(data: data, encoding: .utf8) ?? "Model request failed."
            throw AssistantError.requestFailed(message)
        }
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

        guard let content else {
            throw AssistantError.requestFailed("The model returned no Markdown.")
        }

        let usage = json["usage"] as? [String: Any]
        return ChatCompletionResult(
            content: content,
            inputTokens: usage?["prompt_tokens"] as? Int
                ?? usage?["input_tokens"] as? Int,
            outputTokens: usage?["completion_tokens"] as? Int
                ?? usage?["output_tokens"] as? Int
        )
    }

    private func recordMistralUsage(inputTokens: Int, outputTokens: Int) {
        let cost = Self.mistralCostUSD(inputTokens: inputTokens, outputTokens: outputTokens)
        mistralBudgetSpentUSD += cost
        UserDefaults.standard.set(mistralBudgetSpentUSD, forKey: mistralBudgetSpentUSDKey)
    }

    private func recordMistralOCRUpload(pageCount: Int) {
        mistralOCRPagesUsed = min(Self.mistralOCRPageLimit, mistralOCRPagesUsed + pageCount)
        UserDefaults.standard.set(mistralOCRPagesUsed, forKey: mistralOCRPagesUsedKey)
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

    private func formatUSD(_ value: Double) -> String {
        if value < 0.01 {
            return String(format: "$%.4f", value)
        }
        return String(format: "$%.2f", value)
    }

    private func loadAssistantConfiguration() {
        let defaults = UserDefaults.standard
        if let rawModel = defaults.string(forKey: selectedAssistantModelKey),
           let model = AssistantModel(rawValue: rawModel) {
            selectedAssistantModel = model
        } else {
            selectedAssistantModel = .mistral
        }
        mistralAPIKey = defaults.string(forKey: mistralAPIKeyKey) ?? ""
        mistralModel = defaults.string(forKey: mistralModelKey) ?? Self.defaultMistralModel
        mistralBudgetSpentUSD = defaults.double(forKey: mistralBudgetSpentUSDKey)
        mistralOCRPagesUsed = min(Self.mistralOCRPageLimit, defaults.integer(forKey: mistralOCRPagesUsedKey))
        defaults.removeObject(forKey: openAIAPIKeyKey)
        defaults.removeObject(forKey: openAIModelKey)
        groqAPIKey = defaults.string(forKey: groqAPIKeyKey) ?? ""
        groqModel = defaults.string(forKey: groqModelKey) ?? Self.defaultGroqModel
    }

    private func saveAssistantConfiguration() throws {
        let defaults = UserDefaults.standard
        defaults.set(selectedAssistantModel.rawValue, forKey: selectedAssistantModelKey)
        defaults.set(mistralAPIKey, forKey: mistralAPIKeyKey)
        defaults.set(mistralModel, forKey: mistralModelKey)
        defaults.set(mistralBudgetSpentUSD, forKey: mistralBudgetSpentUSDKey)
        defaults.set(mistralOCRPagesUsed, forKey: mistralOCRPagesUsedKey)
        defaults.set(groqAPIKey, forKey: groqAPIKeyKey)
        defaults.set(groqModel, forKey: groqModelKey)
        defaults.removeObject(forKey: openAIAPIKeyKey)
        defaults.removeObject(forKey: openAIModelKey)
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
        searchIndex = loadedNotes.flatMap { note in
            let fileName = noteIdentityDatabase?.fileName(forNoteID: note.id)
                ?? markdownFileName(for: note.title, id: note.id)
            return searchIndexEntries(for: note, fileName: fileName)
        }
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
        return ext == "pdf"
            || ext == "doc"
            || ext == "docx"
            || ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp"].contains(ext)
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp"].contains(url.pathExtension.lowercased())
    }

    private func attachPDFWithMistralOCR(from url: URL) {
        guard !mistralAPIKey.isEmpty || requestAndSaveMistralAPIKey(
            title: "Mistral API Key",
            message: "Mistral OCR needs your Mistral API key before reading this PDF."
        ) else {
            status = "Mistral API key required for OCR"
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            status = "Could not read \(url.lastPathComponent)"
            return
        }

        guard ocrUploadsRemaining > 0 else {
            status = "No OCR uploads left"
            return
        }

        let pageCount = PDFDocument(data: data)?.pageCount ?? 0
        let pageLimit = pageCount == 0
            ? ocrUploadsRemaining
            : min(pageCount, ocrUploadsRemaining)
        let pages = Array(0..<pageLimit)
        status = "OCR reading \(pageLimit) page\(pageLimit == 1 ? "" : "s")"

        Task {
            do {
                let extractedText = try await extractPDFTextWithMistralOCR(data: data, pages: pages)
                assistantAttachment = PromptAttachment(
                    fileName: url.lastPathComponent,
                    fileExtension: url.pathExtension.lowercased(),
                    extractedText: extractedText
                )
                recordMistralOCRUpload(pageCount: pageLimit)

                if pageCount > pageLimit {
                    status = "\(url.lastPathComponent) attached · first \(pageLimit) pages OCRed"
                } else {
                    status = "\(url.lastPathComponent) attached"
                }
            } catch {
                status = error.localizedDescription
            }
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
        try validateHTTPResponse(response, data: responseData)
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

    private func imagesFolderURL(for brain: BrainSummary) -> URL {
        brain.folderURL.appendingPathComponent("Images", isDirectory: true)
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

        if let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) {
            if let matchingMarkdown = urls.first(where: { url in
                guard url.pathExtension == "md",
                      let note = try? readNote(from: url)
                else { return false }
                return note.id == id
            }) {
                return matchingMarkdown
            }
        }

        let jsonURL = folder.appendingPathComponent("\(id).json")
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            return jsonURL
        }

        return nil
    }

    private func markdownNoteURL(for note: Note, in brain: BrainSummary) -> URL {
        let fileName = markdownFileName(for: note.title, id: note.id)
        return notesFolderURL(for: brain).appendingPathComponent(fileName)
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

    private func markdownFileName(for title: String, id: Note.ID) -> String {
        let slug = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let cleanSlug = slug.isEmpty ? "untitled" : slug
        return "\(cleanSlug)-\(id.prefix(8)).md"
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
        let entry = RecentVault(
            folderPath: activeBrain.folderURL.path,
            brainPath: activeBrain.brainURL.path,
            brainFileName: activeBrain.brainURL.lastPathComponent,
            noteFileName: note.map { markdownDisplayFileName(for: $0.title) },
            updatedAt: updatedAt,
            bookmarkData: securityScopedBookmarkData(for: activeBrain.folderURL)
        )

        recentVaults.removeAll { $0.brainPath == entry.brainPath }
        recentVaults.insert(entry, at: 0)
        recentVaults = Array(recentVaults.prefix(6))
        saveRecentVaults()
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

struct NoteSearchResult: Identifiable, Equatable {
    let id: String
    let noteID: String
    let title: String
    let preview: String
    let query: String
    let blockIndex: Int?
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

struct SearchHighlight: Equatable {
    let noteID: String
    let query: String
    let blockIndex: Int
}

struct PromptAttachment: Equatable {
    let fileName: String
    let fileExtension: String
    let extractedText: String
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
    let groqAPIKey: String
    let groqModel: String
}

struct AssistantPreview: Identifiable, Equatable {
    let id = UUID()
    let prompt: String
    let markdown: String
    let providerTitle: String
    let createdAt: Date
}

private struct ChatCompletionResult {
    let content: String
    let inputTokens: Int?
    let outputTokens: Int?
}

enum AssistantModel: String, CaseIterable, Identifiable {
    case mistral
    case groq

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mistral:
            return "Mistral"
        case .groq:
            return "Groq"
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
    var openaiModel: String? = nil
    var groqModel: String? = nil
    var ollamaModel: String? = nil
    var ollamaURL: String? = nil
    var appleModel: String? = nil
}

struct BrainAppCompatibility: Codable {
    var appID: String
    var minAppVersion: String
    var lastOpenedWith: String
}
