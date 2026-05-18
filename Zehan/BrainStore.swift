//
//  BrainStore.swift
//  Zehan
//
//  Created by Adi Tauqir on 5/15/26.
//

import Combine
import Foundation
import AppKit
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
    @Published var selectedAssistantModel: AssistantModel = .gpt
    @Published var assistantPrompt = ""
    @Published var isGeneratingAssistantResponse = false

    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let recentVaultsKey = "RecentVaults"
    private let openAIAPIKeyKey = "Assistant.OpenAIAPIKey"
    private let openAIModelKey = "Assistant.OpenAIModel"
    private let ollamaURLKey = "Assistant.OllamaURL"
    private let ollamaModelKey = "Assistant.OllamaModel"
    private var openAIAPIKey = ""
    private var openAIModel = "gpt-5"
    private var ollamaURL = "http://localhost:11434"
    private var ollamaModel = "llama3.2"

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
        panel.message = "Select a folder. Zehan will create a visible .brain vault file in that folder."
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
        panel.message = "Select the folder that contains your Zehan .brain vault file."
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
                        provider: "openai",
                        openaiModel: "gpt-5.5",
                        ollamaModel: "llama3.2",
                        ollamaURL: "http://localhost:11434",
                        appleModel: nil
                    ),
                    styleMemory: [],
                    app: BrainAppCompatibility(
                        appID: "noortech.Zehan",
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
                    let message = "That folder does not contain a Zehan .brain vault file."
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
                newDraft()
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
        activeBrain = nil
        notes = []
        selectedNoteID = nil
        newDraft()
        status = "Choose a brain"
    }

    func newDraft() {
        currentNoteID = nil
        selectedNoteID = nil
        title = "Untitled"
        content = Self.starterMarkdown
    }

    func updateTitleFromEditor(_ newTitle: String) {
        title = newTitle
        content = contentBySettingDocumentTitle(newTitle, in: content)
        updateCurrentNoteSummaryTitle(to: displayTitle(for: newTitle))
    }

    func updateContentFromEditor(_ newContent: String) {
        content = newContent
        if let documentTitle = markdownDocumentTitle(in: newContent),
           documentTitle != title {
            title = documentTitle
            updateCurrentNoteSummaryTitle(to: displayTitle(for: documentTitle))
        }
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
        guard let noteURL = noteURL(for: id) else { return }
        withActiveBrainAccess {
            do {
                let note = try readNote(from: noteURL)
                currentNoteID = note.id
                selectedNoteID = note.id
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

    func saveCurrentNote() {
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
                status = "Saved"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func configureModelFromUser() {
        let apiKeyField = NSSecureTextField(string: openAIAPIKey)
        let openAIModelField = NSTextField(string: openAIModel)
        let ollamaURLField = NSTextField(string: ollamaURL)
        let ollamaModelField = NSTextField(string: ollamaModel)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        [
            ("OpenAI API Key", apiKeyField),
            ("GPT Model", openAIModelField),
            ("Ollama URL", ollamaURLField),
            ("Ollama Model", ollamaModelField)
        ].forEach { label, field in
            let row = NSStackView()
            row.orientation = .vertical
            row.spacing = 4
            row.alignment = .leading

            let text = NSTextField(labelWithString: label)
            text.font = .systemFont(ofSize: 12, weight: .medium)

            field.frame = NSRect(x: 0, y: 0, width: 360, height: 24)
            row.addArrangedSubview(text)
            row.addArrangedSubview(field)
            stack.addArrangedSubview(row)
        }

        let alert = NSAlert()
        alert.messageText = "Configure Model"
        alert.informativeText = "Enter the credentials and local settings needed by the selected model."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        openAIAPIKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        openAIModel = openAIModelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        ollamaURL = ollamaURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        ollamaModel = ollamaModelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if openAIModel.isEmpty { openAIModel = "gpt-5" }
        if ollamaURL.isEmpty { ollamaURL = "http://localhost:11434" }
        if ollamaModel.isEmpty { ollamaModel = "llama3.2" }

        saveAssistantConfiguration()
        status = "Model settings saved"
    }

    func submitAssistantPrompt() {
        let prompt = assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGeneratingAssistantResponse else { return }

        assistantPrompt = ""
        isGeneratingAssistantResponse = true
        status = "\(selectedAssistantModel.title) is writing"

        Task {
            await generateAssistantResponse(for: prompt)
        }
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
        withActiveBrainAccess {
            do {
                if let noteURL = noteURL(for: id), FileManager.default.fileExists(atPath: noteURL.path) {
                    try FileManager.default.removeItem(at: noteURL)
                }
                newDraft()
                try loadNotes()
                try syncBrainMetadata()
                status = "Deleted"
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

        notes = try noteURLs
            .map { try readNote(from: $0) }
            .map { NoteSummary(id: $0.id, title: $0.title, updatedAt: $0.updatedAt) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func syncBrainMetadata() throws {
        guard let activeBrain else { return }
        var brain = try readBrain(from: activeBrain.brainURL)
        brain.vault.updatedAt = Date()
        brain.rootNoteID = notes.first?.id
        brain.graph.notes = notes.map {
            BrainNoteReference(id: $0.id, title: $0.title, updatedAt: $0.updatedAt)
        }
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

        let samples = ([styleSample(from: content)] + brain.styleMemory)
            .filter { !$0.isEmpty }
            .prefix(4)

        return samples.joined(separator: "\n\n")
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
        do {
            let output: String
            switch selectedAssistantModel {
            case .gpt:
                output = try await generateWithOpenAI(prompt: prompt)
            case .placeholder:
                output = generatePlaceholderMarkdown(prompt: prompt)
            case .ollama:
                output = try await generateWithOllama(prompt: prompt)
            }

            appendAssistantOutput(output)
            try? updateStyleMemory(with: content)
            status = "\(selectedAssistantModel.title) added Markdown"
        } catch {
            status = error.localizedDescription
        }

        isGeneratingAssistantResponse = false
    }

    private func appendAssistantOutput(_ output: String) {
        let cleanOutput = cleanedAssistantMarkdown(output)
        guard !cleanOutput.isEmpty else { return }

        let separator = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\n\n"
        updateContentFromEditor(content + separator + cleanOutput)
        saveCurrentNote()
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
        - Replace this placeholder with model output after configuring GPT or Ollama.
        """
    }

    private func assistantInstructions() -> String {
        """
        You are Zehan's writing assistant. Return only clean Markdown that can be pasted directly into the current document.
        Do not wrap the answer in code fences unless the user specifically asks for code.
        Do not include meta commentary, apologies, or explanations of what you changed.
        Match the user's writing pattern, vocabulary, rhythm, heading style, and density when possible.
        Preserve the user's existing edits. Prefer appending a new section or paragraph instead of rewriting existing text.
        If the user asks for edits, make the smallest useful change and keep user-authored wording intact.
        Output polished Markdown with clear headings, short paragraphs, and useful lists only when lists are natural.
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

        Learned user writing samples:
        \(learnedStyleMemory())
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

    private func loadAssistantConfiguration() {
        let defaults = UserDefaults.standard
        openAIAPIKey = defaults.string(forKey: openAIAPIKeyKey) ?? ""
        openAIModel = defaults.string(forKey: openAIModelKey) ?? "gpt-5"
        ollamaURL = defaults.string(forKey: ollamaURLKey) ?? "http://localhost:11434"
        ollamaModel = defaults.string(forKey: ollamaModelKey) ?? "llama3.2"
    }

    private func saveAssistantConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(openAIAPIKey, forKey: openAIAPIKeyKey)
        defaults.set(openAIModel, forKey: openAIModelKey)
        defaults.set(ollamaURL, forKey: ollamaURLKey)
        defaults.set(ollamaModel, forKey: ollamaModelKey)
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

enum AssistantModel: String, CaseIterable, Identifiable {
    case gpt
    case placeholder
    case ollama

    var id: String { rawValue }

    var title: String {
        switch self {
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
    var app: BrainAppCompatibility
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
    var ollamaModel: String
    var ollamaURL: String
    var appleModel: String?
}

struct BrainAppCompatibility: Codable {
    var appID: String
    var minAppVersion: String
    var lastOpenedWith: String
}
