import Foundation
import SQLite3

final class StorageManager {
    static let shared = StorageManager()

    private var db: OpaquePointer?
    private let fileManager = FileManager.default

    private let appSupportDir: URL
    private let imagesDir: URL
    private let dbPath: URL

    private let currentSchemaVersion = 2

    private init() {
        // Set up directories - now using "Aurelia"
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportDir = appSupport.appendingPathComponent("Aurelia", isDirectory: true)
        imagesDir = appSupportDir.appendingPathComponent("images", isDirectory: true)
        dbPath = appSupportDir.appendingPathComponent("clipboard.db")

        createDirectoriesIfNeeded()
        migrateFromOldLocation()
        openDatabase()
        createTablesIfNeeded()
        runMigrations()
        migrateFromJSONIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Setup

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }

    private func migrateFromOldLocation() {
        // Migrate from old "ClipboardApp" directory if it exists
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let oldDir = appSupport.appendingPathComponent("ClipboardApp", isDirectory: true)

        guard fileManager.fileExists(atPath: oldDir.path) else { return }

        // Move database
        let oldDB = oldDir.appendingPathComponent("clipboard.db")
        if fileManager.fileExists(atPath: oldDB.path) && !fileManager.fileExists(atPath: dbPath.path) {
            try? fileManager.moveItem(at: oldDB, to: dbPath)
        }

        // Move images
        let oldImages = oldDir.appendingPathComponent("images")
        if fileManager.fileExists(atPath: oldImages.path) {
            if let files = try? fileManager.contentsOfDirectory(at: oldImages, includingPropertiesForKeys: nil) {
                for file in files {
                    let dest = imagesDir.appendingPathComponent(file.lastPathComponent)
                    try? fileManager.moveItem(at: file, to: dest)
                }
            }
        }

        // Remove old directory
        try? fileManager.removeItem(at: oldDir)
        print("Migrated data from ClipboardApp to Aurelia")
    }

    private func openDatabase() {
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func createTablesIfNeeded() {
        let sql = """
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY,
                content_type TEXT NOT NULL,
                text_content TEXT,
                image_filename TEXT,
                file_paths TEXT,
                timestamp REAL NOT NULL,
                program_name TEXT NOT NULL,
                is_pinned INTEGER DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_timestamp ON clipboard_items(timestamp DESC);
            CREATE INDEX IF NOT EXISTS idx_pinned ON clipboard_items(is_pinned);

            CREATE TABLE IF NOT EXISTS ignored_apps (
                bundle_id TEXT PRIMARY KEY,
                app_name TEXT NOT NULL,
                added_at REAL NOT NULL
            );

            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER PRIMARY KEY
            );
            """

        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            print("Error creating tables: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func runMigrations() {
        let storedVersion = getSchemaVersion()

        if storedVersion < 2 {
            // Add new columns if they don't exist (safe to run multiple times)
            let migrations = [
                "ALTER TABLE clipboard_items ADD COLUMN file_paths TEXT",
                "ALTER TABLE clipboard_items ADD COLUMN is_pinned INTEGER DEFAULT 0"
            ]

            for sql in migrations {
                sqlite3_exec(db, sql, nil, nil, nil)
                // Ignore errors - column may already exist
            }

            setSchemaVersion(2)
        }
    }

    private func getSchemaVersion() -> Int {
        var version = 0
        let sql = "SELECT version FROM schema_version LIMIT 1"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return version
    }

    private func setSchemaVersion(_ version: Int) {
        let sql = "INSERT OR REPLACE INTO schema_version (version) VALUES (?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(version))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Migration from JSON

    private func migrateFromJSONIfNeeded() {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldJSONPath = documentsDir.appendingPathComponent("clipboardItems.json")

        guard fileManager.fileExists(atPath: oldJSONPath.path) else { return }

        do {
            let data = try Data(contentsOf: oldJSONPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let oldItems = try decoder.decode([LegacyClipboardItem].self, from: data)

            for item in oldItems {
                let newItem = ClipboardItem(
                    id: item.id,
                    content: item.content.toClipboardContent,
                    timestamp: item.timestamp,
                    programName: item.programName
                )
                insert(newItem)
            }

            try fileManager.removeItem(at: oldJSONPath)
            print("Migrated \(oldItems.count) items from JSON to SQLite")
        } catch {
            print("Migration error: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func insert(_ item: ClipboardItem) {
        let contentType: String
        var textContent: String? = nil
        var imageFilename: String? = nil
        var filePaths: String? = nil

        switch item.content {
        case .text(let text):
            contentType = "text"
            textContent = text
        case .image(let data):
            contentType = "image"
            imageFilename = "\(item.id.uuidString).png"
            saveImageData(data, filename: imageFilename!)
        case .file(let urls):
            contentType = "file"
            filePaths = urls.map { $0.path }.joined(separator: "\n")
        }

        let sql = """
            INSERT OR REPLACE INTO clipboard_items
            (id, content_type, text_content, image_filename, file_paths, timestamp, program_name, is_pinned)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, contentType, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            if let text = textContent {
                sqlite3_bind_text(stmt, 3, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(stmt, 3)
            }

            if let filename = imageFilename {
                sqlite3_bind_text(stmt, 4, filename, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(stmt, 4)
            }

            if let paths = filePaths {
                sqlite3_bind_text(stmt, 5, paths, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(stmt, 5)
            }

            sqlite3_bind_double(stmt, 6, item.timestamp.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 7, item.programName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(stmt, 8, item.isPinned ? 1 : 0)

            if sqlite3_step(stmt) != SQLITE_DONE {
                print("Error inserting item: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(stmt)
    }

    func fetchAll() -> [ClipboardItem] {
        var items: [ClipboardItem] = []

        let sql = "SELECT id, content_type, text_content, image_filename, file_paths, timestamp, program_name, is_pinned FROM clipboard_items ORDER BY timestamp DESC"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = parseRow(stmt) {
                    items.append(item)
                }
            }
        }
        sqlite3_finalize(stmt)

        return items
    }

    private func parseRow(_ stmt: OpaquePointer?) -> ClipboardItem? {
        guard let idStr = sqlite3_column_text(stmt, 0),
              let contentTypeStr = sqlite3_column_text(stmt, 1),
              let programNameStr = sqlite3_column_text(stmt, 6) else {
            return nil
        }

        guard let id = UUID(uuidString: String(cString: idStr)) else { return nil }

        let contentType = String(cString: contentTypeStr)
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        let programName = String(cString: programNameStr)
        let isPinned = sqlite3_column_int(stmt, 7) == 1

        let content: ClipboardContent
        switch contentType {
        case "text":
            guard let textPtr = sqlite3_column_text(stmt, 2) else { return nil }
            content = .text(String(cString: textPtr))
        case "image":
            guard let filenamePtr = sqlite3_column_text(stmt, 3) else { return nil }
            let filename = String(cString: filenamePtr)
            guard let imageData = loadImageData(filename: filename) else { return nil }
            content = .image(imageData)
        case "file":
            guard let pathsPtr = sqlite3_column_text(stmt, 4) else { return nil }
            let pathsString = String(cString: pathsPtr)
            let urls = pathsString.split(separator: "\n").compactMap { URL(fileURLWithPath: String($0)) }
            content = .file(urls: urls)
        default:
            return nil
        }

        return ClipboardItem(id: id, content: content, timestamp: timestamp, programName: programName, isPinned: isPinned)
    }

    func delete(_ item: ClipboardItem) {
        if case .image = item.content {
            let filename = "\(item.id.uuidString).png"
            deleteImageFile(filename: filename)
        }

        let sql = "DELETE FROM clipboard_items WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func deleteAll() {
        if let files = try? fileManager.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }

        let sql = "DELETE FROM clipboard_items"
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    func deleteItemsOlderThan(_ date: Date) {
        // Don't delete pinned items
        let selectSQL = "SELECT image_filename FROM clipboard_items WHERE timestamp < ? AND is_pinned = 0 AND image_filename IS NOT NULL"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let filenamePtr = sqlite3_column_text(stmt, 0) {
                    deleteImageFile(filename: String(cString: filenamePtr))
                }
            }
        }
        sqlite3_finalize(stmt)

        let deleteSQL = "DELETE FROM clipboard_items WHERE timestamp < ? AND is_pinned = 0"
        if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func findByContent(_ content: ClipboardContent) -> ClipboardItem? {
        switch content {
        case .text(let text):
            let sql = "SELECT id, content_type, text_content, image_filename, file_paths, timestamp, program_name, is_pinned FROM clipboard_items WHERE content_type = 'text' AND text_content = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let item = parseRow(stmt)
                    sqlite3_finalize(stmt)
                    return item
                }
            }
            sqlite3_finalize(stmt)
            return nil

        case .image(let data):
            let sql = "SELECT id, content_type, text_content, image_filename, file_paths, timestamp, program_name, is_pinned FROM clipboard_items WHERE content_type = 'image'"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let filenamePtr = sqlite3_column_text(stmt, 3) {
                        let filename = String(cString: filenamePtr)
                        if let existingData = loadImageData(filename: filename), existingData == data {
                            let item = parseRow(stmt)
                            sqlite3_finalize(stmt)
                            return item
                        }
                    }
                }
            }
            sqlite3_finalize(stmt)
            return nil

        case .file(let urls):
            let pathsString = urls.map { $0.path }.joined(separator: "\n")
            let sql = "SELECT id, content_type, text_content, image_filename, file_paths, timestamp, program_name, is_pinned FROM clipboard_items WHERE content_type = 'file' AND file_paths = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, pathsString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let item = parseRow(stmt)
                    sqlite3_finalize(stmt)
                    return item
                }
            }
            sqlite3_finalize(stmt)
            return nil
        }
    }

    func updatePinnedStatus(itemID: UUID, isPinned: Bool) {
        let sql = "UPDATE clipboard_items SET is_pinned = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, isPinned ? 1 : 0)
            sqlite3_bind_text(stmt, 2, itemID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func updateTimestamp(itemID: UUID, timestamp: Date) {
        let sql = "UPDATE clipboard_items SET timestamp = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, timestamp.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, itemID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Ignored Apps

    func insertIgnoredApp(_ app: IgnoredApp) {
        let sql = "INSERT OR REPLACE INTO ignored_apps (bundle_id, app_name, added_at) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, app.bundleID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, app.appName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_double(stmt, 3, app.addedAt.timeIntervalSince1970)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func fetchIgnoredApps() -> [IgnoredApp] {
        var apps: [IgnoredApp] = []
        let sql = "SELECT bundle_id, app_name, added_at FROM ignored_apps ORDER BY app_name"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let bundleIDPtr = sqlite3_column_text(stmt, 0),
                   let appNamePtr = sqlite3_column_text(stmt, 1) {
                    let app = IgnoredApp(
                        bundleID: String(cString: bundleIDPtr),
                        appName: String(cString: appNamePtr),
                        addedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                    )
                    apps.append(app)
                }
            }
        }
        sqlite3_finalize(stmt)
        return apps
    }

    func deleteIgnoredApp(bundleID: String) {
        let sql = "DELETE FROM ignored_apps WHERE bundle_id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, bundleID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Image File Operations

    private func saveImageData(_ data: Data, filename: String) {
        let url = imagesDir.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
    }

    private func loadImageData(filename: String) -> Data? {
        let url = imagesDir.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    private func deleteImageFile(filename: String) {
        let url = imagesDir.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }
}

// MARK: - Legacy Model for Migration

private struct LegacyClipboardItem: Codable {
    let id: UUID
    let content: LegacyClipboardContent
    let timestamp: Date
    let programName: String
}

private enum LegacyClipboardContent: Codable {
    case text(String)
    case image(Data)

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum ContentType: String, Codable {
        case text, image
    }

    var toClipboardContent: ClipboardContent {
        switch self {
        case .text(let str): return .text(str)
        case .image(let data): return .image(data)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        switch type {
        case .text:
            self = .text(try container.decode(String.self, forKey: .value))
        case .image:
            self = .image(try container.decode(Data.self, forKey: .value))
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
        }
    }
}
