import Foundation
import AppKit

// MARK: - ClipboardItem

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: ClipboardContent
    var timestamp: Date
    let programName: String
    var isPinned: Bool
    var groupID: UUID?

    init(content: ClipboardContent, timestamp: Date = Date(), programName: String, isPinned: Bool = false, groupID: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
        self.programName = programName
        self.isPinned = isPinned
        self.groupID = groupID
    }

    init(id: UUID, content: ClipboardContent, timestamp: Date, programName: String, isPinned: Bool = false, groupID: UUID? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.programName = programName
        self.isPinned = isPinned
        self.groupID = groupID
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.timestamp == rhs.timestamp &&
        lhs.programName == rhs.programName &&
        lhs.isPinned == rhs.isPinned &&
        lhs.groupID == rhs.groupID
    }
}

// MARK: - ClipboardGroup

struct ClipboardGroup: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

// MARK: - ClipboardContent

enum ClipboardContent: Codable, Equatable {
    case text(String)
    case image(Data)
    case file(urls: [URL])

    var contentType: String {
        switch self {
        case .text(let text):
            if text.hasPrefix("http://") || text.hasPrefix("https://") {
                return "Link"
            }
            return "Text"
        case .image:
            return "Image"
        case .file:
            return "File"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, value, urls
    }

    private enum ContentType: String, Codable {
        case text, image, file
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .image:
            let value = try container.decode(Data.self, forKey: .value)
            self = .image(value)
        case .file:
            let urlStrings = try container.decode([String].self, forKey: .urls)
            let urls = urlStrings.compactMap { URL(fileURLWithPath: $0) }
            self = .file(urls: urls)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .image(let value):
            try container.encode(ContentType.image, forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let urls):
            try container.encode(ContentType.file, forKey: .type)
            try container.encode(urls.map { $0.path }, forKey: .urls)
        }
    }
}

// MARK: - Content Type Filter

enum ContentTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case links = "Links"
    case images = "Images"
    case files = "Files"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .text: return "doc.text"
        case .links: return "link"
        case .images: return "photo"
        case .files: return "doc"
        }
    }

    func matches(_ content: ClipboardContent) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            if case .text(let str) = content {
                return !str.hasPrefix("http://") && !str.hasPrefix("https://")
            }
            return false
        case .links:
            if case .text(let str) = content {
                return str.hasPrefix("http://") || str.hasPrefix("https://")
            }
            return false
        case .images:
            if case .image = content { return true }
            return false
        case .files:
            if case .file = content { return true }
            return false
        }
    }
}
