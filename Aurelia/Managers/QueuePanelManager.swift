//
//  QueuePanelManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import AppKit
import SwiftUI
import Carbon.HIToolbox

/// Manages the floating queue preview panel
final class QueuePanelManager {
    static let shared = QueuePanelManager()

    private var panel: QueuePanel?
    private var hostingView: NSHostingView<AnyView>?
    private var localMonitor: Any?
    private var globalMouseMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 400

    private init() {}

    func setup() {
        createPanel()
    }

    private func createPanel() {
        let panel = QueuePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure panel behavior - non-activating so it doesn't steal focus
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true  // Allow dragging
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true  // Don't take focus unnecessarily

        // Track window moves to persist position
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.saveWindowPosition()
        }

        // Set up keyboard handler
        panel.onKeyDown = { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }

        self.panel = panel
        updatePanelContent()
    }

    private func updatePanelContent() {
        guard let panel = panel else { return }

        let view = QueuePanelView(
            onPasteItem: { [weak self] index in
                self?.copyItemAt(index: index)
            },
            onDismiss: {
                PasteQueueManager.shared.deactivate()
            }
        )

        let hostingView = NSHostingView(rootView: AnyView(view))
        panel.contentView = hostingView
        self.hostingView = hostingView
    }

    // MARK: - Show/Hide

    func show() {
        guard let panel = panel else {
            setup()
            show()
            return
        }

        // Update content
        updatePanelContent()

        // Position panel
        if let savedPosition = PasteQueueManager.shared.windowPosition {
            // Use saved position
            panel.setFrameOrigin(savedPosition)
        } else if let screen = NSScreen.main {
            // Default: bottom-right corner
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - panelWidth - 20
            let y = screenFrame.minY + 20
            panel.setFrameOrigin(CGPoint(x: x, y: y))
        }

        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))

        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        // Don't activate app or steal focus - user should stay in their current app
        // Panel floats above all windows but doesn't take keyboard focus
        setupLocalMonitor()
        setupGlobalMouseMonitor()
    }

    func hide() {
        guard let panel = panel, panel.isVisible else { return }

        removeLocalMonitor()
        removeGlobalMouseMonitor()

        // Animate out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }

    private func saveWindowPosition() {
        guard let panel = panel else { return }
        PasteQueueManager.shared.windowPosition = panel.frame.origin
    }

    // MARK: - Keyboard Handling

    private func setupLocalMonitor() {
        removeLocalMonitor()
        setupEventTap()

        // Use global monitor for Escape and number keys
        localMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return }

            switch Int(event.keyCode) {
            case kVK_Escape:
                DispatchQueue.main.async {
                    PasteQueueManager.shared.deactivate()
                }

            default:
                // Number keys 1-9 to copy specific item to clipboard
                if let number = self.numberFromKeyCode(Int(event.keyCode)), number >= 1 && number <= 9 {
                    let index = number - 1
                    DispatchQueue.main.async {
                        if index < PasteQueueManager.shared.items.count {
                            self.copyItemAt(index: index)
                        }
                    }
                }
            }
        }
    }

    private func setupEventTap() {
        removeEventTap()

        // Create event tap to intercept Cmd+V BEFORE it reaches apps
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // Check if queue mode is active and visible
                guard QueuePanelManager.shared.isVisible else {
                    return Unmanaged.passRetained(event)
                }

                // Check for Cmd+V
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                if keyCode == Int64(kVK_ANSI_V) && flags.contains(.maskCommand) && !flags.contains(.maskShift) && !flags.contains(.maskControl) && !flags.contains(.maskAlternate) {
                    // Copy next queue item to clipboard SYNCHRONOUSLY before the paste happens
                    // This must be sync so clipboard is updated before Cmd+V is processed
                    _ = PasteQueueManager.shared.pasteNext()
                    // Let the Cmd+V continue - it will paste our queue item
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap for queue paste interception")
            return
        }

        eventTap = tap

        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }

    private func removeLocalMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        removeEventTap()
    }

    private func setupGlobalMouseMonitor() {
        removeGlobalMouseMonitor()

        // Don't close on outside click for queue panel - user may want to keep it open
        // while working. Only close via Escape or exit button.
    }

    private func removeGlobalMouseMonitor() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

        switch Int(event.keyCode) {
        case kVK_Escape:
            PasteQueueManager.shared.deactivate()
            return true
        default:
            if let number = numberFromKeyCode(Int(event.keyCode)), number >= 1 && number <= 9 {
                let index = number - 1
                if index < PasteQueueManager.shared.items.count {
                    copyItemAt(index: index)
                }
                return true
            }
            return false
        }
    }

    private func numberFromKeyCode(_ keyCode: Int) -> Int? {
        switch keyCode {
        case kVK_ANSI_1: return 1
        case kVK_ANSI_2: return 2
        case kVK_ANSI_3: return 3
        case kVK_ANSI_4: return 4
        case kVK_ANSI_5: return 5
        case kVK_ANSI_6: return 6
        case kVK_ANSI_7: return 7
        case kVK_ANSI_8: return 8
        case kVK_ANSI_9: return 9
        default: return nil
        }
    }

    // MARK: - Copy Actions

    /// Copy item at index to clipboard (user will paste manually wherever they want)
    private func copyItemAt(index: Int) {
        _ = PasteQueueManager.shared.pasteAt(index: index)
    }
}

// MARK: - Custom Panel

class QueuePanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    // Don't become key - let user stay focused in their app
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if let handler = onKeyDown, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Queue Panel View

struct QueuePanelView: View {
    let onPasteItem: (Int) -> Void
    let onDismiss: () -> Void

    @State private var queueManager = PasteQueueManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.number")
                    .font(.system(size: 14))
                    .foregroundStyle(AureliaColors.electricCyan)

                Text("Queue Mode")
                    .font(AureliaDesign.Typography.headline)
                    .foregroundStyle(AureliaColors.primaryText)

                Spacer()

                Text("\(queueManager.remainingCount) remaining")
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.tertiaryText)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(AureliaDesign.Spacing.md)
            .background(AureliaColors.abyssMedium.opacity(0.9))

            Divider()
                .background(AureliaColors.separator)

            // Queue items
            if queueManager.items.isEmpty {
                VStack(spacing: AureliaDesign.Spacing.sm) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(AureliaColors.tertiaryText)
                    Text("Copy items to add to queue")
                        .font(AureliaDesign.Typography.body)
                        .foregroundStyle(AureliaColors.secondaryText)
                    Text("Press Cmd+C to capture")
                        .font(AureliaDesign.Typography.caption)
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: AureliaDesign.Spacing.xs) {
                        ForEach(Array(queueManager.items.enumerated()), id: \.element.id) { index, item in
                            QueueItemRow(
                                item: item,
                                index: index,
                                isNext: index == queueManager.nextPasteIndex,
                                onPaste: { onPasteItem(index) },
                                onDelete: { queueManager.removeItem(at: index) }
                            )
                            .draggable(item.id.uuidString) {
                                // Drag preview
                                QueueDragPreview(item: item, index: index)
                            }
                            .dropDestination(for: String.self) { droppedItems, _ in
                                guard let droppedID = droppedItems.first,
                                      let sourceIndex = queueManager.items.firstIndex(where: { $0.id.uuidString == droppedID }) else {
                                    return false
                                }
                                if sourceIndex != index {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        queueManager.reorder(from: sourceIndex, to: index)
                                    }
                                }
                                return true
                            }
                        }
                    }
                    .padding(AureliaDesign.Spacing.sm)
                }
            }

            Divider()
                .background(AureliaColors.separator)

            // Footer controls
            HStack {
                Button {
                    queueManager.flipOrder()
                } label: {
                    Label("Flip", systemImage: "arrow.up.arrow.down")
                        .font(AureliaDesign.Typography.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AureliaColors.secondaryText)
                .disabled(queueManager.remainingCount < 2)

                Spacer()

                Button {
                    queueManager.clearQueue()
                } label: {
                    Label("Wash", systemImage: "water.waves")
                        .font(AureliaDesign.Typography.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AureliaColors.destructive)
                .disabled(queueManager.items.isEmpty)
            }
            .padding(AureliaDesign.Spacing.sm)
            .background(AureliaColors.abyssMedium.opacity(0.9))
        }
        .background(AureliaColors.abyss.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg)
                .stroke(AureliaColors.electricCyan.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: AureliaColors.electricCyan.opacity(0.15), radius: 20)
    }
}

// MARK: - Queue Item Row

struct QueueItemRow: View {
    let item: QueuedItem
    let index: Int
    let isNext: Bool
    let onPaste: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var isHighlighted: Bool {
        isNext || isHovering
    }

    var body: some View {
        HStack(spacing: AureliaDesign.Spacing.sm) {
            // Order number
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isNext ? AureliaColors.electricCyan : AureliaColors.tertiaryText)
                .frame(width: 20)

            // Content preview
            Button(action: onPaste) {
                HStack(spacing: AureliaDesign.Spacing.sm) {
                    Image(systemName: iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(iconColor)
                        .frame(width: 16)

                    Text(previewText)
                        .font(AureliaDesign.Typography.body)
                        .foregroundStyle(item.isPasted ? AureliaColors.tertiaryText : AureliaColors.primaryText)
                        .lineLimit(1)

                    Spacer()

                    if item.isPasted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AureliaColors.electricCyan.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            // Delete button
            if isHovering && !item.isPasted {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, AureliaDesign.Spacing.sm)
        .padding(.vertical, AureliaDesign.Spacing.xs)
        .background(isHighlighted ? AureliaColors.hover : Color.clear)
        .opacity(item.isPasted ? 0.5 : 1.0)
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm)
                    .stroke(AureliaColors.electricCyan.opacity(0.5), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm))
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    private var previewText: String {
        switch item.clipboardItem.content {
        case .text(let text):
            return text.replacingOccurrences(of: "\n", with: " ").prefix(40) + (text.count > 40 ? "..." : "")
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
        switch item.clipboardItem.content {
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
        switch item.clipboardItem.content {
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
}

// MARK: - Drag Preview

struct QueueDragPreview: View {
    let item: QueuedItem
    let index: Int

    var body: some View {
        HStack(spacing: AureliaDesign.Spacing.sm) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AureliaColors.electricCyan)

            Text(previewText)
                .font(AureliaDesign.Typography.body)
                .foregroundStyle(AureliaColors.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, AureliaDesign.Spacing.md)
        .padding(.vertical, AureliaDesign.Spacing.sm)
        .background(AureliaColors.abyss.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm)
                .stroke(AureliaColors.electricCyan.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: AureliaColors.electricCyan.opacity(0.3), radius: 8)
    }

    private var previewText: String {
        switch item.clipboardItem.content {
        case .text(let text):
            return String(text.replacingOccurrences(of: "\n", with: " ").prefix(30)) + (text.count > 30 ? "..." : "")
        case .image:
            return "Image"
        case .file(let urls):
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files"
        }
    }
}
