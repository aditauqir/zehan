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
                    greeting: WelcomeGreeting.message(
                        userName: store.userProfile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? store.userName
                            : store.userProfile.firstName
                    ),
                    recentVaults: store.recentVaults,
                    isBusy: store.isBusy,
                    newBrain: store.createBrainVaultFromUser,
                    openBrain: store.openBrainVaultFromUser,
                    configure: store.configureModelFromUser,
                    personalize: store.configureUsernameFromUser,
                    openRecent: store.openRecentVault
                )
            } else {
                WorkspaceView(store: store)
            }
        }
        .frame(minWidth: 1120, minHeight: 720)
        .task {
            await store.openPreviousBrainAfterFirstFrame()
        }
        .sheet(isPresented: $store.isShowingModelConfiguration) {
            ModelConfigurationView(store: store)
                .frame(width: 620)
                .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $store.isShowingMarkdownHelp) {
            MarkdownHelpView()
                .frame(width: 620, height: 680)
                .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $store.isShowingUsernameConfiguration) {
            UsernameConfigurationView(store: store)
                .frame(width: 460)
                .presentationBackground(.regularMaterial)
        }
    }
}

private struct SplashView: View {
    let greeting: String
    let recentVaults: [RecentVault]
    let isBusy: Bool
    let newBrain: () -> Void
    let openBrain: () -> Void
    let configure: () -> Void
    let personalize: () -> Void
    let openRecent: (RecentVault) -> Void

    var body: some View {
        VStack(spacing: 52) {
            Text(greeting)
                .font(.custom(AppFont.ptSerifRegular, size: AppFont.welcomeGreetingSize))
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 720)

            VStack(spacing: 28) {
                VStack(spacing: 16) {
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

                    HStack(spacing: 12) {
                        SplashUtilityButton(
                            title: "Personalize",
                            systemImage: "wand.and.stars",
                            isDisabled: isBusy,
                            action: personalize
                        )

                        SplashUtilityButton(
                            title: "Configure",
                            systemImage: "gearshape",
                            isDisabled: isBusy,
                            action: configure
                        )
                    }
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

private struct SplashUtilityButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(isHovered ? 0.86 : 0.62))
            .padding(.horizontal, 13)
            .frame(height: 30)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background {
            Capsule()
                .fill(.white.opacity(isHovered ? 0.10 : 0.045))
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(isHovered ? 0.18 : 0.09), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering && !isDisabled
        }
        .opacity(isDisabled ? 0.55 : 1)
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
    @State private var isEditorFlashcardOpen = false
    @State private var readingHighlightRequestID = 0
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

    private var editorFlashcardNoteID: Note.ID? {
        guard !store.isShowingHomePage,
              !store.isShowingHelpDesk,
              store.currentHighlightSummary == nil
        else { return nil }

        return store.currentNoteID ?? store.selectedNoteID
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
                        isHelpDeskSelected: store.isShowingHelpDesk,
                        openHome: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isEditingMarkdown = false
                                isSidebarSearchActive = false
                                sidebarSearchQuery = ""
                                store.openHomePage()
                            }
                        },
                        openHelpDesk: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isEditingMarkdown = false
                                isSidebarSearchActive = false
                                sidebarSearchQuery = ""
                                store.openHelpDesk()
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

                                if shouldShowNewPageHint {
                                    NewBrainPageHint {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            isEditingMarkdown = false
                                            store.newDraft()
                                        }
                                    }
                                    .padding(.top, 8)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                workspaceDetail
            }

            if isGraphExpanded {
                ExpandedGraphOverlay(
                    notes: store.notes,
                    links: store.graphLinks,
                    selectedNoteID: store.currentNoteID,
                    openNote: { noteID in
                        isEditingMarkdown = false
                        store.openNote(id: noteID)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isGraphExpanded = false
                        }
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
                if !store.isShowingHomePage && !store.isShowingHelpDesk {
                    HStack {
                        DocumentChromeControls(
                            canDelete: !store.isViewingGeneratedPage && (store.selectedNoteID != nil || store.currentNoteID != nil),
                            canShowFlashcards: editorFlashcardNoteID != nil,
                            isFlashcardOpen: isEditorFlashcardOpen,
                            canUseFormattingTools: !isReadingMode,
                            typingStatus: typingStatus,
                            newPage: {
                                isEditingMarkdown = false
                                isEditorFlashcardOpen = false
                                store.newDraft()
                            },
                            flashcards: {
                                guard let noteID = editorFlashcardNoteID else { return }
                                isEditingMarkdown = false
                                withAnimation(.easeOut(duration: 0.16)) {
                                    isEditorFlashcardOpen.toggle()
                                }
                                if isEditorFlashcardOpen {
                                    store.requestPageFlashcards(noteID: noteID)
                                }
                            },
                            delete: {
                                isEditingMarkdown = false
                                isEditorFlashcardOpen = false
                                store.deleteSelectedNote()
                            },
                            bold: { NSApp.sendAction(NSSelectorFromString("toggleBoldface:"), to: nil, from: nil) },
                            italic: { NSApp.sendAction(NSSelectorFromString("toggleItalics:"), to: nil, from: nil) },
                            underline: { NSApp.sendAction(NSSelectorFromString("underline:"), to: nil, from: nil) },
                            highlight: {
                                if isReadingMode {
                                    readingHighlightRequestID += 1
                                } else {
                                    NSApp.sendAction(NSSelectorFromString("highlightSelection:"), to: nil, from: nil)
                                }
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
                        if store.isShowingHelpDesk {
                            HelpDeskView(store: store)
                        } else if store.isShowingHomePage {
                            HomePageView(
                                store: store,
                                presentation: store.homePagePresentation,
                                isGenerating: store.isGeneratingHomePage,
                                generationDate: store.latestHomeSummary?.compiledAt,
                                openNote: { store.openNote(id: $0) }
                            )
                        } else if let summary = store.currentHighlightSummary {
                            ReadOnlyHighlightSummaryView(
                                summary: summary,
                                openLinkedNote: { store.openLinkedNote(named: $0) },
                                imageURL: store.markdownImageURL,
                                imageData: store.markdownImageData
                            )
                        } else if isEditorFlashcardOpen, let noteID = editorFlashcardNoteID {
                            EditorPageFlashcardView(
                                state: store.pageFlashcardStates[noteID] ?? .idle,
                                regenerate: { store.requestPageFlashcards(noteID: noteID, force: true) },
                                goTo: { query in
                                    store.openPageFlashcardSource(noteID: noteID, query: query)
                                    withAnimation(.easeOut(duration: 0.16)) {
                                        isEditorFlashcardOpen = false
                                    }
                                }
                            )
                        } else {
                            MarkdownEditingSurface(
                                content: contentBinding,
                                isEditing: $isEditingMarkdown,
                                isReadOnly: isReadingMode,
                                editorBottomInset: editorInputAvoidanceInset,
                                previewBottomInset: renderedPageInputAvoidanceInset,
                                searchHighlight: store.activeSearchHighlight,
                                noteTitles: store.notes.map(\.title),
                                relevanceCandidates: store.markdownRelevanceCandidates(excluding: store.currentNoteID),
                                openLinkedNote: { store.openLinkedNote(named: $0) },
                                clearSearchHighlight: store.clearSearchHighlight,
                                imageURL: store.markdownImageURL,
                                imageData: store.markdownImageData,
                                insertImageFile: store.insertMarkdownImage,
                                insertImageData: store.insertMarkdownImage,
                                highlightRequestID: readingHighlightRequestID,
                                typingStatus: $typingStatus
                            )
                        }
                    }
                    .padding(.horizontal, 38)
                    .padding(.top, 18)
                    .padding(.bottom, store.isShowingHelpDesk ? 4 : 18)

                    HStack {
                        if store.isShowingHelpDesk {
                            Text("Zirn Chat")
                        } else if store.isShowingHomePage {
                            HomeFooter(latestSummary: store.latestHomeSummary)
                        } else if let summary = store.currentHighlightSummary {
                            HighlightSummaryFooter(summary: summary)
                        } else if isEditorFlashcardOpen {
                            Text("Idea Flashcards")
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
                        if !store.isViewingGeneratedPage && !isEditorFlashcardOpen {
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
                    if !isReadingMode && !store.isViewingGeneratedPage && !isEditorFlashcardOpen && !store.isShowingHelpDesk {
                        Color.clear
                            .frame(width: readingToggleSize, height: readingToggleSize)
                            .accessibilityHidden(true)

                        AssistantFloatingPill(store: store)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                            .onPreferenceChange(PillHeightPreferenceKey.self) { height in
                                promptPillHeight = max(38, height)
                            }
                    }

                    if !store.isViewingGeneratedPage && !isEditorFlashcardOpen {
                        ReadingModeToggle(isOn: $isReadingMode, size: readingToggleSize)
                    }
                }
                .padding(.bottom, 54)
                .frame(maxWidth: .infinity, alignment: .center)

            }
        .onChange(of: editorFlashcardNoteID) { _, newID in
            if newID == nil {
                isEditorFlashcardOpen = false
            } else if let newID, isEditorFlashcardOpen {
                store.requestPageFlashcards(noteID: newID)
            }
        }
    }

    private var shouldShowNewPageHint: Bool {
        store.activeBrain != nil
            && store.notes.isEmpty
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

    private var editorInputAvoidanceInset: CGFloat {
        guard isEditingMarkdown, !isReadingMode, !store.isViewingGeneratedPage else { return 0 }
        return promptPillHeight + 92
    }

    private var renderedPageInputAvoidanceInset: CGFloat {
        guard !isReadingMode, !store.isViewingGeneratedPage else { return 0 }
        return promptPillHeight * 1.09
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
                        store.status = "Only PDFs, Word documents, PowerPoint files, and images are supported"
                    }
                    return
                }

                Task { @MainActor in
                    attachDroppedDocument(from: url)
                }
            }
            return true
        }

        guard let directProvider = providers.first(where: { provider in
            Self.directDocumentDropTypes.contains { provider.hasItemConformingToTypeIdentifier($0) }
        }) else {
            store.status = "Only PDFs, Word documents, PowerPoint files, and images are supported"
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
                    store.status = "Only PDFs, Word documents, PowerPoint files, and images are supported"
                }
                return
            }

            Task { @MainActor in
                attachDroppedDocument(from: copiedURL)
            }
        }
        return true
    }

    private func attachDroppedDocument(from url: URL) {
        if store.isShowingHelpDesk {
            store.attachHelpDeskDocument(from: url)
        } else {
            store.attachPromptDocument(from: url)
        }
    }

    private func copyDroppedDocumentToTemporaryURL(_ url: URL, suggestedName: String?) -> URL? {
        let fallbackName = suggestedName?.isEmpty == false ? suggestedName! : url.lastPathComponent
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("zirn-drop-\(UUID().uuidString)-\(fallbackName)")
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

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
        "com.microsoft.powerpoint.ppt",
        "org.openxmlformats.presentationml.presentation",
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
            HStack(spacing: 5) {
                Text("Press")
                Image(systemName: "command")
                    .font(.system(size: 11, weight: .bold))
                Text("N to start")
                Spacer(minLength: 0)
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.primary.opacity(isHovered ? 0.9 : 0.58))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 28)
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
    let canShowFlashcards: Bool
    let isFlashcardOpen: Bool
    let canUseFormattingTools: Bool
    let typingStatus: MarkdownTypingStatus
    let newPage: () -> Void
    let flashcards: () -> Void
    let delete: () -> Void
    let bold: () -> Void
    let italic: () -> Void
    let underline: () -> Void
    let highlight: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            GlassChromeIconButton(systemImage: "square.and.pencil", help: "New Page", action: newPage)
                .keyboardShortcut("n", modifiers: .command)

            GlassChromeIconButton(
                systemImage: "lightbulb",
                help: isFlashcardOpen ? "Hide Idea Flashcards" : "Show Idea Flashcards",
                isActive: isFlashcardOpen,
                action: flashcards
            )
            .disabled(!canShowFlashcards)

            Rectangle()
                .fill(Color.primary.opacity(0.13))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 6)

            GlassChromeIconButton(
                systemImage: "bold",
                help: canUseFormattingTools ? "Bold" : "Bold is unavailable in Reading Mode",
                isActive: typingStatus.isBold,
                action: bold
            )
            .disabled(!canUseFormattingTools)

            GlassChromeIconButton(
                systemImage: "italic",
                help: canUseFormattingTools ? "Italic" : "Italic is unavailable in Reading Mode",
                isActive: typingStatus.isItalic,
                action: italic
            )
            .disabled(!canUseFormattingTools)

            GlassChromeIconButton(
                systemImage: "underline",
                help: canUseFormattingTools ? "Underline" : "Underline is unavailable in Reading Mode",
                isActive: typingStatus.isUnderline,
                action: underline
            )
            .disabled(!canUseFormattingTools)

            GlassChromeIconButton(
                systemImage: "paintbrush.pointed",
                help: canUseFormattingTools ? "Highlight" : "Highlight selected text in Reading Mode",
                isActive: !canUseFormattingTools || typingStatus.isHighlight,
                activeIconColor: .white,
                action: highlight
            )

            Rectangle()
                .fill(Color.primary.opacity(0.13))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 6)

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
                    HelpRow("Create New Brain", "⇧⌘N")
                    HelpRow("Open Brain Vault", "⌘K")
                    HelpRow("Save Vault Metadata", "⇧⌘S")
                    HelpRow("New Page", "⌘N")
                    HelpRow("New Folder", "⌘G")
                    HelpRow("Search Pages", "⌘O")
                    HelpRow("Delete Selected Item", "⌘Delete")
                    HelpRow("Open Zirn Help", "⇧⌘/")
                }

                HelpSection("Editor Flow") {
                    HelpRow("Edit a page", "Click the rendered document.")
                    HelpRow("Return to rendered view", "Press Escape or click outside the editor.")
                    HelpRow("Rename from document", "Change the first # heading; the sidebar title follows it.")
                    HelpRow("Autosave", "Changes save automatically after a short pause.")
                }

                HelpSection("Editor Shortcuts") {
                    HelpRow("Bold", "⌘B")
                    HelpRow("Italic", "⌘I")
                    HelpRow("Underline", "⌘U")
                    HelpRow("Highlight", "⇧⌘H")
                    HelpRow("Complete page link suggestion", "Tab")
                    HelpRow("Paste image into page", "⌘V")
                }

                HelpSection("Link Pages") {
                    HelpCode("[[Research Project]]")
                    HelpCode("[[Research Project|project notes]]")
                    Text("Type [[ to search page titles while editing. Press Tab to accept the suggested page link. Links become highlighted in the rendered view, open matching pages, and appear in the graph.")
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
    var isActive = false
    var isDestructive = false
    var activeIconColor: Color?
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(isDestructive && isHovered ? .palette : .hierarchical)
                .foregroundStyle(primaryStyle, secondaryStyle)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(highlightFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: isHovered ? 5 : 0, y: isHovered ? 2 : 0)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

        if isActive {
            return (activeIconColor ?? Color.accentColor).opacity(isHovered ? 0.98 : 0.88)
        }

        return .primary.opacity(isHovered ? 0.92 : 0.58)
    }

    private var secondaryStyle: Color {
        if isDestructive && isHovered {
            return .red.opacity(0.42)
        }

        return isActive ? (activeIconColor ?? Color.accentColor).opacity(0.34) : .primary.opacity(0.28)
    }

    private var highlightFill: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.15)
        }

        if isActive, isHovered {
            return Color.accentColor.opacity(0.14)
        }

        return .white.opacity(isHovered ? 0.13 : 0)
    }

    private var borderColor: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.30)
        }

        if isActive, isHovered {
            return Color.accentColor.opacity(0.30)
        }

        return .white.opacity(isHovered ? 0.22 : 0)
    }

    private var shadowColor: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.12)
        }

        if isActive, isHovered {
            return Color.accentColor.opacity(0.15)
        }

        return .black.opacity(isHovered ? 0.18 : 0)
    }
}

private struct NoteGraphView: View {
    let notes: [NoteSummary]
    let links: [BrainLinkReference]
    let selectedNoteID: Note.ID?
    var maxVisibleNotes: Int? = 12
    var allowsScrolling = false
    var opensOnSingleClick = true
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
                    .onTapGesture(count: 2) {
                        openNote(note.id)
                    }
                    .onTapGesture {
                        if opensOnSingleClick {
                            openNote(note.id)
                        }
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
                    opensOnSingleClick: false,
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
        .onExitCommand(perform: close)
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
                Text(displayTitle)
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
                draftTitle = editableTitle(for: newTitle)
            }
        }
        .task {
            draftTitle = editableTitle(for: item.title)
        }
    }

    private func beginRename() {
        draftTitle = editableTitle(for: item.title)
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
        draftTitle = editableTitle(for: item.title)
        isRenaming = false
    }

    private var displayTitle: String {
        editableTitle(for: item.title)
    }

    private func editableTitle(for title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !Self.looksLikeGeneratedID(clean) else {
            return "Group"
        }
        return clean
    }

    private static func looksLikeGeneratedID(_ title: String) -> Bool {
        let uuidPattern = #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#
        if title.range(of: uuidPattern, options: .regularExpression) != nil {
            return true
        }
        return title.hasPrefix("group-") && title.count > 18
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
    let isHelpDeskSelected: Bool
    let openHome: () -> Void
    let openHelpDesk: () -> Void
    let reloadHome: () -> Void
    let activateSearch: () -> Void
    @Namespace private var liquidNamespace
    @State private var isHomeHovered = false
    @State private var isHelpDeskHovered = false
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

            helpDeskSegment

            searchSegment
        }
    }

    private var homeSegment: some View {
        sidebarSegment(
            systemImage: isHomeSelected ? "arrow.clockwise" : "house.fill",
            isSelected: isHomeSelected,
            isHovered: isHomeHovered,
            help: isHomeSelected ? "Regenerate Home page" : "Home",
            action: isHomeSelected ? reloadHome : openHome,
            hover: { isHomeHovered = $0 }
        )
    }

    private var helpDeskSegment: some View {
        sidebarSegment(
            systemImage: "bubble.left.and.text.bubble.right",
            isSelected: isHelpDeskSelected,
            isHovered: isHelpDeskHovered,
            help: "Zirn Chat",
            action: openHelpDesk,
            hover: { isHelpDeskHovered = $0 }
        )
    }

    private var searchSegment: some View {
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

    private func sidebarSegment(
        systemImage: String,
        isSelected: Bool,
        isHovered: Bool,
        help: String,
        action: @escaping () -> Void,
        hover: @escaping (Bool) -> Void
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(segmentFill(isSelected: isSelected, isHovered: isHovered))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(segmentStroke(isSelected: isSelected, isHovered: isHovered), lineWidth: 1)
                }
                .shadow(color: Color.accentColor.opacity(isHovered ? 0.16 : 0), radius: isHovered ? 8 : 0, y: isHovered ? 2 : 0)

            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(isSelected || isHovered ? 0.9 : 0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(help)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .offset(x: isSearchActive ? -18 : 0)
        .opacity(isSearchActive ? 0 : 1)
        .scaleEffect(isSearchActive ? 0.96 : 1, anchor: .leading)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                hover(hovering)
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

    private func segmentFill(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.primary.opacity(isHovered ? 0.18 : 0.14)
        }
        return Color.primary.opacity(isHovered ? 0.095 : 0.045)
    }

    private func segmentStroke(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected || isHovered {
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

private enum HelpDeskComposerMetrics {
    static let fontSize: CGFloat = 14
    static let maxVisibleLines = 5
    static let verticalInset: CGFloat = 6
    static let textVerticalInset: CGFloat = 6
    static let minInputHeight: CGFloat = 32

    static var lineHeight: CGFloat {
        ceil(fontSize * 1.38)
    }

    static var maxInputHeight: CGFloat {
        lineHeight * CGFloat(maxVisibleLines) + verticalInset
    }
}

private struct HelpDeskPromptInputView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange
    @Binding var contentHeight: CGFloat
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectionRange: $selectionRange, contentHeight: $contentHeight, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> HelpDeskPromptScrollView {
        let scrollView = HelpDeskPromptScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.onContentHeightChange = { newHeight in
            context.coordinator.updateContentHeight(newHeight)
        }

        let textView = HelpDeskPromptNSTextView()
        textView.onSubmit = { context.coordinator.submit() }
        textView.delegate = context.coordinator
        textView.string = text
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: HelpDeskComposerMetrics.textVerticalInset)
        textView.font = NSFont.systemFont(ofSize: HelpDeskComposerMetrics.fontSize)
        textView.textColor = .labelColor
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        context.coordinator.textView = textView
        textView.setSelectedRange(clamped(selectionRange, in: text))
        scrollView.syncDocumentViewFrame()
        return scrollView
    }

    func updateNSView(_ scrollView: HelpDeskPromptScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HelpDeskPromptNSTextView else { return }
        context.coordinator.text = $text
        context.coordinator.selectionRange = $selectionRange
        context.coordinator.contentHeight = $contentHeight
        context.coordinator.onSubmit = onSubmit
        context.coordinator.textView = textView
        scrollView.onContentHeightChange = { newHeight in
            context.coordinator.updateContentHeight(newHeight)
        }
        textView.onSubmit = { context.coordinator.submit() }

        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(clamped(selectionRange, in: text))
            scrollView.syncDocumentViewFrame()
        }
    }

    private func clamped(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(max(0, range.location), length)
        return NSRange(location: location, length: min(range.length, max(0, length - location)))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectionRange: Binding<NSRange>
        var contentHeight: Binding<CGFloat>
        var onSubmit: () -> Void
        weak var textView: NSTextView?

        init(
            text: Binding<String>,
            selectionRange: Binding<NSRange>,
            contentHeight: Binding<CGFloat>,
            onSubmit: @escaping () -> Void
        ) {
            self.text = text
            self.selectionRange = selectionRange
            self.contentHeight = contentHeight
            self.onSubmit = onSubmit
        }

        func submit() {
            onSubmit()
        }

        func updateContentHeight(_ newHeight: CGFloat) {
            guard abs(contentHeight.wrappedValue - newHeight) > 0.5 else { return }
            contentHeight.wrappedValue = newHeight
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if text.wrappedValue != textView.string {
                text.wrappedValue = textView.string
            }
            publishSelection(from: textView)
            (textView.enclosingScrollView as? HelpDeskPromptScrollView)?.syncDocumentViewFrame()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            publishSelection(from: textView)
        }

        private func publishSelection(from textView: NSTextView) {
            selectionRange.wrappedValue = textView.selectedRange()
        }
    }
}

private final class HelpDeskPromptScrollView: NSScrollView {
    var onContentHeightChange: ((CGFloat) -> Void)?

    func syncDocumentViewFrame() {
        guard let textView = documentView as? NSTextView,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else { return }

        let contentWidth = max(contentSize.width, 1)
        textView.textContainer?.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)

        let usedHeight = layoutManager.usedRect(for: textContainer).height
        let inset = textView.textContainerInset
        let contentNeeded = ceil(usedHeight + inset.height * 2)
        let lineHeight = HelpDeskComposerMetrics.lineHeight
        let contentLines = max(
            1,
            min(
                HelpDeskComposerMetrics.maxVisibleLines,
                Int(ceil(max(0, contentNeeded - inset.height * 2) / lineHeight))
            )
        )
        let preferredVisibleHeight = min(
            HelpDeskComposerMetrics.maxInputHeight,
            max(
                HelpDeskComposerMetrics.minInputHeight,
                CGFloat(contentLines) * lineHeight + inset.height * 2
            )
        )
        onContentHeightChange?(preferredVisibleHeight)

        let visibleHeight = preferredVisibleHeight
        let documentHeight = max(visibleHeight, contentNeeded)

        textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: documentHeight)

        if documentHeight > visibleHeight + 1 {
            textView.scrollRangeToVisible(textView.selectedRange())
        } else {
            contentView.scroll(to: NSPoint(x: 0, y: max(0, documentHeight - visibleHeight)))
        }
    }

    override func layout() {
        super.layout()
        syncDocumentViewFrame()
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        syncDocumentViewFrame()
    }
}

private final class HelpDeskPromptNSTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isReturnKey = event.charactersIgnoringModifiers == "\r" || event.keyCode == 36 || event.keyCode == 76
        if isReturnKey,
           (modifiers.contains(.command) || !modifiers.contains(.shift)) {
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              let characters = event.charactersIgnoringModifiers?.lowercased(),
              characters == "c",
              selectedRange().length == 0
        else {
            return super.performKeyEquivalent(with: event)
        }

        if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}

private struct HelpDeskComposerFocusResigner: NSViewRepresentable {
    func makeNSView(context: Context) -> HelpDeskComposerFocusEventView {
        HelpDeskComposerFocusEventView()
    }

    func updateNSView(_ nsView: HelpDeskComposerFocusEventView, context: Context) {}
}

private final class HelpDeskComposerFocusEventView: NSView {
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.handleMouseDown(event)
            return event
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    deinit {
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let window = event.window,
              let contentView = window.contentView
        else { return }

        let location = contentView.convert(event.locationInWindow, from: nil)
        guard let hitView = contentView.hitTest(location) else { return }

        if hitView is HelpDeskPromptNSTextView
            || hitView.enclosingScrollView?.documentView is HelpDeskPromptNSTextView {
            return
        }

        if window.firstResponder is HelpDeskPromptNSTextView {
            window.makeFirstResponder(nil)
        }
    }
}

private struct HelpDeskView: View {
    @ObservedObject var store: BrainStore
    @State private var conversationSearchQuery = ""
    @State private var isConversationPopoverPresented = false
    @State private var isRecentChatsPopoverPresented = false
    @State private var isConversationMenuHovered = false
    @State private var isNewHovered = false
    @State private var isUploadHovered = false
    @State private var isSendHovered = false
    @State private var isShowMoreHovered = false
    @State private var helpDeskInputSelectionRange = NSRange(location: 0, length: 0)
    @State private var helpDeskComposerContentHeight = HelpDeskComposerMetrics.minInputHeight

    private var selectedConversation: HelpDeskConversation? {
        guard let id = store.selectedHelpDeskConversationID else { return nil }
        return store.helpDeskConversations.first { $0.id == id }
    }

    private var historyConversations: [HelpDeskConversation] {
        store.helpDeskConversations.filter { !$0.messages.isEmpty }
    }

    private var recentHistoryConversations: [HelpDeskConversation] {
        historyConversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var previewRecentConversations: [HelpDeskConversation] {
        Array(recentHistoryConversations.prefix(3))
    }

    private var overflowRecentConversations: [HelpDeskConversation] {
        Array(recentHistoryConversations.dropFirst(3))
    }

    private var helpDeskMessageScrollBottomInset: CGFloat {
        let attachmentHeight = store.helpDeskAttachment != nil ? 36.0 : 0.0
        return helpDeskComposerContentHeight + attachmentHeight + 42
    }

    private var hasActiveConversation: Bool {
        selectedConversation?.messages.isEmpty == false
    }

    var body: some View {
        Group {
            if hasActiveConversation {
                activeConversationView
            } else {
                newConversationView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: hasActiveConversation)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(isPresented: $store.isShowingHelpDeskConversationBrowser) {
            HelpDeskConversationBrowser(
                conversations: store.helpDeskConversations,
                selectedID: store.selectedHelpDeskConversationID,
                searchQuery: $conversationSearchQuery,
                select: { store.selectHelpDeskConversation(id: $0) },
                startNew: { store.startNewHelpDeskConversation() }
            )
            .frame(width: 520, height: 560)
            .presentationBackground(.regularMaterial)
        }
    }

    private var activeConversationView: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Divider()
                    .opacity(0.35)
                    .transition(.opacity)

                messageScrollView
                    .transition(.opacity)
            }
            .background(HelpDeskComposerFocusResigner())

            composerBlock
                .padding(.horizontal, 34)
                .padding(.bottom, 4)
        }
    }

    private var newConversationView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HelpDeskStartBrandView()
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            composerBlock
                .padding(.horizontal, 34)
                .padding(.bottom, 20)

            Spacer(minLength: 0)
        }
    }

    private var composerBlock: some View {
        VStack(spacing: 0) {
            composer
                .frame(maxWidth: hasActiveConversation ? .infinity : 760)

            if !hasActiveConversation, !recentHistoryConversations.isEmpty {
                recentConversationsSection
                    .padding(.top, 28)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recentConversationsSection: some View {
        VStack(spacing: 2) {
            ForEach(previewRecentConversations) { conversation in
                HelpDeskRecentConversationRow(
                    title: conversation.title,
                    select: { store.selectHelpDeskConversation(id: conversation.id) }
                )
            }

            if !overflowRecentConversations.isEmpty {
                Button {
                    isRecentChatsPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Text("Show more")
                            .font(.system(size: 12.5, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(.secondary.opacity(isShowMoreHovered ? 0.92 : 0.58))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isShowMoreHovered = hovering
                    }
                }
                .popover(isPresented: $isRecentChatsPopoverPresented, arrowEdge: .top) {
                    recentConversationsOverflowPopover
                }
            }
        }
        .frame(maxWidth: 420)
    }

    private var recentConversationsOverflowPopover: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(overflowRecentConversations) { conversation in
                HelpDeskRecentConversationRow(
                    title: conversation.title,
                    select: {
                        store.selectHelpDeskConversation(id: conversation.id)
                        isRecentChatsPopoverPresented = false
                    }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let selectedConversation, !selectedConversation.messages.isEmpty {
                        ForEach(selectedConversation.messages) { message in
                            HelpDeskMessageBubble(
                                message: message,
                                openLinkedNote: { store.openLinkedNote(named: $0) },
                                imageURL: store.markdownImageURL,
                                imageData: store.markdownImageData,
                                isActionDisabled: store.isGeneratingHelpDeskResponse,
                                currentPageTitle: store.title,
                                currentStatus: store.status,
                                markdownSuggestion: store.areHelpDeskSuggestionsEnabled(
                                    for: selectedConversation.id
                                )
                                ? store.helpDeskMarkdownSuggestions.first { $0.messageID == message.id }
                                : nil,
                                onRegenerate: {
                                    store.regenerateHelpDeskResponse(assistantMessageID: message.id)
                                },
                                onAddToMarkdown: {
                                    store.addHelpDeskMessageToMarkdown(messageID: message.id)
                                },
                                setLiveStatus: { status in
                                    store.status = status
                                },
                                restoreLiveStatusIfCurrent: { previousStatus, hoverStatus in
                                    if store.status == hoverStatus {
                                        store.status = previousStatus
                                    }
                                },
                                onApplyMarkdownSuggestion: {
                                    store.applyHelpDeskMarkdownSuggestion(messageID: message.id)
                                },
                                onDismissMarkdownSuggestion: {
                                    store.dismissHelpDeskMarkdownSuggestion(messageID: message.id)
                                },
                                onDisableSuggestionsForSession: {
                                    store.disableHelpDeskSuggestionsForCurrentSession()
                                },
                                onDeleteExchange: {
                                    store.deleteHelpDeskExchange(assistantMessageID: message.id)
                                }
                            )
                            .id(message.id)
                        }
                    }

                    if store.isGeneratingHelpDeskResponse {
                        HelpDeskThinkingBubble()
                            .id("thinking")
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 18)
                .padding(.bottom, helpDeskMessageScrollBottomInset)
            }
            .onChange(of: selectedConversation?.messages.count ?? 0) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: store.isGeneratingHelpDeskResponse) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Zirn Chat")
                .font(.custom(AppFont.ptSerifRegular, size: AppFont.chatHeaderTitleSize))

            conversationMenu

            Spacer()

            Button {
                store.startNewHelpDeskConversation()
            } label: {
                HStack(spacing: 7) {
                    Text("New")
                    Image(systemName: "plus")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.black.opacity(0.86))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background {
                    Capsule()
                        .fill(.white.opacity(isNewHovered ? 0.96 : 0.88))
                        .overlay {
                            Capsule()
                                .fill(.ultraThinMaterial.opacity(isNewHovered ? 0.35 : 0.18))
                        }
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.48), lineWidth: 0.8)
                        }
                        .shadow(color: .white.opacity(isNewHovered ? 0.24 : 0.08), radius: isNewHovered ? 11 : 4)
                }
            }
            .buttonStyle(.plain)
            .help("Start new conversation")
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isNewHovered = hovering
                }
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 22)
    }

    private var chatModelSwitch: some View {
        ProviderLogoSwitch(
            selection: selectedChatModelBinding,
            options: AssistantModel.allCases,
            title: { $0.title },
            imageName: { $0.providerLogoAssetName }
        )
        .scaleEffect(0.88)
        .frame(width: 68, height: 30)
        .disabled(store.isGeneratingHelpDeskResponse)
        .opacity(store.isGeneratingHelpDeskResponse ? 0.48 : 1)
        .help("Choose the model Zirn Chat uses")
    }

    private var selectedChatModelBinding: Binding<AssistantModel> {
        Binding(
            get: { store.selectedAssistantModel },
            set: { store.selectAssistantModel($0) }
        )
    }

    private var conversationMenu: some View {
        Button {
            isConversationPopoverPresented.toggle()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary.opacity(isConversationMenuHovered ? 0.95 : 0.72))
                .frame(width: 18, height: 28)
        }
        .buttonStyle(.plain)
        .help("Conversation history")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isConversationMenuHovered = hovering
            }
        }
        .popover(isPresented: $isConversationPopoverPresented, arrowEdge: .bottom) {
            conversationPopover
        }
    }

    private var conversationPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            if historyConversations.isEmpty {
                HStack(spacing: 9) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("No history")
                        .font(.system(size: 13.5, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(height: 38)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(historyConversations) { conversation in
                            HelpDeskConversationMenuRow(
                                conversation: conversation,
                                isSelected: conversation.id == store.selectedHelpDeskConversationID,
                                select: {
                                    store.selectHelpDeskConversation(id: conversation.id)
                                    isConversationPopoverPresented = false
                                },
                                delete: {
                                    store.deleteHelpDeskConversation(id: conversation.id)
                                }
                            )
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let attachment = store.helpDeskAttachment {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                    Text(attachment.fileName)
                        .lineLimit(1)
                    Button {
                        store.removeHelpDeskAttachment()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .fill(.white.opacity(0.07))
                        }
                        .overlay {
                            Capsule()
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                chatModelSwitch

                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 1, height: 22)

                ZStack(alignment: .topLeading) {
                    HelpDeskPromptInputView(
                        text: $store.helpDeskInput,
                        selectionRange: $helpDeskInputSelectionRange,
                        contentHeight: $helpDeskComposerContentHeight,
                        onSubmit: { store.submitHelpDeskPrompt() }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: helpDeskComposerContentHeight)
                    .animation(.smooth(duration: 0.28), value: helpDeskComposerContentHeight)

                    if store.helpDeskInput.isEmpty {
                        Text("Ask the vault")
                            .font(.system(size: HelpDeskComposerMetrics.fontSize))
                            .foregroundStyle(.secondary.opacity(0.68))
                            .padding(.top, HelpDeskComposerMetrics.textVerticalInset)
                            .allowsHitTesting(false)
                    }
                }

                Button {
                    store.chooseHelpDeskAttachmentFromUser()
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(isUploadHovered ? 0.95 : 0.66))
                        .frame(width: 30, height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(isUploadHovered ? 0.09 : 0))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(isUploadHovered ? 0.12 : 0), lineWidth: 0.8)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Upload context")
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.14)) {
                        isUploadHovered = hovering
                    }
                }

                Button {
                    store.submitHelpDeskPrompt()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(canSend ? (isSendHovered ? .white : Color.accentColor) : .secondary.opacity(0.55))
                        .frame(width: 30, height: 32)
                        .background {
                            if canSend && isSendHovered {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.78))
                            }
                        }
                        .overlay {
                            if canSend && (isSendHovered || store.isGeneratingHelpDeskResponse) {
                                AnimatedThinkingBorder(lineWidth: 0.7)
                                    .clipShape(Circle())
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.14)) {
                        isSendHovered = hovering
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if store.isGeneratingHelpDeskResponse {
                    AnimatedThinkingBorder(cornerRadius: 18)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
            }
            .shadow(
                color: .black.opacity(hasActiveConversation ? 0.22 : 0.08),
                radius: hasActiveConversation ? 18 : 6,
                y: hasActiveConversation ? 10 : 3
            )
        }
    }

    private var canSend: Bool {
        (!store.helpDeskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.helpDeskAttachment != nil)
            && !store.isGeneratingHelpDeskResponse
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if store.isGeneratingHelpDeskResponse {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let lastID = selectedConversation?.messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct HelpDeskConversationMenuRow: View {
    let conversation: HelpDeskConversation
    let isSelected: Bool
    let select: () -> Void
    let delete: () -> Void

    @State private var isRowHovered = false
    @State private var isDeleteHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: select) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark" : "bubble.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 16)
                    Text(conversation.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                }
                .foregroundStyle(.primary.opacity(isRowHovered ? 0.96 : 0.82))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: delete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(isDeleteHovered ? .red : .secondary.opacity(0.72))
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(Color.red.opacity(isDeleteHovered ? 0.16 : 0))
                    }
            }
            .buttonStyle(.plain)
            .help("Delete conversation")
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isDeleteHovered = hovering
                }
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, 5)
        .frame(height: 36)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isRowHovered = hovering
            }
        }
    }

    private var rowBackground: Color {
        if isDeleteHovered {
            return Color.red.opacity(0.08)
        }
        if isRowHovered || isSelected {
            return Color.white.opacity(0.08)
        }
        return Color.clear
    }
}

private struct HelpDeskMessageBubble: View {
    let message: HelpDeskMessage
    let openLinkedNote: (String) -> Void
    let imageURL: (String) -> URL?
    let imageData: (String) -> Data?
    let isActionDisabled: Bool
    let currentPageTitle: String
    let currentStatus: String
    let markdownSuggestion: HelpDeskMarkdownSuggestion?
    let onRegenerate: () -> Void
    let onAddToMarkdown: () -> Void
    let setLiveStatus: (String) -> Void
    let restoreLiveStatusIfCurrent: (String, String) -> Void
    let onApplyMarkdownSuggestion: () -> Void
    let onDismissMarkdownSuggestion: () -> Void
    let onDisableSuggestionsForSession: () -> Void
    let onDeleteExchange: () -> Void
    @State private var isRegenerateHovered = false
    @State private var isAddToMarkdownHovered = false
    @State private var isDeleteHovered = false
    @State private var isCopyHovered = false
    @State private var didCopyMessage = false
    @State private var addToMarkdownPreviousStatus: String?

    private var isFollowUpStatusMessage: Bool {
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.hasPrefix("Added to ")
            || text.hasPrefix("Created **")
            || text.hasPrefix("I could not add")
            || text.hasPrefix("I could not create")
            || text.hasPrefix("Okay —")
            || text.hasPrefix("I could not find an existing page")
    }

    private var addToPageHoverStatus: String {
        let trimmedTitle = currentPageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Add to this page" : "Add to \(trimmedTitle)"
    }

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 90)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let attachmentName = message.attachmentName {
                    Label(attachmentName, systemImage: "paperclip")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                MarkdownPreview(
                    content: message.content,
                    searchHighlight: nil,
                    openLinkedNote: openLinkedNote,
                    imageURL: imageURL,
                    imageData: imageData,
                    showsCodeCopyButton: true
                )
                .textSelection(.enabled)

                if message.role == .assistant, let markdownSuggestion {
                    HelpDeskMarkdownSuggestionBox(
                        suggestion: markdownSuggestion,
                        isActionDisabled: isActionDisabled,
                        onApply: onApplyMarkdownSuggestion,
                        onDismiss: onDismissMarkdownSuggestion,
                        onDisableForSession: onDisableSuggestionsForSession
                    )
                }

                if message.role == .assistant {
                    assistantActions
                }
            }
            .padding(.horizontal, message.role == .user ? 14 : 0)
            .padding(.vertical, message.role == .user ? 10 : 0)
            .background {
                if message.role == .user {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .frame(maxWidth: message.role == .user ? 520 : .infinity, alignment: .leading)

            if message.role == .assistant {
                Spacer(minLength: 90)
            }
        }
    }

    @ViewBuilder
    private var assistantActions: some View {
        HStack(spacing: 10) {
            if !isFollowUpStatusMessage {
                Button(action: onRegenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(isRegenerateHovered ? 0.95 : 0.72))
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color.primary.opacity(isRegenerateHovered ? 0.08 : 0.04))
                        }
                }
                .buttonStyle(.plain)
                .disabled(isActionDisabled)
                .help("Regenerate")
                .onHover { isRegenerateHovered = $0 }

                Button(action: onAddToMarkdown) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(isAddToMarkdownHovered ? 0.95 : 0.72))
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color.primary.opacity(isAddToMarkdownHovered ? 0.08 : 0.04))
                        }
                }
                .buttonStyle(.plain)
                .disabled(isActionDisabled)
                .help("Add to markdown document")
                .onHover { hovering in
                    isAddToMarkdownHovered = hovering
                    updateAddToMarkdownHoverStatus(isHovering: hovering)
                }

                Button {
                    copyTextToPasteboard(message.content)
                    didCopyMessage = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        didCopyMessage = false
                    }
                } label: {
                    Image(systemName: didCopyMessage ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(isCopyHovered ? 0.95 : 0.72))
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color.primary.opacity(isCopyHovered ? 0.08 : 0.04))
                        }
                }
                .buttonStyle(.plain)
                .help("Copy answer")
                .onHover { isCopyHovered = $0 }

                Button(action: onDeleteExchange) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(isDeleteHovered ? 0.95 : 0.72))
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(Color.primary.opacity(isDeleteHovered ? 0.08 : 0.04))
                        }
                }
                .buttonStyle(.plain)
                .disabled(isActionDisabled)
                .help("Delete question and answer")
                .onHover { isDeleteHovered = $0 }
            }
        }
        .padding(.top, 2)
    }

    private func updateAddToMarkdownHoverStatus(isHovering: Bool) {
        let hoverStatus = addToPageHoverStatus
        if isHovering {
            addToMarkdownPreviousStatus = currentStatus
            setLiveStatus(hoverStatus)
        } else {
            if let previousStatus = addToMarkdownPreviousStatus {
                restoreLiveStatusIfCurrent(previousStatus, hoverStatus)
            }
            addToMarkdownPreviousStatus = nil
        }
    }
}

private func copyTextToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

private struct HelpDeskMarkdownSuggestionBox: View {
    let suggestion: HelpDeskMarkdownSuggestion
    let isActionDisabled: Bool
    let onApply: () -> Void
    let onDismiss: () -> Void
    let onDisableForSession: () -> Void

    private var suggestionMessage: AttributedString {
        var message = AttributedString()

        switch suggestion.action {
        case .appendToExisting:
            message.append(AttributedString("Add this answer to "))
        case .createNew:
            message.append(AttributedString("No matching page found. Create "))
        }

        var pageTitle = AttributedString(suggestion.pageTitle)
        pageTitle.font = .system(size: 13, weight: .semibold)
        message.append(pageTitle)

        switch suggestion.action {
        case .appendToExisting:
            message.append(AttributedString("?"))
        case .createNew:
            message.append(AttributedString(" with this answer?"))
        }

        return message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suggested page", systemImage: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.78))

            if suggestion.isLoading {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Finding the best page in your vault...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Button("Don't suggest in this session", action: onDisableForSession)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .disabled(isActionDisabled)
                }
            } else {
                Text(suggestionMessage)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button(primaryActionTitle, action: onApply)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(isActionDisabled)

                        Button("Dismiss", action: onDismiss)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isActionDisabled)
                    }

                    Button("Don't suggest in this session", action: onDisableForSession)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .disabled(isActionDisabled)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.22))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.yellow.opacity(0.44), lineWidth: 1)
        }
        .padding(.top, 4)
    }

    private var primaryActionTitle: String {
        switch suggestion.action {
        case .appendToExisting:
            return "Add to page"
        case .createNew:
            return "Create page"
        }
    }
}

private struct HelpDeskStartBrandView: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10.5, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

            Text("Zirn Chat")
                .font(.custom(AppFont.ptSerifRegular, size: AppFont.chatBrandTitleSize))
                .foregroundStyle(.primary.opacity(0.92))
        }
    }
}

private struct HelpDeskRecentConversationRow: View {
    let title: String
    let select: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary.opacity(isHovered ? 0.92 : 0.56))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct HelpDeskThinkingBubble: View {
    var body: some View {
        HStack {
            ThinkingStatusPill()
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct HelpDeskConversationBrowser: View {
    let conversations: [HelpDeskConversation]
    let selectedID: HelpDeskConversation.ID?
    @Binding var searchQuery: String
    let select: (HelpDeskConversation.ID) -> Void
    let startNew: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var filteredConversations: [HelpDeskConversation] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return conversations }
        return conversations.filter { conversation in
            conversation.title.lowercased().contains(query)
                || conversation.messages.contains { $0.content.lowercased().contains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Conversations")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Button {
                    startNew()
                    dismiss()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search conversations", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredConversations) { conversation in
                        Button {
                            select(conversation.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: conversation.id == selectedID ? "checkmark.circle.fill" : "bubble.left")
                                    .foregroundStyle(conversation.id == selectedID ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("\(conversation.messages.count) messages")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.primary.opacity(conversation.id == selectedID ? 0.10 : 0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
    }
}

private struct ReadOnlyHighlightSummaryView: View {
    let summary: HighlightSummary
    let openLinkedNote: (String) -> Void
    let imageURL: (String) -> URL?
    let imageData: (String) -> Data?

    var body: some View {
        ScrollView {
            MarkdownPreview(
                content: summary.markdown,
                searchHighlight: nil,
                openLinkedNote: openLinkedNote,
                imageURL: imageURL,
                imageData: imageData
            )
            .padding(.vertical, 8)
            .textSelection(.enabled)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct HomePageView: View {
    @ObservedObject var store: BrainStore
    let presentation: HomePagePresentation
    let isGenerating: Bool
    let generationDate: Date?
    let openNote: (Note.ID) -> Void
    @State private var isGraphExpanded = false

    private let pageCardColumns = [
        GridItem(.flexible(minimum: 220), spacing: 14),
        GridItem(.flexible(minimum: 220), spacing: 14)
    ]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Home")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 8)

                    if isGenerating {
                        HomeGenerationInlineBlocks()
                            .id(generationDate ?? Date.distantFuture)
                    } else {
                        vaultSummarySection
                        vaultGraphSection
                        pageCardsSection
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.24), value: isGenerating)

            if isGraphExpanded {
                ExpandedGraphOverlay(
                    notes: store.notes,
                    links: store.graphLinks,
                    selectedNoteID: store.currentNoteID,
                    openNote: { noteID in
                        openNote(noteID)
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isGraphExpanded = false
                        }
                    },
                    close: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isGraphExpanded = false
                        }
                    }
                )
                .transition(.scale(scale: 0.985).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isGraphExpanded)
    }

    private var vaultSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.system(size: 22, weight: .bold))

            if presentation.vaultSummary.isEmpty {
                Text("No summary yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary.opacity(0.88))
            } else {
                MarkdownPreview(
                    content: presentation.vaultSummary,
                    searchHighlight: nil,
                    openLinkedNote: { store.openLinkedNote(named: $0) }
                )
                .foregroundStyle(.primary.opacity(0.88))
                .textSelection(.enabled)
            }
        }
    }

    private var vaultGraphSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vault Map")
                .font(.system(size: 22, weight: .bold))

            NoteGraphView(
                notes: store.notes,
                links: store.graphLinks,
                selectedNoteID: store.currentNoteID,
                maxVisibleNotes: nil,
                openNote: openNote,
                expand: {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isGraphExpanded = true
                    }
                }
            )
            .frame(height: 240)
        }
    }

    @ViewBuilder
    private var pageCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Page Summaries")
                .font(.system(size: 22, weight: .bold))

            if presentation.pageCards.isEmpty {
                Text("No pages yet. Press ⌘N to start a new page.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: pageCardColumns, alignment: .leading, spacing: 14) {
                    ForEach(presentation.pageCards) { card in
                        HomePageSummaryCard(card: card, store: store, openNote: openNote)
                    }
                }
            }
        }
    }
}

private struct HomePageSummaryCard: View {
    let card: HomePagePageCard
    @ObservedObject var store: BrainStore
    let openNote: (Note.ID) -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(card.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    if let noteID = card.noteID {
                        Button {
                            openNote(noteID)
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open page")
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 20, height: 24)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Collapse summary" : "Show full summary")
                }

                HomeInlineMarkdownText(card.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 5)
                    .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: isExpanded ? nil : 120, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? 0.14 : 0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovered ? 0.10 : 0.04), radius: isHovered ? 10 : 4, y: 3)
        .onHover { isHovered = $0 }
    }
}

private struct HomePageCardFlashcardPanel: View {
    let state: PageFlashcardState
    let regenerate: () -> Void
    let goTo: (String?) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Idea Flashcards", systemImage: "lightbulb")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.86))

                Spacer(minLength: 0)

                Button(action: regenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Regenerate flashcards")

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close flashcards")
            }

            if state.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating from this page...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let bundle = state.bundle {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(bundle.cards) { card in
                        HomePageMiniFlashcard(card: card, goTo: { goTo(card.anchor) })
                    }
                }
            } else if state.errorMessage == nil {
                Text("No flashcards yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = state.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.red.opacity(0.86))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct EditorPageFlashcardView: View {
    let state: PageFlashcardState
    let regenerate: () -> Void
    let goTo: (String?) -> Void

    private var displayBundle: PageFlashcardBundle? {
        guard let bundle = state.bundle,
              bundle.modelTitle != "Local instant flashcards"
        else { return nil }
        return bundle
    }

    private var cards: [PageFlashcard] {
        displayBundle?.cards ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if state.isLoading {
                    loadingRow
                }

                if cards.isEmpty && !state.isLoading && state.errorMessage == nil {
                    emptyState
                }

                if !cards.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(cards) { card in
                            EditorPageFlashcardCard(card: card, goTo: { goTo(card.anchor) })
                        }
                    }
                }

                if let errorMessage = state.errorMessage {
                    errorRow(errorMessage)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 42)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Idea Flashcards", systemImage: "lightbulb")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.90))

                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 18)

            Button(action: regenerate) {
                Label(state.isLoading ? "Checking" : "Regenerate", systemImage: "arrow.clockwise")
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(state.isLoading)
            .help("Regenerate if the page changed enough")
        }
    }

    private var subtitle: String {
        if let bundle = displayBundle {
            return "\(bundle.cards.count) cards for \(bundle.noteTitle)"
        }

        if state.isLoading {
            return "Generating flashcards for this page."
        }

        return "Generated flashcards for this page will appear here."
    }

    private var loadingRow: some View {
        HStack(spacing: 9) {
            ProgressView()
                .controlSize(.small)
            Text(cards.isEmpty ? "Loading flashcards from this page..." : "Checking whether flashcards need an update...")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No flashcards yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
            Text("Use Regenerate to create cards for this page.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func errorRow(_ errorMessage: String) -> some View {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red.opacity(0.86))
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct EditorPageFlashcardCard: View {
    let card: PageFlashcard
    let goTo: () -> Void
    @State private var showsAnswer = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button {
                withAnimation(.easeOut(duration: 0.14)) {
                    showsAnswer.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Question")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Label(showsAnswer ? "Hide answer" : "Show answer", systemImage: showsAnswer ? "eye.slash" : "eye")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.88))
                    }

                    HomeInlineMarkdownText(card.question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    if showsAnswer {
                        Divider().opacity(0.36)
                        Text("Answer")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        HomeInlineMarkdownText(card.answer)
                            .font(.system(size: 13.5))
                            .foregroundStyle(.primary.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Text("Tap to reveal answer")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.78))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(isHovered ? 0.062 : 0.042))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(isHovered ? 0.13 : 0.075), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            Button(action: goTo) {
                Label("Go to source", systemImage: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct HomePageMiniFlashcard: View {
    let card: PageFlashcard
    let goTo: () -> Void
    @State private var showsAnswer = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.14)) {
                    showsAnswer.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Question")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Label(showsAnswer ? "Hide answer" : "Show answer", systemImage: showsAnswer ? "eye.slash" : "eye")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.86))
                    }

                    HomeInlineMarkdownText(card.question)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)

                    if showsAnswer {
                        Divider().opacity(0.35)
                        Text("Answer")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.secondary)
                        HomeInlineMarkdownText(card.answer)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.primary.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Text("Tap to reveal answer")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.80))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(isHovered ? 0.065 : 0.045))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(isHovered ? 0.13 : 0.07), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            Button(action: goTo) {
                Label("Go to", systemImage: "arrow.up.right")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct HomeFlashcardGroupAccordion: View {
    let group: HomePageFlashcardGroup
    let isExpanded: Bool
    let toggle: () -> Void
    @State private var isHeaderHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(group.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(group.cards.count) cards")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.yellow.opacity(isHeaderHovered ? 0.18 : 0.12))
            }
            .buttonStyle(.plain)
            .onHover { isHeaderHovered = $0 }

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(group.cards) { card in
                        HomeFlashcardView(card: card)
                    }
                }
                .padding(14)
                .background(Color.yellow.opacity(0.08))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.yellow.opacity(0.34), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.16), value: isExpanded)
    }
}

private struct HomeFlashcardView: View {
    let card: HomePageFlashcard
    @State private var showsAnswer = false
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.14)) {
                showsAnswer.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Question")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                HomeInlineMarkdownText(card.question)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if showsAnswer {
                    Divider().opacity(0.35)
                    Text("Answer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    HomeInlineMarkdownText(card.answer)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.88))
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                } else {
                    Text("Tap to reveal answer")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.82))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(isHovered ? 0.12 : 0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct HomeInlineMarkdownText: View {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        if let attributed = try? AttributedString(markdown: normalizedMarkdown) {
            Text(attributed)
        } else {
            Text(plainText(from: normalizedMarkdown))
        }
    }

    private var normalizedMarkdown: String {
        plainText(from: content)
            .replacingOccurrences(
                of: #"\[\[([^\]\|]+)\|([^\]]+)\]\]"#,
                with: "$2",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\[\[([^\]]+)\]\]"#,
                with: "$1",
                options: .regularExpression
            )
    }

    private func plainText(from markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"(?s)%%.*?%%"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?s)==(.+?)=="#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"</?u>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?s)\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?s)__(.+?)__"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?s)~~(.+?)~~"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
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
    let editorBottomInset: CGFloat
    let previewBottomInset: CGFloat
    let searchHighlight: SearchHighlight?
    let noteTitles: [String]
    let relevanceCandidates: [MarkdownRelevanceCandidate]
    let openLinkedNote: (String) -> Void
    let clearSearchHighlight: () -> Void
    let imageURL: (String) -> URL?
    let imageData: (String) -> Data?
    let insertImageFile: (URL) -> Void
    let insertImageData: (Data, String?) -> Void
    let highlightRequestID: Int
    @Binding var typingStatus: MarkdownTypingStatus
    @State private var suggestionAnchor: CGPoint?
    @State private var relevanceAnchor: CGPoint?
    @State private var dismissedRelevanceSuggestionID: String?
    @State private var idleRelevanceSuggestionID: String?
    @State private var relevanceSuggestionPauseTask: Task<Void, Never>?
    @State private var suppressedWikiSuggestionContent = ""
    @State private var suppressedWikiSuggestionCaret = -1
    @State private var editorSelectionRange = NSRange(location: 0, length: 0)
    @State private var markdownViewportOrigin: CGPoint = .zero
    @State private var editorVisibleSourceLocation = 0
    @State private var previewScrollBlockID: Int?
    @State private var pendingPreviewScrollBlockID: Int?
    @State private var modeSurfaceOpacity = 1.0
    private static let relevanceSuggestionPauseNanoseconds: UInt64 = 700_000_000
    private static let modeSwitchAnimation = Animation.easeInOut(duration: 0.16)

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
        .opacity(modeSurfaceOpacity)
        .animation(Self.modeSwitchAnimation, value: modeSurfaceOpacity)
        .onExitCommand {
            setEditing(false)
        }
        .onChange(of: isReadOnly) { _, readOnly in
            if readOnly {
                syncPreviewScrollToEditorViewport()
                setEditing(false)
            }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing {
                syncPreviewScrollToEditorViewport()
            }
        }
        .onChange(of: highlightRequestID) { _, _ in
            guard isReadOnly else { return }
            highlightRenderedSelection()
        }
    }

    private var editor: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                let relevanceSuggestion = visibleRelevanceSuggestion

                InlineMarkdownEditor(
                    text: $content,
                    selectionRange: $editorSelectionRange,
                    typingStatus: $typingStatus,
                    bottomContentInset: editorBottomInset,
                    linkTabCompletionTitle: linkSuggestions.first,
                    suggestionRange: activeSuggestionNSRange,
                    suggestionAnchor: $suggestionAnchor,
                    relevanceHighlightRange: relevanceSuggestion?.phraseRange,
                    relevanceAnchor: $relevanceAnchor,
                    insertImageData: insertImageData,
                    isEditable: true,
                    allowsReadOnlyHighlighting: false,
                    viewportOrigin: $markdownViewportOrigin,
                    visibleSourceLocation: $editorVisibleSourceLocation,
                    finishEditing: {
                        setEditing(false)
                    }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onDisappear {
                        syncPreviewScrollToEditorViewport()
                    }

                if activeWikiLinkContext == nil,
                   let relevanceSuggestion,
                   let relevanceAnchor {
                    RelevanceSuggestionPill(
                        title: relevanceSuggestion.title,
                        apply: { applyRelevanceSuggestion(relevanceSuggestion) },
                        dismiss: { dismissedRelevanceSuggestionID = relevanceSuggestion.id }
                    )
                        .position(
                            x: min(max(112, relevanceAnchor.x), max(112, proxy.size.width - 112)),
                            y: max(24, relevanceAnchor.y - 30)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(2)
                }

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
        .animation(.easeInOut(duration: 0.16), value: visibleRelevanceSuggestion?.id)
        .onAppear {
            scheduleRelevanceSuggestionPause()
        }
        .onChange(of: activeRelevanceSuggestion?.id) { _, newID in
            if newID != dismissedRelevanceSuggestionID {
                dismissedRelevanceSuggestionID = nil
            }
            scheduleRelevanceSuggestionPause()
        }
        .onChange(of: content) { _, _ in
            scheduleRelevanceSuggestionPause()
        }
        .onChange(of: editorSelectionRange) { _, _ in
            scheduleRelevanceSuggestionPause()
        }
        .onDisappear {
            relevanceSuggestionPauseTask?.cancel()
            relevanceSuggestionPauseTask = nil
        }
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

    private var activeRelevanceSuggestion: MarkdownRelevanceSuggestion? {
        guard activeWikiLinkContext == nil else { return nil }
        return Self.relevanceSuggestion(
            in: content,
            selectionRange: editorSelectionRange,
            candidates: relevanceCandidates
        )
    }

    private var visibleRelevanceSuggestion: MarkdownRelevanceSuggestion? {
        guard let suggestion = activeRelevanceSuggestion,
              suggestion.id == idleRelevanceSuggestionID,
              suggestion.id != dismissedRelevanceSuggestionID
        else { return nil }
        return suggestion
    }

    private func scheduleRelevanceSuggestionPause() {
        relevanceSuggestionPauseTask?.cancel()
        relevanceSuggestionPauseTask = nil
        idleRelevanceSuggestionID = nil

        guard activeWikiLinkContext == nil,
              let suggestion = activeRelevanceSuggestion
        else { return }

        let suggestionID = suggestion.id
        relevanceSuggestionPauseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.relevanceSuggestionPauseNanoseconds)
            guard !Task.isCancelled else { return }
            idleRelevanceSuggestionID = suggestionID
        }
    }

    private var linkSuggestionMenuHeight: CGFloat {
        CGFloat(linkSuggestions.count) * 30
            + CGFloat(max(0, linkSuggestions.count - 1)) * 4
            + 38
    }

    private var renderedPreview: some View {
        Group {
            if isReadOnly {
                renderedPreviewScroll
            } else {
                renderedPreviewScroll
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if searchHighlight != nil {
                            clearSearchHighlight()
                        } else {
                            syncEditorSelectionToPreviewViewport()
                            setEditing(true)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
    }

    private var renderedPreviewScroll: some View {
        ScrollViewReader { reader in
            ScrollView {
                Group {
                    if isReadOnly {
                        renderedMarkdownPreview
                            .textSelection(.enabled)
                    } else {
                        renderedMarkdownPreview
                            .textSelection(.disabled)
                    }
                }
                    .padding(.horizontal, 26)
                    .padding(.top, 2)
                    .padding(.bottom, 24 + previewBottomInset)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollPosition(id: $previewScrollBlockID)
            .onAppear {
                scrollToPendingPreviewBlock(with: reader)
            }
            .onChange(of: pendingPreviewScrollBlockID) { _, _ in
                scrollToPendingPreviewBlock(with: reader)
            }
            .onChange(of: searchHighlight) { _, highlight in
                guard let highlight else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    reader.scrollTo(highlight.blockIndex, anchor: .center)
                }
            }
        }
    }

    private var renderedMarkdownPreview: some View {
        MarkdownPreview(
            content: content,
            searchHighlight: searchHighlight,
            openLinkedNote: openLinkedNote,
            imageURL: imageURL,
            imageData: imageData
        )
    }

    private func setEditing(_ editing: Bool) {
        guard isEditing != editing else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            modeSurfaceOpacity = 0.74
            isEditing = editing
        }

        DispatchQueue.main.async {
            withAnimation(Self.modeSwitchAnimation) {
                modeSurfaceOpacity = 1
            }
        }
    }

    private func syncEditorSelectionToPreviewViewport() {
        guard let previewScrollBlockID,
              let block = MarkdownBlock.parse(content).first(where: { $0.id == previewScrollBlockID })
        else { return }

        editorSelectionRange = NSRange(location: block.sourceLocation, length: 0)
        editorVisibleSourceLocation = block.sourceLocation
        markdownViewportOrigin = .zero
    }

    private func syncPreviewScrollToEditorViewport() {
        guard let blockID = markdownBlockID(containing: editorVisibleSourceLocation) else { return }
        previewScrollBlockID = blockID
        pendingPreviewScrollBlockID = blockID
    }

    private func scrollToPendingPreviewBlock(with reader: ScrollViewProxy) {
        guard let blockID = pendingPreviewScrollBlockID else { return }
        DispatchQueue.main.async {
            reader.scrollTo(blockID, anchor: .top)
            pendingPreviewScrollBlockID = nil
        }
    }

    private func markdownBlockID(containing sourceLocation: Int) -> Int? {
        let blocks = MarkdownBlock.parse(content)
        guard !blocks.isEmpty else { return nil }
        let clampedLocation = min(max(0, sourceLocation), (content as NSString).length)
        return blocks.last(where: { $0.sourceLocation <= clampedLocation })?.id ?? blocks.first?.id
    }

    private func highlightRenderedSelection() {
        let pasteboard = NSPasteboard.general
        let previousItems = Self.copiedPasteboardItems(from: pasteboard)

        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)

        DispatchQueue.main.async {
            defer {
                Self.restorePasteboardItems(previousItems, to: pasteboard)
            }

            guard let selectedText = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !selectedText.isEmpty
            else { return }

            applyRenderedHighlight(for: selectedText)
        }
    }

    private func applyRenderedHighlight(for selectedText: String) {
        guard let range = markdownRangeMatchingRenderedSelection(selectedText),
              let swiftRange = Range(range, in: content)
        else { return }

        let rawText = content as NSString
        let selectedSource = rawText.substring(with: range)
        let replacement: String
        let newSelection: NSRange

        if selectedSource.hasPrefix("=="), selectedSource.hasSuffix("=="), selectedSource.count >= 4 {
            replacement = String(selectedSource.dropFirst(2).dropLast(2))
            newSelection = NSRange(location: range.location, length: (replacement as NSString).length)
        } else {
            replacement = "==\(selectedSource)=="
            newSelection = NSRange(location: range.location + 2, length: (selectedSource as NSString).length)
        }

        content.replaceSubrange(swiftRange, with: replacement)
        editorSelectionRange = newSelection
        typingStatus.isHighlight = true
    }

    private func markdownRangeMatchingRenderedSelection(_ selectedText: String) -> NSRange? {
        let source = content as NSString
        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let exactRange = source.range(of: trimmed)
        if exactRange.location != NSNotFound {
            return Self.trimmedRange(in: source, range: exactRange)
        }

        let tokens = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        let pattern = tokens
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: #"\s+"#)

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let fullRange = NSRange(location: 0, length: source.length)
        return regex.firstMatch(in: content, range: fullRange)
            .flatMap { Self.trimmedRange(in: source, range: $0.range) }
    }

    private static func trimmedRange(in source: NSString, range: NSRange) -> NSRange? {
        guard range.location >= 0,
              range.upperBound <= source.length
        else { return nil }

        var location = range.location
        var upperBound = range.upperBound
        let whitespace = CharacterSet.whitespacesAndNewlines

        while location < upperBound,
              let scalar = UnicodeScalar(source.character(at: location)),
              whitespace.contains(scalar) {
            location += 1
        }

        while upperBound > location,
              let scalar = UnicodeScalar(source.character(at: upperBound - 1)),
              whitespace.contains(scalar) {
            upperBound -= 1
        }

        guard upperBound > location else { return nil }
        return NSRange(location: location, length: upperBound - location)
    }

    private static func copiedPasteboardItems(from pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }

    private static func restorePasteboardItems(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private var activeWikiLinkContext: WikiLinkSuggestionContext? {
        guard !content.isEmpty else { return nil }

        let utf16Length = (content as NSString).length
        let caretOffset = min(max(0, editorSelectionRange.location + editorSelectionRange.length), utf16Length)
        if suppressedWikiSuggestionCaret == caretOffset,
           suppressedWikiSuggestionContent == content {
            return nil
        }
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

    private func applyRelevanceSuggestion(_ suggestion: MarkdownRelevanceSuggestion) {
        let rawText = content as NSString
        guard suggestion.phraseRange.location >= 0,
              suggestion.phraseRange.upperBound <= rawText.length
        else { return }

        let phrase = rawText.substring(with: suggestion.phraseRange)
        let normalizedTitle = normalizedLinkSuggestionText(suggestion.title)
        let normalizedPhrase = normalizedLinkSuggestionText(phrase)
        let replacement = normalizedTitle == normalizedPhrase
            ? "[[\(suggestion.title)]]"
            : "[[\(suggestion.title)|\(phrase)]]"
        guard let range = Range(suggestion.phraseRange, in: content) else { return }

        content.replaceSubrange(range, with: replacement)
        let caretLocation = suggestion.phraseRange.location + (replacement as NSString).length
        editorSelectionRange = NSRange(location: caretLocation, length: 0)
        suppressedWikiSuggestionContent = content
        suppressedWikiSuggestionCaret = caretLocation
        suggestionAnchor = nil
        dismissedRelevanceSuggestionID = nil
        relevanceAnchor = nil
    }

    private static func relevanceSuggestion(
        in content: String,
        selectionRange: NSRange,
        candidates: [MarkdownRelevanceCandidate]
    ) -> MarkdownRelevanceSuggestion? {
        guard let phrase = activeRelevancePhrase(in: content, selectionRange: selectionRange) else { return nil }
        let isSelectedPhrase = selectionRange.length > 0
        let phraseTokens = Set(relevanceTokens(in: phrase.text))
        let minimumTokenCount = isSelectedPhrase ? 2 : 4
        let minimumCharacterCount = isSelectedPhrase ? 8 : 18
        guard phraseTokens.count >= minimumTokenCount || phrase.text.count >= minimumCharacterCount else { return nil }

        let normalizedPhrase = normalizedRelevanceText(phrase.text)
        guard !normalizedPhrase.isEmpty,
              !phrase.text.contains("[[")
        else { return nil }

        let scoreThreshold = isSelectedPhrase ? 0.46 : 0.58
        var bestSuggestion: MarkdownRelevanceSuggestion?
        for candidate in candidates {
            let titleTokens = Set(relevanceTokens(in: candidate.title))
            let bodyTokens = Set(relevanceTokens(in: candidate.text))
            guard !titleTokens.isEmpty || !bodyTokens.isEmpty else { continue }

            let normalizedTitle = normalizedRelevanceText(candidate.title)
            let titleContainmentScore: Double
            if normalizedTitle.count >= 6,
               (normalizedTitle.contains(normalizedPhrase) || normalizedPhrase.contains(normalizedTitle)) {
                titleContainmentScore = 0.86
            } else {
                titleContainmentScore = 0
            }

            let titleOverlap = overlapRatio(source: phraseTokens, candidate: titleTokens)
            let bodyOverlap = overlapRatio(source: phraseTokens, candidate: bodyTokens)
            let weightedOverlap = min(1, (0.72 * titleOverlap) + (0.28 * bodyOverlap))
            let bodyOnlyScore = 0.58 * bodyOverlap
            let score = max(titleContainmentScore, weightedOverlap, bodyOnlyScore)

            guard score >= scoreThreshold else { continue }

            let suggestion = MarkdownRelevanceSuggestion(
                candidateID: candidate.id,
                title: candidate.title,
                phrase: phrase.text,
                phraseRange: phrase.range,
                score: score
            )

            if let currentBest = bestSuggestion {
                if suggestion.score > currentBest.score {
                    bestSuggestion = suggestion
                }
            } else {
                bestSuggestion = suggestion
            }
        }

        return bestSuggestion
    }

    private static func activeRelevancePhrase(
        in content: String,
        selectionRange: NSRange
    ) -> (text: String, range: NSRange)? {
        let rawText = content as NSString
        guard rawText.length > 0 else { return nil }

        if selectionRange.length > 0,
           selectionRange.location >= 0,
           selectionRange.upperBound <= rawText.length {
            return trimmedRelevancePhrase(in: rawText, range: selectionRange)
        }

        let caret = min(max(0, selectionRange.location), rawText.length)
        if caret > 0,
           let previousScalar = UnicodeScalar(rawText.character(at: caret - 1)),
           CharacterSet.whitespacesAndNewlines.contains(previousScalar) {
            return nil
        }

        var start = caret
        let delimiters = CharacterSet.newlines.union(CharacterSet(charactersIn: ".;!?()[]{}<>|"))

        while start > 0, caret - start < 96 {
            guard let scalar = UnicodeScalar(rawText.character(at: start - 1)),
                  !delimiters.contains(scalar)
            else { break }
            start -= 1
        }

        return trimmedRelevancePhrase(
            in: rawText,
            range: NSRange(location: start, length: caret - start)
        )
    }

    private static func trimmedRelevancePhrase(
        in rawText: NSString,
        range: NSRange
    ) -> (text: String, range: NSRange)? {
        guard range.location >= 0,
              range.upperBound <= rawText.length,
              range.length > 0
        else { return nil }

        let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "#*-_`~= >"))
        var location = range.location
        var upperBound = range.upperBound

        while location < upperBound,
              let scalar = UnicodeScalar(rawText.character(at: location)),
              trimSet.contains(scalar) {
            location += 1
        }

        while upperBound > location,
              let scalar = UnicodeScalar(rawText.character(at: upperBound - 1)),
              trimSet.contains(scalar) {
            upperBound -= 1
        }

        let trimmedRange = NSRange(location: location, length: upperBound - location)
        guard trimmedRange.length >= 4 else { return nil }

        let text = rawText.substring(with: trimmedRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return (text, trimmedRange)
    }

    private static func relevanceTokens(in text: String) -> [String] {
        normalizedRelevanceText(text)
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                token.count >= 3 && !relevanceStopWords.contains(token)
            }
    }

    private static func normalizedRelevanceText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9_]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func overlapRatio(source: Set<String>, candidate: Set<String>) -> Double {
        guard !source.isEmpty, !candidate.isEmpty else { return 0 }
        let overlap = source.intersection(candidate).count
        let denominator = max(1, min(source.count, candidate.count))
        return Double(overlap) / Double(denominator)
    }

    private static let relevanceStopWords: Set<String> = [
        "the", "and", "for", "with", "from", "this", "that", "there", "their", "they",
        "you", "your", "are", "was", "were", "been", "being", "into", "onto", "about",
        "over", "under", "between", "different", "using", "used", "uses", "each", "such",
        "page", "note", "topic", "text", "when", "then", "than", "what", "which"
    ]

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
    let bottomContentInset: CGFloat
    let linkTabCompletionTitle: String?
    let suggestionRange: NSRange?
    @Binding var suggestionAnchor: CGPoint?
    let relevanceHighlightRange: NSRange?
    @Binding var relevanceAnchor: CGPoint?
    let insertImageData: (Data, String?) -> Void
    let isEditable: Bool
    let allowsReadOnlyHighlighting: Bool
    @Binding var viewportOrigin: CGPoint
    @Binding var visibleSourceLocation: Int
    let finishEditing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            selectionRange: $selectionRange,
            typingStatus: $typingStatus,
            suggestionAnchor: $suggestionAnchor,
            relevanceAnchor: $relevanceAnchor,
            relevanceHighlightRange: relevanceHighlightRange,
            insertImageData: insertImageData,
            isEditable: isEditable,
            allowsReadOnlyHighlighting: allowsReadOnlyHighlighting,
            viewportOrigin: $viewportOrigin,
            visibleSourceLocation: $visibleSourceLocation,
            finishEditing: finishEditing
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomContentInset, right: 0)

        let textView = MarkdownNSTextView()
        textView.commandHandler = context.coordinator
        textView.delegate = context.coordinator
        textView.string = text
        textView.drawsBackground = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.configureUndoLimit()
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
        context.coordinator.configureScrollTracking(in: scrollView)
        context.coordinator.textView = textView
        textView.setSelectedRange(Self.clamped(selectionRange, in: text))
        context.coordinator.applyMarkdownStyling()
        context.coordinator.restoreViewport(in: scrollView)
        context.coordinator.focusEditorOnce()

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
        context.coordinator.relevanceAnchor = $relevanceAnchor
        context.coordinator.finishEditing = finishEditing
        context.coordinator.isEditable = isEditable
        context.coordinator.allowsReadOnlyHighlighting = allowsReadOnlyHighlighting
        context.coordinator.viewportOrigin = $viewportOrigin
        context.coordinator.visibleSourceLocation = $visibleSourceLocation
        let didChangeRelevanceHighlight = context.coordinator.relevanceHighlightRange != relevanceHighlightRange
        context.coordinator.relevanceHighlightRange = relevanceHighlightRange
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomContentInset, right: 0)

        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.textView = textView
        context.coordinator.configureScrollTracking(in: scrollView)
        textView.isEditable = isEditable

        let didReplaceText = textView.string != text
        if didReplaceText {
            textView.string = text
        }

        let clampedSelection = Self.clamped(selectionRange, in: text)
        if didReplaceText || textView.selectedRange() != clampedSelection {
            textView.setSelectedRange(clampedSelection)
            if context.coordinator.hasStoredViewport {
                context.coordinator.restoreViewport(in: scrollView)
            } else if clampedSelection.location > 0 || clampedSelection.length > 0 {
                textView.scrollRangeToVisible(clampedSelection)
            }
        }

        if didReplaceText || didChangeRelevanceHighlight {
            context.coordinator.applyMarkdownStyling()
        }
        context.coordinator.updateSuggestionAnchor()
        context.coordinator.updateRelevanceAnchor()
        context.coordinator.publishVisibleSourceLocation(in: scrollView)
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
        var relevanceAnchor: Binding<CGPoint?>
        var insertImageData: (Data, String?) -> Void
        var isEditable: Bool
        var allowsReadOnlyHighlighting: Bool
        var viewportOrigin: Binding<CGPoint>
        var visibleSourceLocation: Binding<Int>
        var linkTabCompletionTitle: String?
        var suggestionRange: NSRange?
        var relevanceHighlightRange: NSRange?
        var finishEditing: () -> Void
        weak var textView: NSTextView?
        private var isApplyingMarkdownStyling = false
        private var pendingStylingWorkItem: DispatchWorkItem?
        private var didAutoFocusEditor = false
        private var activeInlineCommands: Set<MarkdownInlineCommand> = []
        private var scrollObservation: NSObjectProtocol?

        init(
            text: Binding<String>,
            selectionRange: Binding<NSRange>,
            typingStatus: Binding<MarkdownTypingStatus>,
            suggestionAnchor: Binding<CGPoint?>,
            relevanceAnchor: Binding<CGPoint?>,
            relevanceHighlightRange: NSRange?,
            insertImageData: @escaping (Data, String?) -> Void,
            isEditable: Bool,
            allowsReadOnlyHighlighting: Bool,
            viewportOrigin: Binding<CGPoint>,
            visibleSourceLocation: Binding<Int>,
            finishEditing: @escaping () -> Void
        ) {
            self.text = text
            self.selectionRange = selectionRange
            self.typingStatus = typingStatus
            self.suggestionAnchor = suggestionAnchor
            self.relevanceAnchor = relevanceAnchor
            self.relevanceHighlightRange = relevanceHighlightRange
            self.insertImageData = insertImageData
            self.isEditable = isEditable
            self.allowsReadOnlyHighlighting = allowsReadOnlyHighlighting
            self.viewportOrigin = viewportOrigin
            self.visibleSourceLocation = visibleSourceLocation
            self.finishEditing = finishEditing
        }

        deinit {
            if let scrollObservation {
                NotificationCenter.default.removeObserver(scrollObservation)
            }
        }

        var hasStoredViewport: Bool {
            abs(viewportOrigin.wrappedValue.x) > 0.5 || abs(viewportOrigin.wrappedValue.y) > 0.5
        }

        func configureScrollTracking(in scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            guard scrollObservation == nil else { return }
            scrollObservation = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] notification in
                guard let clipView = notification.object as? NSClipView else { return }
                self?.viewportOrigin.wrappedValue = clipView.bounds.origin
                if let scrollView = clipView.enclosingScrollView {
                    self?.publishVisibleSourceLocation(in: scrollView)
                }
            }
        }

        func restoreViewport(in scrollView: NSScrollView) {
            guard hasStoredViewport else { return }
            let documentBounds = scrollView.documentView?.bounds ?? .zero
            let visibleSize = scrollView.contentView.bounds.size
            let maxY = max(0, documentBounds.height - visibleSize.height)
            let maxX = max(0, documentBounds.width - visibleSize.width)
            let origin = CGPoint(
                x: min(max(0, viewportOrigin.wrappedValue.x), maxX),
                y: min(max(0, viewportOrigin.wrappedValue.y), maxY)
            )

            DispatchQueue.main.async {
                scrollView.contentView.scroll(to: origin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
                self.publishVisibleSourceLocation(in: scrollView)
            }
        }

        func publishVisibleSourceLocation(in scrollView: NSScrollView) {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let visibleOrigin = scrollView.contentView.bounds.origin
            let inset = textView.textContainerInset
            let point = CGPoint(
                x: inset.width + 1,
                y: visibleOrigin.y + inset.height + 1
            )
            let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let length = (textView.string as NSString).length
            let clampedIndex = min(max(0, characterIndex), length)

            if visibleSourceLocation.wrappedValue != clampedIndex {
                visibleSourceLocation.wrappedValue = clampedIndex
            }
        }

        func focusEditorOnce() {
            guard !didAutoFocusEditor else { return }
            didAutoFocusEditor = true

            DispatchQueue.main.async { [weak self] in
                guard let textView = self?.textView,
                      let window = textView.window,
                      window.firstResponder == nil || window.firstResponder === textView.enclosingScrollView
                else { return }

                window.makeFirstResponder(textView)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if text.wrappedValue != textView.string {
                text.wrappedValue = textView.string
            }
            publishSelection(from: textView, deferUpdate: true)
            updateTypingAttributesForCurrentLine(in: textView)
            scheduleMarkdownStyling()
            updateSuggestionAnchor()
            updateRelevanceAnchor()
        }

        func textDidEndEditing(_ notification: Notification) {
            DispatchQueue.main.async { [finishEditing] in
                finishEditing()
            }
        }

        func syncTextAndSelectionAfterUndoRedo(in textView: NSTextView) {
            text.wrappedValue = textView.string
            publishSelection(from: textView, deferUpdate: false)
            updateTypingAttributesForCurrentLine(in: textView)
            scheduleMarkdownStyling()
            updateSuggestionAnchor()
            updateRelevanceAnchor()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                clampDocumentTitleSelection(in: textView)
                publishSelection(from: textView)
                updateTypingAttributesForCurrentLine(in: textView)
            }
            updateSuggestionAnchor()
            updateRelevanceAnchor()
        }

        func pasteImageFromClipboard() -> Bool {
            guard let image = PasteboardImageReader.imagePayload(from: .general) else { return false }
            insertImageData(image.data, image.fileName)
            return true
        }

        private func publishSelection(from textView: NSTextView, deferUpdate: Bool = true) {
            let range = textView.selectedRange()
            let status = typingStatus(in: textView, selectedRange: range)

            let apply = {
                if !NSEqualRanges(self.selectionRange.wrappedValue, range) {
                    self.selectionRange.wrappedValue = range
                }
                if self.typingStatus.wrappedValue != status {
                    self.typingStatus.wrappedValue = status
                }
            }

            if deferUpdate {
                DispatchQueue.main.async(execute: apply)
            } else {
                apply()
            }
        }

        func toggleInlineCommand(_ command: MarkdownInlineCommand, in textView: NSTextView) {
            guard isEditable || (allowsReadOnlyHighlighting && command == .highlight) else { return }
            let wasEditable = textView.isEditable
            if !wasEditable {
                textView.isEditable = true
            }
            defer {
                if !wasEditable {
                    textView.isEditable = false
                }
            }

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
            updateRelevanceAnchor()
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
            updateRelevanceAnchor()
            return true
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            if !shouldAllowDocumentTitleMarkerChange(
                in: textView,
                affectedCharRange: affectedCharRange,
                replacementString: replacementString
            ) {
                return false
            }

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
                    updateRelevanceAnchor()
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
            updateRelevanceAnchor()
            return false
        }

        private static let documentTitleMarker = "# "

        private static func documentTitleHeadingMarkerRange(in rawText: NSString) -> NSRange? {
            guard rawText.length > 0 else { return nil }

            var markerRange: NSRange?
            rawText.enumerateSubstrings(
                in: NSRange(location: 0, length: rawText.length),
                options: [.byLines, .substringNotRequired]
            ) { _, lineRange, _, stop in
                let rawLine = rawText.substring(with: lineRange)
                guard headingLevel(in: rawLine) == 1 else { return }

                let leadingWhitespace = rawLine.prefix { $0 == " " || $0 == "\t" }.count
                markerRange = NSRange(
                    location: lineRange.location + leadingWhitespace,
                    length: (documentTitleMarker as NSString).length
                )
                stop.pointee = true
            }
            return markerRange
        }

        private func shouldAllowDocumentTitleMarkerChange(
            in textView: NSTextView,
            affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            let rawText = textView.string as NSString
            guard let markerRange = Self.documentTitleHeadingMarkerRange(in: rawText) else { return true }

            let replacement = replacementString ?? ""

            if NSIntersectionRange(affectedCharRange, markerRange).length > 0 {
                blockDocumentTitleMarkerEdit(in: textView, markerRange: markerRange)
                return false
            }

            if affectedCharRange.length == 0,
               affectedCharRange.location < markerRange.upperBound,
               !replacement.isEmpty {
                blockDocumentTitleMarkerEdit(in: textView, markerRange: markerRange)
                return false
            }

            return true
        }

        private func blockDocumentTitleMarkerEdit(in textView: NSTextView, markerRange: NSRange) {
            let caret = NSRange(location: markerRange.upperBound, length: 0)
            textView.setSelectedRange(caret)
            selectionRange.wrappedValue = caret
        }

        private func clampDocumentTitleSelection(in textView: NSTextView) {
            let rawText = textView.string as NSString
            guard let markerRange = Self.documentTitleHeadingMarkerRange(in: rawText) else { return }

            let selected = textView.selectedRange()
            guard selected.location <= rawText.length else { return }

            if selected.length == 0 {
                if selected.location > markerRange.location, selected.location < markerRange.upperBound {
                    blockDocumentTitleMarkerEdit(in: textView, markerRange: markerRange)
                }
                return
            }

            if NSIntersectionRange(selected, markerRange).length > 0 {
                let clamped = NSRange(
                    location: markerRange.upperBound,
                    length: max(0, selected.upperBound - markerRange.upperBound)
                )
                textView.setSelectedRange(clamped)
                selectionRange.wrappedValue = clamped
            }
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
            updateRelevanceAnchor()
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
            updateRelevanceAnchor()
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

            pendingStylingWorkItem?.cancel()
            pendingStylingWorkItem = nil
            isApplyingMarkdownStyling = true
            let undoManager = textView.undoManager
            let shouldRestoreUndoRegistration = undoManager?.isUndoRegistrationEnabled == true
            if shouldRestoreUndoRegistration {
                undoManager?.disableUndoRegistration()
            }
            defer {
                if shouldRestoreUndoRegistration {
                    undoManager?.enableUndoRegistration()
                }
                isApplyingMarkdownStyling = false
            }

            let rawText = textView.string as NSString
            let fullRange = NSRange(location: 0, length: rawText.length)
            let selectedRanges = textView.selectedRanges
            let baseAttributes = Self.baseAttributes()

            updateTypingAttributesForCurrentLine(in: textView)

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

            Self.applyMultilineHighlightStyles(in: fullRange, rawText: rawText, textStorage: textStorage)
            Self.applyRelevanceHighlightStyle(range: relevanceHighlightRange, rawText: rawText, textStorage: textStorage)
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

        func scheduleMarkdownStyling() {
            pendingStylingWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.applyMarkdownStyling()
            }
            pendingStylingWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
        }

        private func updateTypingAttributesForCurrentLine(in textView: NSTextView) {
            let rawText = textView.string as NSString
            let selectedRange = textView.selectedRange()
            let location = min(selectedRange.location, rawText.length)
            let lineRange = rawText.lineRange(for: NSRange(location: location, length: 0))
            let rawLine = rawText.substring(with: NSRange(location: lineRange.location, length: min(lineRange.length, rawText.length - lineRange.location)))
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            var attributes = Self.baseAttributes()

            if let headingLevel = Self.headingLevel(in: rawLine) {
                attributes[.font] = NSFont.systemFont(ofSize: Self.headingFontSize(for: headingLevel), weight: .bold)
                attributes[.paragraphStyle] = Self.paragraphStyle(for: trimmedLine, isCode: false)
            } else if trimmedLine.hasPrefix(">") {
                attributes[.font] = Self.italicFont(size: 15)
                attributes[.foregroundColor] = NSColor.secondaryLabelColor
            } else if Self.isListLine(trimmedLine) {
                attributes[.font] = NSFont.systemFont(ofSize: 15, weight: .regular)
            } else if trimmedLine == "---" || trimmedLine == "***" {
                attributes[.font] = NSFont.systemFont(ofSize: 15, weight: .semibold)
                attributes[.foregroundColor] = NSColor.tertiaryLabelColor
            }

            textView.typingAttributes = attributes
        }

        func updateSuggestionAnchor() {
            guard let anchor = anchor(for: suggestionRange) else {
                if suggestionAnchor.wrappedValue != nil {
                    DispatchQueue.main.async {
                        self.suggestionAnchor.wrappedValue = nil
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.suggestionAnchor.wrappedValue = anchor
            }
        }

        func updateRelevanceAnchor() {
            guard let anchor = anchor(for: relevanceHighlightRange) else {
                if relevanceAnchor.wrappedValue != nil {
                    DispatchQueue.main.async {
                        self.relevanceAnchor.wrappedValue = nil
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.relevanceAnchor.wrappedValue = anchor
            }
        }

        private func anchor(for range: NSRange?) -> CGPoint? {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let range
            else { return nil }

            let textLength = (textView.string as NSString).length
            guard range.location >= 0,
                  range.location <= textLength,
                  textLength > 0
            else { return nil }

            let location = min(range.upperBound, textLength)
            let characterRange = NSRange(location: max(0, location - 1), length: min(1, textLength))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let visibleOrigin = textView.enclosingScrollView?.contentView.bounds.origin ?? .zero
            let inset = textView.textContainerInset
            return CGPoint(
                x: rect.maxX + inset.width - visibleOrigin.x,
                y: rect.minY + inset.height - visibleOrigin.y
            )
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
            guard let headingLevel = headingLevel(in: rawLine) else { return false }
            let leadingWhitespace = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            let fontSize = headingFontSize(for: headingLevel)

            textStorage.addAttributes([
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ], range: lineRange)

            let markerLength = min(rawLine.count - leadingWhitespace, headingLevel + 1)
            let markerRange = NSRange(location: lineRange.location + leadingWhitespace, length: markerLength)
            hideSyntax(in: textStorage, range: markerRange)

            return true
        }

        private static func headingLevel(in rawLine: String) -> Int? {
            let leadingWhitespace = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            let candidate = rawLine.dropFirst(leadingWhitespace)
            let headingLevel = candidate.prefix { $0 == "#" }.count

            guard (1...6).contains(headingLevel),
                  candidate.dropFirst(headingLevel).first?.isWhitespace == true
            else { return nil }

            return headingLevel
        }

        private static func headingFontSize(for headingLevel: Int) -> CGFloat {
            switch headingLevel {
            case 1: return 30
            case 2: return 24
            case 3: return 20
            case 4: return 17
            default: return 15.5
            }
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

        private static func applyMultilineHighlightStyles(
            in range: NSRange,
            rawText: NSString,
            textStorage: NSTextStorage
        ) {
            guard let regex = try? NSRegularExpression(
                pattern: #"==(.+?)=="#,
                options: [.dotMatchesLineSeparators]
            ) else { return }

            regex.enumerateMatches(in: rawText as String, range: range) { match, _, _ in
                guard let match else { return }
                textStorage.addAttributes([
                    .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.32),
                    .foregroundColor: NSColor.labelColor
                ], range: match.range)
                hideSyntax(in: textStorage, range: NSRange(location: match.range.location, length: 2))
                hideSyntax(in: textStorage, range: NSRange(location: match.range.upperBound - 2, length: 2))
            }
        }

        private static func applyRelevanceHighlightStyle(
            range: NSRange?,
            rawText: NSString,
            textStorage: NSTextStorage
        ) {
            guard let range,
                  range.location >= 0,
                  range.upperBound <= rawText.length,
                  range.length > 0
            else { return }

            textStorage.addAttributes([
                .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.22),
                .foregroundColor: NSColor.labelColor
            ], range: range)
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
                .foregroundColor: NSColor.tertiaryLabelColor.withAlphaComponent(0.38)
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
    private static let maximumUndoLevels = 14

    weak var commandHandler: InlineMarkdownEditor.Coordinator?

    override var undoManager: UndoManager? {
        let manager = super.undoManager
        manager?.levelsOfUndo = Self.maximumUndoLevels
        return manager
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureUndoLimit()
    }

    func configureUndoLimit() {
        undoManager?.levelsOfUndo = Self.maximumUndoLevels
    }

    override func paste(_ sender: Any?) {
        if commandHandler?.pasteImageFromClipboard() == true {
            return
        }

        super.paste(sender)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)

        let location = convert(event.locationInWindow, from: nil)
        let horizontalInset = textContainerInset.width
        if location.x < horizontalInset || location.x > bounds.width - horizontalInset {
            commandHandler?.finishEditing()
            return
        }

        super.mouseDown(with: event)
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
        if handleEscapeKeyEquivalent(event) {
            return
        }

        if event.charactersIgnoringModifiers == "\t",
           commandHandler?.completeActiveLinkFromTab(in: self) == true {
            return
        }

        if handleUndoRedoKeyEquivalent(event) {
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
        if handleEscapeKeyEquivalent(event) {
            return true
        }

        if event.charactersIgnoringModifiers == "\t",
           commandHandler?.completeActiveLinkFromTab(in: self) == true {
            return true
        }

        if handleUndoRedoKeyEquivalent(event) {
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

    private func handleEscapeKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.keyCode == 53,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
        else {
            return false
        }

        commandHandler?.finishEditing()
        return true
    }

    private func handleUndoRedoKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control),
              let characters = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }

        switch characters {
        case "z" where flags.contains(.shift):
            if undoManager?.canRedo == true {
                undoManager?.redo()
                commandHandler?.syncTextAndSelectionAfterUndoRedo(in: self)
            }
            return true
        case "z":
            if undoManager?.canUndo == true {
                undoManager?.undo()
                commandHandler?.syncTextAndSelectionAfterUndoRedo(in: self)
            }
            return true
        case "y" where !flags.contains(.shift):
            if undoManager?.canRedo == true {
                undoManager?.redo()
                commandHandler?.syncTextAndSelectionAfterUndoRedo(in: self)
            }
            return true
        default:
            return false
        }
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

private struct MarkdownRelevanceSuggestion: Identifiable, Equatable {
    let candidateID: String
    let title: String
    let phrase: String
    let phraseRange: NSRange
    let score: Double

    var id: String {
        "\(candidateID)-\(phraseRange.location)-\(phraseRange.length)"
    }
}

private struct RelevanceSuggestionPill: View {
    let title: String
    let apply: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: apply) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.84))
                        .frame(width: 15, height: 15)

                    Text("Relevant to \(title)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.86))
                        .lineLimit(1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss suggestion")
        }
        .padding(.leading, 12)
        .padding(.trailing, 7)
        .padding(.vertical, 8)
        .fixedSize(horizontal: true, vertical: false)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .help("Link this text to \(title)")
    }
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
        VStack(alignment: .leading, spacing: 9) {
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

private struct AssistantConversationPanel: View {
    let response: AssistantConversationResponse
    let addToPage: () -> Void
    let isAddingToPage: Bool
    let exitConversation: () -> Void
    let openLinkedNote: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("\(response.providerTitle) Answer", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.55))
            }

            responseContent

            HStack {
                Spacer()
                addToPageButton
                exitConversationButton
            }
        }
        .padding(14)
        .frame(width: panelWidth, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 22, y: 10)
    }

    private var addToPageButton: some View {
        Button(action: addToPage) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary.opacity(isAddingToPage ? 0.42 : 0.86))
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.14), lineWidth: 0.8)
                        }
                }
        }
        .buttonStyle(.plain)
        .disabled(isAddingToPage)
        .help("Add this answer to the page")
    }

    private var exitConversationButton: some View {
        Button(action: exitConversation) {
            Text("Exit Conversation")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.86))
                .padding(.horizontal, 15)
                .frame(height: 30)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(Color.primary.opacity(0.14), lineWidth: 0.8)
                        }
                }
        }
        .buttonStyle(.plain)
        .help("Close this answer")
    }

    @ViewBuilder
    private var responseContent: some View {
        if needsScrolling {
            ScrollView {
                responseMarkdown
                    .padding(.trailing, 4)
            }
            .scrollIndicators(.visible)
            .frame(height: responseMaxHeight)
        } else {
            responseMarkdown
                .padding(.trailing, 4)
        }
    }

    private var responseMarkdown: some View {
        MarkdownPreview(
            content: response.answer,
            searchHighlight: nil,
            openLinkedNote: openLinkedNote
        )
        .textSelection(.enabled)
    }

    private var panelWidth: CGFloat {
        min(620, max(360, CGFloat(response.answer.count) * 4.8))
    }

    private var responseMaxHeight: CGFloat {
        min(560, max(320, (NSScreen.main?.visibleFrame.height ?? 900) * 0.52))
    }

    private var estimatedResponseHeight: CGFloat {
        CGFloat(estimatedLineCount) * 22 + 8
    }

    private var estimatedLineCount: Int {
        let charactersPerLine = max(42, Int(panelWidth / 8.4))
        return response.answer
            .components(separatedBy: .newlines)
            .reduce(0) { total, line in
                total + max(1, Int(ceil(Double(line.count) / Double(charactersPerLine))))
            }
    }

    private var needsScrolling: Bool {
        estimatedResponseHeight > responseMaxHeight
    }
}

private struct ConversationReadabilityBackdrop: View {
    var body: some View {
        EmptyView()
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

private struct PromptTextInputView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange
    let placeholder: String
    let fontSize: CGFloat
    let linkTabCompletionTitle: String?
    let suggestionRange: NSRange?
    @Binding var suggestionAnchor: CGPoint?
    let isExpanded: Bool
    let isFocused: Bool
    let submitOnReturn: Bool
    let submit: () -> Void
    let completeLink: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            selectionRange: $selectionRange,
            suggestionAnchor: $suggestionAnchor,
            submit: submit,
            completeLink: completeLink
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = isExpanded
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = PromptNSTextView()
        textView.commandHandler = context.coordinator
        textView.delegate = context.coordinator
        textView.string = text
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.linkTabCompletionTitle = linkTabCompletionTitle
        context.coordinator.suggestionRange = suggestionRange
        context.coordinator.isExpanded = isExpanded
        context.coordinator.isFocused = isFocused
        context.coordinator.submitOnReturn = submitOnReturn
        context.coordinator.updateTextInsets(in: textView)
        textView.setSelectedRange(clamped(selectionRange, in: text))
        context.coordinator.applyFocus(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PromptNSTextView else { return }
        context.coordinator.text = $text
        context.coordinator.selectionRange = $selectionRange
        context.coordinator.suggestionAnchor = $suggestionAnchor
        context.coordinator.linkTabCompletionTitle = linkTabCompletionTitle
        context.coordinator.suggestionRange = suggestionRange
        context.coordinator.isExpanded = isExpanded
        context.coordinator.isFocused = isFocused
        context.coordinator.submitOnReturn = submitOnReturn
        context.coordinator.submit = submit
        context.coordinator.completeLink = completeLink
        context.coordinator.textView = textView
        scrollView.hasVerticalScroller = isExpanded
        textView.font = NSFont.systemFont(ofSize: fontSize)
        context.coordinator.updateTextInsets(in: textView)

        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(clamped(selectionRange, in: text))
        }
        context.coordinator.updateSuggestionAnchor()
        context.coordinator.applyFocus(to: textView)
    }

    private func clamped(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(max(0, range.location), length)
        return NSRange(location: location, length: min(range.length, max(0, length - location)))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectionRange: Binding<NSRange>
        var suggestionAnchor: Binding<CGPoint?>
        var submit: () -> Void
        var completeLink: (String) -> Void
        var linkTabCompletionTitle: String?
        var suggestionRange: NSRange?
        var isExpanded = false
        var isFocused = false
        var submitOnReturn = true
        weak var textView: NSTextView?

        init(
            text: Binding<String>,
            selectionRange: Binding<NSRange>,
            suggestionAnchor: Binding<CGPoint?>,
            submit: @escaping () -> Void,
            completeLink: @escaping (String) -> Void
        ) {
            self.text = text
            self.selectionRange = selectionRange
            self.suggestionAnchor = suggestionAnchor
            self.submit = submit
            self.completeLink = completeLink
        }

        func updateTextInsets(in textView: NSTextView) {
            textView.textContainerInset = isExpanded
                ? NSSize(width: 10, height: 8)
                : NSSize(width: 0, height: 3)
            textView.textContainer?.lineFragmentPadding = 0
        }

        func applyFocus(to textView: NSTextView, retryCount: Int = 0) {
            guard isFocused else { return }
            DispatchQueue.main.async {
                guard let window = textView.window else {
                    if retryCount < 3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                            self.applyFocus(to: textView, retryCount: retryCount + 1)
                        }
                    }
                    return
                }
                guard window.firstResponder !== textView else { return }

                window.makeFirstResponder(textView)
                textView.setSelectedRange(self.clampedSelection(in: textView.string))
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            publishSelection(from: textView)
            updateSuggestionAnchor()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                publishSelection(from: textView)
            }
            updateSuggestionAnchor()
        }

        func completeActiveLinkFromTab(in textView: NSTextView) -> Bool {
            guard let title = linkTabCompletionTitle, !title.isEmpty,
                  let suggestionRange,
                  suggestionRange.location >= 0,
                  suggestionRange.upperBound <= (textView.string as NSString).length
            else { return false }

            textView.replaceCharacters(in: suggestionRange, with: "")
            let newSelection = NSRange(location: suggestionRange.location, length: 0)
            textView.setSelectedRange(newSelection)
            text.wrappedValue = textView.string
            selectionRange.wrappedValue = newSelection
            suggestionAnchor.wrappedValue = nil
            completeLink(title)
            return true
        }

        func handleReturn(in textView: NSTextView, forceSubmit: Bool = false) -> Bool {
            guard forceSubmit || submitOnReturn else { return false }
            submit()
            return true
        }

        func updateSuggestionAnchor() {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let suggestionRange,
                  suggestionRange.location <= (textView.string as NSString).length
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

        private func publishSelection(from textView: NSTextView) {
            let range = textView.selectedRange()
            DispatchQueue.main.async {
                self.selectionRange.wrappedValue = range
            }
        }

        private func clampedSelection(in text: String) -> NSRange {
            let length = (text as NSString).length
            let location = min(max(0, selectionRange.wrappedValue.location), length)
            let rangeLength = min(selectionRange.wrappedValue.length, max(0, length - location))
            return NSRange(location: location, length: rangeLength)
        }
    }
}

private final class PromptNSTextView: NSTextView {
    weak var commandHandler: PromptTextInputView.Coordinator?

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == "\t",
           commandHandler?.completeActiveLinkFromTab(in: self) == true {
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isReturnKey = event.charactersIgnoringModifiers == "\r" || event.keyCode == 36 || event.keyCode == 76
        if isReturnKey,
           (modifiers.contains(.command) || !modifiers.contains(.shift)),
           commandHandler?.handleReturn(in: self, forceSubmit: modifiers.contains(.command)) == true {
            return
        }

        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.charactersIgnoringModifiers == "\t",
           commandHandler?.completeActiveLinkFromTab(in: self) == true {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}

private struct PromptLinkedPageChip: View {
    let title: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(.black.opacity(0.86))
                .lineLimit(1)

            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.black.opacity(0.62))
                    .frame(width: 14, height: 14)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove linked page")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(height: 24)
        .background(Color.white.opacity(0.86))
        .clipShape(Capsule())
        .shadow(color: .white.opacity(0.16), radius: 8)
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
    @State private var isWritingModeHovered = false
    @State private var promptSelectionRange = NSRange(location: 0, length: 0)
    @State private var promptSuggestionAnchor: CGPoint?
    @State private var promptLayoutText = ""
    @State private var promptLayoutRefreshTask: Task<Void, Never>?

    private var noteTitles: [String] {
        store.notes.map(\.title)
    }

    private var promptLinkSuggestions: [String] {
        guard let context = activePromptWikiLinkContext else { return [] }
        let uniqueTitles = Array(NSOrderedSet(array: noteTitles)).compactMap { $0 as? String }
        let normalizedQuery = normalizedPromptLinkSuggestionText(context.query)

        guard !normalizedQuery.isEmpty else {
            return Array(uniqueTitles.prefix(3))
        }

        let prefixMatches = uniqueTitles.filter {
            normalizedPromptLinkSuggestionText($0).hasPrefix(normalizedQuery)
        }
        let containsMatches = uniqueTitles.filter {
            !prefixMatches.contains($0)
                && normalizedPromptLinkSuggestionText($0).contains(normalizedQuery)
        }

        return Array((prefixMatches + containsMatches).prefix(3))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let context = activePromptWikiLinkContext,
               !promptLinkSuggestions.isEmpty {
                LinkSuggestionMenu(
                    query: context.query,
                    suggestions: promptLinkSuggestions,
                    select: { completePromptWikiLink(with: $0, context: context) }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(8)
            }

            if store.isUsingWebSearch {
                WebSearchStatusPill()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isThinking {
                ThinkingStatusPill()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let response = store.assistantConversationResponse {
                AssistantConversationPanel(
                    response: response,
                    addToPage: {
                        store.addAssistantConversationResponseToCurrentNote()
                    },
                    isAddingToPage: store.isGeneratingAssistantResponse,
                    exitConversation: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.exitAssistantConversation()
                        }
                    },
                    openLinkedNote: { store.openLinkedNote(named: $0) }
                )
                .padding(.bottom, 4)
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
                            writingModeButton
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

                        writingModeButton
                        promptLinkChips

                        promptInput(width: textFieldWidth, height: textFieldHeight, isExpanded: false)

                        attachmentControl
                        expandToggle
                        sendButton
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
                    .padding(.vertical, 6)
                    .frame(width: pillWidth)
                    .frame(minHeight: 34)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPromptFocused = true
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
                    .stroke(borderColor, lineWidth: isAnyPromptFocused ? 0.6 : 1)
            }
            .overlay {
                if isThinking {
                    AnimatedThinkingBorder(cornerRadius: pillCornerRadius)
                }
            }
            .shadow(color: glowColor, radius: isAnyPromptFocused ? 7 : 13, y: isAnyPromptFocused ? 0 : 7)
            .onExitCommand {
                if isExpandedComposerPresented {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpandedComposerPresented = false
                    }
                    DispatchQueue.main.async {
                        isExpandedPromptFocused = false
                        isPromptFocused = true
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: isThinking)
        .animation(.easeInOut(duration: 0.18), value: store.assistantAttachment)
        .animation(.easeInOut(duration: 0.18), value: store.assistantConversationResponse)
        .animation(.easeInOut(duration: 0.16), value: store.isAssistantWritingMode)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isExpandedComposerPresented)
        .animation(.smooth(duration: 0.28), value: promptLayoutText)
        .onAppear {
            promptLayoutText = store.assistantPrompt
        }
        .onDisappear {
            promptLayoutRefreshTask?.cancel()
        }
        .onChange(of: store.assistantPrompt) { _, newValue in
            schedulePromptLayoutRefresh(to: newValue)
            expandComposerIfPromptNeedsRoom()
        }
        .onChange(of: store.assistantConversationResponse) { _, response in
            if response != nil {
                collapseExpandedComposer(focusCompactPrompt: false)
            }
        }
        .onChange(of: store.isGeneratingAssistantResponse) { wasGenerating, isGenerating in
            if wasGenerating && !isGenerating {
                collapseExpandedComposer(focusCompactPrompt: false)
            }
        }
        .onPasteCommand(of: [.image, .fileURL]) { providers in
            pastePromptImages(from: providers)
        }
    }

    private var writingModeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                store.toggleAssistantWritingMode()
            }
        } label: {
            Image(systemName: store.isAssistantWritingMode ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.isAssistantWritingMode ? .white : .primary.opacity(isWritingModeHovered ? 0.86 : 0.58))
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(store.isAssistantWritingMode ? Color.white.opacity(0.18) : Color.primary.opacity(isWritingModeHovered ? 0.10 : 0.035))
                }
                .overlay {
                    Circle()
                        .stroke(store.isAssistantWritingMode ? Color.white.opacity(0.34) : Color.primary.opacity(0.08), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .help(store.isAssistantWritingMode ? "Writing mode: AI edits the Markdown" : "Question mode: AI answers without editing")
        .onHover { hovering in
            isWritingModeHovered = hovering
        }
    }

    private var modelMenu: some View {
        ProviderLogoSwitch(
            selection: selectedAssistantModelBinding,
            options: AssistantModel.allCases,
            title: { $0.title },
            imageName: { $0.providerLogoAssetName }
        )
        .scaleEffect(0.88)
        .frame(width: modelMenuWidth, height: 30)
    }

    private var selectedAssistantModelBinding: Binding<AssistantModel> {
        Binding(
            get: { store.selectedAssistantModel },
            set: { store.selectAssistantModel($0) }
        )
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
                isExpandedPromptFocused = false
                isPromptFocused = true
            } else {
                focusExpandedPromptAfterLayout()
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
            submitPromptAndCollapseIfNeeded()
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
            isSendHovered = hovering && (hasPromptInput || isThinking)
        }
    }

    private var expandedPromptEditor: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !store.assistantPromptLinkedPages.isEmpty {
                promptLinkChips
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }

            promptInput(
                width: expandedPillWidth - 10,
                height: expandedPromptInputHeight,
                isExpanded: true
            )
        }
            .background(Color.primary.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .onAppear {
                focusExpandedPromptAfterLayout()
            }
    }

    private var promptLinkChips: some View {
        HStack(spacing: 6) {
            ForEach(store.assistantPromptLinkedPages) { link in
                PromptLinkedPageChip(
                    title: link.title,
                    remove: {
                        withAnimation(.easeInOut(duration: 0.14)) {
                            store.removeAssistantPromptLink(id: link.id)
                        }
                    }
                )
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func promptInput(width: CGFloat, height: CGFloat, isExpanded: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            PromptTextInputView(
                text: $store.assistantPrompt,
                selectionRange: $promptSelectionRange,
                placeholder: promptPlaceholder,
                fontSize: isExpanded ? expandedPromptFontSize : compactPromptFontSize,
                linkTabCompletionTitle: promptLinkSuggestions.first,
                suggestionRange: activePromptSuggestionNSRange,
                suggestionAnchor: $promptSuggestionAnchor,
                isExpanded: isExpanded,
                isFocused: isExpanded ? isExpandedPromptFocused : isPromptFocused,
                submitOnReturn: !isExpanded,
                submit: submitPromptAndCollapseIfNeeded,
                completeLink: { title in
                    completePromptWikiLink(with: title)
                }
            )
            .frame(width: width, height: height)
            .onTapGesture {
                if isExpanded {
                    isExpandedPromptFocused = true
                } else {
                    isPromptFocused = true
                }
            }

            if store.assistantPrompt.isEmpty {
                Text(promptPlaceholder)
                    .font(.system(size: isExpanded ? expandedPromptFontSize : compactPromptFontSize))
                    .foregroundStyle(.secondary.opacity(0.68))
                    .padding(.top, isExpanded ? 9 : 0)
                    .padding(.leading, isExpanded ? 10 : 0)
                    .frame(width: width, height: height, alignment: isExpanded ? .topLeading : .leading)
                    .allowsHitTesting(false)
            }

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
        promptInputHeight(
            lineCount: compactPromptLineCount,
            fontSize: compactPromptFontSize,
            verticalInset: 6,
            minHeight: 24,
            maxHeight: 72
        )
    }

    private var promptNeedsExpandedComposer: Bool {
        compactPromptLineCount >= 2 || store.assistantPrompt.contains("\n")
    }

    private var pillCornerRadius: CGFloat {
        isExpandedComposerPresented ? 20 : (measuredPromptText.count > 54 ? 18 : 17)
    }

    private var measuredPromptText: String {
        let prompt = promptLayoutText.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt.isEmpty ? promptPlaceholder : prompt
    }

    private var promptPlaceholder: String {
        store.isAssistantWritingMode ? "Write with AI" : "Ask question"
    }

    private var estimatedPromptWidth: CGFloat {
        let characterWidth = averagePromptCharacterWidth(fontSize: compactPromptFontSize)
        let raw = min(524, max(86, CGFloat(measuredPromptText.count) * characterWidth))
        let step: CGFloat = 32
        return min(524, max(86, ceil(raw / step) * step))
    }

    private var compactPromptLineCount: Int {
        estimatedPromptLineCount(
            forWidth: textFieldWidth,
            fontSize: compactPromptFontSize,
            horizontalInset: 0,
            maxLines: 4
        )
    }

    private var expandedPromptLineCount: Int {
        estimatedPromptLineCount(
            forWidth: expandedPillWidth - 10,
            fontSize: expandedPromptFontSize,
            horizontalInset: 20,
            maxLines: 6
        )
    }

    private var expandedPromptInputHeight: CGFloat {
        promptInputHeight(
            lineCount: expandedPromptLineCount,
            fontSize: expandedPromptFontSize,
            verticalInset: 18,
            minHeight: 44,
            maxHeight: store.assistantPromptLinkedPages.isEmpty ? 148 : 126
        )
    }

    private var compactPromptFontSize: CGFloat {
        12.5
    }

    private var expandedPromptFontSize: CGFloat {
        14.5
    }

    private func estimatedPromptLineCount(
        forWidth width: CGFloat,
        fontSize: CGFloat,
        horizontalInset: CGFloat,
        maxLines: Int
    ) -> Int {
        let availableWidth = max(48, width - horizontalInset)
        let charactersPerLine = max(8, Int(floor(availableWidth / averagePromptCharacterWidth(fontSize: fontSize))))
        let source = promptLayoutText.isEmpty ? measuredPromptText : promptLayoutText
        let visualLines = source.components(separatedBy: .newlines).reduce(0) { count, line in
            let utf16Count = max(1, (line as NSString).length)
            return count + max(1, Int(ceil(Double(utf16Count) / Double(charactersPerLine))))
        }
        return min(maxLines, max(1, visualLines))
    }

    private func averagePromptCharacterWidth(fontSize: CGFloat) -> CGFloat {
        let sample = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let font = NSFont.systemFont(ofSize: fontSize)
        return max(5.8, measuredTextWidth(sample, font: font) / CGFloat(sample.count))
    }

    private func promptInputHeight(
        lineCount: Int,
        fontSize: CGFloat,
        verticalInset: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> CGFloat {
        let lineHeight = ceil(fontSize * 1.38)
        let calculatedHeight = CGFloat(lineCount) * lineHeight + verticalInset
        return min(maxHeight, max(minHeight, calculatedHeight))
    }

    private var activePromptSuggestionNSRange: NSRange? {
        guard let context = activePromptWikiLinkContext else { return nil }
        return NSRange(context.range, in: store.assistantPrompt)
    }

    private var activePromptWikiLinkContext: WikiLinkSuggestionContext? {
        let prompt = store.assistantPrompt
        guard !prompt.isEmpty else { return nil }

        let utf16Length = (prompt as NSString).length
        let caretOffset = min(max(0, promptSelectionRange.location + promptSelectionRange.length), utf16Length)
        let caretIndex = String.Index(utf16Offset: caretOffset, in: prompt)
        let lineStart = prompt[..<caretIndex].lastIndex(of: "\n").map { prompt.index(after: $0) } ?? prompt.startIndex
        let lineEnd = prompt[caretIndex...].firstIndex(of: "\n") ?? prompt.endIndex

        guard let openRange = prompt.range(of: "[[", options: .backwards, range: lineStart..<caretIndex) else {
            return nil
        }

        let queryRange = openRange.upperBound..<caretIndex
        let queryCandidate = prompt[queryRange]
        guard !queryCandidate.contains("["),
              !queryCandidate.contains("]"),
              queryCandidate.count <= 80
        else { return nil }

        let closingRange = prompt.range(of: "]]", range: caretIndex..<lineEnd)
        let replacementEnd = closingRange?.upperBound ?? caretIndex
        let queryEnd = queryCandidate.firstIndex(of: "|") ?? queryCandidate.endIndex
        let query = String(queryCandidate[..<queryEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        return WikiLinkSuggestionContext(
            range: openRange.lowerBound..<replacementEnd,
            query: query
        )
    }

    private func completePromptWikiLink(with title: String) {
        guard let context = activePromptWikiLinkContext else {
            store.addAssistantPromptLink(title: title)
            return
        }
        completePromptWikiLink(with: title, context: context)
    }

    private func completePromptWikiLink(with title: String, context: WikiLinkSuggestionContext) {
        var prompt = store.assistantPrompt
        guard context.range.lowerBound >= prompt.startIndex,
              context.range.upperBound <= prompt.endIndex
        else { return }

        let replacementLocation = NSRange(context.range, in: prompt).location
        prompt.replaceSubrange(context.range, with: "")
        store.assistantPrompt = prompt
        store.addAssistantPromptLink(title: title)
        promptSelectionRange = NSRange(location: replacementLocation, length: 0)
        promptSuggestionAnchor = nil
    }

    private func normalizedPromptLinkSuggestionText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var attachmentWidth: CGFloat {
        store.assistantAttachment == nil ? 22 : (isExpandedComposerPresented ? 154 : 134)
    }

    private var expandedPillWidth: CGFloat {
        640
    }

    private var compactPillWidth: CGFloat {
        let horizontalPadding: CGFloat = 20
        let itemSpacing = CGFloat(7 * 7)
        return horizontalPadding
            + itemSpacing
            + modelMenuWidth
            + 1
            + 24
            + linkChipsWidth
            + textFieldWidth
            + attachmentWidth
            + 22
            + 24
    }

    private var linkChipsWidth: CGFloat {
        guard !store.assistantPromptLinkedPages.isEmpty else { return 0 }
        let chipSpacing: CGFloat = 6
        let chipPadding: CGFloat = 29
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let chipsWidth = store.assistantPromptLinkedPages.reduce(CGFloat.zero) { partial, link in
            partial + measuredTextWidth(link.title, font: font) + chipPadding
        }
        let gaps = chipSpacing * CGFloat(max(0, store.assistantPromptLinkedPages.count - 1))
        return chipsWidth + gaps
    }

    private var modelMenuWidth: CGFloat {
        68
    }

    private var hasPromptInput: Bool {
        !store.assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.assistantAttachment != nil
    }

    private var borderColor: Color {
        if isThinking {
            return .white.opacity(0.34)
        }

        return isAnyPromptFocused ? .white.opacity(0.34) : .primary.opacity(0.12)
    }

    private var glowColor: Color {
        if isThinking {
            return .white.opacity(0.20)
        }

        return isAnyPromptFocused ? .white.opacity(0.12) : .black.opacity(0.14)
    }

    private var isAnyPromptFocused: Bool {
        isPromptFocused || isExpandedPromptFocused
    }

    private func schedulePromptLayoutRefresh(to text: String) {
        promptLayoutRefreshTask?.cancel()
        promptLayoutRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            promptLayoutText = text
        }
    }

    private func submitPromptAndCollapseIfNeeded() {
        submitOrPreviewThinking()
        if isExpandedComposerPresented {
            collapseExpandedComposer(focusCompactPrompt: false)
        }
    }

    private func submitOrPreviewThinking() {
        if isThinking {
            store.cancelAssistantResponse()
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
        guard promptNeedsExpandedComposer, !isExpandedComposerPresented, !isThinking else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isExpandedComposerPresented = true
        }
        focusExpandedPromptAfterLayout()
    }

    private func collapseExpandedComposer(focusCompactPrompt: Bool) {
        guard isExpandedComposerPresented else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            isExpandedComposerPresented = false
        }
        isExpandedPromptFocused = false
        if focusCompactPrompt {
            DispatchQueue.main.async {
                isPromptFocused = true
            }
        }
    }

    private func focusExpandedPromptAfterLayout() {
        isPromptFocused = false
        isExpandedPromptFocused = false
        DispatchQueue.main.async {
            isExpandedPromptFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
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
        "public.avif",
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
    var cornerRadius: CGFloat? = nil
    @State private var rotation = Angle.degrees(0)

    var body: some View {
        Group {
            if let cornerRadius {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(thinkingGradient, lineWidth: lineWidth)
            } else {
                Capsule()
                    .strokeBorder(thinkingGradient, lineWidth: lineWidth)
            }
        }
        .onAppear {
            rotation = .degrees(0)
            withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                rotation = .degrees(360)
            }
        }
    }

    private var thinkingGradient: AngularGradient {
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
        )
    }
}

private struct MarkdownPreview: View {
    let content: String
    let searchHighlight: SearchHighlight?
    let openLinkedNote: (String) -> Void
    let imageURL: (String) -> URL?
    let imageData: (String) -> Data?
    let showsCodeCopyButton: Bool

    init(
        content: String,
        searchHighlight: SearchHighlight?,
        openLinkedNote: @escaping (String) -> Void,
        imageURL: @escaping (String) -> URL? = { _ in nil },
        imageData: @escaping (String) -> Data? = { _ in nil },
        showsCodeCopyButton: Bool = true
    ) {
        self.content = content
        self.searchHighlight = searchHighlight
        self.openLinkedNote = openLinkedNote
        self.imageURL = imageURL
        self.imageData = imageData
        self.showsCodeCopyButton = showsCodeCopyButton
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
                    MarkdownImageView(alt: alt, path: path, url: imageURL(path), imageData: imageData(path), maxWidth: 320, maxHeight: 240)
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
            paragraphText(text, highlighted: isHighlighted)
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
            MarkdownCodeBlockView(text: text, showsCopyButton: showsCodeCopyButton)
            .highlightedSearchBlock(isHighlighted)

        case .image(let alt, let path):
            MarkdownImageView(alt: alt, path: path, url: imageURL(path), imageData: imageData(path), maxWidth: 520, maxHeight: 360)
                .frame(maxWidth: .infinity, alignment: .center)
                .highlightedSearchBlock(isHighlighted)

        case .table(let table):
            tableView(table, highlighted: isHighlighted)
                .frame(maxWidth: .infinity, alignment: .center)
                .highlightedSearchBlock(isHighlighted)

        case .divider:
            Rectangle()
                .fill(.secondary.opacity(0.22))
                .frame(height: 1)
                .padding(.vertical, 10)
        }
    }

    private func tableView(_ table: MarkdownTable, highlighted: Bool) -> some View {
        let columnWidths = tableColumnWidths(for: table)

        return ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                tableRowView(
                    table.headers,
                    alignments: table.alignments,
                    columnWidths: columnWidths,
                    isHeader: true,
                    highlighted: highlighted
                )

                Rectangle()
                    .fill(Color.primary.opacity(0.16))
                    .frame(height: 1)

                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                    tableRowView(
                        row,
                        alignments: table.alignments,
                        columnWidths: columnWidths,
                        isHeader: false,
                        highlighted: highlighted
                    )
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

    private func tableColumnWidths(for table: MarkdownTable) -> [CGFloat] {
        let columnCount = max(table.headers.count, table.rows.map(\.count).max() ?? 0)
        guard columnCount > 0 else { return [] }

        return (0..<columnCount).map { index in
            let values = [table.headers[safe: index] ?? ""] + table.rows.map { $0[safe: index] ?? "" }
            let longest = values
                .map { $0.replacingOccurrences(of: #"[*_`=<>\[\]\(\)!]"#, with: "", options: .regularExpression) }
                .map(\.count)
                .max() ?? 0
            let estimatedWidth = CGFloat(longest) * 7.8 + 34
            return min(620, max(150, estimatedWidth))
        }
    }

    private func tableRowView(
        _ cells: [String],
        alignments: [MarkdownTableAlignment],
        columnWidths: [CGFloat],
        isHeader: Bool,
        highlighted: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(cells.indices, id: \.self) { index in
                inlineText(cells[index], highlighted: highlighted)
                    .font(.system(size: isHeader ? 13.5 : 13, weight: isHeader ? .semibold : .regular))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(textAlignment(for: alignments[safe: index] ?? .left))
                    .frame(
                        width: columnWidths[safe: index] ?? 150,
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

    @ViewBuilder
    private func paragraphText(_ markdown: String, highlighted: Bool = false) -> some View {
        let lines = markdown.components(separatedBy: "\n")
        if lines.count <= 1 {
            inlineText(markdown, highlighted: highlighted)
                .font(.system(size: 15.5))
                .lineSpacing(4)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    inlineText(line, highlighted: highlighted)
                        .font(.system(size: 15.5))
                        .lineSpacing(4)
                }
            }
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
        let tokenizedHighlights = markdownByTokenizingHighlightMarkers(normalized)
        let normalizedWithoutUnderlineTags = normalized
            .replacingOccurrences(of: #"</?u>"#, with: "", options: .regularExpression)
        let normalizedWithoutUnderlineTagsAndHighlightMarkers = markdownByTokenizingHighlightMarkers(normalizedWithoutUnderlineTags)

        if var attributed = try? AttributedString(markdown: normalizedWithoutUnderlineTagsAndHighlightMarkers.markdown) {
            applyUnderline(matches: underlineMatches, to: &attributed)
            applyHighlight(spans: normalizedWithoutUnderlineTagsAndHighlightMarkers.spans, to: &attributed)
            return Text(attributed)
        }

        return Text(markdownRemovingHighlightTokens(tokenizedHighlights.markdown, spans: tokenizedHighlights.spans))
    }

    private func underlinedTextMatches(in markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"<u>(.*?)</u>"#) else { return [] }
        let nsMarkdown = markdown as NSString
        return regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsMarkdown.substring(with: match.range(at: 1))
        }
    }

    private func markdownByTokenizingHighlightMarkers(_ markdown: String) -> (markdown: String, spans: [MarkdownHighlightTokenSpan]) {
        guard let regex = try? NSRegularExpression(
            pattern: #"==(.+?)=="#,
            options: [.dotMatchesLineSeparators]
        ) else { return (markdown, []) }

        let nsMarkdown = markdown as NSString
        let fullRange = NSRange(location: 0, length: nsMarkdown.length)
        var output = ""
        var spans: [MarkdownHighlightTokenSpan] = []
        var cursor = 0

        for (index, match) in regex.matches(in: markdown, range: fullRange).enumerated() {
            guard match.numberOfRanges > 1 else { continue }
            output += nsMarkdown.substring(with: NSRange(location: cursor, length: match.range.location - cursor))

            let startMarker = "ZIRNHIGHLIGHTSTART\(index)ZIRN"
            let endMarker = "ZIRNHIGHLIGHTEND\(index)ZIRN"
            output += startMarker
            output += nsMarkdown.substring(with: match.range(at: 1))
            output += endMarker
            spans.append(MarkdownHighlightTokenSpan(startMarker: startMarker, endMarker: endMarker))
            cursor = match.range.upperBound
        }

        output += nsMarkdown.substring(from: cursor)
        return (output, spans)
    }

    private func markdownRemovingHighlightTokens(_ markdown: String, spans: [MarkdownHighlightTokenSpan]) -> String {
        spans.reduce(markdown) { output, span in
            output
                .replacingOccurrences(of: span.startMarker, with: "")
                .replacingOccurrences(of: span.endMarker, with: "")
        }
    }

    private func applyHighlight(spans: [MarkdownHighlightTokenSpan], to attributed: inout AttributedString) {
        guard !spans.isEmpty else { return }

        var searchStart = attributed.startIndex
        for span in spans {
            guard let startRange = attributed[searchStart...].range(of: span.startMarker) else { continue }
            let highlightStart = startRange.lowerBound
            attributed.replaceSubrange(startRange, with: AttributedString(""))

            guard let endRange = attributed[highlightStart...].range(of: span.endMarker) else { continue }
            let highlightRange = highlightStart..<endRange.lowerBound
            attributed[highlightRange].backgroundColor = .yellow.opacity(0.42)
            attributed.replaceSubrange(endRange, with: AttributedString(""))
            searchStart = highlightRange.upperBound
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

private struct MarkdownHighlightTokenSpan {
    let startMarker: String
    let endMarker: String
}

private struct MarkdownCodeBlockView: View {
    let text: String
    let showsCopyButton: Bool
    @State private var didCopy = false
    @State private var isCopyHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal) {
                Text(text)
                    .font(.system(size: 13.5, design: .monospaced))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
                    .padding(.top, showsCopyButton ? 10 : 0)
            }
            .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            if showsCopyButton {
                Button {
                    copyTextToPasteboard(text)
                    didCopy = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        didCopy = false
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(isCopyHovered ? 0.95 : 0.72))
                        .frame(width: 24, height: 24)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(isCopyHovered ? 0.10 : 0.06))
                        }
                }
                .buttonStyle(.plain)
                .help("Copy code")
                .padding(6)
                .onHover { isCopyHovered = $0 }
            }
        }
    }
}

private struct MarkdownImageView: View {
    let alt: String
    let path: String
    let url: URL?
    let imageData: Data?
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        Group {
            if let imageData,
               let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let url, !url.isFileURL {
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
        .id(imageIdentity)
        .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var imageIdentity: String {
        if let imageData {
            return "\(path)-\(imageData.count)"
        }

        return url?.absoluteString ?? path
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
    let sourceLocation: Int

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var lineStartOffsets: [Int] = []
        var runningOffset = 0
        for line in lines {
            lineStartOffsets.append(runningOffset)
            runningOffset += (line as NSString).length + 1
        }
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var paragraphStartLine: Int?
        var codeLines: [String] = []
        var codeStartLine: Int?
        var isInCodeBlock = false

        func append(_ kind: Kind, sourceLineIndex: Int) {
            let sourceLocation = lineStartOffsets[safe: sourceLineIndex] ?? (markdown as NSString).length
            blocks.append(MarkdownBlock(id: blocks.count, kind: kind, sourceLocation: sourceLocation))
        }

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            append(.paragraph(paragraph.joined(separator: "\n")), sourceLineIndex: paragraphStartLine ?? 0)
            paragraph.removeAll()
            paragraphStartLine = nil
        }

        var lineIndex = 0
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    append(.code(codeLines.joined(separator: "\n")), sourceLineIndex: codeStartLine ?? lineIndex)
                    codeLines.removeAll()
                    codeStartLine = nil
                } else {
                    flushParagraph()
                    codeStartLine = lineIndex
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
                append(.table(parsedTable.table), sourceLineIndex: lineIndex)
                lineIndex += parsedTable.consumedLineCount
            } else if let heading = parseHeading(trimmed) {
                flushParagraph()
                append(.heading(level: heading.level, text: heading.text), sourceLineIndex: lineIndex)
                lineIndex += 1
            } else if let image = parseImage(trimmed) {
                flushParagraph()
                append(.image(alt: image.alt, path: image.path), sourceLineIndex: lineIndex)
                lineIndex += 1
            } else if isDivider(trimmed) {
                flushParagraph()
                append(.divider, sourceLineIndex: lineIndex)
                lineIndex += 1
            } else if let task = parseTask(trimmed) {
                flushParagraph()
                append(.task(isDone: task.isDone, text: task.text), sourceLineIndex: lineIndex)
                lineIndex += 1
            } else if let bullet = parseBullet(trimmed) {
                flushParagraph()
                append(.bullet(bullet), sourceLineIndex: lineIndex)
                lineIndex += 1
            } else if let numbered = parseNumbered(trimmed) {
                flushParagraph()
                append(.numbered(numbered.number, numbered.text), sourceLineIndex: lineIndex)
                lineIndex += 1
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                append(.quote(text), sourceLineIndex: lineIndex)
                lineIndex += 1
            } else {
                if paragraph.isEmpty {
                    paragraphStartLine = lineIndex
                }
                paragraph.append(trimmed)
                lineIndex += 1
            }
        }

        flushParagraph()
        if isInCodeBlock, !codeLines.isEmpty {
            append(.code(codeLines.joined(separator: "\n")), sourceLineIndex: codeStartLine ?? max(0, lines.count - codeLines.count))
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

        let rawHeaders = splitTableRow(headerLine)
        let rawSeparatorCells = splitTableRow(separatorLine)
        let columnCount = max(rawHeaders.count, rawSeparatorCells.count)
        guard columnCount >= 2,
              rawSeparatorCells.count >= 2,
              rawSeparatorCells.allSatisfy(isTableSeparatorCell)
        else { return nil }

        let headers = normalizedTableCells(rawHeaders, columnCount: columnCount)
        let separatorCells = normalizedTableCells(rawSeparatorCells, columnCount: columnCount)
        let alignments = separatorCells.map { tableAlignment(for: $0) }
        var rows: [[String]] = []
        var cursor = index + 2

        while cursor < lines.count {
            let rowLine = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard !rowLine.isEmpty,
                  rowLine.contains("|"),
                  splitTableRow(rowLine).count >= 2
            else { break }

            rows.append(normalizedTableCells(splitTableRow(rowLine), columnCount: columnCount))
            cursor += 1
        }

        return (
            MarkdownTable(
                headers: headers,
                alignments: normalizedTableAlignments(alignments, columnCount: columnCount),
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

private struct UsernameConfigurationView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var pronouns: String
    @State private var occupationChoice: UserOccupationPickerChoice
    @State private var otherOccupation: String

    init(store: BrainStore) {
        self.store = store
        _firstName = State(initialValue: store.userProfile.firstName)
        _lastName = State(initialValue: store.userProfile.lastName)
        _pronouns = State(initialValue: store.userProfile.pronouns)
        _occupationChoice = State(initialValue: UserOccupationPickerChoice(occupation: store.userProfile.occupation))
        _otherOccupation = State(initialValue: UserOccupationPickerChoice.otherText(from: store.userProfile.occupation))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Profile")
                        .font(.system(size: 24, weight: .bold))

                    Text("Your name and pronouns personalize the welcome greeting, Zirn Chat, and Home summaries. Occupation is optional.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                ConfigurationField(title: "First Name") {
                    TextField("First name", text: $firstName)
                }

                ConfigurationField(title: "Last Name") {
                    TextField("Last name", text: $lastName)
                }
            }

            ConfigurationField(title: "Pronouns") {
                TextField("e.g. she/her, he/him, they/them", text: $pronouns)
            }

            ConfigurationField(title: "Occupation (optional)") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Occupation", selection: $occupationChoice) {
                        ForEach(UserOccupationPickerChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    if occupationChoice == .other {
                        TextField("Specify your occupation", text: $otherOccupation)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    store.isShowingUsernameConfiguration = false
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    store.saveUserProfile(
                        UserProfile(
                            firstName: firstName,
                            lastName: lastName,
                            pronouns: pronouns,
                            occupation: occupationChoice.resolvedOccupation(otherText: otherOccupation)
                        )
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
        .frame(width: 480)
    }
}

private struct ModelConfigurationView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss

    @State private var mistralAPIKey: String
    @State private var mistralVerificationState: APIKeyVerificationState
    @State private var verifiedMistralAPIKey: String
    @State private var deepSeekAPIKey: String
    @State private var deepSeekVerificationState: APIKeyVerificationState
    @State private var verifiedDeepSeekAPIKey: String
    @State private var contentModel: AssistantModel
    @State private var homeGenerationModel: HighlightSummaryModel
    @State private var flashcardGenerationModel: HighlightSummaryModel
    @State private var mistralVerificationTask: Task<Void, Never>?
    @State private var deepSeekVerificationTask: Task<Void, Never>?
    @State private var mistralKeychainState: KeychainSaveState = .idle
    @State private var deepSeekKeychainState: KeychainSaveState = .idle
    @State private var mistralKeychainLoadNotFound = false
    @State private var deepSeekKeychainLoadNotFound = false
    @State private var isLoadingMistralFromKeychain = false
    @State private var isLoadingDeepSeekFromKeychain = false

    private let generationModels: [HighlightSummaryModel] = [.mistral, .deepseek]
    private let documentReadingServiceTitle = "Mistral OCR"

    init(store: BrainStore) {
        self.store = store
        let configuration = store.assistantConfigurationSnapshot
        _mistralAPIKey = State(initialValue: configuration.mistralAPIKey)
        _mistralVerificationState = State(initialValue: configuration.mistralAPIKey.isEmpty ? .idle : .verified)
        _verifiedMistralAPIKey = State(initialValue: configuration.mistralAPIKey)
        _deepSeekAPIKey = State(initialValue: configuration.deepSeekAPIKey)
        _deepSeekVerificationState = State(initialValue: configuration.deepSeekAPIKey.isEmpty ? .idle : .verified)
        _verifiedDeepSeekAPIKey = State(initialValue: configuration.deepSeekAPIKey)
        _contentModel = State(initialValue: store.selectedAssistantModel)
        _homeGenerationModel = State(initialValue: store.selectedHomeGenerationModel == .ollama ? .mistral : store.selectedHomeGenerationModel)
        _flashcardGenerationModel = State(initialValue: store.selectedFlashcardGenerationModel == .ollama ? .mistral : store.selectedFlashcardGenerationModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Configure Models")
                        .font(.system(size: 24, weight: .bold))

                    Text("Connect model providers and choose what Zirn uses for Zirn Chat, content, Home, and flashcards.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    ModelRoutingRow(title: "Zirn Chat + Content") {
                        ProviderLogoSwitch(
                            selection: $contentModel,
                            options: AssistantModel.allCases,
                            title: { $0.title },
                            imageName: { $0.providerLogoAssetName }
                        )
                    }

                    Divider()
                        .padding(.leading, 14)

                    ModelRoutingRow(title: "Home Page Generation") {
                        ProviderLogoSwitch(
                            selection: $homeGenerationModel,
                            options: generationModels,
                            title: { $0.title },
                            imageName: { $0.providerLogoAssetName }
                        )
                    }

                    Divider()
                        .padding(.leading, 14)

                    ModelRoutingRow(title: "Flashcard Generation") {
                        ProviderLogoSwitch(
                            selection: $flashcardGenerationModel,
                            options: generationModels,
                            title: { $0.title },
                            imageName: { $0.providerLogoAssetName }
                        )
                    }

                    Divider()
                        .padding(.leading, 14)

                    ModelRoutingRow(title: "Document Reading Service") {
                        StaticModelServiceLabel(title: documentReadingServiceTitle)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

                Text("DeepSeek's current API does not expose OCR/document-reading support, so PDF, Word, PowerPoint, and image reading stays on Mistral OCR.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mistral API Key")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    APIKeyField(
                        placeholder: "MISTRAL_API_KEY",
                        text: $mistralAPIKey,
                        state: mistralVerificationState,
                        width: mistralAPIKeyFieldWidth
                    )

                    keychainControls(
                        providerName: "Mistral",
                        isLoading: isLoadingMistralFromKeychain,
                        isVerified: isMistralKeyVerified,
                        state: mistralKeychainState,
                        loadNotFound: mistralKeychainLoadNotFound,
                        load: loadMistralFromKeychain,
                        save: saveMistralToKeychain
                    )

                    Text("Default model: \(BrainStore.defaultMistralModel)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if case .failed(let message) = mistralVerificationState {
                        errorText(message)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DeepSeek API Key")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    APIKeyField(
                        placeholder: "DEEPSEEK_API_KEY",
                        text: $deepSeekAPIKey,
                        state: deepSeekVerificationState,
                        width: deepSeekAPIKeyFieldWidth
                    )

                    keychainControls(
                        providerName: "DeepSeek",
                        isLoading: isLoadingDeepSeekFromKeychain,
                        isVerified: isDeepSeekKeyVerified,
                        state: deepSeekKeychainState,
                        loadNotFound: deepSeekKeychainLoadNotFound,
                        load: loadDeepSeekFromKeychain,
                        save: saveDeepSeekToKeychain
                    )

                    Text("Default model: \(BrainStore.defaultDeepSeekModel)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if case .failed(let message) = deepSeekVerificationState {
                        errorText(message)
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
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(!canSaveSelectedModels)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .onChange(of: mistralAPIKey) { _, newValue in
            mistralKeychainState = .idle
            mistralKeychainLoadNotFound = false
            scheduleMistralVerification(for: newValue)
        }
        .onChange(of: deepSeekAPIKey) { _, newValue in
            deepSeekKeychainState = .idle
            deepSeekKeychainLoadNotFound = false
            scheduleDeepSeekVerification(for: newValue)
        }
        .onDisappear {
            mistralVerificationTask?.cancel()
            deepSeekVerificationTask?.cancel()
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

    private var cleanDeepSeekAPIKey: String {
        deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDeepSeekKeyVerified: Bool {
        !cleanDeepSeekAPIKey.isEmpty
            && cleanDeepSeekAPIKey == verifiedDeepSeekAPIKey
            && deepSeekVerificationState == .verified
    }

    private var canSaveSelectedModels: Bool {
        (requiresMistral ? isMistralKeyVerified : true)
            && (requiresDeepSeek ? isDeepSeekKeyVerified : true)
    }

    private var requiresMistral: Bool {
        contentModel == .mistral || homeGenerationModel == .mistral || flashcardGenerationModel == .mistral
    }

    private var requiresDeepSeek: Bool {
        contentModel == .deepseek || homeGenerationModel == .deepseek || flashcardGenerationModel == .deepseek
    }

    private var mistralAPIKeyFieldWidth: CGFloat {
        let text = cleanMistralAPIKey.isEmpty ? "MISTRAL_API_KEY" : cleanMistralAPIKey
        return min(520, max(320, measuredTextWidth(text, font: .systemFont(ofSize: 14)) + 56))
    }

    private var deepSeekAPIKeyFieldWidth: CGFloat {
        let text = cleanDeepSeekAPIKey.isEmpty ? "DEEPSEEK_API_KEY" : cleanDeepSeekAPIKey
        return min(520, max(320, measuredTextWidth(text, font: .systemFont(ofSize: 14)) + 56))
    }

    private func keychainControls(
        providerName: String,
        isLoading: Bool,
        isVerified: Bool,
        state: KeychainSaveState,
        loadNotFound: Bool,
        load: @escaping () -> Void,
        save: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button(action: load) {
                    Label("Load from Keychain", systemImage: "key.viewfinder")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isLoading)
                .help("Import the \(providerName) API key from Apple Passwords")

                Button(action: save) {
                    Label("Add to Keychain", systemImage: "key.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!isVerified || state == .saving)
                .help("Save this \(providerName) API key to Apple Passwords")
            }

            if loadNotFound {
                errorText("\(providerName) API key not found")
            }

            switch state {
            case .idle, .saving:
                EmptyView()
            case .saved(let location):
                Label(
                    location == .applePasswords
                        ? "Saved to Apple Passwords. Search for “Zirn” or the provider domain."
                        : "Saved on this Mac. Search “Zirn” in Passwords, or enable iCloud Keychain to sync.",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.system(size: 12))
                .foregroundStyle(.green)
            case .failed(let message):
                errorText(message)
            }
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.red.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func loadMistralFromKeychain() {
        mistralKeychainLoadNotFound = false
        mistralKeychainState = .idle
        isLoadingMistralFromKeychain = true

        Task {
            defer { isLoadingMistralFromKeychain = false }

            do {
                guard let importedKey = try await MistralKeychainStore.loadMistralAPIKey()?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !importedKey.isEmpty
                else {
                    mistralKeychainLoadNotFound = true
                    return
                }

                mistralAPIKey = importedKey
                scheduleMistralVerification(for: importedKey)
            } catch MistralKeychainStore.KeychainError.authenticationCancelled {
                mistralKeychainState = .failed("Authentication was cancelled.")
            } catch {
                mistralKeychainLoadNotFound = true
                mistralKeychainState = .failed(error.localizedDescription)
            }
        }
    }

    private func loadDeepSeekFromKeychain() {
        deepSeekKeychainLoadNotFound = false
        deepSeekKeychainState = .idle
        isLoadingDeepSeekFromKeychain = true

        Task {
            defer { isLoadingDeepSeekFromKeychain = false }

            do {
                guard let importedKey = try await MistralKeychainStore.loadDeepSeekAPIKey()?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !importedKey.isEmpty
                else {
                    deepSeekKeychainLoadNotFound = true
                    return
                }

                deepSeekAPIKey = importedKey
                scheduleDeepSeekVerification(for: importedKey)
            } catch MistralKeychainStore.KeychainError.authenticationCancelled {
                deepSeekKeychainState = .failed("Authentication was cancelled.")
            } catch {
                deepSeekKeychainLoadNotFound = true
                deepSeekKeychainState = .failed(error.localizedDescription)
            }
        }
    }

    private func scheduleMistralVerification(for apiKey: String) {
        mistralVerificationTask?.cancel()

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
        mistralVerificationTask = Task {
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

    private func scheduleDeepSeekVerification(for apiKey: String) {
        deepSeekVerificationTask?.cancel()

        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAPIKey.isEmpty else {
            deepSeekVerificationState = .idle
            return
        }

        if cleanAPIKey == verifiedDeepSeekAPIKey {
            deepSeekVerificationState = .verified
            return
        }

        deepSeekVerificationState = .verifying
        deepSeekVerificationTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }

            do {
                try await store.verifyAndSaveDeepSeekAPIKey(cleanAPIKey)
                guard !Task.isCancelled else { return }
                verifiedDeepSeekAPIKey = cleanAPIKey
                deepSeekVerificationState = .verified
            } catch {
                guard !Task.isCancelled else { return }
                deepSeekVerificationState = .failed(error.localizedDescription)
            }
        }
    }

    private func saveMistralToKeychain() {
        mistralKeychainState = .saving

        Task {
            do {
                let location = try await store.saveMistralAPIKeyToKeychain(cleanMistralAPIKey)
                mistralKeychainState = .saved(location)
            } catch {
                mistralKeychainState = .failed(error.localizedDescription)
            }
        }
    }

    private func saveDeepSeekToKeychain() {
        deepSeekKeychainState = .saving

        Task {
            do {
                let location = try await store.saveDeepSeekAPIKeyToKeychain(cleanDeepSeekAPIKey)
                deepSeekKeychainState = .saved(location)
            } catch {
                deepSeekKeychainState = .failed(error.localizedDescription)
            }
        }
    }

    private func saveSelectedConfiguration() {
        store.saveModelConfiguration(
            mistralAPIKey: mistralAPIKey,
            mistralModel: BrainStore.defaultMistralModel,
            deepSeekAPIKey: deepSeekAPIKey,
            deepSeekModel: BrainStore.defaultDeepSeekModel,
            contentModel: contentModel,
            homeGenerationModel: homeGenerationModel,
            flashcardGenerationModel: flashcardGenerationModel
        )
    }
}

private enum KeychainSaveState: Equatable {
    case idle
    case saving
    case saved(MistralKeychainStore.SaveLocation)
    case failed(String)
}

private struct APIKeyField: View {
    let placeholder: String
    @Binding var text: String
    let state: APIKeyVerificationState
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .trailing) {
            SecureField(placeholder, text: $text)
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

private struct ModelRoutingRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(1)

            Spacer(minLength: 12)

            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ProviderLogoSwitch<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    let imageName: (Option) -> String
    @State private var hoveredOption: Option?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selection = option
                    }
                } label: {
                    Image(imageName(option))
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(iconColor(for: option))
                        .frame(width: 34, height: 28)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(fillColor(for: option))
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(title(option))
                .onHover { isHovering in
                    withAnimation(.easeOut(duration: 0.14)) {
                        hoveredOption = isHovering ? option : nil
                    }
                }
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.11), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func iconColor(for option: Option) -> Color {
        option == selection ? .primary : .secondary
    }

    private func fillColor(for option: Option) -> Color {
        if option == selection {
            return Color.primary.opacity(0.16)
        }

        if hoveredOption == option {
            return Color.primary.opacity(0.08)
        }

        return .clear
    }
}

private extension AssistantModel {
    var providerLogoAssetName: String {
        switch self {
        case .mistral:
            return "ProviderMistralLogo"
        case .deepseek:
            return "ProviderDeepSeekLogo"
        }
    }
}

private extension HighlightSummaryModel {
    var providerLogoAssetName: String {
        switch self {
        case .mistral:
            return "ProviderMistralLogo"
        case .deepseek:
            return "ProviderDeepSeekLogo"
        case .ollama:
            return "ProviderMistralLogo"
        }
    }
}

private struct StaticModelServiceLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Image("ProviderMistralLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.primary)
                .frame(width: 28, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.12))
                }

            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: true)
        .help("\(title) handles document OCR.")
    }
}

private struct CompactModelMenu<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(title(selection))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .fixedSize(horizontal: true, vertical: true)
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: true)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
    }
}

private struct HighlightSummaryCompilerView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel: HighlightSummaryModel

    init(store: BrainStore) {
        self.store = store
        _selectedModel = State(initialValue: store.selectedFlashcardGenerationModel)
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
                    ForEach([HighlightSummaryModel.mistral, .deepseek]) { model in
                        Text(model.title).tag(model)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
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
                    store.selectedFlashcardGenerationModel = selectedModel
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
