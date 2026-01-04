//
//  FloatingPanelManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import AppKit
import SwiftUI
import Carbon.HIToolbox

/// Manages a floating panel that slides in from the right
final class FloatingPanelManager {
    static let shared = FloatingPanelManager()

    private var panel: KeyboardPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var localMonitor: Any?

    /// The app that was active before showing the panel
    private var previousApp: NSRunningApplication?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private init() {}

    func setup() {
        createPanel()
    }

    private func createPanel() {
        // Create the panel - use regular panel that CAN take focus for keyboard navigation
        let panel = KeyboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel behavior
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        // Set up keyboard handler
        panel.onKeyDown = { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }

        self.panel = panel
        updatePanelContent()
    }

    private func updatePanelContent() {
        guard let panel = panel else { return }

        // Create the SwiftUI view with current shortcut
        let view = FloatingClipboardView(
            shortcutString: HotkeyManager.shared.shortcutDisplayString,
            onSelect: { [weak self] item in
                self?.selectItem(item)
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )

        let hostingView = NSHostingView(rootView: AnyView(view))
        panel.contentView = hostingView
        self.hostingView = hostingView
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let panel = panel else {
            setup()
            show()
            return
        }

        // Update content to reflect current shortcut
        updatePanelContent()

        // Store the current frontmost app before showing
        previousApp = NSWorkspace.shared.frontmostApplication

        // Reset selection to first item
        NotificationCenter.default.post(name: .floatingPanelWillShow, object: nil)

        // Position panel on the RIGHT side of the main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelHeight: CGFloat = min(500, screenFrame.height - 100)
            let panelWidth: CGFloat = 340

            // Start off-screen to the RIGHT
            let startX = screenFrame.maxX
            let targetX = screenFrame.maxX - panelWidth - 20
            let y = screenFrame.midY - panelHeight / 2

            panel.setFrame(NSRect(x: startX, y: y, width: panelWidth, height: panelHeight), display: false)
            panel.orderFrontRegardless()

            // Animate sliding in from RIGHT
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(
                    NSRect(x: targetX, y: y, width: panelWidth, height: panelHeight),
                    display: true
                )
            }

            // Activate app and make panel key so it receives keyboard events immediately
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        // Add local monitor to capture key events
        setupLocalMonitor()
    }

    private func setupLocalMonitor() {
        removeLocalMonitor()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            switch Int(event.keyCode) {
            case kVK_UpArrow:
                NotificationCenter.default.post(name: .floatingPanelArrowUp, object: nil)
                return nil
            case kVK_DownArrow:
                NotificationCenter.default.post(name: .floatingPanelArrowDown, object: nil)
                return nil
            case kVK_Return:
                NotificationCenter.default.post(name: .floatingPanelEnter, object: nil)
                return nil
            case kVK_Escape:
                self.hide()
                return nil
            default:
                return event
            }
        }
    }

    private func removeLocalMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func hide() {
        guard let panel = panel, panel.isVisible else { return }

        removeLocalMonitor()

        // Animate sliding out to RIGHT
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let targetX = screenFrame.maxX

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(
                    NSRect(x: targetX, y: panelFrame.minY, width: panelFrame.width, height: panelFrame.height),
                    display: true
                )
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }
    }

    private func selectItem(_ item: ClipboardItem) {
        // Copy item to clipboard
        ClipboardManager.shared.copyToClipboard(item)

        // Hide panel immediately
        panel?.orderOut(nil)

        // Activate previous app and paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.previousApp?.activate(options: [])

            // Simulate Cmd+V paste after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HotkeyManager.simulatePaste()
            }
        }
    }

    // MARK: - Keyboard Handling

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

        switch Int(event.keyCode) {
        case kVK_UpArrow:
            NotificationCenter.default.post(name: .floatingPanelArrowUp, object: nil)
            return true
        case kVK_DownArrow:
            NotificationCenter.default.post(name: .floatingPanelArrowDown, object: nil)
            return true
        case kVK_Return:
            NotificationCenter.default.post(name: .floatingPanelEnter, object: nil)
            return true
        case kVK_Escape:
            hide()
            return true
        default:
            return false
        }
    }
}

// MARK: - Custom Panel for Keyboard Handling

class KeyboardPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if let handler = onKeyDown, handler(event) {
            return // Event was handled
        }
        super.keyDown(with: event)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let floatingPanelWillShow = Notification.Name("floatingPanelWillShow")
    static let floatingPanelArrowUp = Notification.Name("floatingPanelArrowUp")
    static let floatingPanelArrowDown = Notification.Name("floatingPanelArrowDown")
    static let floatingPanelEnter = Notification.Name("floatingPanelEnter")
}

// MARK: - Floating Clipboard View

struct FloatingClipboardView: View {
    let shortcutString: String
    let onSelect: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    @State private var clipboardManager = ClipboardManager.shared
    @State private var selectedIndex: Int = 0

    private var visibleItems: [ClipboardItem] {
        Array(clipboardManager.items.prefix(15))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Aurelia")
                    .font(AureliaDesign.Typography.headline)
                    .foregroundStyle(AureliaColors.primaryText)

                Spacer()

                Text(shortcutString)
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.tertiaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AureliaColors.abyssMedium)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(AureliaDesign.Spacing.md)
            .background(AureliaColors.abyssMedium.opacity(0.8))

            Divider()
                .background(AureliaColors.separator)

            // Items list
            if clipboardManager.items.isEmpty {
                VStack(spacing: AureliaDesign.Spacing.sm) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 32))
                        .foregroundStyle(AureliaColors.tertiaryText)
                    Text("The deep awaits...")
                        .font(AureliaDesign.Typography.body)
                        .foregroundStyle(AureliaColors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: AureliaDesign.Spacing.xs) {
                            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                                floatingItemRow(for: item, at: index)
                            }
                        }
                        .padding(AureliaDesign.Spacing.sm)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            Divider()
                .background(AureliaColors.separator)

            // Footer hint
            HStack {
                Text("↑↓ Navigate")
                    .foregroundStyle(AureliaColors.tertiaryText)
                Spacer()
                Text("↩ Paste")
                    .foregroundStyle(AureliaColors.tertiaryText)
                Spacer()
                Text("esc Close")
                    .foregroundStyle(AureliaColors.tertiaryText)
            }
            .font(AureliaDesign.Typography.caption)
            .padding(AureliaDesign.Spacing.sm)
            .background(AureliaColors.abyssMedium.opacity(0.8))
        }
        .background(AureliaColors.abyss)
        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg)
                .stroke(AureliaColors.electricCyan.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: AureliaColors.electricCyan.opacity(0.1), radius: 20)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelWillShow)) { _ in
            selectedIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelArrowUp)) { _ in
            moveSelection(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelArrowDown)) { _ in
            moveSelection(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelEnter)) { _ in
            selectCurrentItem()
        }
    }

    private func moveSelection(by delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < visibleItems.count {
            selectedIndex = newIndex
        }
    }

    private func selectCurrentItem() {
        guard !visibleItems.isEmpty, selectedIndex < visibleItems.count else { return }
        onSelect(visibleItems[selectedIndex])
    }

    @ViewBuilder
    private func floatingItemRow(for item: ClipboardItem, at index: Int) -> some View {
        FloatingItemRow(
            item: item,
            isSelected: index == selectedIndex,
            onTap: {
                onSelect(item)
            },
            onDelete: {
                deleteItem(item)
            }
        )
        .id(index)
        .depthOpacity(index: index, surfaceCount: 5)
    }

    private func deleteItem(_ item: ClipboardItem) {
        let currentCount = visibleItems.count
        ClipboardManager.shared.delete(item)
        // Adjust selection if needed
        if selectedIndex >= currentCount - 1 {
            selectedIndex = max(0, currentCount - 2)
        }
    }
}

// MARK: - Floating Item Row

struct FloatingItemRow: View {
    let item: ClipboardItem
    var isSelected: Bool = false
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var isHovering = false

    private var isHighlighted: Bool {
        isSelected || isHovering
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: AureliaDesign.Spacing.sm) {
                    // Content type icon
                    Image(systemName: iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(iconColor)
                        .frame(width: 20)

                    // Content preview
                    VStack(alignment: .leading, spacing: 2) {
                        Text(previewText)
                            .font(AureliaDesign.Typography.body)
                            .foregroundStyle(AureliaColors.primaryText)
                            .lineLimit(1)

                        Text(item.programName)
                            .font(AureliaDesign.Typography.caption)
                            .foregroundStyle(AureliaColors.tertiaryText)
                    }

                    Spacer()

                    // Anchored indicator
                    if item.isPinned {
                        Image("AnchorIcon")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(AureliaColors.anchored)
                    }

                    // Timestamp
                    Text(timeAgo)
                        .font(AureliaDesign.Typography.caption)
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .padding(.horizontal, AureliaDesign.Spacing.sm)
                .padding(.vertical, AureliaDesign.Spacing.xs)
            }
            .buttonStyle(.plain)

            // Delete button (shows on hover)
            if isHovering, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .padding(.trailing, AureliaDesign.Spacing.sm)
                .transition(.opacity)
            }
        }
        .background(isHighlighted ? AureliaColors.hover : Color.clear)
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm)
                    .stroke(AureliaColors.electricCyan.opacity(0.3), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm))
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    private var previewText: String {
        switch item.content {
        case .text(let text):
            return text.replacingOccurrences(of: "\n", with: " ").prefix(50) + (text.count > 50 ? "..." : "")
        case .image:
            return "Image"
        case .file(let urls):
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files"
        }
    }

    private var iconName: String {
        switch item.content {
        case .text(let text):
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                return "link"
            }
            return "doc.text"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }

    private var iconColor: Color {
        switch item.content {
        case .text(let text):
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                return AureliaColors.linkType
            }
            return AureliaColors.textType
        case .image:
            return AureliaColors.imageType
        case .file:
            return AureliaColors.fileType
        }
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(item.timestamp)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}
