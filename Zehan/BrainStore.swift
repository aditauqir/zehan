//
//  BrainStore.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import Combine
import Foundation
import AppKit
import Security
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
    @Published var selectedAssistantModel: AssistantModel = .groq
    @Published var assistantPrompt = ""
    @Published var isGeneratingAssistantResponse = false
    @Published var isShowingModelConfiguration = false
    @Published var pendingAssistantPreview: AssistantPreview?

    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let recentVaultsKey = "RecentVaults"
    private let openAIAPIKeyKey = "Assistant.OpenAIAPIKey"
    private let openAIAPIKeyService = "noortech.Zirn.openai.apiKey"
    private let legacyOpenAIAPIKeyService = "noortech.Zehan.openai.apiKey"
    private let apiKeyAccount = "default"
    private let openAIModelKey = "Assistant.OpenAIModel"
    private let groqAPIKeyKey = "Assistant.GroqAPIKey"
    private let groqAPIKeyService = "noortech.Zirn.groq.apiKey"
    private let groqModelKey = "Assistant.GroqModel"
    private let ollamaURLKey = "Assistant.OllamaURL"
    private let ollamaModelKey = "Assistant.OllamaModel"
    private var openAIAPIKey = ""
    private var openAIModel = "gpt-5"
    private var groqAPIKey = ""
    private var groqModel = "llama-3.3-70b-versatile"
    private var ollamaURL = "http://localhost:11434"
    private var ollamaModel = "llama3.2"
    private var autosaveTask: Task<Void, Never>?
    private var pendingAssistantInsertion: PendingAssistantInsertion?
    private var isApplyingAssistantOutput = false
    private var noteIdentityDatabase: NoteIdentityDatabase?

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
                        provider: "groq",
                        openaiModel: "gpt-5.5",
                        groqModel: "llama-3.3-70b-versatile",
                        ollamaModel: "llama3.2",
                        ollamaURL: "http://localhost:11434",
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
        resetDraft()
        status = "Choose a brain"
    }

    func newDraft() {
        pendingAssistantInsertion = nil
        pendingAssistantPreview = nil
        currentNoteID = nil
        selectedNoteID = nil
        title = "Untitled"
        content = Self.starterMarkdown
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
        title = newTitle
        content = contentBySettingDocumentTitle(newTitle, in: content)
        updateCurrentNoteSummaryTitle(to: displayTitle(for: newTitle))
        scheduleAutosave()
    }

    func updateContentFromEditor(_ newContent: String) {
        content = newContent
        if let documentTitle = markdownDocumentTitle(in: newContent),
           documentTitle != title {
            title = documentTitle
            updateCurrentNoteSummaryTitle(to: displayTitle(for: documentTitle))
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

    func openNote(id: Note.ID) {
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
                let note = Note(
                    id: id,
                    title: cleanTitle.isEmpty ? "Untitled" : cleanTitle,
                    content: content,
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
            openAIAPIKey: openAIAPIKey,
            openAIModel: openAIModel,
            groqAPIKey: groqAPIKey,
            groqModel: groqModel,
            ollamaURL: ollamaURL,
            ollamaModel: ollamaModel
        )
    }

    func saveModelConfiguration(
        openAIAPIKey: String,
        openAIModel: String,
        groqAPIKey: String,
        groqModel: String,
        ollamaURL: String,
        ollamaModel: String
    ) {
        self.openAIAPIKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.openAIModel = openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.groqAPIKey = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.groqModel = groqModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ollamaURL = ollamaURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ollamaModel = ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)

        if self.openAIModel.isEmpty { self.openAIModel = "gpt-5" }
        if self.groqModel.isEmpty { self.groqModel = "llama-3.3-70b-versatile" }
        if self.ollamaURL.isEmpty { self.ollamaURL = "http://localhost:11434" }
        if self.ollamaModel.isEmpty { self.ollamaModel = "llama3.2" }

        do {
            try saveAssistantConfiguration()
            isShowingModelConfiguration = false
            status = "Model settings saved"
        } catch {
            status = error.localizedDescription
        }
    }

    func submitAssistantPrompt() {
        let prompt = assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGeneratingAssistantResponse else { return }

        assistantPrompt = ""
        pendingAssistantPreview = nil
        isGeneratingAssistantResponse = true
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
        let cleanTitle = displayTitle(for: newTitle)

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
                NoteSearchResult(id: $0.id, title: $0.title, preview: "Recently updated")
            }
        }

        return notes.compactMap { noteSummary in
            guard let noteURL = noteURL(for: noteSummary.id),
                  let data = try? Data(contentsOf: noteURL),
                  let note = try? readNote(from: noteURL, data: data)
            else {
                return nil
            }

            let plainContent = plainText(fromMarkdown: note.content)
            let fileName = noteURL.lastPathComponent
            let titleMatches = note.title.localizedCaseInsensitiveContains(cleanQuery)
            let contentMatches = note.content.localizedCaseInsensitiveContains(cleanQuery)
                || plainContent.localizedCaseInsensitiveContains(cleanQuery)
            let fileNameMatches = fileName.localizedCaseInsensitiveContains(cleanQuery)
            guard titleMatches || contentMatches || fileNameMatches else { return nil }

            return NoteSearchResult(
                id: note.id,
                title: note.title,
                preview: searchPreview(
                    query: cleanQuery,
                    note: note,
                    plainContent: plainContent,
                    fileName: fileName,
                    titleMatches: titleMatches,
                    fileNameMatches: fileNameMatches
                )
            )
        }
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
        let loadedNotes = try noteURLs.map { url in
            var note = try readNote(from: url)
            let fileName = url.lastPathComponent
            let metadataID = note.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let indexedID = noteIdentityDatabase?.noteID(forFileName: fileName)
            let candidateID = indexedID ?? (metadataID.isEmpty ? nil : note.id)
            let finalID: Note.ID

            if let candidateID, !seenIDs.contains(candidateID) {
                finalID = candidateID
            } else {
                finalID = UUID().uuidString
            }

            if finalID != note.id {
                note = Note(
                    id: finalID,
                    title: note.title,
                    content: note.content,
                    createdAt: note.createdAt,
                    updatedAt: Date()
                )
                try writeNote(note, to: url)
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
        }

        do {
            let output: String
            let providerTitle = selectedAssistantModel.title
            switch selectedAssistantModel {
            case .gpt:
                output = try await generateWithOpenAI(prompt: prompt)
            case .groq:
                output = try await generateWithGroq(prompt: prompt)
            case .placeholder:
                output = generatePlaceholderMarkdown(prompt: prompt)
            case .ollama:
                output = try await generateWithOllama(prompt: prompt)
            }

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

    private func generateWithOpenAI(prompt: String) async throws -> String {
        guard !openAIAPIKey.isEmpty else {
            throw AssistantError.missingConfiguration("Add an OpenAI API key in Settings > Configure Model.")
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": openAIModel,
            "instructions": assistantInstructions(),
            "input": assistantInput(for: prompt),
            "store": false
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try extractOpenAIOutputText(from: data)
    }

    private func generateWithGroq(prompt: String) async throws -> String {
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
            "max_completion_tokens": 4096,
            "stream": false
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try extractChatCompletionOutputText(from: data)
    }

    private func generateWithOllama(prompt: String) async throws -> String {
        guard let url = URL(string: ollamaURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/generate") else {
            throw AssistantError.missingConfiguration("Add a valid Ollama URL in Settings > Configure Model.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": ollamaModel,
            "prompt": "\(assistantInstructions())\n\n\(assistantInput(for: prompt))",
            "stream": false
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["response"] as? String ?? ""
    }

    private func generatePlaceholderMarkdown(prompt: String) -> String {
        """
        ## \(prompt)

        - Draft the idea in your own language.
        - Add context, examples, and next steps.
        - Replace this placeholder with model output after configuring Groq, GPT, or Ollama.
        """
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
        \(prompt)

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

    private func extractOpenAIOutputText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AssistantError.requestFailed("Could not read model response.")
        }

        if let outputText = json["output_text"] as? String {
            return outputText
        }

        if let output = json["output"] as? [[String: Any]] {
            return output.compactMap { item in
                guard let content = item["content"] as? [[String: Any]] else { return nil }
                return content.compactMap { contentItem in
                    contentItem["text"] as? String
                }.joined(separator: "\n")
            }.joined(separator: "\n")
        }

        throw AssistantError.requestFailed("The model returned no Markdown.")
    }

    private func extractChatCompletionOutputText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AssistantError.requestFailed("The model returned no Markdown.")
        }

        return content
    }

    private func loadAssistantConfiguration() {
        let defaults = UserDefaults.standard
        let keychainAPIKey = loadAPIKeyFromKeychain(service: openAIAPIKeyService)
            ?? loadAPIKeyFromKeychain(service: legacyOpenAIAPIKeyService)
        let legacyDefaultsAPIKey = defaults.string(forKey: openAIAPIKeyKey)
        openAIAPIKey = keychainAPIKey ?? legacyDefaultsAPIKey ?? ""
        if keychainAPIKey == nil,
           let legacyDefaultsAPIKey,
           !legacyDefaultsAPIKey.isEmpty,
           let keyData = legacyDefaultsAPIKey.data(using: .utf8) {
            try? saveKeychainData(keyData, service: openAIAPIKeyService)
        }
        defaults.removeObject(forKey: openAIAPIKeyKey)
        openAIModel = defaults.string(forKey: openAIModelKey) ?? "gpt-5"
        let keychainGroqKey = loadAPIKeyFromKeychain(service: groqAPIKeyService)
        let legacyDefaultsGroqKey = defaults.string(forKey: groqAPIKeyKey)
        groqAPIKey = keychainGroqKey ?? legacyDefaultsGroqKey ?? ""
        if keychainGroqKey == nil,
           let legacyDefaultsGroqKey,
           !legacyDefaultsGroqKey.isEmpty,
           let keyData = legacyDefaultsGroqKey.data(using: .utf8) {
            try? saveKeychainData(keyData, service: groqAPIKeyService)
        }
        defaults.removeObject(forKey: groqAPIKeyKey)
        groqModel = defaults.string(forKey: groqModelKey) ?? "llama-3.3-70b-versatile"
        ollamaURL = defaults.string(forKey: ollamaURLKey) ?? "http://localhost:11434"
        ollamaModel = defaults.string(forKey: ollamaModelKey) ?? "llama3.2"
    }

    private func saveAssistantConfiguration() throws {
        let defaults = UserDefaults.standard
        if openAIAPIKey.isEmpty {
            deleteAPIKeyFromKeychain(service: openAIAPIKeyService)
        } else if let keyData = openAIAPIKey.data(using: .utf8) {
            try saveKeychainData(keyData, service: openAIAPIKeyService)
        }
        if groqAPIKey.isEmpty {
            deleteAPIKeyFromKeychain(service: groqAPIKeyService)
        } else if let keyData = groqAPIKey.data(using: .utf8) {
            try saveKeychainData(keyData, service: groqAPIKeyService)
        }
        defaults.removeObject(forKey: openAIAPIKeyKey)
        defaults.removeObject(forKey: groqAPIKeyKey)
        defaults.set(openAIModel, forKey: openAIModelKey)
        defaults.set(groqModel, forKey: groqModelKey)
        defaults.set(ollamaURL, forKey: ollamaURLKey)
        defaults.set(ollamaModel, forKey: ollamaModelKey)
    }

    private func loadAPIKeyFromKeychain(service: String) -> String? {
        var query = keychainBaseQuery(service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }

        return key
    }

    private func saveKeychainData(_ data: Data, service: String) throws {
        var query = keychainBaseQuery(service: service)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let addAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw AssistantError.missingConfiguration("Could not update the API key in Keychain.")
        }

        query.merge(addAttributes) { _, new in new }
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AssistantError.missingConfiguration("Could not save the API key in Keychain.")
        }
    }

    private func deleteAPIKeyFromKeychain(service: String) {
        SecItemDelete(keychainBaseQuery(service: service) as CFDictionary)
    }

    private func keychainBaseQuery(service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
    }

    private func searchPreview(
        query: String,
        note: Note,
        plainContent: String,
        fileName: String,
        titleMatches: Bool,
        fileNameMatches: Bool
    ) -> String {
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
    let title: String
    let preview: String
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
    let openAIAPIKey: String
    let openAIModel: String
    let groqAPIKey: String
    let groqModel: String
    let ollamaURL: String
    let ollamaModel: String
}

struct AssistantPreview: Identifiable, Equatable {
    let id = UUID()
    let prompt: String
    let markdown: String
    let providerTitle: String
    let createdAt: Date
}

enum AssistantModel: String, CaseIterable, Identifiable {
    case groq
    case gpt
    case placeholder
    case ollama

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groq:
            return "Groq"
        case .gpt:
            return "GPT"
        case .placeholder:
            return "Placeholder"
        case .ollama:
            return "Ollama"
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
    var openaiModel: String
    var groqModel: String?
    var ollamaModel: String
    var ollamaURL: String
    var appleModel: String?
}

struct BrainAppCompatibility: Codable {
    var appID: String
    var minAppVersion: String
    var lastOpenedWith: String
}
