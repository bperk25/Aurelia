import Foundation
import AppKit

@Observable
final class ClipboardManager {
    static let shared = ClipboardManager()

    private(set) var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private let settings = AppSettings.shared
    private let storage = StorageManager.shared
    private let privacy = PrivacyManager.shared

    // MARK: - Date Formatter (cached)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Lifecycle

    private init() {
        loadItems()
        lastChangeCount = pasteboard.changeCount
    }

    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Clipboard Checking

    private func checkClipboard() {
        // Check if monitoring is paused
        guard !privacy.isMonitoringPaused else { return }

        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Get frontmost app info
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let programName = frontmostApp?.localizedName ?? "Unknown"
        let bundleID = frontmostApp?.bundleIdentifier

        // Check if app is in ignore list
        guard !privacy.isAppIgnored(bundleID: bundleID) else { return }

        // Check for files first (Finder copies)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty,
           urls.allSatisfy({ $0.isFileURL }) {
            let content = ClipboardContent.file(urls: urls)
            addItem(content: content, programName: programName)
            return
        }

        // Check for text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let content = ClipboardContent.text(text)
            addItem(content: content, programName: programName)
            return
        }

        // Check for images (PNG first, then TIFF)
        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            let content = ClipboardContent.image(imageData)
            addItem(content: content, programName: programName)
        }
    }

    private func addItem(content: ClipboardContent, programName: String) {
        // Remove duplicate if exists
        if let existing = storage.findByContent(content) {
            storage.delete(existing)
            items.removeAll { $0.id == existing.id }
        }

        // Create and insert new item
        let newItem = ClipboardItem(content: content, programName: programName)
        storage.insert(newItem)
        items.insert(newItem, at: 0)

        // Prune old items
        pruneExpiredItems()

        // Post notification for menu bar pulse animation
        NotificationCenter.default.post(name: .clipboardDidChange, object: nil)
    }

    // MARK: - Copy to Clipboard

    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()

        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let data):
            pasteboard.setData(data, forType: .tiff)
        case .file(let urls):
            pasteboard.writeObjects(urls as [NSURL])
        }

        lastChangeCount = pasteboard.changeCount

        // Update timestamp and move to front
        let now = Date()
        storage.updateTimestamp(itemID: item.id, timestamp: now)

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].timestamp = now
            let updatedItem = items.remove(at: index)
            items.insert(updatedItem, at: 0)
        }
    }

    func copyAsPlainText(_ item: ClipboardItem) {
        pasteboard.clearContents()

        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image:
            // Can't convert image to text
            break
        case .file(let urls):
            let pathsText = urls.map { $0.path }.joined(separator: "\n")
            pasteboard.setString(pathsText, forType: .string)
        }

        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Item Management

    func delete(_ item: ClipboardItem) {
        storage.delete(item)
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        storage.deleteAll()
        items.removeAll()
    }

    func togglePinned(_ item: ClipboardItem) {
        let newPinnedState = !item.isPinned
        storage.updatePinnedStatus(itemID: item.id, isPinned: newPinnedState)

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPinned = newPinnedState
        }
    }

    func pruneExpiredItems() {
        guard let days = settings.retentionPeriod.days else { return }
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }

        storage.deleteItemsOlderThan(cutoffDate)
        // Keep pinned items regardless of age
        items.removeAll { $0.timestamp < cutoffDate && !$0.isPinned }
    }

    // MARK: - Filtering

    func filteredItems(searchText: String, contentType: ContentTypeFilter) -> [ClipboardItem] {
        var result = items

        // Filter by content type
        if contentType != .all {
            result = result.filter { contentType.matches($0.content) }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                switch item.content {
                case .text(let text):
                    return text.lowercased().contains(query)
                case .image:
                    return "image".contains(query)
                case .file(let urls):
                    return urls.contains { $0.lastPathComponent.lowercased().contains(query) }
                }
            }
        }

        return result
    }

    var pinnedItems: [ClipboardItem] {
        items.filter { $0.isPinned }
    }

    // MARK: - Persistence

    private func loadItems() {
        items = storage.fetchAll()
        pruneExpiredItems()
    }

    func refresh() {
        loadItems()
    }
}
