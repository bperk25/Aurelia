//
//  MenuBarPopoverView.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import SwiftUI
import Carbon.HIToolbox

struct MenuBarPopoverView: View {
    private var clipboardManager = ClipboardManager.shared
    @State private var selectedIndex: Int = 0
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

        return Array(baseItems.prefix(15))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effect
            HStack {
                Text("Aurelia")
                    .font(AureliaDesign.Typography.headline)
                    .foregroundStyle(AureliaColors.primaryText)

                Spacer()

                Button {
                    MenuBarManager.shared.hidePopover()
                    AppDelegate.showMainWindow()
                } label: {
                    Text("Open App")
                        .font(AureliaDesign.Typography.caption)
                        .foregroundStyle(AureliaColors.electricCyan)
                }
                .buttonStyle(.borderless)
            }
            .padding(AureliaDesign.Spacing.md)
            .background(.ultraThinMaterial)
            .background(AureliaColors.abyssMedium.opacity(0.5))

            Divider()
                .background(AureliaColors.separator)

            // Recent items with depth opacity
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
                                MenuBarItemRow(
                                    item: item,
                                    isSelected: index == selectedIndex
                                ) {
                                    selectItem(item)
                                }
                                .id(index)
                                .depthOpacity(index: index, surfaceCount: 5)
                            }
                        }
                        .padding(AureliaDesign.Spacing.sm)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            Divider()
                .background(AureliaColors.separator)

            // Group selector
            HStack(spacing: AureliaDesign.Spacing.md) {
                // Left arrow
                Button {
                    navigateGroup(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
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
                                .font(.system(size: 9))
                            Text(option.name)
                                .font(AureliaDesign.Typography.captionBold)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 7))
                        }
                    }
                    .foregroundStyle(AureliaColors.secondaryText)
                    .padding(.horizontal, AureliaDesign.Spacing.sm)
                    .padding(.vertical, 4)
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(groupOptions.count > 1 ? AureliaColors.secondaryText : AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .disabled(groupOptions.count <= 1)
            }
            .padding(.horizontal, AureliaDesign.Spacing.md)
            .padding(.vertical, AureliaDesign.Spacing.sm)
            .background(AureliaColors.abyssMedium.opacity(0.6))

            Divider()
                .background(AureliaColors.separator)

            // Footer with glass effect
            HStack {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AureliaColors.secondaryText)

                Spacer()

                Button("Quit Aurelia") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AureliaColors.secondaryText)
            }
            .font(AureliaDesign.Typography.caption)
            .padding(AureliaDesign.Spacing.md)
            .background(.ultraThinMaterial)
            .background(AureliaColors.abyssMedium.opacity(0.5))
        }
        .frame(
            width: AureliaDesign.Layout.menuBarPopoverWidth,
            height: AureliaDesign.Layout.menuBarPopoverHeight
        )
        .background(AureliaColors.abyss.opacity(0.95))
        .background(KeyboardHandler(
            onArrowUp: { moveSelection(by: -1) },
            onArrowDown: { moveSelection(by: 1) },
            onArrowLeft: { navigateGroup(by: -1) },
            onArrowRight: { navigateGroup(by: 1) },
            onEnter: { selectCurrentItem() },
            onEscape: { MenuBarManager.shared.hidePopover() }
        ))
        .onAppear {
            selectedIndex = 0
            selectedGroupIndex = 0
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
        selectItem(visibleItems[selectedIndex])
    }

    private func selectItem(_ item: ClipboardItem) {
        clipboardManager.copyToClipboard(item)
        MenuBarManager.shared.hidePopover()

        // Return focus to previous app and paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            MenuBarManager.shared.activatePreviousApp()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HotkeyManager.simulatePaste()
            }
        }
    }
}

// MARK: - Keyboard Handler

struct KeyboardHandler: NSViewRepresentable {
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onArrowLeft: () -> Void
    let onArrowRight: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.onArrowUp = onArrowUp
        view.onArrowDown = onArrowDown
        view.onArrowLeft = onArrowLeft
        view.onArrowRight = onArrowRight
        view.onEnter = onEnter
        view.onEscape = onEscape
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyboardView, context: Context) {
        nsView.onArrowUp = onArrowUp
        nsView.onArrowDown = onArrowDown
        nsView.onArrowLeft = onArrowLeft
        nsView.onArrowRight = onArrowRight
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape
    }
}

class KeyboardView: NSView {
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onArrowLeft: (() -> Void)?
    var onArrowRight: (() -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_UpArrow:
            onArrowUp?()
        case kVK_DownArrow:
            onArrowDown?()
        case kVK_LeftArrow:
            onArrowLeft?()
        case kVK_RightArrow:
            onArrowRight?()
        case kVK_Return:
            onEnter?()
        case kVK_Escape:
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    let item: ClipboardItem
    var isSelected: Bool = false
    let onTap: () -> Void

    @State private var isHovering = false

    private var isHighlighted: Bool {
        isSelected || isHovering
    }

    var body: some View {
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
            .background(isHighlighted ? AureliaColors.hover : Color.clear)
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm)
                        .stroke(AureliaColors.electricCyan.opacity(0.3), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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

#Preview {
    MenuBarPopoverView()
}
