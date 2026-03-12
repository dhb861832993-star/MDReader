import Foundation
import SQLite3

/// 文件索引数据库管理
/// 使用 SQLite 实现文件元数据缓存，支持快速搜索
class FileIndexDatabase {
    static let shared = FileIndexDatabase()
    private var db: OpaquePointer?

    private let dbPath: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("file_index.db")
    }()

    private init() {
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }

    private func createTables() {
        let createFilesTable = """
            CREATE TABLE IF NOT EXISTS files (
                id TEXT PRIMARY KEY,
                path TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                size INTEGER,
                modified_time REAL,
                is_directory INTEGER,
                file_type TEXT,
                is_favorite INTEGER DEFAULT 0,
                tags TEXT,
                last_opened REAL,
                reading_position REAL DEFAULT 0
            );
        """

        let createIndex = """
            CREATE INDEX IF NOT EXISTS idx_name ON files(name);
            CREATE INDEX IF NOT EXISTS idx_path ON files(path);
            CREATE INDEX IF NOT EXISTS idx_modified ON files(modified_time);
        """

        let createFTSTable = """
            CREATE VIRTUAL TABLE IF NOT EXISTS file_fts USING fts5(
                name,
                content='files',
                content_rowid='id'
            );
        """

        execute(createFilesTable)
        execute(createIndex)
        execute(createFTSTable)
    }

    private func execute(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    // MARK: - CRUD Operations

    func saveFile(_ item: FileItem) {
        let sql = """
            INSERT OR REPLACE INTO files (
                id, path, name, size, modified_time, is_directory,
                file_type, is_favorite, tags, last_opened
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }

        sqlite3_bind_text(statement, 1, (item.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (item.url.path as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (item.name as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(statement, 4, sqlite3_int64(item.size))
        sqlite3_bind_double(statement, 5, item.modificationDate.timeIntervalSince1970)
        sqlite3_bind_int(statement, 6, item.isDirectory ? 1 : 0)
        sqlite3_bind_text(statement, 7, (item.fileType.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 8, item.isFavorite ? 1 : 0)
        sqlite3_bind_text(statement, 9, (item.tags.joined(separator: ",") as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 10, Date().timeIntervalSince1970)

        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }

    func getFile(at path: String) -> FileItem? {
        let sql = "SELECT * FROM files WHERE path = ? LIMIT 1;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(statement, 1, (path as NSString).utf8String, -1, nil)

        var item: FileItem?
        if sqlite3_step(statement) == SQLITE_ROW {
            item = parseFileItem(from: statement!)
        }

        sqlite3_finalize(statement)
        return item
    }

    func getAllFiles(inDirectory path: String) -> [FileItem] {
        let sql = """
            SELECT * FROM files
            WHERE path LIKE ? AND path != ?
            ORDER BY is_directory DESC, modified_time DESC;
        """
        var statement: OpaquePointer?
        var items: [FileItem] = []

        let pattern = path + "/%"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return items }

        sqlite3_bind_text(statement, 1, (pattern as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (path as NSString).utf8String, -1, nil)

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseFileItem(from: statement!) {
                items.append(item)
            }
        }

        sqlite3_finalize(statement)
        return items
    }

    func searchFiles(query: String) -> [FileItem] {
        // 使用 FTS5 全文搜索
        let sql = """
            SELECT f.* FROM files f
            JOIN file_fts fts ON f.id = fts.rowid
            WHERE file_fts MATCH ?
            ORDER BY f.modified_time DESC
            LIMIT 50;
        """
        var statement: OpaquePointer?
        var items: [FileItem] = []

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return items }
        sqlite3_bind_text(statement, 1, (query + "*" as NSString).utf8String, -1, nil)

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseFileItem(from: statement!) {
                items.append(item)
            }
        }

        sqlite3_finalize(statement)
        return items
    }

    func updateReadingPosition(fileId: String, position: Double) {
        let sql = "UPDATE files SET reading_position = ?, last_opened = ? WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }

        sqlite3_bind_double(statement, 1, position)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, (fileId as NSString).utf8String, -1, nil)

        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }

    func getRecentFiles(limit: Int = 20) -> [FileItem] {
        let sql = """
            SELECT * FROM files
            WHERE last_opened IS NOT NULL
            ORDER BY last_opened DESC
            LIMIT ?;
        """
        var statement: OpaquePointer?
        var items: [FileItem] = []

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return items }
        sqlite3_bind_int(statement, 1, Int32(limit))

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseFileItem(from: statement!) {
                items.append(item)
            }
        }

        sqlite3_finalize(statement)
        return items
    }

    func getFavoriteFiles() -> [FileItem] {
        let sql = "SELECT * FROM files WHERE is_favorite = 1 ORDER BY modified_time DESC;"
        var statement: OpaquePointer?
        var items: [FileItem] = []

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return items }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseFileItem(from: statement!) {
                items.append(item)
            }
        }

        sqlite3_finalize(statement)
        return items
    }

    // MARK: - Helper

    private func parseFileItem(from statement: OpaquePointer) -> FileItem? {
        guard let idString = sqlite3_column_text(statement, 0),
              let pathString = sqlite3_column_text(statement, 1) else { return nil }

        let id = UUID(uuidString: String(cString: idString))
        let url = URL(fileURLWithPath: String(cString: pathString))

        // 重新创建 FileItem（实际应用中应存储完整数据）
        var item = FileItem(url: url)

        // 恢复元数据
        if let name = sqlite3_column_text(statement, 2) {
            // 从数据库恢复的额外属性
        }

        return item
    }
}

// MARK: - 内存缓存
class MemoryFileCache {
    static let shared = MemoryFileCache()
    private var cache: NSCache<NSString, FileItem> = {
        let cache = NSCache<NSString, FileItem>()
        cache.countLimit = 1000 // 最多缓存 1000 个文件
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()

    private init() {}

    func get(key: String) -> FileItem? {
        return cache.object(forKey: key as NSString)
    }

    func set(_ item: FileItem, forKey key: String) {
        cache.setObject(item, forKey: key as NSString)
    }

    func remove(key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - 文件内容缓存
class FileContentCache {
    static let shared = FileContentCache()
    private var contentCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 100 // 最多缓存 100 个文件内容
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        return cache
    }()

    private var renderedCache: NSCache<NSString, NSAttributedString> = {
        let cache = NSCache<NSString, NSAttributedString>()
        cache.countLimit = 50 // 最多缓存 50 个渲染结果
        return cache
    }()

    private init() {}

    func getContent(key: String) -> String? {
        return contentCache.object(forKey: key as NSString) as String?
    }

    func setContent(_ content: String, forKey key: String) {
        let cost = content.lengthOfBytes(using: .utf8)
        contentCache.setObject(content as NSString, forKey: key as NSString, cost: cost)
    }

    func getRendered(key: String) -> NSAttributedString? {
        return renderedCache.object(forKey: key as NSString)
    }

    func setRendered(_ attributedString: NSAttributedString, forKey key: String) {
        renderedCache.setObject(attributedString, forKey: key as NSString)
    }

    func clear() {
        contentCache.removeAllObjects()
        renderedCache.removeAllObjects()
    }
}
