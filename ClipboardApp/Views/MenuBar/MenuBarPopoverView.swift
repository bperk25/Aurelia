//
//  MenuBarPopoverView.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import SwiftUI

struct MenuBarPopoverView: View {
    @State private var clipboardManager = ClipboardManager()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Aurelia")
                    .font(AureliaDesign.Typography.headline)
                    .foregroundStyle(AureliaColors.primaryText)

                Spacer()

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "Aurelia" || $0.isKeyWindow }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    Text("Open App")
                        .font(AureliaDesign.Typography.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(AureliaDesign.Spacing.md)
            .background(AureliaColors.sidebarBackground)

            Divider()

            // Recent items
            if clipboardManager.items.isEmpty {
                VStack(spacing: AureliaDesign.Spacing.sm) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(AureliaColors.tertiaryText)
                    Text("No clipboard history")
                        .font(AureliaDesign.Typography.body)
                        .foregroundStyle(AureliaColors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: AureliaDesign.Spacing.xs) {
                        ForEach(clipboardManager.items.prefix(15)) { item in
                            MenuBarItemRow(item: item) {
                                clipboardManager.copyToClipboard(item)
                                MenuBarManager.shared.hidePopover()
                            }
                        }
                    }
                    .padding(AureliaDesign.Spacing.sm)
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit Aurelia") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .font(AureliaDesign.Typography.caption)
            .padding(AureliaDesign.Spacing.md)
            .background(AureliaColors.sidebarBackground)
        }
        .frame(
            width: AureliaDesign.Layout.menuBarPopoverWidth,
            height: AureliaDesign.Layout.menuBarPopoverHeight
        )
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    let item: ClipboardItem
    let onTap: () -> Void

    @State private var isHovering = false

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

                // Timestamp
                Text(timeAgo)
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.tertiaryText)
            }
            .padding(.horizontal, AureliaDesign.Spacing.sm)
            .padding(.vertical, AureliaDesign.Spacing.xs)
            .background(isHovering ? AureliaColors.hover : Color.clear)
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
