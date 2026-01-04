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

                    Label("Starred", systemImage: "star.fill")
                        .foregroundStyle(AureliaColors.starred)
                        .tag(SidebarItem.starred)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            // Main content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, AureliaDesign.Spacing.lg)
                    .padding(.vertical, AureliaDesign.Spacing.md)

                Divider()

                // Content area
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 220))],
                            spacing: AureliaDesign.Spacing.md
                        ) {
                            ForEach(filteredItems) { item in
                                ClipboardItemCard(
                                    item: item,
                                    clipboardManager: clipboardManager
                                )
                            }
                        }
                        .padding(AureliaDesign.Spacing.lg)
                    }
                }
            }
            .frame(minWidth: 600)
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
            .background(AureliaColors.cardBackground)
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
            .alert("Clear Clipboard History", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clipboardManager.clearAll()
                }
            } message: {
                Text("Are you sure you want to delete all clipboard items? This cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AureliaDesign.Spacing.md) {
            Image(systemName: selectedSidebarItem == .starred ? "star" : "doc.on.clipboard")
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
            return "No items match your search"
        }
        switch selectedSidebarItem {
        case .all:
            return "Copy something to get started"
        case .starred:
            return "Star items to keep them here"
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
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AureliaColors.starred)
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
        .background(AureliaColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.lg))
        .shadow(
            color: isHovering ? AureliaDesign.Shadow.md : AureliaDesign.Shadow.sm,
            radius: isHovering ? 8 : 2,
            x: 0, y: isHovering ? 4 : 1
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(AureliaDesign.Animation.spring, value: isHovering)
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
        .background(AureliaColors.sidebarBackground)
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
                item.isPinned ? "Unstar" : "Star",
                systemImage: item.isPinned ? "star.slash" : "star"
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
