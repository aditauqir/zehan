//
//  ContentView.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import AppKit
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
        .sheet(isPresented: $store.isShowingMarkdownHelp) {
            MarkdownHelpView()
                .frame(width: 620, height: 680)
                .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $store.isShowingUsedModelsConfiguration) {
            UsedModelsConfigurationView(store: store)
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
    @State private var isReadingMode = false
    @State private var isGraphExpanded = false
    @State private var promptPillHeight: CGFloat = 38
    @State private var isDocumentDropTargeted = false
    @State private var sidebarSearchQuery = ""
    @State private var isSidebarSearchActive = false
    @State private var draggedSidebarItemID: SidebarItem.ID?
    @State private var typingStatus = MarkdownTypingStatus()
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

                    SidebarHomeSearchControl(
                        isSearchActive: $isSidebarSearchActive,
                        query: $sidebarSearchQuery,
                        isSearchFocused: $isSidebarSearchFocused,
                        isHomeSelected: store.isShowingHomePage,
                        openHome: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isEditingMarkdown = false
                                isSidebarSearchActive = false
                                sidebarSearchQuery = ""
                                store.openHomePage()
                            }
                        },
                        reloadHome: {
                            isEditingMarkdown = false
                            isSidebarSearchActive = false
                            sidebarSearchQuery = ""
                            store.regenerateHomePage()
                        },
                        activateSearch: {
                            withAnimation(.easeInOut(duration: 0.55)) {
                                isSidebarSearchActive = true
                            }
                            isSidebarSearchFocused = true
                        }
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
                                ForEach(store.visibleSidebarItems()) { item in
                                    sidebarItemRow(item)
                                        .onDrag {
                                            draggedSidebarItemID = item.id
                                            return NSItemProvider(object: item.id as NSString)
                                        }
                                        .onDrop(
                                            of: [.plainText],
                                            delegate: SidebarItemDropDelegate(
                                                item: item,
                                                store: store,
                                                draggedItemID: { draggedSidebarItemID },
                                                clearDraggedItem: { draggedSidebarItemID = nil }
                                            )
                                        )
                                }

                                Color.clear
                                    .frame(height: 14)
                                    .onDrop(
                                        of: [.plainText],
                                        delegate: SidebarEndDropDelegate(
                                            store: store,
                                            draggedItemID: { draggedSidebarItemID },
                                            clearDraggedItem: { draggedSidebarItemID = nil }
                                        )
                                    )
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
                    if shouldShowNewPageHint {
                        NewBrainPageHint {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isEditingMarkdown = false
                                store.newDraft()
                            }
                        }
                        .padding(.bottom, 116)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .zIndex(2)
                    }
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
            isSidebarSearchActive = true
            isSidebarSearchFocused = true
            store.isShowingPageSearch = false
        }
        .onChange(of: isReadingMode) { _, isReading in
            if isReading {
                isEditingMarkdown = false
            }
        }
    }

    private var workspaceDetail: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if !store.isShowingHomePage {
                    HStack {
                        DocumentChromeControls(
                            canDelete: !store.isViewingGeneratedPage && (store.selectedNoteID != nil || store.currentNoteID != nil),
                            newPage: {
                                isEditingMarkdown = false
                                store.newDraft()
                            },
                            delete: {
                                isEditingMarkdown = false
                                store.deleteSelectedNote()
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
                }

                    Group {
                        if store.isShowingHomePage {
                            ReadOnlyHomePageView(
                                markdown: store.homeMarkdown,
                                isGenerating: store.isGeneratingHomePage,
                                openLinkedNote: { store.openLinkedNote(named: $0) },
                                imageURL: store.markdownImageURL
                            )
                        } else if let summary = store.currentHighlightSummary {
                            ReadOnlyHighlightSummaryView(
                                summary: summary,
                                openLinkedNote: { store.openLinkedNote(named: $0) },
                                imageURL: store.markdownImageURL
                            )
                        } else {
                            MarkdownEditingSurface(
                                content: contentBinding,
                                isEditing: $isEditingMarkdown,
                                isReadOnly: isReadingMode,
                                searchHighlight: store.activeSearchHighlight,
                                noteTitles: store.notes.map(\.title),
                                openLinkedNote: { store.openLinkedNote(named: $0) },
                                clearSearchHighlight: store.clearSearchHighlight,
                                imageURL: store.markdownImageURL,
                                insertImageFile: store.insertMarkdownImage,
                                insertImageData: store.insertMarkdownImage,
                                typingStatus: $typingStatus
                            )
                        }
                    }
                    .padding(.horizontal, 38)
                    .padding(.top, 18)
                    .padding(.bottom, 18)

                    HStack {
                        if store.isShowingHomePage {
                            HomeFooter(latestSummary: store.latestHomeSummary)
                        } else if let summary = store.currentHighlightSummary {
                            HighlightSummaryFooter(summary: summary)
                        } else {
                            Text(store.documentStats)
                                .contentTransition(.numericText())
                        }
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
                        if !store.isViewingGeneratedPage {
                            MarkdownTypingStatusIcons(status: typingStatus)
                        }
                        if !store.isShowingHomePage {
                            FooterStatusMessage(status: store.status)
                            AssistantConnectionStatusDot(status: store.assistantConnectionStatus)
                        }
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
                    if !isReadingMode && !store.isViewingGeneratedPage {
                        ReadingModeToggle(isOn: $isReadingMode, size: readingToggleSize)
                            .opacity(0)
                            .allowsHitTesting(false)

                        AssistantFloatingPill(store: store)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                            .onPreferenceChange(PillHeightPreferenceKey.self) { height in
                                promptPillHeight = max(38, height)
                            }
                    }

                    if !store.isViewingGeneratedPage {
                        ReadingModeToggle(isOn: $isReadingMode, size: readingToggleSize)
                    }
                }
                .padding(.bottom, 54)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var shouldShowNewPageHint: Bool {
        store.activeBrain != nil
            && store.notes.isEmpty
            && !store.isShowingHomePage
            && store.currentHighlightSummary == nil
            && !isEditingMarkdown
    }

    @ViewBuilder
    private func sidebarItemRow(_ item: SidebarItem) -> some View {
        switch item.kind {
        case .note:
            if let noteID = item.noteID,
               let note = store.noteSummary(for: noteID) {
                NoteSidebarRow(
                    note: note,
                    isSelected: !store.isViewingGeneratedPage && (store.selectedNoteID == note.id || store.currentNoteID == note.id),
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
                .padding(.leading, item.groupID == nil ? 0 : 18)
            }
        case .group:
            SidebarGroupRow(
                item: item,
                isSelected: store.selectedSidebarGroupID == item.id,
                toggle: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.selectSidebarGroup(id: item.id)
                        store.toggleSidebarGroup(id: item.id)
                    }
                },
                rename: { newTitle in
                    store.renameSidebarGroup(id: item.id, to: newTitle)
                },
                delete: {
                    store.deleteSidebarGroup(id: item.id)
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
                        store.status = "Only PDFs, Word documents, and images are supported"
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
            store.status = "Only PDFs, Word documents, and images are supported"
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
                    store.status = "Only PDFs, Word documents, and images are supported"
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
        "org.openxmlformats.wordprocessingml.document",
        UTType.image.identifier
    ]

    private static let supportedDocumentDropTypes = [UTType.fileURL.identifier] + directDocumentDropTypes
}

private struct FooterStatusMessage: View {
    let status: String
    @State private var isHovered = false

    private var isWarning: Bool {
        let lowercased = status.lowercased()
        return status.count > 64
            || lowercased.contains("permission")
            || lowercased.contains("couldn")
            || lowercased.contains("failed")
            || lowercased.contains("error")
            || lowercased.contains("cannot")
    }

    private var popupWidth: CGFloat {
        min(460, max(260, CGFloat(status.count) * 5.2))
    }

    var body: some View {
        Group {
            if isWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.yellow.opacity(0.92))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottomTrailing) {
                        if isHovered {
                            Text(status)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(4)
                                .truncationMode(.tail)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(width: popupWidth, alignment: .leading)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                                .offset(y: -18)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                                .zIndex(2)
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.12)) {
                            isHovered = hovering
                        }
                    }
                    .help(status)
            } else {
                Text(status)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)
            }
        }
    }
}

private struct NewBrainPageHint: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(isHovered ? 0.13 : 0.08))
                    )

                HStack(spacing: 6) {
                    Text("Press")
                        .foregroundStyle(.secondary)

                    KeyboardShortcutCapsule(text: "Cmd")
                    KeyboardShortcutCapsule(text: "N")

                    Text("to start a new page")
                        .foregroundStyle(.primary.opacity(0.82))
                }
                .font(.system(size: 13.5, weight: .semibold))
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(isHovered ? 0.18 : 0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isHovered ? 0.18 : 0.11), radius: isHovered ? 14 : 9, y: isHovered ? 8 : 5)
        }
        .buttonStyle(.plain)
        .help("Create a new page")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }
}

private struct KeyboardShortcutCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.78))
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }
    }
}

private struct MarkdownTypingStatus: Equatable {
    var isCapsLockOn = NSEvent.modifierFlags.contains(.capsLock)
    var isBold = false
    var isItalic = false
    var isUnderline = false
    var isHighlight = false
}

private struct MarkdownTypingStatusIcons: View {
    let status: MarkdownTypingStatus

    var body: some View {
        HStack(spacing: 7) {
            statusIcon(status.isCapsLockOn ? "capslock.fill" : "capslock", isActive: status.isCapsLockOn, help: "Caps Lock")
            statusIcon("bold", isActive: status.isBold, help: "Bold")
            statusIcon("italic", isActive: status.isItalic, help: "Italic")
            statusIcon("underline", isActive: status.isUnderline, help: "Underline")
            statusIcon("paintbrush.pointed", isActive: status.isHighlight, help: "Highlight")
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Color.primary.opacity(0.045))
        .clipShape(Capsule())
        .animation(.easeOut(duration: 0.12), value: status)
    }

    private func statusIcon(_ name: String, isActive: Bool, help: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 11.5, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? Color.primary.opacity(0.92) : Color.secondary.opacity(0.34))
            .frame(width: 13, height: 16)
            .help(help)
    }
}

private struct AssistantConnectionStatusDot: View {
    let status: AssistantConnectionStatus
    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(status == .offline ? 0.18 : 0.42), radius: 5)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if isHovered {
                    Text(status.helpText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                        .fixedSize()
                        .offset(y: -18)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        .padding(.leading, 2)
        .zIndex(isHovered ? 1 : 0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private var color: Color {
        switch status {
        case .online:
            return .green.opacity(0.88)
        case .offline:
            return .red.opacity(0.86)
        case .local:
            return .yellow.opacity(0.9)
        }
    }
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

                Text("Drop to attach PDFs, Word documents, or images")
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
        }
    }
}

private struct MarkdownHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close Help")
            .padding(16)
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
    var allowsScrolling = false
    let openNote: (Note.ID) -> Void
    var expand: (() -> Void)?
    @State private var savedNodePositions: [String: CGPoint] = [:]
    @State private var activeDragPosition: CGPoint?
    @State private var activeDraggedNodeID: Note.ID?
    private let graphNodeSize = CGSize(width: 74, height: 38)

    var body: some View {
        GeometryReader { proxy in
            let visibleNotes = maxVisibleNotes.map { Array(notes.prefix($0)) } ?? notes
            let visibleNoteIDs = visibleNotes.map(\.id)
            let canvasSize = allowsScrolling ? scrollCanvasSize(for: visibleNotes.count, viewport: proxy.size) : proxy.size

            if allowsScrolling {
                ScrollView([.horizontal, .vertical]) {
                    graphCanvas(visibleNotes: visibleNotes, visibleNoteIDs: visibleNoteIDs, size: canvasSize)
                        .frame(width: canvasSize.width, height: canvasSize.height)
                }
                .scrollIndicators(.visible)
            } else {
                graphCanvas(visibleNotes: visibleNotes, visibleNoteIDs: visibleNoteIDs, size: canvasSize)
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

    private func graphCanvas(visibleNotes: [NoteSummary], visibleNoteIDs: [Note.ID], size: CGSize) -> some View {
        let defaultPositions = nodePositions(for: visibleNotes, in: size)
        let positions = adjustedPositions(from: defaultPositions, in: size)

        return ZStack {
            Canvas { context, _ in
                guard !visibleNotes.isEmpty else { return }

                for link in links {
                    guard let start = positions[link.from],
                          let end = positions[link.to],
                          start.x.isFinite,
                          start.y.isFinite,
                          end.x.isFinite,
                          end.y.isFinite
                    else { continue }

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(.primary.opacity(0.18)), lineWidth: 1)
                }
            }
            .frame(width: size.width, height: size.height)

            ForEach(visibleNotes) { note in
                if let point = positions[note.id] {
                    let isDragging = activeDraggedNodeID == note.id

                    GraphNodeView(
                        note: note,
                        isSelected: note.id == selectedNoteID
                    )
                    .frame(width: graphNodeSize.width, height: graphNodeSize.height)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .scaleEffect(isDragging ? 1.08 : 1)
                    .position(point)
                    .zIndex(isDragging || note.id == selectedNoteID ? 3 : 1)
                    .allowsHitTesting(activeDraggedNodeID == nil || activeDraggedNodeID == note.id)
                    .onTapGesture {
                        openNote(note.id)
                    }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named("graphCanvas"))
                            .onChanged { value in
                                if activeDraggedNodeID == nil {
                                    activeDraggedNodeID = note.id
                                }
                                guard activeDraggedNodeID == note.id else { return }
                                activeDragPosition = clampedNodePoint(value.location, in: size)
                            }
                            .onEnded { value in
                                guard activeDraggedNodeID == note.id else {
                                    activeDragPosition = nil
                                    activeDraggedNodeID = nil
                                    return
                                }
                                let finalPoint = clampedNodePoint(value.location, in: size)
                                withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.78)) {
                                    savedNodePositions[note.id] = finalPoint
                                    activeDragPosition = nil
                                    activeDraggedNodeID = nil
                                }
                            }
                    )
                    .animation(nil, value: activeDragPosition)
                    .animation(.spring(response: 0.34, dampingFraction: 0.72), value: savedNodePositions[note.id])
                    .animation(.spring(response: 0.22, dampingFraction: 0.62), value: isDragging)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: "graphCanvas")
        .onAppear {
            syncNodePositions(defaultPositions: defaultPositions, noteIDs: visibleNoteIDs, size: size)
        }
        .onChange(of: visibleNoteIDs) { _, newIDs in
            syncNodePositions(defaultPositions: defaultPositions, noteIDs: newIDs, size: size)
        }
        .onChange(of: size) { _, newSize in
            let newDefaultPositions = nodePositions(for: visibleNotes, in: newSize)
            syncNodePositions(defaultPositions: newDefaultPositions, noteIDs: visibleNoteIDs, size: newSize)
        }
    }

    private func scrollCanvasSize(for noteCount: Int, viewport: CGSize) -> CGSize {
        guard noteCount > 12 else { return viewport }

        let multiplier = min(2.1, max(1, sqrt(CGFloat(noteCount) / 12)))
        return CGSize(
            width: max(viewport.width, viewport.width * multiplier),
            height: max(viewport.height, viewport.height * multiplier)
        )
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

    private func adjustedPositions(from defaultPositions: [String: CGPoint], in size: CGSize) -> [String: CGPoint] {
        defaultPositions.mapValues { point in point }
            .reduce(into: [:]) { output, item in
                let id = item.key
                if activeDraggedNodeID == id, let activeDragPosition {
                    output[id] = clampedNodePoint(activeDragPosition, in: size)
                } else if let savedPosition = savedNodePositions[id] {
                    output[id] = clampedNodePoint(savedPosition, in: size)
                } else {
                    output[id] = clampedNodePoint(item.value, in: size)
                }
            }
    }

    private func syncNodePositions(defaultPositions: [String: CGPoint], noteIDs: [String], size: CGSize) {
        let visibleIDs = Set(noteIDs)
        savedNodePositions = savedNodePositions.filter { visibleIDs.contains($0.key) }

        var occupiedPositions: [String: CGPoint] = savedNodePositions
            .filter { visibleIDs.contains($0.key) }
            .mapValues { clampedNodePoint($0, in: size) }

        for id in noteIDs {
            let fallback = defaultPositions[id] ?? CGPoint(x: size.width / 2, y: size.height / 2)
            if let savedPosition = savedNodePositions[id] {
                let clampedPosition = clampedNodePoint(savedPosition, in: size)
                savedNodePositions[id] = clampedPosition
                occupiedPositions[id] = clampedPosition
            } else {
                let openPosition = nonOverlappingNodePoint(
                    preferred: fallback,
                    nodeID: id,
                    occupied: Array(occupiedPositions.values),
                    size: size
                )
                savedNodePositions[id] = openPosition
                occupiedPositions[id] = openPosition
            }
        }
    }

    private func nonOverlappingNodePoint(
        preferred: CGPoint,
        nodeID: String,
        occupied: [CGPoint],
        size: CGSize
    ) -> CGPoint {
        let preferredPoint = clampedNodePoint(preferred, in: size)
        guard overlapsNode(at: preferredPoint, occupied: occupied) else { return preferredPoint }

        let candidates = proceduralStarCandidates(around: preferredPoint, nodeID: nodeID, size: size)
        if let openCandidate = candidates.first(where: { !overlapsNode(at: $0, occupied: occupied) }) {
            return openCandidate
        }

        return candidates.max { lhs, rhs in
            nodePlacementScore(lhs, preferred: preferredPoint, occupied: occupied)
                < nodePlacementScore(rhs, preferred: preferredPoint, occupied: occupied)
        } ?? preferredPoint
    }

    private func proceduralStarCandidates(around preferred: CGPoint, nodeID: String, size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 - 4)
        let seedAngle = seededAngle(for: nodeID)
        let goldenAngle = CGFloat.pi * (3 - sqrt(5))
        let spacing = max(graphNodeSize.width + 14, graphNodeSize.height + 22)
        var candidates: [CGPoint] = [preferred]

        for index in 1...180 {
            let radius = sqrt(CGFloat(index)) * spacing * 0.42
            let angle = seedAngle + CGFloat(index) * goldenAngle
            candidates.append(
                clampedNodePoint(
                    CGPoint(
                        x: preferred.x + cos(angle) * radius,
                        y: preferred.y + sin(angle) * radius
                    ),
                    in: size
                )
            )

            candidates.append(
                clampedNodePoint(
                    CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    ),
                    in: size
                )
            )
        }

        return candidates.removingNearDuplicatePoints()
    }

    private func overlapsNode(at point: CGPoint, occupied: [CGPoint]) -> Bool {
        occupied.contains { other in
            abs(point.x - other.x) < graphNodeSize.width + 12
                && abs(point.y - other.y) < graphNodeSize.height + 12
        }
    }

    private func nodePlacementScore(_ point: CGPoint, preferred: CGPoint, occupied: [CGPoint]) -> CGFloat {
        let nearestDistance = occupied
            .map { hypot(point.x - $0.x, point.y - $0.y) }
            .min() ?? 10_000
        let preferredDistance = hypot(point.x - preferred.x, point.y - preferred.y)
        return nearestDistance - preferredDistance * 0.08
    }

    private func seededAngle(for id: String) -> CGFloat {
        let seed = id.unicodeScalars.reduce(UInt32(2166136261)) { partial, scalar in
            (partial ^ scalar.value) &* 16777619
        }
        return CGFloat(seed % 360) / 180 * .pi
    }

    private func clampedNodePoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let horizontalInset: CGFloat = 42
        let verticalInset: CGFloat = 26
        return CGPoint(
            x: min(max(point.x, horizontalInset), max(horizontalInset, size.width - horizontalInset)),
            y: min(max(point.y, verticalInset), max(verticalInset, size.height - verticalInset))
        )
    }
}

private extension Array where Element == CGPoint {
    func removingNearDuplicatePoints() -> [CGPoint] {
        var output: [CGPoint] = []
        for point in self {
            guard !output.contains(where: { hypot(point.x - $0.x, point.y - $0.y) < 2 }) else {
                continue
            }
            output.append(point)
        }
        return output
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ContextUsageBar: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        HStack {
            Label("Usage", systemImage: "gauge.with.dots.needle.50percent")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(store.contextUsagePercent)%")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .frame(height: 20)
    }
}

private struct OCRUploadCounterView: View {
    @ObservedObject var store: BrainStore

    var body: some View {
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
        .padding(.horizontal, 2)
        .frame(height: 20)
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

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close Graph")
                }
                .frame(height: 30)

                NoteGraphView(
                    notes: notes,
                    links: links,
                    selectedNoteID: selectedNoteID,
                    maxVisibleNotes: nil,
                    allowsScrolling: true,
                    openNote: openNote,
                    expand: nil
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 16)
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

private struct GraphNodeView: View {
    let note: NoteSummary
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
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

private struct HomeSidebarRow: View {
    let isSelected: Bool
    let open: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)

                Text("Home")
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.14) : Color.primary.opacity(isHovered ? 0.07 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Open Home")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct SidebarGroupRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let toggle: () -> Void
    let rename: (String) -> Void
    let delete: () -> Void
    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var draftTitle = ""
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)

            if isRenaming {
                TextField("Group name", text: $draftTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .textFieldStyle(.plain)
                    .focused($isRenameFocused)
                    .onSubmit(commitRename)
                    .onExitCommand(perform: cancelRename)
            } else {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
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
            if !isRenaming {
                toggle()
            }
        }
        .onTapGesture(count: 2) {
            beginRename()
        }
        .contextMenu {
            Button {
                beginRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                delete()
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onChange(of: item.title) { _, newTitle in
            if !isRenaming {
                draftTitle = newTitle
            }
        }
        .task {
            draftTitle = item.title
        }
    }

    private func beginRename() {
        draftTitle = item.title
        isRenaming = true
        DispatchQueue.main.async {
            isRenameFocused = true
        }
    }

    private func commitRename() {
        let cleanTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            rename(cleanTitle)
        }
        isRenaming = false
    }

    private func cancelRename() {
        draftTitle = item.title
        isRenaming = false
    }

    private var rowFill: Color {
        if isSelected {
            return Color.primary.opacity(isHovered ? 0.16 : 0.12)
        }
        return Color.primary.opacity(isHovered ? 0.075 : 0.025)
    }
}

private struct SidebarItemDropDelegate: DropDelegate {
    let item: SidebarItem
    let store: BrainStore
    let draggedItemID: () -> SidebarItem.ID?
    let clearDraggedItem: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedItemID(),
              draggedID != item.id
        else { return }

        withAnimation(.easeInOut(duration: 0.16)) {
            if item.kind == .group {
                store.moveSidebarItem(id: draggedID, intoGroup: item.id)
            } else {
                store.moveSidebarItem(id: draggedID, before: item.id)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        clearDraggedItem()
        return true
    }
}

private struct SidebarEndDropDelegate: DropDelegate {
    let store: BrainStore
    let draggedItemID: () -> SidebarItem.ID?
    let clearDraggedItem: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedItemID() else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            store.moveSidebarItemToEnd(id: draggedID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        clearDraggedItem()
        return true
    }
}

private struct SidebarHomeSearchControl: View {
    @Binding var isSearchActive: Bool
    @Binding var query: String
    var isSearchFocused: FocusState<Bool>.Binding
    let isHomeSelected: Bool
    let openHome: () -> Void
    let reloadHome: () -> Void
    let activateSearch: () -> Void
    @Namespace private var liquidNamespace
    @State private var isHomeHovered = false
    @State private var isSearchHovered = false

    var body: some View {
        ZStack(alignment: .leading) {
            if isSearchActive {
                liquidSearchField
                    .transition(.identity)
            } else {
                inactiveButtons
                    .transition(.identity)
            }
        }
        .frame(height: 32)
        .animation(.easeInOut(duration: 0.55), value: isSearchActive)
    }

    private var inactiveButtons: some View {
        HStack(spacing: 8) {
            homeSegment

            Button(action: activateSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(isSearchHovered ? 0.86 : 0.66))
                    .matchedGeometryEffect(id: "searchIcon", in: liquidNamespace)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(searchLiquidSurface(isHovered: isSearchHovered))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Search Pages")
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isSearchHovered = hovering
                }
            }
        }
    }

    private var homeSegment: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(homeSegmentFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(homeSegmentStroke, lineWidth: 1)
                }
                .shadow(color: Color.accentColor.opacity(isHomeHovered ? 0.16 : 0), radius: isHomeHovered ? 8 : 0, y: isHomeHovered ? 2 : 0)

            Button(action: isHomeSelected ? reloadHome : openHome) {
                Image(systemName: isHomeSelected ? "arrow.clockwise" : "house.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(isHomeSelected || isHomeHovered ? 0.9 : 0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(isHomeSelected ? "Regenerate Home page" : "Home")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .offset(x: isSearchActive ? -18 : 0)
        .opacity(isSearchActive ? 0 : 1)
        .scaleEffect(isSearchActive ? 0.96 : 1, anchor: .leading)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHomeHovered = hovering
            }
        }
    }

    private var liquidSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .matchedGeometryEffect(id: "searchIcon", in: liquidNamespace)
                .frame(width: 16, height: 16)

            TextField("Search pages", text: $query)
                .font(.system(size: 13, weight: .medium))
                .textFieldStyle(.plain)
                .focused(isSearchFocused)

            Button {
                if query.isEmpty {
                    dismissSearch()
                } else {
                    query = ""
                    isSearchFocused.wrappedValue = true
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(query.isEmpty ? "Close search" : "Clear search")
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(searchLiquidSurface(isHovered: false))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            isSearchFocused.wrappedValue = true
        }
        .onAppear {
            isSearchFocused.wrappedValue = true
        }
    }

    private func searchLiquidSurface(isHovered: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isSearchActive ? 0.060 : (isHovered ? 0.095 : 0.050)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSearchActive || isSearchFocused.wrappedValue || isHovered ? Color.accentColor.opacity(0.38) : Color.primary.opacity(0.095), lineWidth: 1)
            }
            .shadow(color: isHovered ? Color.accentColor.opacity(0.14) : .black.opacity(isSearchActive ? 0.10 : 0.02), radius: isSearchActive || isHovered ? 10 : 3, y: isSearchActive || isHovered ? 4 : 1)
            .matchedGeometryEffect(id: "searchSurface", in: liquidNamespace)
    }

    private var homeSegmentFill: Color {
        if isHomeSelected {
            return Color.primary.opacity(isHomeHovered ? 0.18 : 0.14)
        }
        return Color.primary.opacity(isHomeHovered ? 0.095 : 0.045)
    }

    private var homeSegmentStroke: Color {
        if isHomeSelected || isHomeHovered {
            return Color.accentColor.opacity(0.34)
        }
        return Color.primary.opacity(0.095)
    }

    private func dismissSearch() {
        withAnimation(.easeInOut(duration: 0.55)) {
            query = ""
            isSearchActive = false
        }
    }
}

private struct HighlightSummarySidebarRow: View {
    let summary: HighlightSummary
    let isSelected: Bool
    let open: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(summary.sourceTitle)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary.opacity(isHovered || isSelected ? 0.96 : 0.78))
            .shadow(color: .yellow.opacity(isHovered ? 0.34 : 0), radius: isHovered ? 7 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(summary.title)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct ReadOnlyHighlightSummaryView: View {
    let summary: HighlightSummary
    let openLinkedNote: (String) -> Void
    let imageURL: (String) -> URL?

    var body: some View {
        ScrollView {
            MarkdownPreview(
                content: summary.markdown,
                searchHighlight: nil,
                openLinkedNote: openLinkedNote,
                imageURL: imageURL
            )
            .padding(.vertical, 8)
            .textSelection(.enabled)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ReadOnlyHomePageView: View {
    let markdown: String
    let isGenerating: Bool
    let openLinkedNote: (String) -> Void
    let imageURL: (String) -> URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Home")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                if isGenerating {
                    HomeGenerationInlineBlocks()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    MarkdownPreview(
                        content: markdownWithoutHomeHeading,
                        searchHighlight: nil,
                        openLinkedNote: openLinkedNote,
                        imageURL: imageURL
                    )
                    .textSelection(.enabled)
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.24), value: isGenerating)
    }

    private var markdownWithoutHomeHeading: String {
        var lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "# Home" {
            lines.removeFirst()
            while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                lines.removeFirst()
            }
        }
        return lines.joined(separator: "\n")
    }
}

private struct HomeGenerationInlineBlocks: View {
    @State private var visibleLineCount = 0

    private let lineWidths: [CGFloat] = [
        0.30, 0.78, 0.66, 0.88, 0.52,
        0.24, 0.70, 0.83, 0.58, 0.76,
        0.45, 0.68
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(lineWidths.indices, id: \.self) { index in
                HomeGenerationLineBlock(
                    widthFraction: lineWidths[index],
                    height: index == 0 || index == 5 ? 26 : 14,
                    isHeading: index == 0 || index == 5,
                    isVisible: index <= visibleLineCount
                )
                .padding(.top, index == 5 ? 12 : 0)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            visibleLineCount = 0
            while !Task.isCancelled {
                for index in lineWidths.indices {
                    visibleLineCount = index
                    try? await Task.sleep(for: .milliseconds(170))
                }
                try? await Task.sleep(for: .milliseconds(420))
            }
        }
    }
}

private struct HomeGenerationLineBlock: View {
    let widthFraction: CGFloat
    let height: CGFloat
    let isHeading: Bool
    let isVisible: Bool
    @State private var shimmerOffset: CGFloat = -1.2

    var body: some View {
        GeometryReader { proxy in
            let width = max(80, proxy.size.width * widthFraction)
            RoundedRectangle(cornerRadius: isHeading ? 5 : 4, style: .continuous)
                .fill(Color(nsColor: .controlAccentColor))
                .brightness(isHeading ? 0 : -0.08)
                .frame(width: width, height: height)
                .overlay(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.40),
                            Color.white.opacity(0.22),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.48, height: height)
                    .offset(x: shimmerOffset * width)
                    .blur(radius: 1)
                    .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: isHeading ? 5 : 4, style: .continuous))
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 5)
                .animation(.easeInOut(duration: 0.22), value: isVisible)
                .task {
                    shimmerOffset = -0.55
                    withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: false)) {
                        shimmerOffset = 1.55
                    }
                }
        }
        .frame(height: height)
    }
}

private struct HomeFooter: View {
    let latestSummary: HighlightSummary?

    private var compiledAtText: String {
        guard let latestSummary else { return "No Home page generated" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Compiled \(formatter.string(from: latestSummary.compiledAt))"
    }

    private var durationText: String? {
        guard let latestSummary else { return nil }
        if latestSummary.compileDuration < 1 {
            return "\(Int((latestSummary.compileDuration * 1000).rounded())) ms"
        }
        return String(format: "%.1f sec", latestSummary.compileDuration)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(compiledAtText)
            if let durationText, let latestSummary {
                Text("·")
                Text(durationText)
                Text("·")
                Text(latestSummary.modelTitle)
            }
        }
            .lineLimit(1)
    }
}

private struct HighlightSummaryFooter: View {
    let summary: HighlightSummary

    private var compiledAtText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: summary.compiledAt)
    }

    private var durationText: String {
        if summary.compileDuration < 1 {
            return "\(Int((summary.compileDuration * 1000).rounded())) ms"
        }
        return String(format: "%.1f sec", summary.compileDuration)
    }

    var body: some View {
        HStack(spacing: 9) {
            Label(compiledAtText, systemImage: "clock")
            Label(durationText, systemImage: "timer")
            Label(summary.modelTitle, systemImage: "cpu")
        }
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .truncationMode(.tail)
    }
}

private struct MarkdownEditingSurface: View {
    @Binding var content: String
    @Binding var isEditing: Bool
    let isReadOnly: Bool
    let searchHighlight: SearchHighlight?
    let noteTitles: [String]
    let openLinkedNote: (String) -> Void
    let clearSearchHighlight: () -> Void
    let imageURL: (String) -> URL?
    let insertImageFile: (URL) -> Void
    let insertImageData: (Data, String?) -> Void
    @Binding var typingStatus: MarkdownTypingStatus
    @State private var suggestionAnchor: CGPoint?
    @State private var editorSelectionRange = NSRange(location: 0, length: 0)

    private var linkSuggestions: [String] {
        guard let context = activeWikiLinkContext else { return [] }
        let uniqueTitles = Array(NSOrderedSet(array: noteTitles)).compactMap { $0 as? String }
        let normalizedQuery = normalizedLinkSuggestionText(context.query)

        guard !normalizedQuery.isEmpty else {
            return Array(uniqueTitles.prefix(2))
        }

        let prefixMatches = uniqueTitles.filter {
            normalizedLinkSuggestionText($0).hasPrefix(normalizedQuery)
        }

        if prefixMatches.count >= 2 {
            return Array(prefixMatches.prefix(2))
        }

        let containsMatches = uniqueTitles.filter {
            !prefixMatches.contains($0)
                && normalizedLinkSuggestionText($0).contains(normalizedQuery)
        }

        return Array((prefixMatches + containsMatches).prefix(2))
    }

    var body: some View {
        Group {
            if isEditing && !isReadOnly {
                editor
            } else {
                renderedPreview
            }
        }
        .onExitCommand {
            isEditing = false
        }
        .onChange(of: isReadOnly) { _, readOnly in
            if readOnly {
                isEditing = false
            }
        }
    }

    private var editor: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                InlineMarkdownEditor(
                    text: $content,
                    selectionRange: $editorSelectionRange,
                    typingStatus: $typingStatus,
                    linkTabCompletionTitle: linkSuggestions.first,
                    suggestionRange: activeSuggestionNSRange,
                    suggestionAnchor: $suggestionAnchor,
                    insertImageData: insertImageData
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let context = activeWikiLinkContext,
                   !linkSuggestions.isEmpty,
                   let suggestionAnchor {
                    let menuHeight = linkSuggestionMenuHeight
                    LinkSuggestionMenu(
                        query: context.query,
                        suggestions: linkSuggestions,
                        select: { completeWikiLink(with: $0, context: context) }
                    )
                    .position(
                        x: min(max(116, suggestionAnchor.x + 110), max(116, proxy.size.width - 116)),
                        y: max(menuHeight / 2 + 8, suggestionAnchor.y - menuHeight / 2 - 8)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(2)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
        .animation(.easeInOut(duration: 0.14), value: linkSuggestions)
        .onPasteCommand(of: [UTType.image]) { providers in
            insertImages(from: providers)
        }
        .onDrop(of: Self.supportedImageDropTypes, isTargeted: nil) { providers in
            insertDroppedImages(from: providers)
            return true
        }
    }

    private var activeSuggestionNSRange: NSRange? {
        guard let context = activeWikiLinkContext else { return nil }
        return NSRange(context.range, in: content)
    }

    private var linkSuggestionMenuHeight: CGFloat {
        CGFloat(linkSuggestions.count) * 30
            + CGFloat(max(0, linkSuggestions.count - 1)) * 4
            + 38
    }

    private var renderedPreview: some View {
        ScrollViewReader { reader in
            ScrollView {
                MarkdownPreview(
                    content: content,
                    searchHighlight: searchHighlight,
                    openLinkedNote: openLinkedNote,
                    imageURL: imageURL
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
            } else if !isReadOnly {
                isEditing = true
            }
        }
    }

    private var activeWikiLinkContext: WikiLinkSuggestionContext? {
        guard !content.isEmpty else { return nil }

        let utf16Length = (content as NSString).length
        let caretOffset = min(max(0, editorSelectionRange.location + editorSelectionRange.length), utf16Length)
        let caretIndex = String.Index(utf16Offset: caretOffset, in: content)
        let lineStart = content[..<caretIndex].lastIndex(of: "\n").map { content.index(after: $0) } ?? content.startIndex
        let lineEnd = content[caretIndex...].firstIndex(of: "\n") ?? content.endIndex

        guard let openRange = content.range(of: "[[", options: .backwards, range: lineStart..<caretIndex) else {
            return nil
        }

        let queryRange = openRange.upperBound..<caretIndex
        let queryCandidate = content[queryRange]

        guard !queryCandidate.contains("["),
              !queryCandidate.contains("]"),
              queryCandidate.count <= 80
        else { return nil }

        let closingRange = content.range(of: "]]", range: caretIndex..<lineEnd)
        let replacementEnd = closingRange?.upperBound ?? caretIndex
        let queryEnd = queryCandidate.firstIndex(of: "|") ?? queryCandidate.endIndex
        let query = String(queryCandidate[..<queryEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        return WikiLinkSuggestionContext(
            range: openRange.lowerBound..<replacementEnd,
            query: query
        )
    }

    private func completeWikiLink(with title: String, context: WikiLinkSuggestionContext) {
        guard context.range.lowerBound >= content.startIndex,
              context.range.upperBound <= content.endIndex
        else { return }

        let replacementLocation = NSRange(context.range, in: content).location
        content.replaceSubrange(context.range, with: "[[\(title)]]")
        editorSelectionRange = NSRange(location: replacementLocation + (title as NSString).length + 4, length: 0)
        suggestionAnchor = nil
    }

    private func insertImages(from providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                loadImageData(from: provider, typeIdentifier: UTType.png.identifier, suggestedName: provider.suggestedName)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) {
                loadImageData(from: provider, typeIdentifier: UTType.tiff.identifier, suggestedName: provider.suggestedName)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                loadImageData(from: provider, typeIdentifier: UTType.image.identifier, suggestedName: provider.suggestedName)
            }
        }
    }

    private func insertDroppedImages(from providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let nsURL = item as? NSURL {
                        url = nsURL as URL
                    } else {
                        url = item as? URL
                    }

                    guard let url else { return }
                    Task { @MainActor in
                        insertImageFile(url)
                    }
                }
            } else {
                insertImages(from: [provider])
            }
        }
    }

    private func loadImageData(from provider: NSItemProvider, typeIdentifier: String, suggestedName: String?) {
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
            guard let data else { return }
            Task { @MainActor in
                insertImageData(data, suggestedName)
            }
        }
    }

    private func normalizedLinkSuggestionText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let supportedImageDropTypes = [UTType.fileURL.identifier, UTType.image.identifier]
}

private struct InlineMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange
    @Binding var typingStatus: MarkdownTypingStatus
    let linkTabCompletionTitle: String?
    let suggestionRange: NSRange?
    @Binding var suggestionAnchor: CGPoint?
    let insertImageData: (Data, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            selectionRange: $selectionRange,
            typingStatus: $typingStatus,
            suggestionAnchor: $suggestionAnchor,
            insertImageData: insertImageData
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = MarkdownNSTextView()
        textView.commandHandler = context.coordinator
        textView.delegate = context.coordinator
        textView.string = text
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 26, height: 14)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        textView.setSelectedRange(Self.clamped(selectionRange, in: text))
        context.coordinator.applyMarkdownStyling()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.selectionRange = $selectionRange
        context.coordinator.typingStatus = $typingStatus
        context.coordinator.suggestionAnchor = $suggestionAnchor
        context.coordinator.insertImageData = insertImageData
        context.coordinator.linkTabCompletionTitle = linkTabCompletionTitle
        context.coordinator.suggestionRange = suggestionRange

        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.textView = textView

        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(Self.clamped(selectionRange, in: text))
        }

        context.coordinator.applyMarkdownStyling()
        context.coordinator.updateSuggestionAnchor()

        if textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private static func clamped(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(max(0, range.location), length)
        return NSRange(
            location: location,
            length: min(max(0, range.length), max(0, length - location))
        )
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectionRange: Binding<NSRange>
        var typingStatus: Binding<MarkdownTypingStatus>
        var suggestionAnchor: Binding<CGPoint?>
        var insertImageData: (Data, String?) -> Void
        var linkTabCompletionTitle: String?
        var suggestionRange: NSRange?
        weak var textView: NSTextView?
        private var isApplyingMarkdownStyling = false
        private var activeInlineCommands: Set<MarkdownInlineCommand> = []

        init(
            text: Binding<String>,
            selectionRange: Binding<NSRange>,
            typingStatus: Binding<MarkdownTypingStatus>,
            suggestionAnchor: Binding<CGPoint?>,
            insertImageData: @escaping (Data, String?) -> Void
        ) {
            self.text = text
            self.selectionRange = selectionRange
            self.typingStatus = typingStatus
            self.suggestionAnchor = suggestionAnchor
            self.insertImageData = insertImageData
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            publishSelection(from: textView)
            applyMarkdownStyling()
            updateSuggestionAnchor()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                publishSelection(from: textView)
            }
            updateSuggestionAnchor()
        }

        func pasteImageFromClipboard() -> Bool {
            guard let image = PasteboardImageReader.imagePayload(from: .general) else { return false }
            insertImageData(image.data, image.fileName)
            return true
        }

        private func publishSelection(from textView: NSTextView) {
            let range = textView.selectedRange()
            let status = typingStatus(in: textView, selectedRange: range)
            DispatchQueue.main.async {
                self.selectionRange.wrappedValue = range
                self.typingStatus.wrappedValue = status
            }
        }

        func toggleInlineCommand(_ command: MarkdownInlineCommand, in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0 else {
                if activeInlineCommands.contains(command) {
                    activeInlineCommands.remove(command)
                } else {
                    activeInlineCommands.insert(command)
                }
                publishSelection(from: textView)
                return
            }

            let rawText = textView.string as NSString
            guard selectedRange.upperBound <= rawText.length else { return }

            let selectedText = rawText.substring(with: selectedRange)
            guard let coreRange = selectedText.rangeOfNonWhitespace(in: selectedRange) else { return }

            if unwrapInlineCommandInsideSelection(command, in: coreRange, textView: textView) {
                return
            }

            if unwrapInlineCommand(command, in: coreRange, textView: textView) {
                return
            }

            let coreText = rawText.substring(with: coreRange)
            let replacement = "\(command.openMarker)\(coreText)\(command.closeMarker)"
            textView.replaceCharacters(in: coreRange, with: replacement)

            let newSelection = NSRange(
                location: coreRange.location + (command.openMarker as NSString).length,
                length: (coreText as NSString).length
            )
            textView.setSelectedRange(newSelection)
            text.wrappedValue = textView.string
            selectionRange.wrappedValue = newSelection
            typingStatus.wrappedValue = typingStatus(in: textView, selectedRange: newSelection)
            applyMarkdownStyling()
            updateSuggestionAnchor()
        }

        func completeActiveLinkFromTab(in textView: NSTextView) -> Bool {
            guard let suggestionRange else { return false }

            let rawText = textView.string as NSString
            guard suggestionRange.location >= 0,
                  suggestionRange.upperBound <= rawText.length
            else { return false }

            let replacement: String
            if let linkTabCompletionTitle, !linkTabCompletionTitle.isEmpty {
                replacement = "[[\(linkTabCompletionTitle)]]"
            } else {
                let current = rawText.substring(with: suggestionRange)
                replacement = current.hasSuffix("]]") ? current : "\(current)]]"
            }

            textView.replaceCharacters(in: suggestionRange, with: replacement)
            let newSelection = NSRange(location: suggestionRange.location + (replacement as NSString).length, length: 0)
            textView.setSelectedRange(newSelection)
            text.wrappedValue = textView.string
            selectionRange.wrappedValue = newSelection
            suggestionAnchor.wrappedValue = nil
            typingStatus.wrappedValue = typingStatus(in: textView, selectedRange: newSelection)
            applyMarkdownStyling()
            updateSuggestionAnchor()
            return true
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard !activeInlineCommands.isEmpty,
                  affectedCharRange.length == 0,
                  let replacementString,
                  !replacementString.isEmpty
            else { return true }

            if replacementString.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                guard !activeInlineCommands.contains(.highlight) else {
                    return true
                }

                let closeLength = activeCommandCloseMarkersLength(at: affectedCharRange.location, in: textView)
                activeInlineCommands.removeAll()

                if closeLength > 0 {
                    textView.replaceCharacters(
                        in: NSRange(location: affectedCharRange.location + closeLength, length: 0),
                        with: replacementString
                    )
                    let newSelection = NSRange(location: affectedCharRange.location + closeLength + (replacementString as NSString).length, length: 0)
                    textView.setSelectedRange(newSelection)
                    text.wrappedValue = textView.string
                    selectionRange.wrappedValue = newSelection
                    typingStatus.wrappedValue = typingStatus(in: textView, selectedRange: newSelection)
                    applyMarkdownStyling()
                    updateSuggestionAnchor()
                    return false
                }

                return true
            }

            if isCaretInsideActiveFormattedRun(affectedCharRange.location, in: textView) {
                return true
            }

            let orderedCommands = activeCommandsInRenderOrder
            let openMarkers = orderedCommands.map(\.openMarker).joined()
            let closeMarkers = orderedCommands.reversed().map(\.closeMarker).joined()
            let replacement = "\(openMarkers)\(replacementString)\(closeMarkers)"
            textView.replaceCharacters(in: affectedCharRange, with: replacement)

            let newSelection = NSRange(
                location: affectedCharRange.location + (openMarkers as NSString).length + (replacementString as NSString).length,
                length: 0
            )
            textView.setSelectedRange(newSelection)
            text.wrappedValue = textView.string
            selectionRange.wrappedValue = newSelection
            typingStatus.wrappedValue = typingStatus(in: textView, selectedRange: newSelection)
            applyMarkdownStyling()
            updateSuggestionAnchor()
            return false
        }

        private var activeCommandsInRenderOrder: [MarkdownInlineCommand] {
            [.bold, .italic, .underline, .highlight].filter { activeInlineCommands.contains($0) }
        }

        private func isCaretInsideActiveFormattedRun(_ location: Int, in textView: NSTextView) -> Bool {
            if activeCommandCloseMarkersLength(at: location, in: textView) > 0 {
                return true
            }

            let rawText = textView.string as NSString
            let activeRange = Self.activeWordRange(around: NSRange(location: location, length: 0), in: rawText)
            return activeCommandsInRenderOrder.allSatisfy { command in
                Self.isRange(activeRange, wrappedBy: command.openMarker, close: command.closeMarker, in: rawText)
            }
        }

        private func activeCommandCloseMarkersLength(at location: Int, in textView: NSTextView) -> Int {
            let rawText = textView.string as NSString
            guard location < rawText.length else { return 0 }

            let closeMarkers = activeCommandsInRenderOrder.reversed().map(\.closeMarker).joined()
            let closeLength = (closeMarkers as NSString).length
            guard closeLength > 0,
                  location + closeLength <= rawText.length
            else { return 0 }

            return rawText.substring(with: NSRange(location: location, length: closeLength)) == closeMarkers ? closeLength : 0
        }

        private func unwrapInlineCommand(_ command: MarkdownInlineCommand, in coreRange: NSRange, textView: NSTextView) -> Bool {
            let rawText = textView.string as NSString
            let openLength = (command.openMarker as NSString).length
            let closeLength = (command.closeMarker as NSString).length
            let openRange = NSRange(location: coreRange.location - openLength, length: openLength)
            let closeRange = NSRange(location: coreRange.upperBound, length: closeLength)

            guard openRange.location >= 0,
                  closeRange.upperBound <= rawText.length,
                  rawText.substring(with: openRange) == command.openMarker,
                  rawText.substring(with: closeRange) == command.closeMarker
            else { return false }

            textView.replaceCharacters(in: closeRange, with: "")
            textView.replaceCharacters(in: openRange, with: "")

            let newSelection = NSRange(location: openRange.location, length: coreRange.length)
            textView.setSelectedRange(newSelection)
            text.wrappedValue = textView.string
            selectionRange.wrappedValue = newSelection
            typingStatus.wrappedValue = typingStatus(in: textView, selectedRange: newSelection)
            applyMarkdownStyling()
            updateSuggestionAnchor()
            return true
        }

        private func unwrapInlineCommandInsideSelection(_ command: MarkdownInlineCommand, in coreRange: NSRange, textView: NSTextView) -> Bool {
            let rawText = textView.string as NSString
            let openLength = (command.openMarker as NSString).length
            let closeLength = (command.closeMarker as NSString).length
            guard coreRange.length >= openLength + closeLength else { return false }

            let openRange = NSRange(location: coreRange.location, length: openLength)
            let closeRange = NSRange(location: coreRange.upperBound - closeLength, length: closeLength)
            guard rawText.substring(with: openRange) == command.openMarker,
                  rawText.substring(with: closeRange) == command.closeMarker
            else { return false }

            textView.replaceCharacters(in: closeRange, with: "")
            textView.replaceCharacters(in: openRange, with: "")

            let newSelection = NSRange(
                location: coreRange.location,
                length: coreRange.length - openLength - closeLength
            )
            textView.setSelectedRange(newSelection)
            text.wrappedValue = textView.string
            selectionRange.wrappedValue = newSelection
            typingStatus.wrappedValue = typingStatus(in: textView, selectedRange: newSelection)
            applyMarkdownStyling()
            updateSuggestionAnchor()
            return true
        }

        func updateKeyboardFlags(_ flags: NSEvent.ModifierFlags, in textView: NSTextView) {
            var status = typingStatus(in: textView, selectedRange: textView.selectedRange())
            status.isCapsLockOn = flags.contains(.capsLock)
            DispatchQueue.main.async {
                self.typingStatus.wrappedValue = status
            }
        }

        private func typingStatus(in textView: NSTextView, selectedRange: NSRange) -> MarkdownTypingStatus {
            let rawText = textView.string as NSString
            let activeRange = Self.activeWordRange(around: selectedRange, in: rawText)
            return MarkdownTypingStatus(
                isCapsLockOn: NSEvent.modifierFlags.contains(.capsLock),
                isBold: activeInlineCommands.contains(.bold) || Self.isRange(activeRange, wrappedBy: "**", close: "**", in: rawText),
                isItalic: activeInlineCommands.contains(.italic) || Self.isItalicRange(activeRange, in: rawText),
                isUnderline: activeInlineCommands.contains(.underline) || Self.isRange(activeRange, wrappedBy: "<u>", close: "</u>", in: rawText),
                isHighlight: activeInlineCommands.contains(.highlight) || Self.isRange(activeRange, wrappedBy: "==", close: "==", in: rawText)
            )
        }

        private static func activeWordRange(around selectedRange: NSRange, in rawText: NSString) -> NSRange {
            guard rawText.length > 0 else { return NSRange(location: 0, length: 0) }
            if selectedRange.length > 0 {
                return selectedRange
            }

            var start = min(selectedRange.location, rawText.length)
            var end = start
            let whitespace = CharacterSet.whitespacesAndNewlines

            while start > 0 {
                let range = NSRange(location: start - 1, length: 1)
                guard let scalar = UnicodeScalar(rawText.character(at: start - 1)),
                      !whitespace.contains(scalar)
                else { break }
                if rawText.substring(with: range) == "*" || rawText.substring(with: range) == ">" {
                    break
                }
                start -= 1
            }

            while end < rawText.length {
                guard let scalar = UnicodeScalar(rawText.character(at: end)),
                      !whitespace.contains(scalar)
                else { break }
                if rawText.substring(with: NSRange(location: end, length: 1)) == "*" || rawText.substring(with: NSRange(location: end, length: 1)) == "<" {
                    break
                }
                end += 1
            }

            return NSRange(location: start, length: max(0, end - start))
        }

        private static func isRange(_ range: NSRange, wrappedBy open: String, close: String, in rawText: NSString) -> Bool {
            guard range.length > 0 else { return false }
            let openLength = (open as NSString).length
            let closeLength = (close as NSString).length
            let openLocation = range.location - openLength
            let closeLocation = range.upperBound
            guard openLocation >= 0,
                  closeLocation + closeLength <= rawText.length
            else { return false }

            return rawText.substring(with: NSRange(location: openLocation, length: openLength)) == open
                && rawText.substring(with: NSRange(location: closeLocation, length: closeLength)) == close
        }

        private static func isItalicRange(_ range: NSRange, in rawText: NSString) -> Bool {
            guard isRange(range, wrappedBy: "*", close: "*", in: rawText) else { return false }
            let beforeBefore = range.location >= 2 ? rawText.substring(with: NSRange(location: range.location - 2, length: 2)) : ""
            let afterAfter = range.upperBound + 2 <= rawText.length ? rawText.substring(with: NSRange(location: range.upperBound, length: 2)) : ""
            return beforeBefore != "**" && afterAfter != "**"
        }

        func applyMarkdownStyling() {
            guard !isApplyingMarkdownStyling, let textView else { return }
            guard let textStorage = textView.textStorage else { return }

            isApplyingMarkdownStyling = true
            defer { isApplyingMarkdownStyling = false }

            let rawText = textView.string as NSString
            let fullRange = NSRange(location: 0, length: rawText.length)
            let selectedRanges = textView.selectedRanges
            let baseAttributes = Self.baseAttributes()

            textView.typingAttributes = baseAttributes

            guard fullRange.length > 0 else {
                return
            }

            textStorage.beginEditing()
            textStorage.setAttributes(baseAttributes, range: fullRange)

            var isInCodeBlock = false
            rawText.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, enclosingRange, _ in
                let rawLine = rawText.substring(with: lineRange)
                let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)

                textStorage.addAttributes([
                    .paragraphStyle: Self.paragraphStyle(for: trimmedLine, isCode: isInCodeBlock)
                ], range: enclosingRange)

                if trimmedLine.hasPrefix("```") {
                    Self.styleCodeLine(in: textStorage, range: lineRange)
                    isInCodeBlock.toggle()
                    return
                }

                if isInCodeBlock {
                    Self.styleCodeLine(in: textStorage, range: lineRange)
                    return
                }

                if Self.applyHeadingStyle(to: rawLine, in: lineRange, textStorage: textStorage) {
                    Self.applyInlineStyles(in: lineRange, rawText: rawText, textStorage: textStorage, baseFontSize: 20)
                    return
                }

                if trimmedLine.hasPrefix(">") {
                    textStorage.addAttributes([
                        .font: Self.italicFont(size: 15),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ], range: lineRange)
                    Self.tintLeadingMarker(">", in: rawLine, lineRange: lineRange, textStorage: textStorage)
                } else if Self.isListLine(trimmedLine) {
                    textStorage.addAttributes([
                        .font: NSFont.systemFont(ofSize: 15, weight: .regular)
                    ], range: lineRange)
                    Self.tintListMarker(in: rawLine, lineRange: lineRange, textStorage: textStorage)
                } else if trimmedLine == "---" || trimmedLine == "***" {
                    textStorage.addAttributes([
                        .foregroundColor: NSColor.tertiaryLabelColor,
                        .font: NSFont.systemFont(ofSize: 15, weight: .semibold)
                    ], range: lineRange)
                }

                Self.applyInlineStyles(in: lineRange, rawText: rawText, textStorage: textStorage, baseFontSize: 15)
            }

            textStorage.endEditing()
            textView.selectedRanges = selectedRanges.compactMap { value in
                let range = value.rangeValue
                guard range.location <= rawText.length else { return nil }
                return NSValue(range: NSRange(
                    location: range.location,
                    length: min(range.length, max(0, rawText.length - range.location))
                ))
            }
        }

        func updateSuggestionAnchor() {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let suggestionRange,
                  suggestionRange.location <= textView.string.count
            else {
                if suggestionAnchor.wrappedValue != nil {
                    DispatchQueue.main.async {
                        self.suggestionAnchor.wrappedValue = nil
                    }
                }
                return
            }

            let textLength = (textView.string as NSString).length
            let location = min(suggestionRange.upperBound, textLength)
            let characterRange = NSRange(location: max(0, location - 1), length: min(1, textLength))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let visibleOrigin = textView.enclosingScrollView?.contentView.bounds.origin ?? .zero
            let inset = textView.textContainerInset
            let anchor = CGPoint(
                x: rect.maxX + inset.width - visibleOrigin.x,
                y: rect.minY + inset.height - visibleOrigin.y
            )

            DispatchQueue.main.async {
                self.suggestionAnchor.wrappedValue = anchor
            }
        }

        private static func baseAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(for: "", isCode: false)
            ]
        }

        private static func paragraphStyle(for line: String, isCode: Bool) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = isCode ? 2 : 5
            style.paragraphSpacing = line.isEmpty ? 5 : 7
            style.tabStops = []
            style.defaultTabInterval = 24
            return style
        }

        private static func applyHeadingStyle(to rawLine: String, in lineRange: NSRange, textStorage: NSTextStorage) -> Bool {
            let leadingWhitespace = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            let candidate = rawLine.dropFirst(leadingWhitespace)
            let headingLevel = candidate.prefix { $0 == "#" }.count

            guard (1...6).contains(headingLevel),
                  candidate.dropFirst(headingLevel).first?.isWhitespace == true
            else { return false }

            let fontSize: CGFloat
            switch headingLevel {
            case 1: fontSize = 30
            case 2: fontSize = 24
            case 3: fontSize = 20
            case 4: fontSize = 17
            default: fontSize = 15.5
            }

            textStorage.addAttributes([
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ], range: lineRange)

            let markerLength = min(rawLine.count - leadingWhitespace, headingLevel + 1)
            let markerRange = NSRange(location: lineRange.location + leadingWhitespace, length: markerLength)
            hideSyntax(in: textStorage, range: markerRange)

            return true
        }

        private static func styleCodeLine(in textStorage: NSTextStorage, range: NSRange) {
            textStorage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.42)
            ], range: range)
        }

        private static func applyInlineStyles(
            in lineRange: NSRange,
            rawText: NSString,
            textStorage: NSTextStorage,
            baseFontSize: CGFloat
        ) {
            applyRegex("`([^`]+)`", in: lineRange, rawText: rawText, textStorage: textStorage) { matchRange in
                textStorage.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: max(12.5, baseFontSize - 1), weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .backgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.55)
                ], range: matchRange)
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.location, length: 1))
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.upperBound - 1, length: 1))
            }

            applyRegex("\\*\\*([^*]+)\\*\\*", in: lineRange, rawText: rawText, textStorage: textStorage) { matchRange in
                textStorage.addAttributes([
                    .font: NSFont.systemFont(ofSize: baseFontSize, weight: .bold)
                ], range: matchRange)
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.location, length: 2))
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.upperBound - 2, length: 2))
            }

            applyRegex("(?<!\\*)\\*([^*]+)\\*(?!\\*)", in: lineRange, rawText: rawText, textStorage: textStorage) { matchRange in
                textStorage.addAttributes([
                    .font: italicFont(size: baseFontSize)
                ], range: matchRange)
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.location, length: 1))
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.upperBound - 1, length: 1))
            }

            applyRegex("<u>(.*?)</u>", in: lineRange, rawText: rawText, textStorage: textStorage) { matchRange in
                textStorage.addAttributes([
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: matchRange)
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.location, length: 3))
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.upperBound - 4, length: 4))
            }

            applyRegex("==([^=]+)==", in: lineRange, rawText: rawText, textStorage: textStorage) { matchRange in
                textStorage.addAttributes([
                    .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.32),
                    .foregroundColor: NSColor.labelColor
                ], range: matchRange)
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.location, length: 2))
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.upperBound - 2, length: 2))
            }

            applyRegex("\\[\\[([^\\]]+)\\]\\]", in: lineRange, rawText: rawText, textStorage: textStorage) { matchRange in
                textStorage.addAttributes([
                    .foregroundColor: NSColor.controlAccentColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: matchRange)
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.location, length: 2))
                hideSyntax(in: textStorage, range: NSRange(location: matchRange.upperBound - 2, length: 2))
            }

            applyRegex("!\\[[^\\]]*\\]\\([^)]+\\)", in: lineRange, rawText: rawText, textStorage: textStorage) { matchRange in
                textStorage.addAttributes([
                    .foregroundColor: NSColor.systemTeal,
                    .font: NSFont.systemFont(ofSize: baseFontSize, weight: .medium)
                ], range: matchRange)
            }
        }

        private static func applyRegex(
            _ pattern: String,
            in lineRange: NSRange,
            rawText: NSString,
            textStorage: NSTextStorage,
            apply: (NSRange) -> Void
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.enumerateMatches(in: rawText as String, range: lineRange) { match, _, _ in
                guard let match else { return }
                apply(match.range)
            }
        }

        private static func isListLine(_ line: String) -> Bool {
            guard !line.isEmpty else { return false }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                return true
            }

            let parts = line.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            return parts.count == 2
                && parts[0].allSatisfy(\.isNumber)
                && parts[1].hasPrefix(" ")
        }

        private static func tintLeadingMarker(
            _ marker: Character,
            in rawLine: String,
            lineRange: NSRange,
            textStorage: NSTextStorage
        ) {
            guard let markerIndex = rawLine.firstIndex(of: marker) else { return }
            let offset = rawLine.distance(from: rawLine.startIndex, to: markerIndex)
            textStorage.addAttributes([
                .foregroundColor: NSColor.tertiaryLabelColor
            ], range: NSRange(location: lineRange.location + offset, length: 1))
        }

        private static func tintListMarker(in rawLine: String, lineRange: NSRange, textStorage: NSTextStorage) {
            let trimmedStart = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            let line = rawLine.dropFirst(trimmedStart)
            let markerLength: Int

            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                markerLength = 1
            } else if let dotIndex = line.firstIndex(of: "."),
                      line[..<dotIndex].allSatisfy(\.isNumber) {
                markerLength = line.distance(from: line.startIndex, to: dotIndex) + 1
            } else {
                return
            }

            textStorage.addAttributes([
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold)
            ], range: NSRange(location: lineRange.location + trimmedStart, length: markerLength))
        }

        private static func hideSyntax(in textStorage: NSTextStorage, range: NSRange) {
            guard range.location >= 0,
                  range.length > 0,
                  range.upperBound <= textStorage.length
            else { return }

            textStorage.addAttributes([
                .font: NSFont.systemFont(ofSize: 1),
                .foregroundColor: NSColor.clear
            ], range: range)
        }

        private static func italicFont(size: CGFloat) -> NSFont {
            let font = NSFont.systemFont(ofSize: size, weight: .regular)
            return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
    }
}

private enum MarkdownInlineCommand: Hashable {
    case bold
    case italic
    case underline
    case highlight

    var openMarker: String {
        switch self {
        case .bold:
            return "**"
        case .italic:
            return "*"
        case .underline:
            return "<u>"
        case .highlight:
            return "=="
        }
    }

    var closeMarker: String {
        switch self {
        case .bold:
            return "**"
        case .italic:
            return "*"
        case .underline:
            return "</u>"
        case .highlight:
            return "=="
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

    func rangeOfNonWhitespace(in selectedRange: NSRange) -> NSRange? {
        let nsString = self as NSString
        var location = 0
        var upperBound = nsString.length
        let whitespace = CharacterSet.whitespacesAndNewlines

        while location < upperBound,
              let scalar = UnicodeScalar(nsString.character(at: location)),
              whitespace.contains(scalar) {
            location += 1
        }

        while upperBound > location,
              let scalar = UnicodeScalar(nsString.character(at: upperBound - 1)),
              whitespace.contains(scalar) {
            upperBound -= 1
        }

        guard upperBound > location else { return nil }
        return NSRange(location: selectedRange.location + location, length: upperBound - location)
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else { return nil }

        return bitmap.representation(using: .png, properties: [:])
    }
}

private struct PasteboardImagePayload {
    let data: Data
    let fileName: String
}

private enum PasteboardImageReader {
    static func hasImage(on pasteboard: NSPasteboard = .general) -> Bool {
        imagePayload(from: pasteboard) != nil
    }

    static func imagePayload(from pasteboard: NSPasteboard) -> PasteboardImagePayload? {
        for candidate in directImageTypes {
            if let data = pasteboard.data(forType: candidate.type) {
                if candidate.needsPNGConversion,
                   let image = NSImage(data: data),
                   let pngData = image.pngData() {
                    return PasteboardImagePayload(data: pngData, fileName: "clipboard-image.png")
                }

                return PasteboardImagePayload(data: data, fileName: "clipboard-image.\(candidate.fileExtension)")
            }
        }

        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL],
           let imageURL = urls.first(where: isSupportedImageURL),
           let data = try? Data(contentsOf: imageURL) {
            return PasteboardImagePayload(data: data, fileName: imageURL.lastPathComponent)
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
           let image = images.first,
           let pngData = image.pngData() {
            return PasteboardImagePayload(data: pngData, fileName: "clipboard-image.png")
        }

        return nil
    }

    nonisolated private static func isSupportedImageURL(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "webp"].contains(url.pathExtension.lowercased())
    }

    private static let directImageTypes: [(type: NSPasteboard.PasteboardType, fileExtension: String, needsPNGConversion: Bool)] = [
        (.png, "png", false),
        (NSPasteboard.PasteboardType(UTType.jpeg.identifier), "jpg", false),
        (.tiff, "png", true),
        (NSPasteboard.PasteboardType(UTType.gif.identifier), "gif", false),
        (NSPasteboard.PasteboardType("public.heic"), "heic", false),
        (NSPasteboard.PasteboardType("org.webmproject.webp"), "webp", false)
    ]
}

private final class MarkdownNSTextView: NSTextView {
    weak var commandHandler: InlineMarkdownEditor.Coordinator?

    override func paste(_ sender: Any?) {
        if commandHandler?.pasteImageFromClipboard() == true {
            return
        }

        super.paste(sender)
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)),
           PasteboardImageReader.hasImage() {
            return true
        }

        return super.validateUserInterfaceItem(item)
    }

    @objc(toggleBoldface:)
    func handleToggleBoldface(_ sender: Any?) {
        commandHandler?.toggleInlineCommand(.bold, in: self)
    }

    @objc(toggleItalics:)
    func handleToggleItalics(_ sender: Any?) {
        commandHandler?.toggleInlineCommand(.italic, in: self)
    }

    override func underline(_ sender: Any?) {
        commandHandler?.toggleInlineCommand(.underline, in: self)
    }

    @objc(highlightSelection:)
    func highlightSelection(_ sender: Any?) {
        commandHandler?.toggleInlineCommand(.highlight, in: self)
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == "\t",
           commandHandler?.completeActiveLinkFromTab(in: self) == true {
            return
        }

        if handleFormattingKeyEquivalent(event) {
            return
        }

        commandHandler?.updateKeyboardFlags(event.modifierFlags, in: self)
        super.keyDown(with: event)
        commandHandler?.updateKeyboardFlags(event.modifierFlags, in: self)
    }

    override func flagsChanged(with event: NSEvent) {
        commandHandler?.updateKeyboardFlags(event.modifierFlags, in: self)
        super.flagsChanged(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.charactersIgnoringModifiers == "\t",
           commandHandler?.completeActiveLinkFromTab(in: self) == true {
            return true
        }

        if handleFormattingKeyEquivalent(event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        if selectedRange().length > 0 {
            if menu.items.contains(where: { $0.action == #selector(highlightSelection(_:)) }) == false {
                menu.insertItem(.separator(), at: 0)
                let item = NSMenuItem(
                    title: "Highlight",
                    action: #selector(highlightSelection(_:)),
                    keyEquivalent: "h"
                )
                item.keyEquivalentModifierMask = [.command, .shift]
                item.target = self
                menu.insertItem(item, at: 0)
            }
        }
        return menu
    }

    private func handleFormattingKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              !event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option),
              !event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.control),
              let characters = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }

        switch characters {
        case "b":
            commandHandler?.toggleInlineCommand(.bold, in: self)
            return true
        case "i":
            commandHandler?.toggleInlineCommand(.italic, in: self)
            return true
        case "u":
            commandHandler?.toggleInlineCommand(.underline, in: self)
            return true
        case "h" where event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift):
            commandHandler?.toggleInlineCommand(.highlight, in: self)
            return true
        default:
            return false
        }
    }
}

private struct WikiLinkSuggestionContext {
    let range: Range<String.Index>
    let query: String
}

private struct LinkSuggestionMenu: View {
    let query: String
    let suggestions: [String]
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(suggestions, id: \.self) { title in
                Button {
                    select(title)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)

                        Text(highlightedTitle(title))
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)

                        Spacer(minLength: 10)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: 220, height: 30, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Text("Tab")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 9.5, weight: .bold))
            }
            .foregroundStyle(.secondary.opacity(0.72))
            .padding(.horizontal, 10)
            .frame(width: 220, height: 22, alignment: .trailing)
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .help("Complete link")
    }

    private func highlightedTitle(_ title: String) -> AttributedString {
        var attributed = AttributedString(title)
        guard !query.isEmpty,
              let range = attributed.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
        else { return attributed }

        attributed[range].foregroundColor = .accentColor
        attributed[range].font = .system(size: 12.5, weight: .bold)
        return attributed
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

private struct PromptTextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 16

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private func measuredTextWidth(_ text: String, font: NSFont) -> CGFloat {
    ceil((text as NSString).size(withAttributes: [.font: font]).width)
}

private struct AssistantFloatingPill: View {
    @ObservedObject var store: BrainStore
    @FocusState private var isPromptFocused: Bool
    @State private var isExpandedComposerPresented = false
    @FocusState private var isExpandedPromptFocused: Bool
    @State private var isSendHovered = false
    @State private var isAttachmentHovered = false
    @State private var measuredPromptHeight: CGFloat = 16

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
                    HStack(spacing: 7) {
                        modelMenu

                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 1, height: 18)

                        TextField("Material?", text: $store.assistantPrompt, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5))
                            .lineLimit(1...4)
                            .frame(width: textFieldWidth, height: textFieldHeight, alignment: .leading)
                            .background(promptHeightReader)
                            .focused($isPromptFocused)
                            .onSubmit {
                                submitOrPreviewThinking()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isPromptFocused = true
                            }

                        attachmentControl
                        expandToggle
                        sendButton
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 7)
                    .padding(.vertical, 6)
                    .frame(width: pillWidth)
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPromptFocused = true
                    }
                    .onPreferenceChange(PromptTextHeightPreferenceKey.self) { height in
                        measuredPromptHeight = min(68, max(16, height))
                    }
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
            .contentShape(RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous))
            .onTapGesture {
                if isExpandedComposerPresented {
                    isExpandedPromptFocused = true
                } else {
                    isPromptFocused = true
                }
            }
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
        .onChange(of: store.assistantPrompt) { _, _ in
            expandComposerIfPromptNeedsRoom()
        }
        .onChange(of: measuredPromptHeight) { _, _ in
            expandComposerIfPromptNeedsRoom()
        }
        .onPasteCommand(of: [.image, .fileURL]) { providers in
            pastePromptImages(from: providers)
        }
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
            .padding(.leading, 3)
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
                Button {
                    store.choosePromptAttachmentFromUser()
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(isAttachmentHovered ? 0.96 : 0.82))
                        .frame(width: 22, height: 24)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isAttachmentHovered ? Color.primary.opacity(0.18) : Color.clear)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isAttachmentHovered ? Color.primary.opacity(0.10) : Color.clear, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("Attach a PDF, Word document, or image")
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isAttachmentHovered = hovering
                    }
                }
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
        min(430, max(180, estimatedPromptWidth))
    }

    private var textFieldHeight: CGFloat {
        measuredPromptHeight
    }

    private var promptNeedsExpandedComposer: Bool {
        estimatedPromptLineCount >= 2 || measuredPromptHeight > 24
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

    private var estimatedPromptLineCount: Int {
        let lines = store.assistantPrompt.components(separatedBy: .newlines)
        let visualLines = lines.reduce(0) { count, line in
            count + max(1, Int(ceil(Double(max(1, line.count)) / 58.0)))
        }
        return min(4, max(1, visualLines))
    }

    private var promptHeightReader: some View {
        Text(store.assistantPrompt.isEmpty ? "Material?" : store.assistantPrompt)
            .font(.system(size: 12.5))
            .lineLimit(1...4)
            .frame(width: textFieldWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PromptTextHeightPreferenceKey.self, value: proxy.size.height)
                }
            }
    }

    private var attachmentWidth: CGFloat {
        store.assistantAttachment == nil ? 22 : (isExpandedComposerPresented ? 154 : 134)
    }

    private var expandedPillWidth: CGFloat {
        640
    }

    private var compactPillWidth: CGFloat {
        modelMenuWidth + 1 + textFieldWidth + attachmentWidth + 22 + 24 + 25 + 18
    }

    private var modelMenuWidth: CGFloat {
        store.selectedAssistantModel == .groq ? 52 : 70
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

    private func expandComposerIfPromptNeedsRoom() {
        guard promptNeedsExpandedComposer, !isExpandedComposerPresented else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isExpandedComposerPresented = true
        }
        DispatchQueue.main.async {
            isExpandedPromptFocused = true
        }
    }

    private func pastePromptImages(from providers: [NSItemProvider]) {
        guard isPromptFocused || isExpandedPromptFocused else { return }

        if let fileProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            fileProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
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
                        store.status = "Only image files can be pasted into the prompt"
                    }
                    return
                }

                Task { @MainActor in
                    store.attachPromptDocument(from: url)
                }
            }
            return
        }

        guard let imageProvider = providers.first(where: { provider in
            Self.promptImagePasteTypes.contains { provider.hasItemConformingToTypeIdentifier($0) }
        }) else {
            return
        }

        let typeIdentifier = Self.promptImagePasteTypes.first {
            imageProvider.hasItemConformingToTypeIdentifier($0)
        } ?? UTType.image.identifier
        imageProvider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
            if let error {
                Task { @MainActor in
                    store.status = error.localizedDescription
                }
                return
            }

            guard let data else {
                Task { @MainActor in
                    store.status = "Could not read pasted image"
                }
                return
            }

            Task { @MainActor in
                store.attachPromptImage(data: data, suggestedFileName: imageProvider.suggestedName ?? Self.promptImageFileName(for: typeIdentifier))
            }
        }
    }

    private static func promptImageFileName(for typeIdentifier: String) -> String {
        let fileExtension: String
        if let preferredExtension = UTType(typeIdentifier)?.preferredFilenameExtension {
            fileExtension = preferredExtension
        } else if typeIdentifier == "public.heic" {
            fileExtension = "heic"
        } else if typeIdentifier == "org.webmproject.webp" {
            fileExtension = "webp"
        } else {
            fileExtension = "png"
        }
        return "pasted-image.\(fileExtension)"
    }

    private static let promptImagePasteTypes = [
        UTType.png.identifier,
        UTType.jpeg.identifier,
        UTType.tiff.identifier,
        UTType.gif.identifier,
        "public.heic",
        "org.webmproject.webp",
        UTType.image.identifier
    ]
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
    let imageURL: (String) -> URL?

    init(
        content: String,
        searchHighlight: SearchHighlight?,
        openLinkedNote: @escaping (String) -> Void,
        imageURL: @escaping (String) -> URL? = { _ in nil }
    ) {
        self.content = content
        self.searchHighlight = searchHighlight
        self.openLinkedNote = openLinkedNote
        self.imageURL = imageURL
    }

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(content)
    }

    private var renderBlocks: [MarkdownRenderBlock] {
        var output: [MarkdownRenderBlock] = []
        var imageGroup: [MarkdownBlock] = []

        func flushImageGroup() {
            guard !imageGroup.isEmpty else { return }
            output.append(MarkdownRenderBlock(id: imageGroup.first?.id ?? output.count, blocks: imageGroup))
            imageGroup.removeAll()
        }

        for block in blocks {
            if case .image = block.kind {
                imageGroup.append(block)
            } else {
                flushImageGroup()
                output.append(MarkdownRenderBlock(id: block.id, blocks: [block]))
            }
        }

        flushImageGroup()
        return output
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(renderBlocks) { renderBlock in
                renderBlockView(renderBlock)
                    .id(renderBlock.id)
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
    private func renderBlockView(_ renderBlock: MarkdownRenderBlock) -> some View {
        if renderBlock.blocks.count > 1,
           renderBlock.blocks.allSatisfy({ block in
               if case .image = block.kind { return true }
               return false
           }) {
            imageGridView(renderBlock.blocks)
        } else if let block = renderBlock.blocks.first {
            blockView(block)
        }
    }

    private func imageGridView(_ blocks: [MarkdownBlock]) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(minimum: 180, maximum: 320), spacing: 12),
            count: min(3, max(2, blocks.count))
        )

        return LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(blocks) { block in
                if case .image(let alt, let path) = block.kind {
                    MarkdownImageView(alt: alt, url: imageURL(path), maxWidth: 320, maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .highlightedSearchBlock(searchHighlight?.blockIndex == block.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
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

        case .image(let alt, let path):
            MarkdownImageView(alt: alt, url: imageURL(path), maxWidth: 520, maxHeight: 360)
                .frame(maxWidth: .infinity, alignment: .center)
                .highlightedSearchBlock(isHighlighted)

        case .table(let table):
            tableView(table, highlighted: isHighlighted)
                .highlightedSearchBlock(isHighlighted)

        case .divider:
            Rectangle()
                .fill(.secondary.opacity(0.22))
                .frame(height: 1)
                .padding(.vertical, 10)
        }
    }

    private func tableView(_ table: MarkdownTable, highlighted: Bool) -> some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                tableRowView(table.headers, alignments: table.alignments, isHeader: true, highlighted: highlighted)

                Rectangle()
                    .fill(Color.primary.opacity(0.16))
                    .frame(height: 1)

                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                    tableRowView(row, alignments: table.alignments, isHeader: false, highlighted: highlighted)
                        .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.025) : Color.clear)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .background(.quaternary.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func tableRowView(
        _ cells: [String],
        alignments: [MarkdownTableAlignment],
        isHeader: Bool,
        highlighted: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(cells.indices, id: \.self) { index in
                inlineText(cells[index], highlighted: highlighted)
                    .font(.system(size: isHeader ? 13.5 : 13, weight: isHeader ? .semibold : .regular))
                    .lineLimit(nil)
                    .multilineTextAlignment(textAlignment(for: alignments[safe: index] ?? .left))
                    .frame(
                        minWidth: 118,
                        maxWidth: 210,
                        alignment: frameAlignment(for: alignments[safe: index] ?? .left)
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, isHeader ? 9 : 8)
                    .background(isHeader ? Color.primary.opacity(0.055) : Color.clear)
                    .overlay(alignment: .trailing) {
                        if index < cells.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 1)
                        }
                    }
            }
        }
    }

    private func textAlignment(for alignment: MarkdownTableAlignment) -> TextAlignment {
        switch alignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }

    private func frameAlignment(for alignment: MarkdownTableAlignment) -> Alignment {
        switch alignment {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }

    private func inlineText(_ markdown: String, highlighted: Bool = false) -> Text {
        if highlighted, let query = searchHighlight?.query, !query.isEmpty {
            return Text(attributedSearchText(markdown, query: query))
        }

        let normalized = markdownByHighlightingWikiLinks(markdown)
            .replacingOccurrences(
                of: #"%%.*?%%"#,
                with: "",
                options: .regularExpression
            )

        let underlineMatches = underlinedTextMatches(in: normalized)
        let highlightMatches = highlightedTextMatches(in: normalized)
        let normalizedWithoutUnderlineTags = normalized
            .replacingOccurrences(of: #"</?u>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"==([^=]+)=="#, with: "$1", options: .regularExpression)

        if var attributed = try? AttributedString(markdown: normalizedWithoutUnderlineTags) {
            applyUnderline(matches: underlineMatches, to: &attributed)
            applyHighlight(matches: highlightMatches, to: &attributed)
            return Text(attributed)
        }

        return Text(normalizedWithoutUnderlineTags)
    }

    private func underlinedTextMatches(in markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"<u>(.*?)</u>"#) else { return [] }
        let nsMarkdown = markdown as NSString
        return regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsMarkdown.substring(with: match.range(at: 1))
        }
    }

    private func highlightedTextMatches(in markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"==([^=]+)=="#) else { return [] }
        let nsMarkdown = markdown as NSString
        return regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsMarkdown.substring(with: match.range(at: 1))
        }
    }

    private func applyUnderline(matches: [String], to attributed: inout AttributedString) {
        guard !matches.isEmpty else { return }

        var searchStart = attributed.startIndex
        for match in matches where !match.isEmpty {
            guard let range = attributed[searchStart...].range(of: match) else { continue }
            attributed[range].underlineStyle = .single
            searchStart = range.upperBound
        }
    }

    private func applyHighlight(matches: [String], to attributed: inout AttributedString) {
        guard !matches.isEmpty else { return }

        var searchStart = attributed.startIndex
        for match in matches where !match.isEmpty {
            guard let range = attributed[searchStart...].range(of: match) else { continue }
            attributed[range].backgroundColor = .yellow.opacity(0.42)
            searchStart = range.upperBound
        }
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

private struct MarkdownImageView: View {
    let alt: String
    let url: URL?
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        Group {
            if let url, url.isFileURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        missingImage
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 90)
                    @unknown default:
                        missingImage
                    }
                }
            } else {
                missingImage
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var missingImage: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
            Text(alt.isEmpty ? "Image" : alt)
                .lineLimit(1)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .background(.quaternary.opacity(0.32))
    }
}

private struct MarkdownRenderBlock: Identifiable {
    let id: Int
    let blocks: [MarkdownBlock]
}

private struct MarkdownTable {
    let headers: [String]
    let alignments: [MarkdownTableAlignment]
    let rows: [[String]]
}

private enum MarkdownTableAlignment {
    case left
    case center
    case right
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
        case image(alt: String, path: String)
        case table(MarkdownTable)
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

        var lineIndex = 0
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                } else {
                    flushParagraph()
                }
                isInCodeBlock.toggle()
                lineIndex += 1
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
                lineIndex += 1
                continue
            }

            guard !trimmed.isEmpty else {
                flushParagraph()
                lineIndex += 1
                continue
            }

            if let parsedTable = parseTable(startingAt: lineIndex, in: lines) {
                flushParagraph()
                append(.table(parsedTable.table))
                lineIndex += parsedTable.consumedLineCount
            } else if let heading = parseHeading(trimmed) {
                flushParagraph()
                append(.heading(level: heading.level, text: heading.text))
                lineIndex += 1
            } else if let image = parseImage(trimmed) {
                flushParagraph()
                append(.image(alt: image.alt, path: image.path))
                lineIndex += 1
            } else if isDivider(trimmed) {
                flushParagraph()
                append(.divider)
                lineIndex += 1
            } else if let task = parseTask(trimmed) {
                flushParagraph()
                append(.task(isDone: task.isDone, text: task.text))
                lineIndex += 1
            } else if let bullet = parseBullet(trimmed) {
                flushParagraph()
                append(.bullet(bullet))
                lineIndex += 1
            } else if let numbered = parseNumbered(trimmed) {
                flushParagraph()
                append(.numbered(numbered.number, numbered.text))
                lineIndex += 1
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                append(.quote(text))
                lineIndex += 1
            } else {
                paragraph.append(trimmed)
                lineIndex += 1
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

    private static func parseImage(_ line: String) -> (alt: String, path: String)? {
        guard line.hasPrefix("!["),
              let altEnd = line.range(of: "]("),
              line.hasSuffix(")")
        else { return nil }

        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<altEnd.lowerBound])
        let pathStart = altEnd.upperBound
        let pathEnd = line.index(before: line.endIndex)
        guard pathStart <= pathEnd else { return nil }
        return (alt, String(line[pathStart..<pathEnd]))
    }

    private static func parseTable(startingAt index: Int, in lines: [String]) -> (table: MarkdownTable, consumedLineCount: Int)? {
        guard index + 1 < lines.count else { return nil }

        let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
        let separatorLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard headerLine.contains("|") else { return nil }

        let headers = splitTableRow(headerLine)
        let separatorCells = splitTableRow(separatorLine)
        guard headers.count >= 2,
              separatorCells.count == headers.count,
              separatorCells.allSatisfy(isTableSeparatorCell)
        else { return nil }

        let alignments = separatorCells.map { tableAlignment(for: $0) }
        var rows: [[String]] = []
        var cursor = index + 2

        while cursor < lines.count {
            let rowLine = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard !rowLine.isEmpty,
                  rowLine.contains("|"),
                  splitTableRow(rowLine).count >= 2
            else { break }

            rows.append(normalizedTableCells(splitTableRow(rowLine), columnCount: headers.count))
            cursor += 1
        }

        return (
            MarkdownTable(
                headers: normalizedTableCells(headers, columnCount: headers.count),
                alignments: normalizedTableAlignments(alignments, columnCount: headers.count),
                rows: rows
            ),
            cursor - index
        )
    }

    nonisolated private static func splitTableRow(_ line: String) -> [String] {
        var cleanLine = line.trimmingCharacters(in: .whitespaces)
        if cleanLine.hasPrefix("|") {
            cleanLine.removeFirst()
        }
        if cleanLine.hasSuffix("|") {
            cleanLine.removeLast()
        }

        return cleanLine
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    nonisolated private static func isTableSeparatorCell(_ cell: String) -> Bool {
        var cleanCell = cell.trimmingCharacters(in: .whitespaces)
        if cleanCell.hasPrefix(":") {
            cleanCell.removeFirst()
        }
        if cleanCell.hasSuffix(":") {
            cleanCell.removeLast()
        }

        return cleanCell.count >= 3 && cleanCell.allSatisfy { $0 == "-" }
    }

    nonisolated private static func tableAlignment(for separatorCell: String) -> MarkdownTableAlignment {
        let cleanCell = separatorCell.trimmingCharacters(in: .whitespaces)
        if cleanCell.hasPrefix(":") && cleanCell.hasSuffix(":") {
            return .center
        }
        if cleanCell.hasSuffix(":") {
            return .right
        }
        return .left
    }

    nonisolated private static func normalizedTableCells(_ cells: [String], columnCount: Int) -> [String] {
        if cells.count == columnCount {
            return cells
        }

        if cells.count > columnCount {
            return Array(cells.prefix(columnCount))
        }

        return cells + Array(repeating: "", count: columnCount - cells.count)
    }

    nonisolated private static func normalizedTableAlignments(_ alignments: [MarkdownTableAlignment], columnCount: Int) -> [MarkdownTableAlignment] {
        if alignments.count == columnCount {
            return alignments
        }

        if alignments.count > columnCount {
            return Array(alignments.prefix(columnCount))
        }

        return alignments + Array(repeating: .left, count: columnCount - alignments.count)
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
    @State private var isTitleHovered = false

    var body: some View {
        HStack {
            Button {
                store.openLatestHighlightSummaryOrCompiler()
            } label: {
                Label(store.activeBrain?.name ?? "Brain", systemImage: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary.opacity(isTitleHovered ? 0.96 : 0.86))
                    .shadow(color: .yellow.opacity(isTitleHovered ? 0.28 : 0), radius: isTitleHovered ? 7 : 0)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open highlighted summary")
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isTitleHovered = hovering
                }
            }
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
    var onDismiss: (() -> Void)? = nil

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

            if !query.isEmpty || onDismiss != nil {
                Button {
                    if query.isEmpty {
                        onDismiss?()
                    } else {
                        query = ""
                        isFocused.wrappedValue = true
                    }
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

private enum APIKeyVerificationState: Equatable {
    case idle
    case verifying
    case verified
    case failed(String)
}

private struct ModelConfigurationView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss

    @State private var mistralAPIKey: String
    @State private var groqAPIKey: String
    @State private var groqModel: String
    @State private var selectedModel: AssistantModel
    @State private var mistralVerificationState: APIKeyVerificationState
    @State private var verifiedMistralAPIKey: String
    @State private var verificationTask: Task<Void, Never>?

    init(store: BrainStore) {
        self.store = store
        let configuration = store.assistantConfigurationSnapshot
        _mistralAPIKey = State(initialValue: configuration.mistralAPIKey)
        _groqAPIKey = State(initialValue: configuration.groqAPIKey)
        _groqModel = State(initialValue: configuration.groqModel)
        _selectedModel = State(initialValue: store.selectedAssistantModel)
        _mistralVerificationState = State(initialValue: configuration.mistralAPIKey.isEmpty ? .idle : .verified)
        _verifiedMistralAPIKey = State(initialValue: configuration.mistralAPIKey)
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
                        MistralAPIKeyField(
                            text: $mistralAPIKey,
                            state: mistralVerificationState,
                            width: mistralAPIKeyFieldWidth
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default model: \(BrainStore.defaultMistralModel)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        if case .failed(let message) = mistralVerificationState {
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    ConfigurationField(title: "Groq API Key") {
                        SecureField("gsk-...", text: $groqAPIKey)
                    }

                    ConfigurationField(title: "Groq Model") {
                        TextField(BrainStore.defaultGroqModel, text: $groqModel)
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
                    saveSelectedConfiguration()
                    dismiss()
                } label: {
                    Text(selectedModel == .mistral ? "Done" : "Save")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(selectedModel == .mistral && !isMistralKeyVerified)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .onChange(of: mistralAPIKey) { _, newValue in
            scheduleMistralVerification(for: newValue)
        }
        .onChange(of: selectedModel) { _, newValue in
            if newValue == .mistral {
                scheduleMistralVerification(for: mistralAPIKey)
            }
        }
        .onDisappear {
            verificationTask?.cancel()
        }
    }

    private var cleanMistralAPIKey: String {
        mistralAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isMistralKeyVerified: Bool {
        !cleanMistralAPIKey.isEmpty
            && cleanMistralAPIKey == verifiedMistralAPIKey
            && mistralVerificationState == .verified
    }

    private var mistralAPIKeyFieldWidth: CGFloat {
        let text = cleanMistralAPIKey.isEmpty ? "MISTRAL_API_KEY" : cleanMistralAPIKey
        return min(440, max(230, measuredTextWidth(text, font: .systemFont(ofSize: 14)) + 56))
    }

    private func scheduleMistralVerification(for apiKey: String) {
        verificationTask?.cancel()

        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else {
            mistralVerificationState = .idle
            return
        }

        if cleanAPIKey == verifiedMistralAPIKey {
            mistralVerificationState = .verified
            return
        }

        mistralVerificationState = .verifying
        verificationTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }

            do {
                try await store.verifyAndSaveMistralAPIKey(cleanAPIKey)
                guard !Task.isCancelled else { return }
                verifiedMistralAPIKey = cleanAPIKey
                mistralVerificationState = .verified
            } catch {
                guard !Task.isCancelled else { return }
                mistralVerificationState = .failed(error.localizedDescription)
            }
        }
    }

    private func saveSelectedConfiguration() {
        store.selectAssistantModel(selectedModel)
        store.saveModelConfiguration(
            mistralAPIKey: mistralAPIKey,
            mistralModel: BrainStore.defaultMistralModel,
            groqAPIKey: groqAPIKey,
            groqModel: groqModel
        )
    }
}

private struct MistralAPIKeyField: View {
    @Binding var text: String
    let state: APIKeyVerificationState
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .trailing) {
            SecureField("MISTRAL_API_KEY", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .frame(width: width)

            statusAccessory
                .frame(width: 18, height: 18)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.16), value: width)
    }

    @ViewBuilder
    private var statusAccessory: some View {
        switch state {
        case .idle:
            EmptyView()
        case .verifying:
            ProgressView()
                .scaleEffect(0.45)
        case .verified:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red.opacity(0.85))
        }
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

private struct UsedModelsConfigurationView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss
    @State private var promptModel: AssistantModel
    @State private var summaryModel: HighlightSummaryModel
    @State private var ollamaBaseURL: String
    @State private var ollamaModel: String

    init(store: BrainStore) {
        self.store = store
        let ollama = store.ollamaConfigurationSnapshot
        _promptModel = State(initialValue: store.selectedAssistantModel)
        _summaryModel = State(initialValue: store.selectedHighlightSummaryModel)
        _ollamaBaseURL = State(initialValue: ollama.baseURL)
        _ollamaModel = State(initialValue: ollama.model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "cpu")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.74))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Models Used Where")
                        .font(.system(size: 24, weight: .bold))
                    Text("Choose the model used for editing prompts and highlight summaries.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ConfigurationField(title: "Prompt Editing Model") {
                    Picker("Prompt Editing Model", selection: $promptModel) {
                        ForEach(AssistantModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                ConfigurationField(title: "Highlight Compile Model") {
                    Picker("Highlight Compile Model", selection: $summaryModel) {
                        ForEach(HighlightSummaryModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                ConfigurationField(title: "Ollama URL") {
                    TextField(BrainStore.defaultOllamaURL, text: $ollamaBaseURL)
                }

                ConfigurationField(title: "Ollama Model") {
                    TextField(BrainStore.defaultOllamaModel, text: $ollamaModel)
                }
            }

            HStack(spacing: 12) {
                Button {
                    store.isShowingUsedModelsConfiguration = false
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    store.saveUsedModelConfiguration(
                        promptModel: promptModel,
                        summaryModel: summaryModel,
                        ollamaBaseURL: ollamaBaseURL,
                        ollamaModel: ollamaModel
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

private struct HighlightSummaryCompilerView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel: HighlightSummaryModel

    init(store: BrainStore) {
        self.store = store
        _selectedModel = State(initialValue: store.selectedHighlightSummaryModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.76))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Compile Highlights")
                        .font(.system(size: 24, weight: .bold))
                    Text("Choose the model before generating the read-only summary.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ConfigurationField(title: "Model") {
                Picker("Model", selection: $selectedModel) {
                    ForEach(HighlightSummaryModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Button {
                    store.isShowingHighlightSummaryCompiler = false
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    store.compileCurrentHighlightSummary()
                    dismiss()
                } label: {
                    Text("Compile")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(store.isCompilingHighlightSummary)
            }
        }
        .padding(28)
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
