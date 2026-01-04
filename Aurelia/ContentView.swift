import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings
    private var clipboardManager = ClipboardManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: ContentTypeFilter = .all
    @State private var selectedSidebarItem: SidebarItem = .all
    @State private var showingClearConfirmation = false

    enum SidebarItem: Hashable {
        case all
        case starred
    }

    var filteredItems: [ClipboardItem] {
        var items: [ClipboardItem]

        switch selectedSidebarItem {
        case .all:
            items = clipboardManager.items
        case .starred:
            items = clipboardManager.pinnedItems
        }

        return clipboardManager.filteredItems(searchText: searchText, contentType: selectedFilter)
            .filter { item in
                switch selectedSidebarItem {
                case .all: return true
                case .starred: return item.isPinned
                }
            }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSidebarItem) {
                Section("Library") {
                    Label("All Items", systemImage: "tray.full")
                        .tag(SidebarItem.all)

                    Label {
                        Text("Anchored")
                    } icon: {
                        Image("AnchorIcon")
                            .renderingMode(.template)
                    }
                    .foregroundStyle(AureliaColors.anchored)
                    .tag(SidebarItem.starred)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .background(AureliaColors.sidebarBackground)
        } detail: {
            // Main content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, AureliaDesign.Spacing.lg)
                    .padding(.vertical, AureliaDesign.Spacing.md)

                Divider()
                    .background(AureliaColors.separator)

                // Content area
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 220))],
                            spacing: AureliaDesign.Spacing.md
                        ) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemCard(
                                    item: item,
                                    clipboardManager: clipboardManager
                                )
                                .depthOpacity(index: index, surfaceCount: 8)
                            }
                        }
                        .padding(AureliaDesign.Spacing.lg)
                    }
                }
            }
            .frame(minWidth: 600)
            .background(AureliaColors.windowBackground)
        }
        .navigationTitle("Aurelia")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .background(AureliaColors.abyss)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: AureliaDesign.Spacing.md) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AureliaColors.secondaryText)
                TextField("Search clipboard...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AureliaColors.primaryText)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AureliaColors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AureliaDesign.Spacing.sm)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.md))
            .frame(maxWidth: 300)

            Spacer()

            // Filter buttons
            HStack(spacing: AureliaDesign.Spacing.xs) {
                ForEach(ContentTypeFilter.allCases) { filter in
                    FilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(AureliaDesign.Animation.quick) {
                            selectedFilter = filter
                        }
                    }
                }
            }

            // Clear button
            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(AureliaColors.destructive)
            .alert("Clear Clipboard History", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clipboardManager.clearAll()
                }
            } message: {
                Text("All your clipboard items will be washed away into the deep. This cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AureliaDesign.Spacing.md) {
            Group {
                if selectedSidebarItem == .starred {
                    Image("AnchorIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "water.waves")
                }
            }
                .font(.system(size: 48))
                .foregroundStyle(AureliaColors.tertiaryText)

            Text(emptyStateMessage)
                .font(AureliaDesign.Typography.body)
                .foregroundStyle(AureliaColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No items found in these waters"
        }
        switch selectedSidebarItem {
        case .all:
            return "The deep awaits..."
        case .starred:
            return "Anchor items to keep them safe"
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let filter: ContentTypeFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AureliaDesign.Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11))
                Text(filter.rawValue)
                    .font(AureliaDesign.Typography.captionBold)
            }
            .padding(.horizontal, AureliaDesign.Spacing.sm)
            .padding(.vertical, AureliaDesign.Spacing.xs)
            .background(isSelected ? AureliaColors.accent.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? AureliaColors.accent : AureliaColors.secondaryText)
            .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clipboard Item Card

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let clipboardManager: ClipboardManager

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: AureliaDesign.Spacing.sm) {
            // Content preview
            contentPreview
                .frame(
                    width: AureliaDesign.Card.width,
                    height: AureliaDesign.Card.previewHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.md))

            // Metadata
            HStack {
                ContentTypeBadge(type: item.content.contentType)

                Spacer()

                if item.isPinned {
                    Image("AnchorIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(AureliaColors.anchored)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.programName)
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.secondaryText)
                    .lineLimit(1)

                Text(ClipboardManager.formatDate(item.timestamp))
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.tertiaryText)
            }
        }
        .padding(AureliaDesign.Spacing.sm)
        .frame(width: AureliaDesign.Card.width + AureliaDesign.Spacing.sm * 2)
        .bioluminescentCard(isHovering: isHovering)
        .scaleEffect(isHovering ? 1.015 : 1.0)
        .animation(AureliaDesign.Animation.gentle, value: isHovering)
        .onHover { isHovering = $0 }
        .onTapGesture {
            clipboardManager.copyToClipboard(item)
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch item.content {
        case .text(let text):
            Text(text)
                .font(AureliaDesign.Typography.body)
                .foregroundStyle(AureliaColors.primaryText)
                .lineLimit(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(AureliaDesign.Spacing.sm)
                .background(
                    item.content.contentType == "Link"
                        ? AureliaColors.linkType.opacity(0.1)
                        : AureliaColors.textType.opacity(0.1)
                )

        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderView(icon: "photo", text: "Image")
            }

        case .file(let urls):
            VStack(alignment: .leading, spacing: AureliaDesign.Spacing.xs) {
                ForEach(urls.prefix(3), id: \.self) { url in
                    HStack(spacing: AureliaDesign.Spacing.xs) {
                        Image(systemName: "doc")
                            .foregroundStyle(AureliaColors.fileType)
                        Text(url.lastPathComponent)
                            .font(AureliaDesign.Typography.caption)
                            .foregroundStyle(AureliaColors.primaryText)
                            .lineLimit(1)
                    }
                }
                if urls.count > 3 {
                    Text("+ \(urls.count - 3) more")
                        .font(AureliaDesign.Typography.caption)
                        .foregroundStyle(AureliaColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(AureliaDesign.Spacing.sm)
            .background(AureliaColors.fileType.opacity(0.1))
        }
    }

    private func placeholderView(icon: String, text: String) -> some View {
        VStack(spacing: AureliaDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(AureliaColors.tertiaryText)
            Text(text)
                .font(AureliaDesign.Typography.caption)
                .foregroundStyle(AureliaColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AureliaColors.abyssMedium)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            clipboardManager.copyToClipboard(item)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if case .text = item.content {
            Button {
                clipboardManager.copyAsPlainText(item)
            } label: {
                Label("Copy as Plain Text", systemImage: "text.alignleft")
            }
        }

        Divider()

        Button {
            clipboardManager.togglePinned(item)
        } label: {
            Label(
                item.isPinned ? "Remove Anchor" : "Anchor",
                systemImage: item.isPinned ? "xmark.circle" : "arrow.down.to.line"
            )
        }

        Divider()

        Button(role: .destructive) {
            clipboardManager.delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    ContentView()
}
