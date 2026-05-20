//
//  ContentView.swift
//  Zirn
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

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                BrainSidebarHeader(store: store)
                .onTapGesture {
                    isEditingMarkdown = false
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
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
                    openNote: { noteID in
                        isEditingMarkdown = false
                        store.openNote(id: noteID)
                    }
                )
                .frame(height: 152)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 12)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
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
                        openLinkedNote: { store.openLinkedNote(named: $0) }
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
                        AssistantFloatingPill(store: store)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }

                    ReadingModeToggle(isOn: $isReadingMode)
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
        .animation(.easeInOut(duration: 0.22), value: isReadingMode)
        .animation(.easeInOut(duration: 0.22), value: store.notes)
        .animation(.easeInOut(duration: 0.18), value: store.status)
        .animation(.easeInOut(duration: 0.2), value: store.isGeneratingAssistantResponse)
        .sheet(isPresented: $isShowingMarkdownHelp) {
            MarkdownHelpView()
                .frame(width: 620, height: 680)
                .presentationBackground(.regularMaterial)
        }
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { store.content },
            set: { store.updateContentFromEditor($0) }
        )
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
    let openNote: (Note.ID) -> Void

    var body: some View {
        GeometryReader { proxy in
            let visibleNotes = Array(notes.prefix(12))
            let positions = nodePositions(for: visibleNotes, in: proxy.size)

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
                        GraphNodeButton(
                            note: note,
                            isSelected: note.id == selectedNoteID
                        ) {
                            openNote(note.id)
                        }
                        .position(point)
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
    let openLinkedNote: (String) -> Void

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
            MarkdownPreview(content: content, openLinkedNote: openLinkedNote)
                .padding(.horizontal, 26)
                .padding(.top, 2)
                .padding(.bottom, 24)
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
                MarkdownPreview(content: preview.markdown, openLinkedNote: openLinkedNote)
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
                .frame(width: 38, height: 38)
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

private struct AssistantFloatingPill: View {
    @ObservedObject var store: BrainStore
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if isThinking {
                ThinkingStatusPill()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 7) {
                Menu {
                    ForEach(AssistantModel.allCases) { model in
                        Button {
                            store.selectedAssistantModel = model
                        } label: {
                            if store.selectedAssistantModel == model {
                                Label(model.title, systemImage: "checkmark")
                            } else {
                                Text(model.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(store.selectedAssistantModel.title)
                            .font(.system(size: 10.5, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7.5, weight: .semibold))
                    }
                    .foregroundStyle(.primary.opacity(0.78))
                }
                .buttonStyle(.plain)
                .frame(width: 42, alignment: .leading)

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

                Button {
                    submitOrPreviewThinking()
                } label: {
                    Image(systemName: isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .disabled(store.assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking)
            }
            .padding(.leading, 11)
            .padding(.trailing, 7)
            .padding(.vertical, 7)
            .frame(width: pillWidth)
            .frame(minHeight: 34)
            .background(.ultraThinMaterial)
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
        }
        .animation(.easeOut(duration: 0.18), value: pillWidth)
        .animation(.easeInOut(duration: 0.18), value: pillCornerRadius)
        .animation(.easeOut(duration: 0.18), value: isThinking)
    }

    private var isThinking: Bool {
        store.isGeneratingAssistantResponse
    }

    private var pillWidth: CGFloat {
        min(640, max(340, 116 + estimatedPromptWidth))
    }

    private var textFieldWidth: CGFloat {
        max(178, pillWidth - 116)
    }

    private var pillCornerRadius: CGFloat {
        measuredPromptText.count > 54 ? 18 : 17
    }

    private var measuredPromptText: String {
        let prompt = store.assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt.isEmpty ? "Material?" : prompt
    }

    private var estimatedPromptWidth: CGFloat {
        let characterWidth: CGFloat = 7.35
        return min(524, max(86, CGFloat(measuredPromptText.count) * characterWidth))
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

        guard !store.assistantPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
    let openLinkedNote: (String) -> Void

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
        switch block.kind {
        case .heading(let level, let text):
            inlineText(text)
                .font(.system(size: headingSize(for: level), weight: headingWeight(for: level)))
                .padding(.top, level == 1 ? 0 : 5)
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

        case .task(let isDone, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isDone ? .green.opacity(0.82) : .secondary)
                inlineText(text)
                    .font(.system(size: 15.5))
                    .foregroundStyle(isDone ? .secondary : .primary)
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

        case .divider:
            Rectangle()
                .fill(.secondary.opacity(0.22))
                .frame(height: 1)
                .padding(.vertical, 10)
        }
    }

    private func inlineText(_ markdown: String) -> Text {
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
            } else if isDivider(trimmed) {
                flushParagraph()
                blocks.append(MarkdownBlock(kind: .divider))
            } else if let task = parseTask(trimmed) {
                flushParagraph()
                blocks.append(MarkdownBlock(kind: .task(isDone: task.isDone, text: task.text)))
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

private struct ModelConfigurationView: View {
    @ObservedObject var store: BrainStore
    @Environment(\.dismiss) private var dismiss

    @State private var openAIAPIKey: String
    @State private var openAIModel: String
    @State private var groqAPIKey: String
    @State private var groqModel: String
    @State private var ollamaURL: String
    @State private var ollamaModel: String

    init(store: BrainStore) {
        self.store = store
        let configuration = store.assistantConfigurationSnapshot
        _openAIAPIKey = State(initialValue: configuration.openAIAPIKey)
        _openAIModel = State(initialValue: configuration.openAIModel)
        _groqAPIKey = State(initialValue: configuration.groqAPIKey)
        _groqModel = State(initialValue: configuration.groqModel)
        _ollamaURL = State(initialValue: configuration.ollamaURL)
        _ollamaModel = State(initialValue: configuration.ollamaModel)
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

                    Text("Add the credentials and local endpoints Zirn should use for Groq, GPT, and Ollama.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ConfigurationField(title: "Groq API Key") {
                    SecureField("gsk-...", text: $groqAPIKey)
                }

                ConfigurationField(title: "Groq Model") {
                    TextField("llama-3.3-70b-versatile", text: $groqModel)
                }

                ConfigurationField(title: "OpenAI API Key") {
                    SecureField("sk-...", text: $openAIAPIKey)
                }

                ConfigurationField(title: "GPT Model") {
                    TextField("gpt-5", text: $openAIModel)
                }

                ConfigurationField(title: "Ollama URL") {
                    TextField("http://localhost:11434", text: $ollamaURL)
                }

                ConfigurationField(title: "Ollama Model") {
                    TextField("llama3.2", text: $ollamaModel)
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
                    store.saveModelConfiguration(
                        openAIAPIKey: openAIAPIKey,
                        openAIModel: openAIModel,
                        groqAPIKey: groqAPIKey,
                        groqModel: groqModel,
                        ollamaURL: ollamaURL,
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
