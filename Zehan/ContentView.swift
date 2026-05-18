//
//  ContentView.swift
//  Zehan
//
//  Created by Adi Tauqir on 5/15/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        Group {
            if store.activeBrain == nil {
                SplashView(
                    recentVaults: store.recentVaults,
                    isBusy: store.isBusy,
                    newBrain: store.createBrainVaultFromUser,
                    openBrain: store.openBrainVaultFromUser,
                    openRecent: store.openRecentVault
                )
            } else {
                WorkspaceView(store: store)
            }
        }
        .frame(minWidth: 1120, minHeight: 720)
        .sheet(isPresented: $store.isShowingPageSearch) {
            PageSearchView(store: store)
                .frame(width: 520, height: 286)
                .presentationBackground(.clear)
        }
    }
}

private struct SplashView: View {
    let recentVaults: [RecentVault]
    let isBusy: Bool
    let newBrain: () -> Void
    let openBrain: () -> Void
    let openRecent: (RecentVault) -> Void

    var body: some View {
        VStack(spacing: 62) {
            Text("Welcome to your second brain")
                .font(.system(size: 40, weight: .light, design: .default).italic())
                .foregroundStyle(.white.opacity(0.78))

            VStack(spacing: 34) {
                HStack(spacing: 34) {
                    SplashActionButton(
                        title: "Create New Brain",
                        systemImage: "folder.badge.plus",
                        width: 218,
                        isProminent: true,
                        isDisabled: isBusy,
                        action: newBrain
                    )

                    SplashActionButton(
                        title: "Open Brain Vault",
                        systemImage: "folder",
                        width: 246,
                        isProminent: false,
                        isDisabled: isBusy,
                        action: openBrain
                    )
                }

                RecentVaultsView(
                    recentVaults: recentVaults,
                    isDisabled: isBusy,
                    openRecent: openRecent
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.10),
                    Color(red: 0.075, green: 0.075, blue: 0.075)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.dark)
    }
}

private struct RecentVaultsView: View {
    let recentVaults: [RecentVault]
    let isDisabled: Bool
    let openRecent: (RecentVault) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(recentVaults.prefix(4)) { vault in
                RecentVaultRow(vault: vault, isDisabled: isDisabled) {
                    openRecent(vault)
                }
            }
        }
        .frame(width: 520)
        .opacity(recentVaults.isEmpty ? 0 : 1)
        .accessibilityHidden(recentVaults.isEmpty)
    }
}

private struct RecentVaultRow: View {
    let vault: RecentVault
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                HStack(spacing: 4) {
                    Text(vault.brainFileName)
                        .font(.system(size: 10.5, weight: .regular))
                        .lineLimit(1)

                    if let noteFileName = vault.noteFileName {
                        Text(">")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.26))

                        Text(noteFileName)
                            .font(.system(size: 10.5, weight: .regular))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white.opacity(isHovered ? 0.66 : 0.46))

                Text("last edited \(Self.timeFormatter.string(from: vault.updatedAt))")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(.white.opacity(isHovered ? 0.58 : 0.38))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering && !isDisabled
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct SplashActionButton: View {
    let title: String
    let systemImage: String
    let width: CGFloat
    let isProminent: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 12)

                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 18)
            .frame(width: width, height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background {
            Capsule()
                .fill(backgroundColor)
        }
        .overlay {
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        }
        .shadow(color: shadowColor, radius: isHovered ? 16 : 0, y: isHovered ? 8 : 0)
        .scaleEffect(isHovered && !isDisabled ? 1.012 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering && !isDisabled
        }
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var foregroundColor: Color {
        isHovered ? .white.opacity(0.92) : .white.opacity(0.72)
    }

    private var backgroundColor: Color {
        if isHovered {
            return .white.opacity(isProminent ? 0.145 : 0.105)
        }

        return .white.opacity(isProminent ? 0.085 : 0.028)
    }

    private var borderColor: Color {
        .white.opacity(isHovered ? 0.24 : 0.105)
    }

    private var shadowColor: Color {
        .black.opacity(isHovered ? 0.22 : 0)
    }
}

private struct WorkspaceView: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                BrainSidebarHeader(store: store)
                .padding(.top, 12)

                Button {
                    store.newDraft()
                } label: {
                    Label("New Page", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .keyboardShortcut("n", modifiers: .command)

                List(selection: $store.selectedNoteID) {
                    ForEach(store.notes) { note in
                        Text(note.title)
                            .lineLimit(1)
                            .tag(note.id)
                    }
                }
                .onChange(of: store.selectedNoteID) { _, id in
                    guard let id else { return }
                    store.openNote(id: id)
                }
            }
            .padding(.horizontal, 12)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        TextField("Untitled", text: titleBinding)
                            .font(.system(size: 30, weight: .bold))
                            .textFieldStyle(.plain)

                        Button("Save") {
                            store.saveCurrentNote()
                        }
                        .keyboardShortcut("s", modifiers: .command)

                        Button(role: .destructive) {
                            store.deleteCurrentNote()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(store.currentNoteID == nil)
                    }
                    .padding(.horizontal, 44)
                    .padding(.vertical, 18)

                    MarkdownEditingSurface(content: contentBinding)
                        .padding(.horizontal, 38)
                        .padding(.bottom, 18)

                    HStack {
                        Text(store.documentStats)
                        Spacer()
                        Text(store.status)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(.regularMaterial)
                }
                .background(Color(nsColor: .textBackgroundColor))

                Divider()

                AssistantPanel(store: store)
                    .frame(width: 320)
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { store.title },
            set: { store.updateTitleFromEditor($0) }
        )
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { store.content },
            set: { store.updateContentFromEditor($0) }
        )
    }
}

private struct MarkdownEditingSurface: View {
    @Binding var content: String
    @State private var isEditing = false

    var body: some View {
        Group {
            if isEditing {
                editor
            } else {
                renderedPreview
            }
        }
        .onExitCommand {
            isEditing = false
        }
    }

    private var editor: some View {
        TextEditor(text: $content)
            .font(.system(size: 15, design: .monospaced))
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var renderedPreview: some View {
        ScrollView {
            MarkdownPreview(content: content)
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .contentShape(Rectangle())
        .onTapGesture {
            isEditing = true
        }
    }
}

private struct AssistantPanel: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Picker("", selection: $store.selectedAssistantModel) {
                    ForEach(AssistantModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 10) {
                    TextField("Material?", text: $store.assistantPrompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .onSubmit {
                            store.submitAssistantPrompt()
                        }

                    Button {
                        store.submitAssistantPrompt()
                    } label: {
                        Image(systemName: store.isGeneratingAssistantResponse ? "hourglass" : "arrow.up.circle.fill")
                            .font(.system(size: 29, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isGeneratingAssistantResponse)
                }
                .padding(.leading, 21)
                .padding(.trailing, 13)
                .frame(height: 58)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(0.13), lineWidth: 1)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct MarkdownPreview: View {
    let content: String

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            inlineText(text)
                .font(.system(size: headingSize(for: level), weight: headingWeight(for: level)))
                .padding(.top, level == 1 ? 8 : 5)
                .padding(.bottom, 2)

        case .paragraph(let text):
            inlineText(text)
                .font(.system(size: 15.5))
                .lineSpacing(4)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 15.5, weight: .semibold))
                inlineText(text)
                    .font(.system(size: 15.5))
            }

        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(.secondary)
                inlineText(text)
                    .font(.system(size: 15.5))
            }

        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.secondary.opacity(0.28))
                    .frame(width: 3)
                inlineText(text)
                    .font(.system(size: 15.5).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

        case .code(let text):
            Text(text)
                .font(.system(size: 13.5, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func inlineText(_ markdown: String) -> Text {
        if let attributed = try? AttributedString(markdown: markdown) {
            return Text(attributed)
        }

        return Text(markdown)
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: 28
        case 2: 23
        case 3: 19
        default: 16.5
        }
    }

    private func headingWeight(for level: Int) -> Font.Weight {
        level <= 2 ? .bold : .semibold
    }
}

private struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet(String)
        case numbered(Int, String)
        case quote(String)
        case code(String)
    }

    let id = UUID()
    let kind: Kind

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(MarkdownBlock(kind: .paragraph(paragraph.joined(separator: " "))))
            paragraph.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    blocks.append(MarkdownBlock(kind: .code(codeLines.joined(separator: "\n"))))
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

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(MarkdownBlock(kind: .heading(level: heading.level, text: heading.text)))
            } else if let bullet = parseBullet(trimmed) {
                flushParagraph()
                blocks.append(MarkdownBlock(kind: .bullet(bullet)))
            } else if let numbered = parseNumbered(trimmed) {
                flushParagraph()
                blocks.append(MarkdownBlock(kind: .numbered(numbered.number, numbered.text)))
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                blocks.append(MarkdownBlock(kind: .quote(text)))
            } else {
                paragraph.append(trimmed)
            }
        }

        flushParagraph()
        if isInCodeBlock, !codeLines.isEmpty {
            blocks.append(MarkdownBlock(kind: .code(codeLines.joined(separator: "\n"))))
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let markers = line.prefix { $0 == "#" }
        guard !markers.isEmpty, markers.count <= 6 else { return nil }
        let rest = line.dropFirst(markers.count)
        guard rest.first == " " else { return nil }
        return (markers.count, rest.trimmingCharacters(in: .whitespaces))
    }

    private static func parseBullet(_ line: String) -> String? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") else { return nil }
        return String(line.dropFirst(2))
    }

    private static func parseNumbered(_ line: String) -> (number: Int, text: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let numberText = line[..<dotIndex]
        guard let number = Int(numberText) else { return nil }
        let textStart = line.index(after: dotIndex)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }
        return (number, String(line[line.index(after: textStart)...]))
    }
}

private struct BrainSidebarHeader: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        HStack {
            Label(store.activeBrain?.name ?? "Brain", systemImage: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .contextMenu {
                    Button {
                        store.renameBrainFromUser()
                    } label: {
                        Label("Rename Brain", systemImage: "pencil")
                    }

                    Button {
                        store.showBrainInfo()
                    } label: {
                        Label("Get More Info", systemImage: "info.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        store.confirmDeleteBrain()
                    } label: {
                        Label("Delete Brain", systemImage: "trash")
                    }
                }

            Spacer()

            Button {
                store.closeBrain()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
            .help("Switch brain")
        }
    }
}

private struct PageSearchView: View {
    @ObservedObject var store: BrainStore
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var results: [NoteSearchResult] {
        store.searchNotes(matching: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Search pages", text: $query)
                    .font(.system(size: 18, weight: .medium))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(.ultraThinMaterial)

            Divider().opacity(0.35)

            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)

                    Text("No Matching Pages")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { result in
                    Button {
                        store.openNote(id: result.id)
                        store.isShowingPageSearch = false
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(result.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)

                            Text(result.preview)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 28, y: 16)
        .task {
            isSearchFocused = true
        }
    }
}

#Preview {
    ContentView(store: BrainStore())
}
