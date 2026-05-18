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
                    status: store.status,
                    isBusy: store.isBusy,
                    newBrain: store.createBrainVaultFromUser,
                    openBrain: store.openBrainVaultFromUser
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
    let status: String
    let isBusy: Bool
    let newBrain: () -> Void
    let openBrain: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SplashTitleBar()

            VStack(spacing: 64) {
                Text("Welcome to your second brain")
                    .font(.system(size: 40, weight: .light, design: .default).italic())
                    .foregroundStyle(.primary)

                VStack(spacing: 18) {
                    Button(action: newBrain) {
                        Label("Create New Brain", systemImage: "folder.badge.plus")
                            .labelStyle(SplashButtonLabelStyle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 294, height: 44)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                    .disabled(isBusy)

                    Button(action: openBrain) {
                        Label("Open Brain Vault", systemImage: "folder")
                            .labelStyle(SplashButtonLabelStyle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 294, height: 44)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .disabled(isBusy)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 22)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SplashTitleBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Label("Zehan", systemImage: "brain.head.profile")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            Spacer()
        }
        .padding(.leading, 78)
        .padding(.trailing, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }
}

private struct SplashButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            configuration.icon
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
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
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Untitled", text: $store.title)
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

                TextEditor(text: $store.content)
                    .font(.system(size: 15, design: .monospaced))
                    .scrollContentBackground(.hidden)
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
