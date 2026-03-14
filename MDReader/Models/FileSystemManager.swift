import Foundation
import Combine
import SwiftUI

// MARK: - 阅读器主题
enum ReaderTheme: String, CaseIterable {
    case light, sepia, dark, midnight

    var name: String {
        switch self {
        case .light: return "浅色"
        case .sepia: return "暖色"
        case .dark: return "深色"
        case .midnight: return "午夜"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: return .white
        case .sepia: return Color(red: 0.98, green: 0.95, blue: 0.91)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .midnight: return Color(red: 0.05, green: 0.08, blue: 0.15)
        }
    }

    var textColor: Color {
        switch self {
        case .light, .sepia: return .primary
        case .dark, .midnight: return .white
        }
    }
}

enum FileType: String, Codable {
    case markdown
    case json
    case yaml
    case code
    case text
    case image
    case other

    var icon: String {
        switch self {
        case .markdown: return "doc.text"
        case .json: return "curlybraces"
        case .yaml: return "doc.badge.gearshape"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .image: return "photo"
        case .other: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .markdown: return .blue
        case .json: return .green
        case .yaml: return .orange
        case .code: return .purple
        case .text: return .gray
        case .image: return .pink
        case .other: return .gray
        }
    }
}

struct FileItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64
    let modificationDate: Date
    let isDirectory: Bool
    let fileType: FileType
    var isFavorite: Bool = false
    var tags: [String] = []

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.modificationDate = resourceValues?.contentModificationDate ?? Date()
        self.isDirectory = resourceValues?.isDirectory ?? false

        if isDirectory {
            self.fileType = .other
        } else {
            self.fileType = FileItem.detectFileType(url: url)
        }
    }

    init(url: URL, isFavorite: Bool, tags: [String]) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.modificationDate = resourceValues?.contentModificationDate ?? Date()
        self.isDirectory = resourceValues?.isDirectory ?? false

        if isDirectory {
            self.fileType = .other
        } else {
            self.fileType = FileItem.detectFileType(url: url)
        }

        self.isFavorite = isFavorite
        self.tags = tags
    }

    static func detectFileType(url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "mdown":
            return .markdown
        case "json":
            return .json
        case "yaml", "yml":
            return .yaml
        case "swift", "py", "js", "ts", "go", "rs", "java", "cpp", "c", "h", "sql":
            return .code
        case "txt", "log":
            return .text
        case "png", "jpg", "jpeg", "gif", "webp":
            return .image
        default:
            return .other
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modificationDate, relativeTo: Date())
    }
}

@Observable
class FileSystemManager {
    static let shared = FileSystemManager()

    private var fileIndex = FileIndex()

    var currentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    var files: [FileItem] = []
    var isLoading = false
    var searchQuery = ""

    // 最近打开的文件URL列表
    var recentOpenedURLs: [URL] = []

    var filteredFiles: [FileItem] {
        if searchQuery.isEmpty {
            return files
        }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    // 最近打开的文件
    var recentOpenedFiles: [FileItem] {
        recentOpenedURLs.compactMap { url in
            files.first { $0.url == url }
        }
    }

    private init() {
        // 延迟初始化，避免启动时崩溃
        Task { @MainActor in
            loadRecentOpenedFiles()
            loadIndexCache()
            scanCurrentDirectory()
        }
    }

    // 记录文件打开
    func recordFileOpened(_ file: FileItem) {
        // 移除旧的记录
        recentOpenedURLs.removeAll { $0 == file.url }
        // 添加到最前面
        recentOpenedURLs.insert(file.url, at: 0)
        // 最多保留 20 个
        if recentOpenedURLs.count > 20 {
            recentOpenedURLs = Array(recentOpenedURLs.prefix(20))
        }
        saveRecentOpenedFiles()
    }

    private let recentFilesKey = "recentOpenedFiles"

    private func loadRecentOpenedFiles() {
        if let paths = UserDefaults.standard.array(forKey: recentFilesKey) as? [String] {
            recentOpenedURLs = paths.map { URL(fileURLWithPath: $0) }
        }
    }

    private func saveRecentOpenedFiles() {
        let paths = recentOpenedURLs.map { $0.path }
        UserDefaults.standard.set(paths, forKey: recentFilesKey)
    }

    func scanCurrentDirectory() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var newFiles: [FileItem] = []
            let fileManager = FileManager.default

            do {
                let contents = try fileManager.contentsOfDirectory(at: self.currentDirectory,
                                                                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                                                                    options: .skipsHiddenFiles)

                for url in contents {
                    let item = FileItem(url: url)
                    newFiles.append(item)
                }

                newFiles.sort { item1, item2 in
                    if item1.isDirectory != item2.isDirectory {
                        return item1.isDirectory
                    }
                    return item1.modificationDate > item2.modificationDate
                }

                DispatchQueue.main.async {
                    self.files = newFiles
                    self.isLoading = false
                    self.saveIndexCache()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    func navigateToDirectory(_ url: URL) {
        currentDirectory = url
        scanCurrentDirectory()
    }

    func navigateUp() {
        let parent = currentDirectory.deletingLastPathComponent()
        if parent.path != currentDirectory.path {
            navigateToDirectory(parent)
        }
    }

    func toggleFavorite(_ item: FileItem) {
        if let index = files.firstIndex(where: { $0.id == item.id }) {
            files[index].isFavorite.toggle()
            saveFileMetadata()
        }
    }

    // MARK: - 标签管理
    func addTag(_ tag: String, to item: FileItem) {
        if let index = files.firstIndex(where: { $0.id == item.id }) {
            if !files[index].tags.contains(tag) {
                files[index].tags.append(tag)
                saveFileMetadata()
            }
        }
    }

    func removeTag(_ tag: String, from item: FileItem) {
        if let index = files.firstIndex(where: { $0.id == item.id }) {
            files[index].tags.removeAll { $0 == tag }
            saveFileMetadata()
        }
    }

    func setTags(_ tags: [String], for item: FileItem) {
        if let index = files.firstIndex(where: { $0.id == item.id }) {
            files[index].tags = tags
            saveFileMetadata()
        }
    }

    // 获取所有已使用的标签
    var allTags: [String] {
        let tags = Set(files.flatMap { $0.tags })
        return Array(tags).sorted()
    }

    // 按标签搜索
    func filesWithTag(_ tag: String) -> [FileItem] {
        return files.filter { $0.tags.contains(tag) }
    }

    // MARK: - 重命名
    func renameFile(_ item: FileItem, to newName: String) -> Bool {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)

        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)

            // 更新内存中的数据
            if let index = files.firstIndex(where: { $0.id == item.id }) {
                files[index] = FileItem(url: newURL, isFavorite: files[index].isFavorite, tags: files[index].tags)
            }

            // 更新最近打开记录
            if let recentIndex = recentOpenedURLs.firstIndex(of: item.url) {
                recentOpenedURLs[recentIndex] = newURL
                saveRecentOpenedFiles()
            }

            saveFileMetadata()
            return true
        } catch {
            print("重命名失败: \(error)")
            return false
        }
    }

    // MARK: - 删除
    func deleteFile(_ item: FileItem) -> Bool {
        do {
            try FileManager.default.removeItem(at: item.url)
            files.removeAll { $0.id == item.id }
            recentOpenedURLs.removeAll { $0 == item.url }
            saveRecentOpenedFiles()
            saveFileMetadata()
            return true
        } catch {
            print("删除失败: \(error)")
            return false
        }
    }

    func loadFileContent(_ item: FileItem) async throws -> String {
        return try String(contentsOf: item.url, encoding: .utf8)
    }

    // MARK: - 元数据持久化
    private let metadataKey = "fileMetadata"

    private func saveFileMetadata() {
        var metadata: [String: [String: Any]] = [:]
        for file in files {
            metadata[file.url.path] = [
                "isFavorite": file.isFavorite,
                "tags": file.tags
            ]
        }
        UserDefaults.standard.set(metadata, forKey: metadataKey)
    }

    private func loadIndexCache() {
        // 加载元数据
        if let metadata = UserDefaults.standard.dictionary(forKey: metadataKey) as? [String: [String: Any]] {
            for (path, data) in metadata {
                if let index = files.firstIndex(where: { $0.url.path == path }) {
                    files[index].isFavorite = data["isFavorite"] as? Bool ?? false
                    files[index].tags = data["tags"] as? [String] ?? []
                }
            }
        }
    }

    private func saveIndexCache() {
        saveFileMetadata()
    }
}

class FileIndex {
    private var index: [URL: FileItem] = [:]

    func getItem(_ url: URL) -> FileItem? {
        return index[url]
    }

    func updateItem(_ item: FileItem) {
        index[item.url] = item
    }

    func search(query: String) -> [FileItem] {
        return index.values.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
