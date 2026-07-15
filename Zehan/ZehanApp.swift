//
//  ZirnApp.swift
//  Zirn
//
//  Created by Adi Tauqir on 5/15/26.
//

import CoreText
import AppKit
import QuartzCore
import SwiftUI

@main
struct ZirnApp: App {
    @StateObject private var store = BrainStore()

    init() {
        Self.registerBundledFonts()
        ZirnSparkleController.shared.startIfNeeded()
    }

    private static func registerBundledFonts() {
        for fontName in ["PT_Serif-Web-Regular", "PT_Serif-Web-Italic"] {
            guard let url = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        Window("Zirn", id: "main") {
            ContentView(store: store)
                .background(VoiceDynamicIslandPresenter(store: store))
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Zirn") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Zirn",
                            .applicationVersion: ZirnReleaseInfo.displayVersion,
                        ]
                    )
                }

                Button("Check for Updates…") {
                    ZirnSparkleController.shared.checkForUpdates()
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Page") {
                    store.newDraft()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(store.activeBrain == nil)

                Button("Create New Brain") {
                    store.createBrainVaultFromUser()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Group") {
                    store.createSidebarGroup()
                }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(store.activeBrain == nil)
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Search Pages") {
                    store.showPageSearch()
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(store.activeBrain == nil)

                Button("Open Brain Vault") {
                    store.openBrainVaultFromUser()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Open Your Files") {
                    store.openFilesFolder()
                }
                .disabled(store.activeBrain == nil)

                Button("Go to Home") {
                    store.goToStartPage()
                }

                Divider()
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save Vault") {
                    store.saveVault()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeBrain == nil)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("y", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(after: .pasteboard) {
                Button("Bold") {
                    NSApp.sendAction(NSSelectorFromString("toggleBoldface:"), to: nil, from: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    NSApp.sendAction(NSSelectorFromString("toggleItalics:"), to: nil, from: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Underline") {
                    NSApp.sendAction(NSSelectorFromString("underline:"), to: nil, from: nil)
                }
                .keyboardShortcut("u", modifiers: .command)

                Button("Highlight") {
                    NSApp.sendAction(NSSelectorFromString("highlightSelection:"), to: nil, from: nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Delete") {
                    store.deleteSelectedSidebarItem()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.activeBrain == nil || (store.selectedSidebarGroupID == nil && store.selectedNoteID == nil && store.currentNoteID == nil))
            }

            CommandGroup(replacing: .appVisibility) {
                Button("Hide Zirn") {
                    NSApp.hide(nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option])

                Button("Hide Others") {
                    NSApp.hideOtherApplications(nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option, .shift])

                Button("Show All") {
                    NSApp.unhideAllApplications(nil)
                }
            }

            CommandMenu("Settings") {
                Button("Configure Username") {
                    store.configureUsernameFromUser()
                }

                Button("Login with iCloud (in dev)") {
                    store.loginWithICloudInDevelopment()
                }
                .disabled(true)

                Divider()

                Button("Configure Models") {
                    store.configureModelFromUser()
                }

                Divider()

                Button("Compile Highlight Summary") {
                    store.compileCurrentHighlightSummary()
                }
                .disabled(!store.canCompileCurrentHighlights)
            }

            CommandGroup(replacing: .help) {
                Button("Zirn Help") {
                    store.showHelp()
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            UsageStatusBarView(store: store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                Text(store.totalUsagePercentLabel)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct VoiceDynamicIslandPresenter: NSViewRepresentable {
    @ObservedObject var store: BrainStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.hostingAnchor = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostingAnchor = nsView
        context.coordinator.store = store
        context.coordinator.updatePanel(animated: true)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.closePanel()
    }

    @MainActor
    final class Coordinator {
        weak var hostingAnchor: NSView?
        var store: BrainStore
        private var panel: VoiceIslandPanel?
        private var hostingView: NSHostingView<VoiceDynamicIslandView>?
        private var activationObservers: [NSObjectProtocol] = []
        private var lastAppliedPanelSize: NSSize = .zero

        init(store: BrainStore) {
            self.store = store
            activationObservers = [
                NotificationCenter.default.addObserver(
                    forName: NSApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.updatePanel(animated: true)
                },
                NotificationCenter.default.addObserver(
                    forName: NSApplication.didResignActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.updatePanel(animated: true)
                }
            ]
        }

        deinit {
            activationObservers.forEach(NotificationCenter.default.removeObserver)
        }

        func updatePanel(animated: Bool) {
            guard shouldShowPanel else {
                hidePanel(animated: animated)
                lastAppliedPanelSize = .zero
                return
            }

            let panel = panel ?? makePanel()
            self.panel = panel
            let size = panelSize
            let sizeChanged = size != lastAppliedPanelSize

            let rootView = VoiceDynamicIslandView(store: store)
            if let hostingView {
                hostingView.rootView = rootView
                if panel.isVisible {
                    hostingView.frame = NSRect(origin: .zero, size: size)
                }
            } else {
                let created = NSHostingView(rootView: rootView)
                created.sizingOptions = []
                created.frame = NSRect(origin: .zero, size: size)
                created.autoresizingMask = [.width, .height]
                created.wantsLayer = true
                created.layer?.backgroundColor = NSColor.clear.cgColor
                panel.contentView = created
                hostingView = created
            }

            if panel.isVisible {
                // Only animate frame when the shell size actually changes.
                // Live transcript / speech-level ticks must not re-slam the panel.
                if sizeChanged {
                    position(panel, size: size, animated: animated)
                    lastAppliedPanelSize = size
                }
            } else {
                showPanelWithEntrance(panel, finalSize: size, animated: animated)
                lastAppliedPanelSize = size
            }
        }

        func closePanel() {
            panel?.close()
            panel = nil
            hostingView = nil
            lastAppliedPanelSize = .zero
        }

        private var shouldShowPanel: Bool {
            if store.pendingVoiceTranscriptDraft != nil || store.isEnhancingVoiceTranscript {
                return true
            }
            return !NSApp.isActive && (store.pendingVoiceAudioSourceSelection != nil
                || store.activeVoiceCaptureTarget != nil
                || store.isFinalizingVoiceTranscript
                || store.voiceTranscriptionNotice != nil)
        }

        private var panelSize: NSSize {
            if store.pendingVoiceTranscriptDraft != nil || store.isEnhancingVoiceTranscript {
                // Header + ~10-line scrollable transcript + single action row.
                return NSSize(width: 520, height: 292)
            }
            if store.isFinalizingVoiceTranscript {
                return NSSize(width: 448, height: 82)
            }
            if store.voiceTranscriptionNotice != nil {
                return NSSize(width: 320, height: 48)
            }
            if store.pendingVoiceAudioSourceSelection != nil {
                return NSSize(width: 408, height: 48)
            }
            return NSSize(width: 420, height: 48)
        }

        private func hidePanel(animated: Bool) {
            guard let panel, panel.isVisible else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animated ? 0.22 : 0
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                panel.orderOut(nil)
                self?.hostingView = nil
            }
        }

        private func makePanel() -> VoiceIslandPanel {
            let panel = VoiceIslandPanel(
                contentRect: NSRect(origin: .zero, size: panelSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.isFloatingPanel = true
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            return panel
        }

        private func position(_ panel: NSPanel, size: NSSize, animated: Bool) {
            guard let newFrame = panelFrame(for: size) else { return }
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.42
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    context.allowsImplicitAnimation = true
                    panel.animator().setFrame(newFrame, display: true)
                }
            } else {
                panel.setFrame(newFrame, display: true)
            }
        }

        private func showPanelWithEntrance(_ panel: NSPanel, finalSize: NSSize, animated: Bool) {
            guard let finalFrame = panelFrame(for: finalSize) else { return }
            guard animated else {
                panel.alphaValue = 1
                panel.setFrame(finalFrame, display: true)
                hostingView?.frame = NSRect(origin: .zero, size: finalSize)
                panel.orderFrontRegardless()
                return
            }

            let startSize = NSSize(width: finalSize.width + 76, height: finalSize.height + 28)
            let startFrame = NSRect(
                x: finalFrame.midX - startSize.width / 2,
                y: finalFrame.minY + 18,
                width: startSize.width,
                height: startSize.height
            )
            panel.alphaValue = 0.04
            panel.setFrame(startFrame, display: true)
            hostingView?.frame = NSRect(origin: .zero, size: startSize)
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.82, 0.26, 1)
                context.allowsImplicitAnimation = true
                panel.animator().alphaValue = 1
                panel.animator().setFrame(finalFrame, display: true)
            } completionHandler: { [weak self] in
                self?.hostingView?.frame = NSRect(origin: .zero, size: finalSize)
            }
        }

        private func panelFrame(for size: NSSize) -> NSRect? {
            let screen = hostingAnchor?.window?.screen ?? NSScreen.main
            guard let screen else { return nil }

            // Keep the top edge fixed so pill → expanded morphs stay Y-aligned.
            let topInset: CGFloat = 8
            let origin = NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.visibleFrame.maxY - topInset - size.height
            )
            return NSRect(origin: origin, size: size)
        }
    }
}

private final class VoiceIslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        // Become key so SwiftUI button actions (esp. copy → pasteboard) fire reliably
        // on a nonactivating status panel.
        if !isKeyWindow {
            makeKeyAndOrderFront(nil)
        }
        super.mouseDown(with: event)
    }
}

private struct VoiceEntranceKeystoneShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * 0.08
        let corner = min(rect.height * 0.42, 22)
        var path = Path()
        path.move(to: CGPoint(x: topInset + corner, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - topInset - corner, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topInset * 0.35, y: corner),
            control: CGPoint(x: rect.maxX - topInset, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - corner, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: corner, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - corner),
            control: CGPoint(x: 0, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: topInset * 0.35, y: corner))
        path.addQuadCurve(
            to: CGPoint(x: topInset + corner, y: 0),
            control: CGPoint(x: topInset, y: 0)
        )
        path.closeSubpath()
        return path
    }
}

private struct VoiceDynamicIslandView: View {
    @ObservedObject var store: BrainStore
    @Namespace private var islandNamespace
    @State private var isSlamSettled = false

    private var targetTitle: String {
        switch store.pendingVoiceTranscriptDraft?.target
            ?? store.activeVoiceCaptureTarget
            ?? store.pendingVoiceAudioSourceSelection {
        case .editor:
            if let draft = store.pendingVoiceTranscriptDraft, draft.target == .editor {
                let clean = draft.noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { return clean }
            }
            if let captureTitle = store.voiceCaptureDestinationTitle?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !captureTitle.isEmpty {
                return captureTitle
            }
            let openTitle = store.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return openTitle.isEmpty ? "Untitled" : openTitle
        case .helpDesk:
            return "Zirn Chat"
        case nil:
            return "Voice"
        }
    }

    private var sourceLabel: String {
        switch store.activeVoiceAudioSource {
        case .systemAudio:
            return "On Screen"
        case .microphone:
            return "Voice"
        case nil:
            return "Audio"
        }
    }

    var body: some View {
        Group {
            if let draft = store.pendingVoiceTranscriptDraft {
                expandedTranscriptView(draft)
            } else if let notice = store.voiceTranscriptionNotice, !NSApp.isActive {
                failedNoticePillView(notice)
            } else if store.pendingVoiceAudioSourceSelection != nil {
                sourceChoicePillView
            } else if store.isFinalizingVoiceTranscript {
                transcribingPillView
            } else {
                recordingPillView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isSlamSettled ? 1 : 0.10)
        .scaleEffect(x: isSlamSettled ? 1 : 1.12, y: isSlamSettled ? 1 : 1.28, anchor: .top)
        .offset(y: isSlamSettled ? 0 : -18)
        .background(alignment: .top) {
            VoiceEntranceKeystoneShape()
                .fill(Color.black.opacity(isSlamSettled ? 0 : 0.34))
                .scaleEffect(x: isSlamSettled ? 1 : 1.18, y: isSlamSettled ? 1 : 1.38, anchor: .top)
                .allowsHitTesting(false)
        }
        .onAppear {
            isSlamSettled = false
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    isSlamSettled = true
                }
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: store.isFinalizingVoiceTranscript)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: store.pendingVoiceTranscriptDraft?.id)
        .animation(.spring(response: 0.38, dampingFraction: 0.9), value: store.pendingVoiceAudioSourceSelection)
        .animation(.easeInOut(duration: 0.2), value: store.isEnhancingVoiceTranscript)
    }

    private var sourceChoicePillView: some View {
        HStack(spacing: 8) {
            Text("Transcribe")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            Spacer(minLength: 6)

            ForEach(VoiceAudioSource.allCases) { source in
                VoiceIslandAudioSourceButton(source: source) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                        store.selectVoiceAudioSource(source)
                    }
                }
            }

            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    store.dismissVoiceAudioSourceSelection()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(width: 408, height: 48)
        .background(islandChrome)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.36), radius: 16, y: 6)
        .matchedGeometryEffect(id: "voice-island-shell", in: islandNamespace)
    }

    private var recordingPillView: some View {
        HStack(spacing: 10) {
            VoiceDotGridSpinner()
                .frame(width: 16, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(compactTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(
                            BrainStore.formattedVoiceCaptureElapsed(
                                store.voiceCaptureElapsed(at: context.date)
                            )
                        )
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.72))
                    }
                }
                Text(compactSubtitle)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    store.stopVoiceCapture()
                }
            } label: {
                Text("Stop")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.9))
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Color.white.opacity(0.96))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggleVoiceCapturePaused()
                }
            } label: {
                Text(store.isVoiceCapturePaused ? "Resume" : "Pause")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Color.red.opacity(store.isVoiceCapturePaused ? 0.72 : 0.9))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .shadow(color: .red.opacity(store.isVoiceCapturePaused ? 0.18 : 0.34), radius: 8, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(width: 420, height: 48)
        .background {
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.96))
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.42)
                    .blendMode(.plusLighter)
            }
        }
        .clipShape(Capsule())
        .overlay {
            // Dual rim: light inner + dark outer so the pill stays visible over any desktop.
            ZStack {
                Capsule()
                    .strokeBorder(Color.black.opacity(0.45), lineWidth: 1.6)
                    .padding(-0.6)
                    .blur(radius: 0.35)
                Capsule()
                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 1.1)
            }
            .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.48), radius: 14, y: 5)
        .shadow(color: .white.opacity(0.22), radius: 5, y: 0)
        .matchedGeometryEffect(id: "voice-island-shell", in: islandNamespace)
        .animation(.easeInOut(duration: 0.18), value: store.isVoiceCapturePaused)
    }

    private var transcribingPillView: some View {
        ZStack {
            HStack(spacing: 12) {
                VoiceOrbitingCirclesSpinner()
                    .frame(width: 66, height: 72)
                    .offset(y: -1)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        store.cancelFinalizingVoiceTranscription()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.92))
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .shadow(color: .red.opacity(0.34), radius: 10, y: 1)
                }
                .buttonStyle(.plain)
                .help("Cancel transcription")
            }

            Text(progressLabel)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
                .shadow(color: .white.opacity(0.16), radius: 6)
        }
        .padding(.horizontal, 14)
        .frame(width: 448, height: 76)
        .background(islandChrome)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.36), radius: 16, y: 6)
        .matchedGeometryEffect(id: "voice-island-shell", in: islandNamespace)
    }

    private func failedNoticePillView(_ notice: String) -> some View {
        let label = Self.compactFailureLabel(for: notice)
        return HStack(spacing: 10) {
            Image(systemName: label == "Failed" ? "exclamationmark.triangle.fill" : "waveform.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))

            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    store.dismissVoiceTranscriptionNotice()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(width: 320, height: 48)
        .background(islandChrome)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.36), radius: 16, y: 6)
        .matchedGeometryEffect(id: "voice-island-shell", in: islandNamespace)
    }

    private static func compactFailureLabel(for notice: String) -> String {
        let lowered = notice.lowercased()
        if lowered.contains("fail") {
            return "Failed"
        }
        if lowered.contains("nothing") || lowered.contains("no audio") || lowered.contains("empty") {
            return "No audio"
        }
        return "Failed"
    }

    private var islandChrome: some View {
        Color.black.opacity(0.96)
    }

    private var compactTitle: String {
        if store.isFinalizingVoiceTranscript { return "Transcribing" }
        return store.isVoiceCapturePaused ? "Paused" : "Recording"
    }

    private var compactSubtitle: String {
        if store.isFinalizingVoiceTranscript {
            return "\(targetTitle) · processing audio"
        }
        return "\(targetTitle) · \(sourceLabel)"
    }

    private var progressValue: Double {
        min(1, max(0, store.voiceTranscriptionProgress))
    }

    private var progressLabel: String {
        "\(Int((progressValue * 100).rounded()))%"
    }

    private func expandedTranscriptView(_ draft: VoiceTranscriptDraft) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                VoiceTranscriptDestinationPicker(store: store, draft: draft, style: .dark)

                Spacer(minLength: 4)

                VoiceTranscriptDismissButton(
                    style: .dark,
                    isDisabled: store.isEnhancingVoiceTranscript
                ) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                        store.discardPendingVoiceTranscript()
                    }
                }
            }

            Group {
                if store.isEnhancingVoiceTranscript {
                    VoiceTranscriptRefineSkeleton(style: .dark)
                } else {
                    VoiceTranscriptScrollableText(
                        text: draft.text,
                        foreground: .white.opacity(0.92)
                    )
                }
            }
            .padding(.top, 8)

            VoiceTranscriptReviewActionRow(
                store: store,
                draft: draft,
                style: .dark,
                dismissAfterInsert: false
            )
                .padding(.top, 10)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .frame(width: 520, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            // Sized exactly to the card — never larger than the rounded shell.
            VoiceIslandExpandedGlassChrome(cornerRadius: 28)
        }
        .clipShape(cardShape)
        .overlay {
            cardShape
                .stroke(Color.white.opacity(0.14), lineWidth: 0.9)
        }
        .shadow(color: .black.opacity(0.42), radius: 24, y: 10)
        .matchedGeometryEffect(id: "voice-island-shell", in: islandNamespace)
        .animation(.easeInOut(duration: 0.16), value: draft.revisionIndex)
        .animation(.easeInOut(duration: 0.16), value: draft.revisionHistory.count)
    }
}

/// Soft black upper chrome that yields to real AppKit frosted glass in the lower half.
private struct VoiceIslandExpandedGlassChrome: View {
    let cornerRadius: CGFloat

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            // Opaque black base — fully covers the card so nothing rectangular can peek out.
            cardShape
                .fill(Color.black.opacity(0.96))

            // Frosted glass only in the lower band (where the fade reveals it).
            VoiceIslandFrostedGlassView(cornerRadius: cornerRadius)
                .mask {
                    cardShape
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .clear, location: 0.42),
                                    .init(color: .white.opacity(0.35), location: 0.55),
                                    .init(color: .white.opacity(0.88), location: 0.72),
                                    .init(color: .white, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .clipShape(cardShape)

            // Soft black veil on top that clears toward the bottom so glass shows through.
            cardShape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.94), location: 0),
                            .init(color: Color.black.opacity(0.78), location: 0.36),
                            .init(color: Color.black.opacity(0.28), location: 0.62),
                            .init(color: Color.black.opacity(0.06), location: 0.82),
                            .init(color: Color.clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Extra SwiftUI material punch in the lower glass band (already shape-clipped).
            cardShape
                .fill(.thinMaterial)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.38),
                            .init(color: .white.opacity(0.40), location: 0.55),
                            .init(color: .white.opacity(0.88), location: 0.78),
                            .init(color: .white, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .allowsHitTesting(false)
        }
        .compositingGroup()
        .mask(cardShape)
        .clipShape(cardShape)
        .allowsHitTesting(false)
    }
}

/// Clipped frosted glass. `NSVisualEffectView` ignores SwiftUI `clipShape` alone, so
/// corner radius is applied via a continuous CAShapeLayer mask matching the card.
private struct VoiceIslandFrostedGlassView: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> VoiceIslandClippedGlassContainer {
        let container = VoiceIslandClippedGlassContainer()
        container.cornerRadius = cornerRadius
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.masksToBounds = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.isEmphasized = true
        effect.wantsLayer = true
        effect.layer?.backgroundColor = NSColor.clear.cgColor
        effect.layer?.masksToBounds = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.autoresizingMask = [.width, .height]
        effect.frame = container.bounds
        container.addSubview(effect)
        container.effectView = effect
        container.applyContinuousCornerMask()
        return container
    }

    func updateNSView(_ container: VoiceIslandClippedGlassContainer, context: Context) {
        container.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.backgroundColor = NSColor.clear.cgColor
        if let effect = container.effectView {
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.isEmphasized = true
            effect.frame = container.bounds
            effect.layer?.backgroundColor = NSColor.clear.cgColor
            effect.layer?.masksToBounds = true
            effect.layer?.cornerRadius = cornerRadius
            effect.layer?.cornerCurve = .continuous
        }
        container.applyContinuousCornerMask()
    }
}

private final class VoiceIslandClippedGlassContainer: NSView {
    weak var effectView: NSVisualEffectView?
    var cornerRadius: CGFloat = 28

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        effectView?.frame = bounds
        effectView?.layer?.backgroundColor = NSColor.clear.cgColor
        effectView?.layer?.cornerRadius = cornerRadius
        effectView?.layer?.cornerCurve = .continuous
        effectView?.layer?.masksToBounds = true
        layer?.masksToBounds = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.clear.cgColor
        applyContinuousCornerMask()
    }

    func applyContinuousCornerMask() {
        wantsLayer = true
        guard bounds.width > 0, bounds.height > 0 else { return }

        layer?.mask = Self.continuousRoundedRectMask(in: bounds, cornerRadius: cornerRadius)

        if let effect = effectView {
            effect.wantsLayer = true
            effect.layer?.mask = Self.continuousRoundedRectMask(in: effect.bounds, cornerRadius: cornerRadius)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
        applyContinuousCornerMask()
    }

    private static func continuousRoundedRectMask(in rect: CGRect, cornerRadius: CGFloat) -> CAShapeLayer {
        let mask = CAShapeLayer()
        mask.frame = rect
        mask.path = continuousRoundedRectPath(in: rect, cornerRadius: cornerRadius)
        mask.fillColor = NSColor.black.cgColor
        return mask
    }

    /// Approximates SwiftUI continuous corner curves closely enough to kill square bleed.
    private static func continuousRoundedRectPath(in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        let path = CGMutablePath()
        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY

        path.move(to: CGPoint(x: minX + radius, y: minY))
        path.addLine(to: CGPoint(x: maxX - radius, y: minY))
        path.addCurve(
            to: CGPoint(x: maxX, y: minY + radius),
            control1: CGPoint(x: maxX - radius * 0.45, y: minY),
            control2: CGPoint(x: maxX, y: minY + radius * 0.45)
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - radius))
        path.addCurve(
            to: CGPoint(x: maxX - radius, y: maxY),
            control1: CGPoint(x: maxX, y: maxY - radius * 0.45),
            control2: CGPoint(x: maxX - radius * 0.45, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX + radius, y: maxY))
        path.addCurve(
            to: CGPoint(x: minX, y: maxY - radius),
            control1: CGPoint(x: minX + radius * 0.45, y: maxY),
            control2: CGPoint(x: minX, y: maxY - radius * 0.45)
        )
        path.addLine(to: CGPoint(x: minX, y: minY + radius))
        path.addCurve(
            to: CGPoint(x: minX + radius, y: minY),
            control1: CGPoint(x: minX, y: minY + radius * 0.45),
            control2: CGPoint(x: minX + radius * 0.45, y: minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct VoiceIslandAudioSourceButton: View {
    let source: VoiceAudioSource
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: source.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                Text(source.title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.white.opacity(isHovered ? 1 : 0.94))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Color.white.opacity(isHovered ? 0.24 : 0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(isHovered ? 0.44 : 0.14), lineWidth: 0.8)
            }
            .shadow(color: .white.opacity(isHovered ? 0.18 : 0), radius: 6, y: 0)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct VoiceDotGridSpinner: View {
    private let columns = 3
    private let rows = 4
    private let dotSize: CGFloat = 2.6
    private let spacing: CGFloat = 3.2

    // Distinct slow frequencies and phases per dot so the shimmer reads as random
    // while every fade stays smooth and continuous (ease-in-out via cosine).
    private let frequencies: [Double] = [
        0.55, 0.82, 0.67, 0.94,
        0.73, 0.60, 0.88, 0.70,
        0.63, 0.90, 0.76, 0.58
    ]
    private let phases: [Double] = [
        0.0, 2.3, 4.1, 1.2,
        5.4, 3.1, 0.7, 4.8,
        2.9, 1.9, 5.9, 3.7
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            dot(for: index, time: time)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dot(for index: Int, time: TimeInterval) -> some View {
        let wave = (cos(time * frequencies[index] * .pi + phases[index]) + 1) / 2
        let opacity = 0.16 + wave * 0.84
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color.white.opacity(0.78)
                    ],
                    center: UnitPoint(x: 0.34, y: 0.3),
                    startRadius: 0.2,
                    endRadius: dotSize * 0.75
                )
            )
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.55 * opacity), lineWidth: 0.5)
            }
            .frame(width: dotSize, height: dotSize)
            .opacity(opacity)
            .shadow(color: .white.opacity(0.28 * opacity), radius: 1.6)
    }
}

private struct VoiceOrbitingCirclesSpinner: View {
    private let radii: [CGFloat] = [0.94, 1.05, 0.88, 1.10, 0.98]
    private let baseSizes: [CGFloat] = [6.4, 7.6, 5.8, 8.4, 7.0]
    private let sizeFrequencies: [Double] = [0.62, 0.84, 0.71, 0.93, 0.78]
    private let sizePhases: [Double] = [0.0, 1.4, 2.8, 4.1, 5.6]
    private let phaseOffsets: [Double] = [0.0, 1.18, 2.48, 3.74, 5.08]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 36.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let orbit = side * 0.22
                ZStack {
                    ForEach(0..<5, id: \.self) { index in
                        let angle = time * 0.82 + phaseOffsets[index]
                        let wobble = sin(time * 0.52 + Double(index) * 1.63) * 1.6
                        let radius = orbit * radii[index] + CGFloat(wobble)
                        let sizeWave = (sin(time * sizeFrequencies[index] + sizePhases[index]) + 1) / 2
                        // Stronger pulse: ~0.48× → ~1.55× base size.
                        let dotSize = baseSizes[index] * (0.48 + sizeWave * 1.07)
                        let glowOpacity = 0.22 + sizeWave * 0.58
                        let glowRadius = 3.2 + sizeWave * 7.5
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.88),
                                        Color.white.opacity(0.18 + sizeWave * 0.22)
                                    ],
                                    center: UnitPoint(x: 0.30, y: 0.26),
                                    startRadius: 0.4,
                                    endRadius: dotSize
                                )
                            )
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.52 + sizeWave * 0.28), lineWidth: 0.6)
                            }
                            .frame(width: dotSize, height: dotSize)
                            .background {
                                Circle()
                                    .fill(Color.white.opacity(0.10 + sizeWave * 0.38))
                                    .blur(radius: 3.5 + sizeWave * 5.5)
                                    .scaleEffect(1.55 + sizeWave * 0.55)
                            }
                            .shadow(color: .white.opacity(glowOpacity), radius: glowRadius)
                            .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

private struct VoiceRecordingDot: View {
    let isPaused: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let blink = isPaused ? 1 : 0.42 + (sin(time * 7.6) + 1) * 0.29

            Circle()
                .fill(isPaused ? Color.orange : Color.red)
                .opacity(blink)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                }
                .shadow(color: (isPaused ? Color.orange : Color.red).opacity(isPaused ? 0.3 : 0.65), radius: isPaused ? 4 : 8)
                .animation(.easeInOut(duration: 0.18), value: isPaused)
        }
    }
}

private struct VoiceStatusBarLabel: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        HStack(spacing: 6) {
            if store.isVoiceCapturePaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 9, weight: .bold))
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .symbolEffect(.variableColor.iterative, options: .repeating, value: store.activeVoiceCaptureTarget != nil)
            }

            Text(store.isVoiceCapturePaused ? "Paused" : "Recording")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Color.black.opacity(0.90))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.28), radius: 7, y: 2)
        .animation(.easeOut(duration: 0.16), value: store.isVoiceCapturePaused)
    }
}

private struct VoiceStatusBarView: View {
    @ObservedObject var store: BrainStore

    private var targetTitle: String {
        switch store.activeVoiceCaptureTarget {
        case .editor:
            if let captureTitle = store.voiceCaptureDestinationTitle?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !captureTitle.isEmpty {
                return "\(captureTitle) dictation"
            }
            let openTitle = store.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\((openTitle.isEmpty ? "Untitled" : openTitle)) dictation"
        case .helpDesk:
            return "Zirn Chat voice"
        case nil:
            return "Voice capture"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.88))
                        .frame(width: 34, height: 34)
                    if store.isVoiceCapturePaused {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        MenuBarAudioLinesIcon()
                            .frame(width: 22, height: 18)
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isVoiceCapturePaused ? "Voice paused" : "Recording voice")
                        .font(.system(size: 13, weight: .bold))
                    Text(targetTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        store.stopVoiceCapture()
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.black.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(Color.white.opacity(0.94))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        store.toggleVoiceCapturePaused()
                    }
                } label: {
                    Label(store.isVoiceCapturePaused ? "Resume" : "Pause", systemImage: store.isVoiceCapturePaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(Color.red.opacity(store.isVoiceCapturePaused ? 0.72 : 0.88))
                        .clipShape(Capsule())
                        .shadow(color: .red.opacity(0.24), radius: 9)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 280)
        .animation(.easeOut(duration: 0.16), value: store.isVoiceCapturePaused)
    }
}

private struct MenuBarAudioLinesIcon: View {
    private let baseHeights: [CGFloat] = [0.20, 0.52, 0.84, 0.38, 0.62, 0.22]

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(baseHeights.indices, id: \.self) { index in
                    Capsule(style: .continuous)
                        .frame(width: 2, height: lineHeight(for: index, time: time))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func lineHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let wave = (sin(time * 7.2 + Double(index) * 0.84) + 1) / 2
        return 4 + (baseHeights[index] * 8) + CGFloat(wave) * 4
    }
}

private struct UsageStatusBarView: View {
    @ObservedObject var store: BrainStore

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Usage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(store.totalUsageLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 18)

                Text(store.totalUsagePercentLabel)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            ProgressView(value: store.totalUsageFraction)
                .progressViewStyle(.linear)
                .controlSize(.small)

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                UsageBreakdownRow(
                    title: "Mistral usage",
                    value: store.mistralUsageBreakdownLabel,
                    icon: .asset("ProviderMistralLogo")
                )

                UsageBreakdownRow(
                    title: "Mistral OCR",
                    value: store.mistralOCRUsageBreakdownLabel,
                    icon: .symbol("doc.viewfinder")
                )

                UsageBreakdownRow(
                    title: "DeepSeek usage",
                    value: store.deepSeekUsageBreakdownLabel,
                    icon: .asset("ProviderDeepSeekLogo")
                )
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}

private struct UsageBreakdownRow: View {
    let title: String
    let value: String
    let icon: UsageBreakdownIcon

    var body: some View {
        HStack(spacing: 9) {
            iconView
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.86))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private enum UsageBreakdownIcon {
    case asset(String)
    case symbol(String)
}

private enum ZirnReleaseInfo {
    static let codename = "Raxat"

    static var displayVersion: String {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "1.4.1"
        return "v\(version) (\(codename))"
    }
}
