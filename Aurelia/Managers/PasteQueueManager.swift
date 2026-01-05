//
//  PasteQueueManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import Foundation
import AppKit

// MARK: - Queue Notifications

extension Notification.Name {
    static let queueModeDidActivate = Notification.Name("queueModeDidActivate")
    static let queueModeDidDeactivate = Notification.Name("queueModeDidDeactivate")
    static let queueDidUpdate = Notification.Name("queueDidUpdate")
    static let queueItemDidPaste = Notification.Name("queueItemDidPaste")
}

// MARK: - Queued Item

struct QueuedItem: Identifiable {
    let id: UUID
    let clipboardItem: ClipboardItem
    var isPasted: Bool = false
    var order: Int

    init(clipboardItem: ClipboardItem, order: Int) {
        self.id = UUID()
        self.clipboardItem = clipboardItem
        self.order = order
    }
}

// MARK: - Paste Queue Manager

@Observable
final class PasteQueueManager {
    static let shared = PasteQueueManager()

    // MARK: - Queue State

    private(set) var isQueueModeActive: Bool = false
    var items: [QueuedItem] = []

    /// Index of the next item to paste (0-based)
    var nextPasteIndex: Int {
        items.firstIndex(where: { !$0.isPasted }) ?? items.count
    }

    /// Number of items remaining to paste
    var remainingCount: Int {
        items.filter { !$0.isPasted }.count
    }

    /// Total items in queue (including pasted)
    var totalCount: Int {
        items.count
    }

    // MARK: - Settings (loaded from AppSettings)

    private let defaults = UserDefaults.standard

    var autoClearAfterComplete: Bool {
        get { defaults.bool(forKey: "queueAutoClear") }
        set { defaults.set(newValue, forKey: "queueAutoClear") }
    }

    var keepPastedItemsVisible: Bool {
        get { defaults.object(forKey: "queueKeepPastedVisible") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "queueKeepPastedVisible") }
    }

    var maxQueueSize: Int {
        get {
            let value = defaults.integer(forKey: "queueMaxSize")
            return value > 0 ? value : 50
        }
        set { defaults.set(newValue, forKey: "queueMaxSize") }
    }

    // MARK: - Window Position Persistence

    var windowPosition: CGPoint? {
        get {
            guard defaults.object(forKey: "queueWindowX") != nil else { return nil }
            let x = defaults.double(forKey: "queueWindowX")
            let y = defaults.double(forKey: "queueWindowY")
            return CGPoint(x: x, y: y)
        }
        set {
            if let point = newValue {
                defaults.set(point.x, forKey: "queueWindowX")
                defaults.set(point.y, forKey: "queueWindowY")
            } else {
                defaults.removeObject(forKey: "queueWindowX")
                defaults.removeObject(forKey: "queueWindowY")
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Set defaults if not set
        if defaults.object(forKey: "queueAutoClear") == nil {
            defaults.set(true, forKey: "queueAutoClear")
        }
        if defaults.object(forKey: "queueKeepPastedVisible") == nil {
            defaults.set(true, forKey: "queueKeepPastedVisible")
        }
    }

    // MARK: - Queue Mode Lifecycle

    func activate() {
        guard !isQueueModeActive else { return }

        isQueueModeActive = true
        items.removeAll()

        NotificationCenter.default.post(name: .queueModeDidActivate, object: nil)

        // Show queue panel
        QueuePanelManager.shared.show()
    }

    func deactivate() {
        guard isQueueModeActive else { return }

        isQueueModeActive = false

        // Optionally clear items or keep for reference
        if !keepPastedItemsVisible {
            items.removeAll()
        }

        NotificationCenter.default.post(name: .queueModeDidDeactivate, object: nil)

        // Hide queue panel
        QueuePanelManager.shared.hide()
    }

    func toggle() {
        if isQueueModeActive {
            deactivate()
        } else {
            activate()
        }
    }

    // MARK: - Queue Operations

    /// Add an item to the queue (called by ClipboardManager when queue mode is active)
    func addToQueue(_ item: ClipboardItem) {
        guard isQueueModeActive else { return }
        guard items.count < maxQueueSize else { return }

        let order = items.count
        let queuedItem = QueuedItem(clipboardItem: item, order: order)
        items.append(queuedItem)

        NotificationCenter.default.post(name: .queueDidUpdate, object: nil)
    }

    /// Paste the next unpasted item in the queue
    /// Returns the item that was pasted, or nil if queue is exhausted
    @discardableResult
    func pasteNext() -> ClipboardItem? {
        guard let index = items.firstIndex(where: { !$0.isPasted }) else {
            // Queue exhausted
            if autoClearAfterComplete {
                deactivate()
            }
            return nil
        }

        return pasteAt(index: index)
    }

    /// Paste item at specific index
    @discardableResult
    func pasteAt(index: Int) -> ClipboardItem? {
        guard index >= 0 && index < items.count else { return nil }
        guard !items[index].isPasted else { return nil }

        // Mark as pasted
        items[index].isPasted = true

        let clipboardItem = items[index].clipboardItem

        // Copy to system clipboard
        ClipboardManager.shared.copyToClipboard(clipboardItem)

        NotificationCenter.default.post(name: .queueItemDidPaste, object: index)
        NotificationCenter.default.post(name: .queueDidUpdate, object: nil)

        // Check if all items pasted
        if remainingCount == 0 && autoClearAfterComplete {
            // Delay deactivation slightly so user sees final state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.deactivate()
            }
        }

        return clipboardItem
    }

    // MARK: - Queue Manipulation

    /// Reorder items (move from one index to another)
    func reorder(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex else { return }
        guard sourceIndex >= 0 && sourceIndex < items.count else { return }
        guard destinationIndex >= 0 && destinationIndex <= items.count else { return }

        let item = items.remove(at: sourceIndex)
        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        items.insert(item, at: adjustedDestination)

        // Update order values
        updateOrderValues()

        NotificationCenter.default.post(name: .queueDidUpdate, object: nil)
    }

    /// Flip/reverse the order of all unpasted items
    func flipOrder() {
        // Get indices of unpasted items
        let unpastedIndices = items.indices.filter { !items[$0].isPasted }

        guard unpastedIndices.count > 1 else { return }

        // Extract unpasted items
        var unpastedItems = unpastedIndices.map { items[$0] }

        // Reverse them
        unpastedItems.reverse()

        // Put them back
        for (i, originalIndex) in unpastedIndices.enumerated() {
            items[originalIndex] = unpastedItems[i]
        }

        // Update order values
        updateOrderValues()

        NotificationCenter.default.post(name: .queueDidUpdate, object: nil)
    }

    /// Remove item at index
    func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }

        items.remove(at: index)
        updateOrderValues()

        NotificationCenter.default.post(name: .queueDidUpdate, object: nil)
    }

    /// Clear all items from queue ("Wash Queue")
    func clearQueue() {
        items.removeAll()
        NotificationCenter.default.post(name: .queueDidUpdate, object: nil)
    }

    /// Reset pasted status for all items (re-paste from beginning)
    func resetQueue() {
        for i in items.indices {
            items[i].isPasted = false
        }
        NotificationCenter.default.post(name: .queueDidUpdate, object: nil)
    }

    // MARK: - Helpers

    private func updateOrderValues() {
        for (index, _) in items.enumerated() {
            items[index].order = index
        }
    }
}
