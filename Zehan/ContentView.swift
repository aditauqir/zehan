//
//  ContentView.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import SwiftUI
import UniformTypeIdentifiers

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
        .sheet(isPresented: $store.isShowingModelConfiguration) {
            ModelConfigurationView(store: store)
                .frame(width: 500)
                .presentationBackground(.regularMaterial)
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
    @State private var isEditingMarkdown = false
    @State private var isShowingMarkdownHelp = false
    @State private var isReadingMode = false
    @State private var isGraphExpanded = false
    @State private var promptPillHeight: CGFloat = 38
    @State private var isDocumentDropTargeted = false
    @State private var sidebarSearchQuery = ""
    @FocusState private var isSidebarSearchFocused: Bool

    private var cleanSidebarSearchQuery: String {
        sidebarSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchingSidebar: Bool {
        !cleanSidebarSearchQuery.isEmpty
    }

    private var sidebarSearchResults: [NoteSearchResult] {
        guard isSearchingSidebar else { return [] }
        return store.searchNotes(matching: sidebarSearchQuery)
    }

    var body: some View {
        ZStack {
            NavigationSplitView {
                VStack(spacing: 12) {
                    BrainSidebarHeader(store: store)
                    .onTapGesture {
                        isEditingMarkdown = false
                    }

                    SidebarSearchField(
                        query: $sidebarSearchQuery,
                        isFocused: $isSidebarSearchFocused
                    )

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            if isSearchingSidebar {
                                if sidebarSearchResults.isEmpty {
                                    SidebarSearchEmptyView()
                                        .padding(.top, 22)
                                } else {
                                    ForEach(sidebarSearchResults) { result in
                                        PageSearchResultRow(result: result, query: cleanSidebarSearchQuery) {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                isEditingMarkdown = false
                                                store.openSearchResult(result)
                                            }
                                        }
                                    }
                                }
                            } else {
                                ForEach(store.notes) { note in
                                    NoteSidebarRow(
                                        note: note,
                                        isSelected: store.selectedNoteID == note.id || store.currentNoteID == note.id,
                                        open: {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                isEditingMarkdown = false
                                                store.openNote(id: note.id)
                                            }
                                        },
                                        rename: {
                                            isEditingMarkdown = false
                                            store.renameNoteFromUser(id: note.id)
                                        },
                                        nutshell: {
                                            isEditingMarkdown = false
                                            store.showNoteNutshell(id: note.id)
                                        },
                                        delete: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isEditingMarkdown = false
                                                store.deleteNote(id: note.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .scrollContentBackground(.hidden)
                    .onTapGesture {
                        isEditingMarkdown = false
                    }

                    ContextUsageBar(store: store)

                    OCRUploadCounterView(store: store)

                    NoteGraphView(
                        notes: store.notes,
                        links: store.graphLinks,
                        selectedNoteID: store.currentNoteID,
                        maxVisibleNotes: 12,
                        openNote: { noteID in
                            isEditingMarkdown = false
                            store.openNote(id: noteID)
                        },
                        expand: {
                            withAnimation(.easeInOut(duration: 0.24)) {
                                isGraphExpanded = true
                            }
                        }
                    )
                    .frame(height: 152)
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 12)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } detail: {
                ZStack(alignment: .bottom) {
                    workspaceDetail
                }
            }

            if isGraphExpanded {
                ExpandedGraphOverlay(
                    notes: store.notes,
                    links: store.graphLinks,
                    selectedNoteID: store.currentNoteID,
                    openNote: { noteID in
                        isEditingMarkdown = false
                        store.openNote(id: noteID)
                    },
                    close: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isGraphExpanded = false
                        }
                    }
                )
                .transition(.scale(scale: 0.985).combined(with: .opacity))
                .zIndex(4)
            }

            if isDocumentDropTargeted {
                DocumentDropSplash()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
        .onDrop(of: Self.supportedDocumentDropTypes, isTargeted: $isDocumentDropTargeted) { providers in
            handleDocumentDrop(providers)
        }
        .animation(.easeInOut(duration: 0.22), value: isReadingMode)
        .animation(.easeInOut(duration: 0.24), value: isGraphExpanded)
        .animation(.easeInOut(duration: 0.18), value: isDocumentDropTargeted)
        .animation(.easeInOut(duration: 0.22), value: store.notes)
        .animation(.easeInOut(duration: 0.18), value: store.status)
        .animation(.easeInOut(duration: 0.2), value: store.isGeneratingAssistantResponse)
        .animation(.easeInOut(duration: 0.16), value: isSearchingSidebar)
        .onChange(of: store.isShowingPageSearch) { _, shouldFocusSearch in
            guard shouldFocusSearch else { return }
            isSidebarSearchFocused = true
            store.isShowingPageSearch = false
        }
        .sheet(isPresented: $isShowingMarkdownHelp) {
            MarkdownHelpView()
                .frame(width: 620, height: 680)
                .presentationBackground(.regularMaterial)
        }
    }

    private var workspaceDetail: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                    HStack {
                        DocumentChromeControls(
                            canDelete: store.selectedNoteID != nil || store.currentNoteID != nil,
                            newPage: {
                                isEditingMarkdown = false
                                store.newDraft()
                            },
                            delete: {
                                isEditingMarkdown = false
                                store.deleteSelectedNote()
                            },
                            help: {
                                isEditingMarkdown = false
                                isShowingMarkdownHelp = true
                            }
                        )

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 64)
                    .frame(height: 44)
                    .background(Color(nsColor: .textBackgroundColor))
                    .onTapGesture {
                        isEditingMarkdown = false
                    }

                    MarkdownEditingSurface(
                        content: contentBinding,
                        isEditing: $isEditingMarkdown,
                        searchHighlight: store.activeSearchHighlight,
                        openLinkedNote: { store.openLinkedNote(named: $0) },
                        clearSearchHighlight: store.clearSearchHighlight
                    )
                        .padding(.horizontal, 38)
                        .padding(.top, 18)
                        .padding(.bottom, 18)

                    HStack {
                        Text(store.documentStats)
                            .contentTransition(.numericText())
                        if isReadingMode {
                            HStack(spacing: 5) {
                                Image(systemName: "eyeglasses")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Reading Mode")
                            }
                            .foregroundStyle(.white.opacity(0.86))
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                        Spacer()
                        Text(store.status)
                            .contentTransition(.opacity)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(.regularMaterial)
                    .onTapGesture {
                        isEditingMarkdown = false
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))

                HStack(alignment: .bottom, spacing: 10) {
                    if !isReadingMode {
                        ReadingModeToggle(isOn: $isReadingMode, size: readingToggleSize)
                            .opacity(0)
                            .allowsHitTesting(false)

                        AssistantFloatingPill(store: store)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                            .onPreferenceChange(PillHeightPreferenceKey.self) { height in
                                promptPillHeight = max(38, height)
                            }
                    }

                    ReadingModeToggle(isOn: $isReadingMode, size: readingToggleSize)
                }
                .padding(.bottom, 54)
                .frame(maxWidth: .infinity, alignment: .center)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        isEditingMarkdown = false
                    }
                )
        }
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { store.content },
            set: { store.updateContentFromEditor($0) }
        )
    }

    private var readingToggleSize: CGFloat {
        min(44, max(38, promptPillHeight))
    }

    private func handleDocumentDrop(_ providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    Task { @MainActor in
                        store.status = error.localizedDescription
                    }
                    return
                }

                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let nsURL = item as? NSURL {
                    url = nsURL as URL
                } else {
                    url = item as? URL
                }

                guard let url else {
                    Task { @MainActor in
                        store.status = "Only PDFs and Word documents are supported"
                    }
                    return
                }

                Task { @MainActor in
                    store.attachPromptDocument(from: url)
                }
            }
            return true
        }

        guard let directProvider = providers.first(where: { provider in
            Self.directDocumentDropTypes.contains { provider.hasItemConformingToTypeIdentifier($0) }
        }) else {
            store.status = "Only PDFs and Word documents are supported"
            return false
        }

        let typeIdentifier = Self.directDocumentDropTypes.first {
            directProvider.hasItemConformingToTypeIdentifier($0)
        } ?? UTType.pdf.identifier
        directProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            if let error {
                Task { @MainActor in
                    store.status = error.localizedDescription
                }
                return
            }

            guard let url,
                  let copiedURL = copyDroppedDocumentToTemporaryURL(url, suggestedName: directProvider.suggestedName)
            else {
                Task { @MainActor in
                    store.status = "Only PDFs and Word documents are supported"
                }
                return
            }

            Task { @MainActor in
                store.attachPromptDocument(from: copiedURL)
            }
        }
        return true
    }

    private func copyDroppedDocumentToTemporaryURL(_ url: URL, suggestedName: String?) -> URL? {
        let fallbackName = suggestedName?.isEmpty == false ? suggestedName! : url.lastPathComponent
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("zirn-drop-\(UUID().uuidString)-\(fallbackName)")

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            Task { @MainActor in
                store.status = error.localizedDescription
            }
            return nil
        }
    }

    private static let directDocumentDropTypes = [
        UTType.pdf.identifier,
        "com.microsoft.word.doc",
        "org.openxmlformats.wordprocessingml.document"
    ]

    private static let supportedDocumentDropTypes = [UTType.fileURL.identifier] + directDocumentDropTypes
}

private struct DocumentDropSplash: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.16))

            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.blue.opacity(0.88))

                Text("Only PDFs and Word documents supported")
                    .font(.system(size: 20, weight: .semibold))
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 30)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 34, y: 18)
        }
    }
}

private struct DocumentChromeControls: View {
    let canDelete: Bool
    let newPage: () -> Void
    let delete: () -> Void
    let help: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            GlassChromeIconButton(systemImage: "square.and.pencil", help: "New Page", action: newPage)
                .keyboardShortcut("n", modifiers: .command)

            Rectangle()
                .fill(Color.primary.opacity(0.13))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 2)

            GlassChromeIconButton(
                systemImage: "trash.fill",
                help: "Delete",
                isDestructive: true,
                action: delete
            )
            .disabled(!canDelete)

            GlassChromeIconButton(
                systemImage: "questionmark.circle.fill",
                help: "Commands and Markdown Help",
                action: help
            )
        }
    }
}

private struct MarkdownHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.72))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zirn Help")
                            .font(.system(size: 28, weight: .bold))
                        Text("Commands, shortcuts, links, and Markdown syntax.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                HelpSection("App Commands") {
                    HelpRow("Create New Brain", "Command Shift N")
                    HelpRow("Open Brain Vault", "Command K")
                    HelpRow("Save Vault Metadata", "Command Shift S")
                    HelpRow("New Page", "Command N")
                    HelpRow("Search Pages", "Command O")
                    HelpRow("Delete Selected Page", "Command Backspace")
                }

                HelpSection("Editor Flow") {
                    HelpRow("Edit a page", "Click the rendered document.")
                    HelpRow("Return to rendered view", "Press Escape or click outside the editor.")
                    HelpRow("Rename from document", "Change the first # heading; the sidebar title follows it.")
                    HelpRow("Autosave", "Changes save automatically after a short pause.")
                }

                HelpSection("Link Pages") {
                    HelpCode("[[Research Project]]")
                    HelpCode("[[Research Project|project notes]]")
                    Text("Links become highlighted in the rendered view. Clicking one opens the matching page title. Linked pages also appear in the graph.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                HelpSection("Basic Markdown") {
                    HelpCode("# Heading 1\n## Heading 2\n### Heading 3")
                    HelpCode("**bold**  *italic*  ~~strikethrough~~  ==highlight==")
                    HelpCode("- Bullet\n- Another bullet\n\n1. Ordered\n2. Ordered")
                    HelpCode("- [ ] Task\n- [x] Done")
                    HelpCode("> Quote\n\n---\n\n`inline code`")
                }

                HelpSection("Code Blocks") {
                    HelpCode("```swift\nlet note = \"Zirn\"\nprint(note)\n```")
                }

                HelpSection("Tables and Advanced Syntax") {
                    HelpCode("| Name | Status |\n| --- | --- |\n| Draft | Active |")
                    HelpCode("$$\ne^{i\\pi} + 1 = 0\n$$")
                    Text("Tables and math are stored as Markdown. The current renderer is lightweight, so some advanced syntax may display more simply until the renderer is expanded.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HelpSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            content()
        }
    }
}

private struct HelpRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

private struct HelpCode: View {
    let code: String

    init(_ code: String) {
        self.code = code
    }

    var body: some View {
        Text(code)
            .font(.system(size: 12.5, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GlassChromeIconButton: View {
    let systemImage: String
    let help: String
    var isDestructive = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(isDestructive && isHovered ? .palette : .hierarchical)
                .foregroundStyle(primaryStyle, secondaryStyle)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .fill(highlightFill)
                }
                .overlay {
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: isHovered ? 9 : 4, y: isHovered ? 4 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .opacity(isEnabled ? 1 : 0.36)
        .onHover { hovering in
            isHovered = hovering && isEnabled
        }
    }

    private var primaryStyle: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.92)
        }

        return .primary.opacity(isHovered ? 0.92 : 0.58)
    }

    private var secondaryStyle: Color {
        isDestructive && isHovered ? .red.opacity(0.42) : .primary.opacity(0.28)
    }

    private var highlightFill: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.15)
        }

        return .white.opacity(isHovered ? 0.13 : 0.025)
    }

    private var borderColor: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.30)
        }

        return .white.opacity(isHovered ? 0.22 : 0.11)
    }

    private var shadowColor: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.12)
        }

        return .black.opacity(isHovered ? 0.18 : 0.08)
    }
}

private struct NoteGraphView: View {
    let notes: [NoteSummary]
    let links: [BrainLinkReference]
    let selectedNoteID: Note.ID?
    var maxVisibleNotes: Int? = 12
    let openNote: (Note.ID) -> Void
    var expand: (() -> Void)?
    @State private var nodeOffsets: [String: CGSize] = [:]
    @State private var activeDragOffsets: [String: CGSize] = [:]
    @State private var droppingNodeID: String?

    var body: some View {
        GeometryReader { proxy in
            let visibleNotes = maxVisibleNotes.map { Array(notes.prefix($0)) } ?? notes
            let basePositions = nodePositions(for: visibleNotes, in: proxy.size)
            let positions = adjustedPositions(from: basePositions)

            ZStack {
                Canvas { context, _ in
                    guard !visibleNotes.isEmpty else { return }

                    for link in links {
                        guard let start = positions[link.from],
                              let end = positions[link.to]
                        else { continue }

                        var path = Path()
                        path.move(to: start)
                        path.addLine(to: end)
                        context.stroke(path, with: .color(.primary.opacity(0.18)), lineWidth: 1)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                ForEach(visibleNotes) { note in
                    if let point = positions[note.id] {
                        let isDragging = activeDragOffsets[note.id] != nil
                        let isDropping = droppingNodeID == note.id

                        GraphNodeButton(
                            note: note,
                            isSelected: note.id == selectedNoteID
                        ) {
                            openNote(note.id)
                        }
                        .position(point)
                        .scaleEffect(isDragging ? 1.1 : (isDropping ? 0.97 : 1))
                        .rotationEffect(.degrees(isDragging ? Double((activeDragOffsets[note.id]?.width ?? 0) / 34) : 0))
                        .zIndex(isDragging || isDropping ? 2 : 1)
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    droppingNodeID = nil
                                    activeDragOffsets[note.id] = value.translation
                                }
                                .onEnded { value in
                                    let existing = nodeOffsets[note.id] ?? .zero
                                    let restingOffset = CGSize(
                                        width: existing.width + value.translation.width,
                                        height: existing.height + value.translation.height
                                    )
                                    withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                                        nodeOffsets[note.id] = CGSize(
                                            width: restingOffset.width,
                                            height: restingOffset.height + 16
                                        )
                                        activeDragOffsets[note.id] = nil
                                        droppingNodeID = note.id
                                    }

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.48)) {
                                            nodeOffsets[note.id] = restingOffset
                                            droppingNodeID = nil
                                        }
                                    }
                                }
                        )
                        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.76), value: activeDragOffsets[note.id])
                        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: nodeOffsets[note.id])
                        .animation(.spring(response: 0.22, dampingFraction: 0.62), value: isDragging)
                        .animation(.spring(response: 0.36, dampingFraction: 0.52), value: isDropping)
                    }
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if let expand {
                Button {
                    expand()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.66))
                        .frame(width: 26, height: 26)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.16), lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .help("Expand Graph")
                .padding(8)
            }
        }
    }

    private func nodePositions(for notes: [NoteSummary], in size: CGSize) -> [String: CGPoint] {
        guard !notes.isEmpty else { return [:] }

        let center = CGPoint(x: size.width / 2, y: size.height / 2 - 4)
        let radius = max(18, min(size.width, size.height) * 0.34)
        guard notes.count > 1 else {
            return [notes[0].id: center]
        }

        var positions: [String: CGPoint] = [:]
        for (index, note) in notes.enumerated() {
            let angle = (Double(index) / Double(notes.count)) * .pi * 2 - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            positions[note.id] = point
        }
        return positions
    }

    private func adjustedPositions(from basePositions: [String: CGPoint]) -> [String: CGPoint] {
        basePositions.mapValues { point in point }
            .reduce(into: [:]) { output, item in
                let id = item.key
                let offset = nodeOffsets[id] ?? .zero
                let activeOffset = activeDragOffsets[id] ?? .zero
                output[id] = CGPoint(
                    x: item.value.x + offset.width + activeOffset.width,
                    y: item.value.y + offset.height + activeOffset.height
                )
            }
    }
}

private struct ContextUsageBar: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Usage", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(store.contextUsageLabel) · \(store.contextUsagePercent)%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))

                    Capsule()
                        .fill(usageGradient)
                        .frame(width: max(8, proxy.size.width * store.contextUsageFraction))
                }
            }
            .frame(height: 7)

            Text(store.contextUsageDetail)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private var usageGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.28, green: 0.72, blue: 0.95),
                Color(red: 0.66, green: 0.84, blue: 0.28)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct OCRUploadCounterView: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Uploads", systemImage: "doc.viewfinder")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(store.ocrUploadCounterLabel)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))

                    Capsule()
                        .fill(uploadGradient)
                        .frame(width: max(8, proxy.size.width * (1 - store.ocrUploadUsageFraction)))
                }
            }
            .frame(height: 7)

            Text(store.ocrUploadCounterDetail)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 2)
    }

    private var uploadGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.62, blue: 0.28),
                Color(red: 0.42, green: 0.78, blue: 0.56)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct ExpandedGraphOverlay: View {
    let notes: [NoteSummary]
    let links: [BrainLinkReference]
    let selectedNoteID: Note.ID?
    let openNote: (Note.ID) -> Void
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close Graph")
                }

                NoteGraphView(
                    notes: notes,
                    links: links,
                    selectedNoteID: selectedNoteID,
                    maxVisibleNotes: nil,
                    openNote: openNote,
                    expand: nil
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.34), radius: 34, y: 18)
            .padding(28)
        }
    }
}

private struct GraphNodeButton: View {
    let note: NoteSummary
    let isSelected: Bool
    let open: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? .green.opacity(0.85) : .primary.opacity(isHovered ? 0.72 : 0.52))
                    .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                    .overlay {
                        Circle()
                            .stroke(.primary.opacity(isHovered || isSelected ? 0.24 : 0.08), lineWidth: 1)
                            .frame(width: isSelected ? 20 : 16, height: isSelected ? 20 : 16)
                    }

                Text(note.title)
                    .font(.system(size: 8, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isHovered ? Color.primary.opacity(0.72) : Color.secondary)
                    .lineLimit(1)
                    .frame(width: 62)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(note.title)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct NoteSidebarRow: View {
    let note: NoteSummary
    let isSelected: Bool
    let open: () -> Void
    let rename: () -> Void
    let nutshell: () -> Void
    let delete: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(note.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 26)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rowFill)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                open()
            }

            Button(role: .destructive) {
                delete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.red.opacity(deleteIconOpacity))
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(.red.opacity(isHovered ? 0.12 : 0))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Delete")
            .opacity(isHovered ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .allowsHitTesting(isHovered)
            .padding(.trailing, 5)
        }
        .contextMenu {
            Button {
                rename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                nutshell()
            } label: {
                Label("In a Nutshell", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive) {
                delete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var deleteIconOpacity: Double {
        isHovered ? 0.82 : 0
    }

    private var rowFill: Color {
        if isSelected {
            return Color.primary.opacity(0.14)
        }

        return Color.primary.opacity(isHovered ? 0.07 : 0)
    }
}

private struct MarkdownEditingSurface: View {
    @Binding var content: String
    @Binding var isEditing: Bool
    let searchHighlight: SearchHighlight?
    let openLinkedNote: (String) -> Void
    let clearSearchHighlight: () -> Void

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
        ScrollViewReader { reader in
            ScrollView {
                MarkdownPreview(
                    content: content,
                    searchHighlight: searchHighlight,
                    openLinkedNote: openLinkedNote
                )
                    .padding(.horizontal, 26)
                    .padding(.top, 2)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: searchHighlight) { _, highlight in
                guard let highlight else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    reader.scrollTo(highlight.blockIndex, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .contentShape(Rectangle())
        .onTapGesture {
            if searchHighlight != nil {
                clearSearchHighlight()
            } else {
                isEditing = true
            }
        }
    }
}

private struct AssistantPreviewPanel: View {
    let preview: AssistantPreview
    let accept: () -> Void
    let reject: () -> Void
    let openLinkedNote: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("\(preview.providerTitle) Preview", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.76))

                Spacer()

                Button(action: reject) {
                    Label("Reject", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Reject output")

                Button(action: accept) {
                    Label("Accept", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Insert into note")
            }

            ScrollView {
                MarkdownPreview(content: preview.markdown, searchHighlight: nil, openLinkedNote: openLinkedNote)
                    .padding(.trailing, 4)
            }
            .frame(maxHeight: 220)
        }
        .padding(14)
        .frame(width: 560)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 22, y: 10)
    }
}

private struct ReadingModeToggle: View {
    @Binding var isOn: Bool
    let size: CGFloat
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isOn.toggle()
            }
        } label: {
            Image(systemName: "eyeglasses")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(isOn ? 0.9 : 0.62))
                .frame(width: size, height: size)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .fill(.white.opacity(isHovered || isOn ? 0.10 : 0.02))
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(isOn ? 0.34 : 0.16), lineWidth: 0.85)
                }
                .shadow(color: .white.opacity(isOn ? 0.16 : 0), radius: isOn ? 8 : 0)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Exit Reading Mode" : "Enter Reading Mode")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }
}

private struct PillHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 38

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AssistantFloatingPill: View {
    @ObservedObject var store: BrainStore
    @FocusState private var isPromptFocused: Bool
    @State private var isExpandedComposerPresented = false
    @FocusState private var isExpandedPromptFocused: Bool
    @State private var isSendHovered = false

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if store.isUsingWebSearch {
                WebSearchStatusPill()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isThinking {
                ThinkingStatusPill()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            VStack(spacing: isExpandedComposerPresented ? 10 : 0) {
                if isExpandedComposerPresented {
                    expandedPromptEditor
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if isExpandedComposerPresented {
                    ZStack {
                        HStack {
                            modelMenu

                            Spacer()

                            attachmentControl
                            expandToggle
                        }

                        sendButton
                    }
                    .padding(.horizontal, 5)
                    .padding(.bottom, 2)
                    .frame(width: pillWidth)
                } else {
                    HStack(spacing: 5) {
                        modelMenu

                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 1, height: 18)

                        TextField("Material?", text: $store.assistantPrompt, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5))
                            .lineLimit(1...4)
                            .frame(width: textFieldWidth, alignment: .leading)
                            .focused($isPromptFocused)
                            .onSubmit {
                                submitOrPreviewThinking()
                            }

                        attachmentControl
                        expandToggle
                        sendButton
                    }
                    .padding(.leading, 5)
                    .padding(.trailing, 4)
                    .padding(.vertical, 6)
                    .frame(width: pillWidth)
                    .frame(minHeight: 34)
                }
            }
            .padding(isExpandedComposerPresented ? 5 : 0)
            .background(.ultraThinMaterial)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PillHeightPreferenceKey.self, value: proxy.size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: isPromptFocused ? 0.6 : 1)
            }
            .overlay {
                if isThinking {
                    AnimatedThinkingBorder()
                }
            }
            .shadow(color: glowColor, radius: isPromptFocused ? 7 : 13, y: isPromptFocused ? 0 : 7)
            .onExitCommand {
                if isExpandedComposerPresented {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpandedComposerPresented = false
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: pillWidth)
        .animation(.easeInOut(duration: 0.18), value: pillCornerRadius)
        .animation(.easeOut(duration: 0.18), value: isThinking)
        .animation(.easeInOut(duration: 0.18), value: store.assistantAttachment)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isExpandedComposerPresented)
    }

    private var modelMenu: some View {
        Menu {
            ForEach(AssistantModel.allCases) { model in
                Button {
                    store.selectAssistantModel(model)
                } label: {
                    if model == store.selectedAssistantModel {
                        Label(model.title, systemImage: "checkmark")
                    } else {
                        Text(model.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.selectedAssistantModel.title)
                    .font(.system(size: 12.2, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: modelMenuWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }

    private var attachmentControl: some View {
        Group {
            if let attachment = store.assistantAttachment {
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 12, weight: .semibold))
                    Text(attachment.fileName)
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: isExpandedComposerPresented ? 118 : 92)
                    Button {
                        store.removePromptAttachment()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 18, height: 18)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Remove attachment")
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 7)
                .padding(.trailing, 3)
                .frame(height: 24)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            } else {
                Image(systemName: "paperclip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.58))
                    .frame(width: 22, height: 24)
                    .help("Drag a PDF or Word document anywhere into the app")
            }
        }
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpandedComposerPresented.toggle()
            }
            if !isExpandedComposerPresented {
                isPromptFocused = true
            } else {
                DispatchQueue.main.async {
                    isExpandedPromptFocused = true
                }
            }
        } label: {
            Image(systemName: isExpandedComposerPresented ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 22, height: 24)
        }
        .buttonStyle(.plain)
        .help(isExpandedComposerPresented ? "Minimize prompt" : "Expand prompt")
    }

    private var sendButton: some View {
        Button {
            submitOrPreviewThinking()
            if isExpandedComposerPresented {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpandedComposerPresented = false
                }
            }
        } label: {
            if isExpandedComposerPresented {
                HStack(spacing: 7) {
                    Image(systemName: isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 15.5, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)

                    Text(isThinking ? "Stop" : "Send")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .frame(height: 30)
                .background {
                    Capsule()
                        .fill(isSendHovered ? .white.opacity(0.16) : .white.opacity(0.06))
                }
                .overlay {
                    if isSendHovered {
                        AnimatedThinkingBorder(lineWidth: 0.7)
                    }
                }
            } else {
                Image(systemName: isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSendHovered ? .white : .primary.opacity(0.78))
                    .frame(width: 24, height: 28)
                    .background {
                        if isSendHovered {
                            Circle()
                                .fill(.white.opacity(0.16))
                        }
                    }
                    .overlay {
                        if isSendHovered {
                            AnimatedThinkingBorder(lineWidth: 0.7)
                                .clipShape(Circle())
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!hasPromptInput && !isThinking)
        .opacity(!hasPromptInput && !isThinking && !isExpandedComposerPresented ? 0.42 : 1)
        .onHover { hovering in
            isSendHovered = hovering && hasPromptInput
        }
    }

    private var expandedPromptEditor: some View {
        TextEditor(text: $store.assistantPrompt)
            .font(.system(size: 14.5))
            .scrollContentBackground(.hidden)
            .focused($isExpandedPromptFocused)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(width: expandedPillWidth - 10, height: 206)
            .background(Color.primary.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .onAppear {
                isExpandedPromptFocused = true
            }
    }

    private var isThinking: Bool {
        store.isGeneratingAssistantResponse
    }

    private var pillWidth: CGFloat {
        isExpandedComposerPresented ? expandedPillWidth : min(730, compactPillWidth)
    }

    private var textFieldWidth: CGFloat {
        min(430, max(96, estimatedPromptWidth))
    }

    private var pillCornerRadius: CGFloat {
        isExpandedComposerPresented ? 20 : (measuredPromptText.count > 54 ? 18 : 17)
    }

    private var measuredPromptText: String {
        let prompt = store.assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt.isEmpty ? "Material?" : prompt
    }

    private var estimatedPromptWidth: CGFloat {
        let characterWidth: CGFloat = 7.35
        return min(524, max(86, CGFloat(measuredPromptText.count) * characterWidth))
    }

    private var attachmentWidth: CGFloat {
        store.assistantAttachment == nil ? 22 : (isExpandedComposerPresented ? 154 : 134)
    }

    private var expandedPillWidth: CGFloat {
        640
    }

    private var compactPillWidth: CGFloat {
        modelMenuWidth + 1 + textFieldWidth + attachmentWidth + 22 + 24 + 25 + 9
    }

    private var modelMenuWidth: CGFloat {
        store.selectedAssistantModel == .groq ? 45 : 62
    }

    private var hasPromptInput: Bool {
        !store.assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.assistantAttachment != nil
    }

    private var borderColor: Color {
        if isThinking {
            return .white.opacity(0.34)
        }

        return isPromptFocused ? .white.opacity(0.34) : .primary.opacity(0.12)
    }

    private var glowColor: Color {
        if isThinking {
            return .white.opacity(0.20)
        }

        return isPromptFocused ? .white.opacity(0.12) : .black.opacity(0.14)
    }

    private func submitOrPreviewThinking() {
        if isThinking {
            return
        }

        guard hasPromptInput else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            store.submitAssistantPrompt()
        }
    }
}

private struct ThinkingStatusPill: View {
    var body: some View {
        Text("Thinking...")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.78))
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                AnimatedThinkingBorder(lineWidth: 0.75)
            }
            .shadow(color: .white.opacity(0.16), radius: 8)
    }
}

private struct WebSearchStatusPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 10.5, weight: .semibold))

            Text("Web search")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.blue.opacity(0.92))
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.blue.opacity(0.22), lineWidth: 0.75)
        }
        .shadow(color: Color.blue.opacity(0.12), radius: 8)
    }
}

private struct AnimatedThinkingBorder: View {
    var lineWidth: CGFloat = 0.85
    @State private var rotation = Angle.degrees(0)

    var body: some View {
        Capsule()
            .stroke(
                AngularGradient(
                    colors: [
                        .white.opacity(0.12),
                        .white.opacity(0.72),
                        Color(red: 0.78, green: 0.93, blue: 0.30).opacity(0.84),
                        .white.opacity(0.18),
                        .white.opacity(0.12)
                    ],
                    center: .center,
                    angle: rotation
                ),
                lineWidth: lineWidth
            )
            .onAppear {
                rotation = .degrees(0)
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    rotation = .degrees(360)
                }
            }
    }
}

private struct MarkdownPreview: View {
    let content: String
    let searchHighlight: SearchHighlight?
    let openLinkedNote: (String) -> Void

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                blockView(block)
                    .id(block.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "zirn-note" || url.scheme == "zehan-note",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let title = components.queryItems?.first(where: { $0.name == "title" })?.value,
                  !title.isEmpty
            else {
                return .systemAction
            }

            openLinkedNote(title)
            return .handled
        })
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        let isHighlighted = searchHighlight?.blockIndex == block.id

        switch block.kind {
        case .heading(let level, let text):
            inlineText(text, highlighted: isHighlighted)
                .font(.system(size: headingSize(for: level), weight: headingWeight(for: level)))
                .padding(.top, level == 1 ? 0 : 5)
                .padding(.bottom, 2)
                .highlightedSearchBlock(isHighlighted)

        case .paragraph(let text):
            inlineText(text, highlighted: isHighlighted)
                .font(.system(size: 15.5))
                .lineSpacing(4)
                .highlightedSearchBlock(isHighlighted)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(size: 15.5, weight: .semibold))
                inlineText(text, highlighted: isHighlighted)
                    .font(.system(size: 15.5))
            }
            .highlightedSearchBlock(isHighlighted)

        case .task(let isDone, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDone ? .green.opacity(0.82) : .secondary)
                inlineText(text, highlighted: isHighlighted)
                    .font(.system(size: 15.5))
                    .foregroundStyle(isDone ? .secondary : .primary)
            }
            .highlightedSearchBlock(isHighlighted)

        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(.secondary)
                inlineText(text, highlighted: isHighlighted)
                    .font(.system(size: 15.5))
            }
            .highlightedSearchBlock(isHighlighted)

        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.secondary.opacity(0.28))
                    .frame(width: 3)
                inlineText(text, highlighted: isHighlighted)
                    .font(.system(size: 15.5).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .highlightedSearchBlock(isHighlighted)

        case .code(let text):
            inlineText(text, highlighted: isHighlighted)
                .font(.system(size: 13.5, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .highlightedSearchBlock(isHighlighted)

        case .divider:
            Rectangle()
                .fill(.secondary.opacity(0.22))
                .frame(height: 1)
                .padding(.vertical, 10)
        }
    }

    private func inlineText(_ markdown: String, highlighted: Bool = false) -> Text {
        if highlighted, let query = searchHighlight?.query, !query.isEmpty {
            return Text(attributedSearchText(markdown, query: query))
        }

        let normalized = markdownByHighlightingWikiLinks(markdown)
            .replacingOccurrences(
                of: #"==([^=]+)=="#,
                with: "**$1**",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"%%.*?%%"#,
                with: "",
                options: .regularExpression
            )

        if let attributed = try? AttributedString(markdown: normalized) {
            return Text(attributed)
        }

        return Text(normalized)
    }

    private func attributedSearchText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let range = attributed.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return attributed
        }
        attributed[range].backgroundColor = .yellow.opacity(0.55)
        attributed[range].foregroundColor = .black
        return attributed
    }

    private func markdownByHighlightingWikiLinks(_ markdown: String) -> String {
        let pattern = #"\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var output = ""
        var cursor = 0

        for match in regex.matches(in: markdown, range: range) {
            output += nsString.substring(with: NSRange(location: cursor, length: match.range.location - cursor))

            let title = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let display: String
            if match.range(at: 2).location != NSNotFound {
                display = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                display = title
            }

            var queryAllowed = CharacterSet.urlQueryAllowed
            queryAllowed.remove(charactersIn: "&+=?")
            let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? title
            output += "[**\(display)**](zirn-note://open?title=\(encodedTitle))"
            cursor = match.range.location + match.range.length
        }

        output += nsString.substring(from: cursor)
        return output
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
        case task(isDone: Bool, text: String)
        case numbered(Int, String)
        case quote(String)
        case code(String)
        case divider
    }

    let id: Int
    let kind: Kind

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var isInCodeBlock = false

        func append(_ kind: Kind) {
            blocks.append(MarkdownBlock(id: blocks.count, kind: kind))
        }

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    append(.code(codeLines.joined(separator: "\n")))
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
                append(.heading(level: heading.level, text: heading.text))
            } else if isDivider(trimmed) {
                flushParagraph()
                append(.divider)
            } else if let task = parseTask(trimmed) {
                flushParagraph()
                append(.task(isDone: task.isDone, text: task.text))
            } else if let bullet = parseBullet(trimmed) {
                flushParagraph()
                append(.bullet(bullet))
            } else if let numbered = parseNumbered(trimmed) {
                flushParagraph()
                append(.numbered(numbered.number, numbered.text))
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                append(.quote(text))
            } else {
                paragraph.append(trimmed)
            }
        }

        flushParagraph()
        if isInCodeBlock, !codeLines.isEmpty {
            append(.code(codeLines.joined(separator: "\n")))
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
        guard line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") else { return nil }
        return String(line.dropFirst(2))
    }

    private static func parseTask(_ line: String) -> (isDone: Bool, text: String)? {
        let prefixes = ["- [ ] ", "* [ ] ", "+ [ ] ", "- [x] ", "* [x] ", "+ [x] ", "- [X] ", "* [X] ", "+ [X] "]
        guard let prefix = prefixes.first(where: { line.hasPrefix($0) }) else { return nil }
        let isDone = prefix.localizedCaseInsensitiveContains("[x]")
        return (isDone, String(line.dropFirst(prefix.count)))
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "-" }
            || compact.allSatisfy { $0 == "*" }
            || compact.allSatisfy { $0 == "_" }
    }

    private static func parseNumbered(_ line: String) -> (number: Int, text: String)? {
        guard let markerIndex = line.firstIndex(where: { $0 == "." || $0 == ")" }) else { return nil }
        let numberText = line[..<markerIndex]
        guard let number = Int(numberText) else { return nil }
        let textStart = line.index(after: markerIndex)
        guard textStart < line.endIndex, line[textStart] == " " else { return nil }
        return (number, String(line[line.index(after: textStart)...]))
    }
}

private extension View {
    func highlightedSearchBlock(_ isHighlighted: Bool) -> some View {
        self
            .padding(isHighlighted ? 4 : 0)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.yellow.opacity(0.22))
                }
            }
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

private struct SidebarSearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)

            TextField("Search pages", text: $query)
                .font(.system(size: 13, weight: .medium))
                .textFieldStyle(.plain)
                .focused(isFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused.wrappedValue ? Color.accentColor.opacity(0.52) : Color.primary.opacity(0.095), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            isFocused.wrappedValue = true
        }
    }
}

private struct SidebarSearchEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)

            Text("No matching pages")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ModelConfigurationView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss

    @State private var mistralAPIKey: String
    @State private var mistralModel: String
    @State private var groqAPIKey: String
    @State private var groqModel: String
    @State private var selectedModel: AssistantModel

    init(store: BrainStore) {
        self.store = store
        let configuration = store.assistantConfigurationSnapshot
        _mistralAPIKey = State(initialValue: configuration.mistralAPIKey)
        _mistralModel = State(initialValue: configuration.mistralModel)
        _groqAPIKey = State(initialValue: configuration.groqAPIKey)
        _groqModel = State(initialValue: configuration.groqModel)
        _selectedModel = State(initialValue: store.selectedAssistantModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Configure Model")
                        .font(.system(size: 24, weight: .bold))

                    Text("Choose whether Zirn writes with Mistral or Groq.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ConfigurationField(title: "Provider") {
                    Picker("Provider", selection: $selectedModel) {
                        ForEach(AssistantModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                if selectedModel == .mistral {
                    ConfigurationField(title: "Mistral API Key") {
                        SecureField("MISTRAL_API_KEY", text: $mistralAPIKey)
                    }

                    ConfigurationField(title: "Mistral Model") {
                        TextField("mistral-large-latest", text: $mistralModel)
                    }
                } else {
                    ConfigurationField(title: "Groq API Key") {
                        SecureField("gsk-...", text: $groqAPIKey)
                    }

                    ConfigurationField(title: "Groq Model") {
                        TextField("llama-3.3-70b-versatile", text: $groqModel)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    store.isShowingModelConfiguration = false
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    store.selectAssistantModel(selectedModel)
                    store.saveModelConfiguration(
                        mistralAPIKey: mistralAPIKey,
                        mistralModel: mistralModel,
                        groqAPIKey: groqAPIKey,
                        groqModel: groqModel
                    )
                    dismiss()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(28)
    }
}

private struct ConfigurationField<Field: View>: View {
    let title: String
    @ViewBuilder let field: () -> Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            field()
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
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
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(results) { result in
                            PageSearchResultRow(result: result, query: query) {
                                open(result)
                            }
                        }
                    }
                    .padding(8)
                }
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

    private func open(_ result: NoteSearchResult) {
        isSearchFocused = false
        store.openSearchResult(result)
        store.isShowingPageSearch = false
    }
}

private struct PageSearchResultRow: View {
    let result: NoteSearchResult
    let query: String
    let open: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: result.blockIndex == nil ? "doc.text" : "text.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(highlightedText(result.title, query: query))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(highlightedText(result.preview, query: query))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0.45)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.09) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isHovered ? Color.primary.opacity(0.10) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .help("Open \(result.title)")
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty,
              let range = attributed.range(of: cleanQuery, options: [.caseInsensitive, .diacriticInsensitive])
        else {
            return attributed
        }
        attributed[range].backgroundColor = .yellow.opacity(0.58)
        attributed[range].foregroundColor = .black
        return attributed
    }
}

#Preview {
    ContentView(store: BrainStore())
}
