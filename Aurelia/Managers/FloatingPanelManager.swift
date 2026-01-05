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
    private var globalMouseMonitor: Any?

    /// The app that was active before showing the panel
    private var previousApp: NSRunningApplication?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Panel dimensions based on view mode
    private var panelWidth: CGFloat {
        AppSettings.shared.panelViewMode == .thumbnail ? 480 : 340
    }

    private var panelHeight: CGFloat {
        500
    }

    private init() {}

    func setup() {
        createPanel()
    }

    private func createPanel() {
        // Create the panel - use regular panel that CAN take focus for keyboard navigation
        let panel = KeyboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
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

        // Create the SwiftUI view with current shortcut and view mode
        let view = FloatingClipboardView(
            shortcutString: HotkeyManager.shared.shortcutDisplayString,
            viewMode: AppSettings.shared.panelViewMode,
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

        // Update panel size based on current view mode
        let width = panelWidth
        let height = panelHeight

        // Update content to reflect current shortcut and view mode
        updatePanelContent()

        // Store the current frontmost app before showing
        previousApp = NSWorkspace.shared.frontmostApplication

        // Reset selection to first item
        NotificationCenter.default.post(name: .floatingPanelWillShow, object: nil)

        // Position panel on the RIGHT side of the main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let finalHeight: CGFloat = min(height, screenFrame.height - 100)

            // Start off-screen to the RIGHT
            let startX = screenFrame.maxX
            let targetX = screenFrame.maxX - width - 20
            let y = screenFrame.midY - finalHeight / 2

            panel.setFrame(NSRect(x: startX, y: y, width: width, height: finalHeight), display: false)
            panel.orderFrontRegardless()

            // Animate sliding in from RIGHT
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(
                    NSRect(x: targetX, y: y, width: width, height: finalHeight),
                    display: true
                )
            }

            // Activate app and make panel key so it receives keyboard events immediately
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        // Add monitors to capture events
        setupLocalMonitor()
        setupGlobalMouseMonitor()
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
            case kVK_LeftArrow:
                NotificationCenter.default.post(name: .floatingPanelArrowLeft, object: nil)
                return nil
            case kVK_RightArrow:
                NotificationCenter.default.post(name: .floatingPanelArrowRight, object: nil)
                return nil
            case kVK_Return:
                NotificationCenter.default.post(name: .floatingPanelEnter, object: nil)
                return nil
            case kVK_Escape:
                self.hide()
                return nil
            case kVK_Delete:  // Backspace key
                NotificationCenter.default.post(name: .floatingPanelBackspace, object: nil)
                return nil
            default:
                // Handle character input for search
                if let chars = event.characters, !chars.isEmpty {
                    // Only handle printable characters (no modifiers except shift)
                    let modifiers = event.modifierFlags.intersection([.command, .option, .control])
                    if modifiers.isEmpty {
                        NotificationCenter.default.post(name: .floatingPanelCharacter, object: chars)
                        return nil
                    }
                }
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

    private func setupGlobalMouseMonitor() {
        removeGlobalMouseMonitor()

        // Monitor clicks outside the panel
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible, let panel = self.panel else { return }

            // Get click location in screen coordinates
            let clickLocation = event.locationInWindow

            // Check if click is outside panel frame
            let panelFrame = panel.frame
            if !panelFrame.contains(clickLocation) {
                self.hide()
            }
        }
    }

    private func removeGlobalMouseMonitor() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }

    func hide() {
        guard let panel = panel, panel.isVisible else { return }

        removeLocalMonitor()
        removeGlobalMouseMonitor()

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
        case kVK_LeftArrow:
            NotificationCenter.default.post(name: .floatingPanelArrowLeft, object: nil)
            return true
        case kVK_RightArrow:
            NotificationCenter.default.post(name: .floatingPanelArrowRight, object: nil)
            return true
        case kVK_Return:
            NotificationCenter.default.post(name: .floatingPanelEnter, object: nil)
            return true
        case kVK_Escape:
            hide()
            return true
        case kVK_Delete:
            NotificationCenter.default.post(name: .floatingPanelBackspace, object: nil)
            return true
        default:
            // Handle character input for search
            if let chars = event.characters, !chars.isEmpty {
                let modifiers = event.modifierFlags.intersection([.command, .option, .control])
                if modifiers.isEmpty {
                    NotificationCenter.default.post(name: .floatingPanelCharacter, object: chars)
                    return true
                }
            }
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
    static let floatingPanelArrowLeft = Notification.Name("floatingPanelArrowLeft")
    static let floatingPanelArrowRight = Notification.Name("floatingPanelArrowRight")
    static let floatingPanelEnter = Notification.Name("floatingPanelEnter")
    static let floatingPanelCharacter = Notification.Name("floatingPanelCharacter")
    static let floatingPanelBackspace = Notification.Name("floatingPanelBackspace")
}

// MARK: - Floating Clipboard View

struct FloatingClipboardView: View {
    let shortcutString: String
    let viewMode: PanelViewMode
    let onSelect: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    @State private var clipboardManager = ClipboardManager.shared
    @State private var selectedIndex: Int = 0
    @State private var searchText: String = ""
    @State private var selectedGroupIndex: Int = 0

    private struct GroupOption: Identifiable {
        let id: UUID?
        let name: String
        let isAnchored: Bool
        let icon: String

        var identifier: String { id?.uuidString ?? (isAnchored ? "anchored" : "all") }
    }

    private var groupOptions: [GroupOption] {
        var options: [GroupOption] = [
            GroupOption(id: nil, name: "All", isAnchored: false, icon: "tray.full"),
            GroupOption(id: nil, name: "Anchored", isAnchored: true, icon: "arrow.down.to.line")
        ]
        options += clipboardManager.groups.map {
            GroupOption(id: $0.id, name: $0.name, isAnchored: false, icon: "folder")
        }
        return options
    }

    private var currentGroupOption: GroupOption? {
        guard selectedGroupIndex < groupOptions.count else { return nil }
        return groupOptions[selectedGroupIndex]
    }

    private var visibleItems: [ClipboardItem] {
        let baseItems: [ClipboardItem]

        if let option = currentGroupOption {
            if option.isAnchored {
                baseItems = clipboardManager.pinnedItems
            } else if let groupID = option.id {
                baseItems = clipboardManager.items(inGroup: groupID)
            } else {
                baseItems = Array(clipboardManager.items.prefix(50))
            }
        } else {
            baseItems = Array(clipboardManager.items.prefix(50))
        }

        if searchText.isEmpty {
            return Array(baseItems.prefix(15))
        }
        let filtered = baseItems.filter { item in
            switch item.content {
            case .text(let text):
                return text.localizedCaseInsensitiveContains(searchText)
            case .image:
                return "image".localizedCaseInsensitiveContains(searchText)
            case .file(let urls):
                return urls.contains { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return Array(filtered.prefix(15))
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

            // Search bar
            HStack(spacing: AureliaDesign.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(AureliaColors.tertiaryText)

                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text("Type to search...")
                            .font(AureliaDesign.Typography.body)
                            .foregroundStyle(AureliaColors.tertiaryText)
                    }
                    Text(searchText)
                        .font(AureliaDesign.Typography.body)
                        .foregroundStyle(AureliaColors.primaryText)
                }

                Spacer()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        selectedIndex = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AureliaColors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AureliaDesign.Spacing.md)
            .padding(.vertical, AureliaDesign.Spacing.sm)
            .background(AureliaColors.abyss)

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
            } else if visibleItems.isEmpty && !searchText.isEmpty {
                VStack(spacing: AureliaDesign.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(AureliaColors.tertiaryText)
                    Text("No items found")
                        .font(AureliaDesign.Typography.body)
                        .foregroundStyle(AureliaColors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        if viewMode == .thumbnail {
                            // Thumbnail grid view
                            LazyVStack(spacing: AureliaDesign.Spacing.sm) {
                                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                                    FloatingThumbnailRow(
                                        item: item,
                                        isSelected: index == selectedIndex,
                                        onTap: { onSelect(item) },
                                        onDelete: { deleteItem(item) }
                                    )
                                    .id(index)
                                    .depthOpacity(index: index, surfaceCount: 5)
                                }
                            }
                            .padding(AureliaDesign.Spacing.sm)
                        } else {
                            // List view
                            LazyVStack(spacing: AureliaDesign.Spacing.xs) {
                                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                                    floatingItemRow(for: item, at: index)
                                }
                            }
                            .padding(AureliaDesign.Spacing.sm)
                        }
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

            // Group selector footer
            HStack(spacing: AureliaDesign.Spacing.md) {
                // Left arrow
                Button {
                    navigateGroup(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(groupOptions.count > 1 ? AureliaColors.secondaryText : AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .disabled(groupOptions.count <= 1)

                Spacer()

                // Group selector dropdown
                Menu {
                    ForEach(Array(groupOptions.enumerated()), id: \.element.identifier) { index, option in
                        Button {
                            selectedGroupIndex = index
                            selectedIndex = 0
                        } label: {
                            Label(option.name, systemImage: option.icon)
                        }
                    }
                } label: {
                    HStack(spacing: AureliaDesign.Spacing.xs) {
                        if let option = currentGroupOption {
                            Image(systemName: option.icon)
                                .font(.system(size: 10))
                            Text(option.name)
                                .font(AureliaDesign.Typography.captionBold)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                        }
                    }
                    .foregroundStyle(AureliaColors.secondaryText)
                    .padding(.horizontal, AureliaDesign.Spacing.sm)
                    .padding(.vertical, AureliaDesign.Spacing.xs)
                    .background(AureliaColors.abyssMedium)
                    .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm))
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Right arrow
                Button {
                    navigateGroup(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(groupOptions.count > 1 ? AureliaColors.secondaryText : AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .disabled(groupOptions.count <= 1)
            }
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
            selectedGroupIndex = 0
            searchText = ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelArrowUp)) { _ in
            moveSelection(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelArrowDown)) { _ in
            moveSelection(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelArrowLeft)) { _ in
            navigateGroup(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelArrowRight)) { _ in
            navigateGroup(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelEnter)) { _ in
            selectCurrentItem()
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelCharacter)) { notification in
            if let char = notification.object as? String {
                searchText += char
                selectedIndex = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatingPanelBackspace)) { _ in
            if !searchText.isEmpty {
                searchText.removeLast()
                selectedIndex = 0
            }
        }
    }

    private func moveSelection(by delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < visibleItems.count {
            selectedIndex = newIndex
        }
    }

    private func navigateGroup(by delta: Int) {
        let count = groupOptions.count
        guard count > 0 else { return }
        selectedGroupIndex = (selectedGroupIndex + delta + count) % count
        selectedIndex = 0
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

// MARK: - Floating Thumbnail Row

struct FloatingThumbnailRow: View {
    let item: ClipboardItem
    var isSelected: Bool = false
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var isHovering = false
    @State private var ogManager = OpenGraphManager.shared

    private var isHighlighted: Bool {
        isSelected || isHovering
    }

    /// Check if this is a link
    private var isLink: Bool {
        if case .text(let text) = item.content {
            return text.hasPrefix("http://") || text.hasPrefix("https://")
        }
        return false
    }

    /// Get the URL string if this is a link
    private var linkURL: String? {
        if case .text(let text) = item.content,
           text.hasPrefix("http://") || text.hasPrefix("https://") {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: AureliaDesign.Spacing.md) {
                    // Content thumbnail - always 80x60
                    contentThumbnail
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm))

                    // Content details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(previewText)
                            .font(AureliaDesign.Typography.body)
                            .foregroundStyle(AureliaColors.primaryText)
                            .lineLimit(2)

                        HStack(spacing: AureliaDesign.Spacing.xs) {
                            // Content type badge
                            ContentTypeBadge(type: item.content.contentType)

                            if item.isPinned {
                                Image("AnchorIcon")
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 8, height: 8)
                                    .foregroundStyle(AureliaColors.anchored)
                            }
                        }

                        HStack {
                            Text(item.programName)
                                .font(AureliaDesign.Typography.caption)
                                .foregroundStyle(AureliaColors.tertiaryText)

                            Spacer()

                            Text(timeAgo)
                                .font(AureliaDesign.Typography.caption)
                                .foregroundStyle(AureliaColors.tertiaryText)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(AureliaDesign.Spacing.sm)
            }
            .buttonStyle(.plain)

            // Delete button (shows on hover)
            if isHovering, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
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
                RoundedRectangle(cornerRadius: AureliaDesign.Radius.md)
                    .stroke(AureliaColors.electricCyan.opacity(0.3), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.md))
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .task {
            // Fetch OG image for links
            if let url = linkURL {
                await ogManager.fetchImage(for: url)
            }
        }
    }

    // MARK: - Content Thumbnail

    @ViewBuilder
    private var contentThumbnail: some View {
        switch item.content {
        case .text:
            if isLink, let url = linkURL {
                // Link - show OG image or link icon
                if let ogImage = ogManager.cachedImage(for: url) {
                    Image(nsImage: ogImage)
                        .resizable()
                        .scaledToFill()
                } else if ogManager.isFetching(url) {
                    // Loading state
                    ZStack {
                        AureliaColors.linkType.opacity(0.15)
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                } else {
                    // No OG image available - show link icon
                    thumbnailPlaceholder(icon: "link", color: AureliaColors.linkType)
                }
            } else {
                // Plain text - show text icon
                thumbnailPlaceholder(icon: "doc.text.fill", color: AureliaColors.textType)
            }

        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                thumbnailPlaceholder(icon: "photo", color: AureliaColors.imageType)
            }

        case .file(let urls):
            VStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AureliaColors.fileType)
                if urls.count > 1 {
                    Text("\(urls.count) files")
                        .font(.system(size: 9))
                        .foregroundStyle(AureliaColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AureliaColors.fileType.opacity(0.15))
        }
    }

    private func thumbnailPlaceholder(icon: String, color: Color) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.15))
    }

    private var previewText: String {
        switch item.content {
        case .text(let text):
            return text.replacingOccurrences(of: "\n", with: " ").prefix(80) + (text.count > 80 ? "..." : "")
        case .image:
            return "Image"
        case .file(let urls):
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files"
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
