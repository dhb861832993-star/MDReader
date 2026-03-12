import Foundation
import Combine
import SwiftUI

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

struct FileItem: Identifiable, Codable, Equatable {
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
        self.size = resourceValues?[.fileSizeKey] as? Int64 ?? 0
        self.modificationDate = resourceValues?[.contentModificationDateKey] as? Date ?? Date()
        self.isDirectory = resourceValues?[.isDirectoryKey] as? Bool ?? false

        if isDirectory {
            self.fileType = .other
        } else {
            self.fileType = FileItem.detectFileType(url: url)
        }
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
class FileSystemManager: ObservableObject {
    static let shared = FileSystemManager()

    private var fileIndex = FileIndex()
    private var cancellables = Set<AnyCancellable>()

    var currentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    var files: [FileItem] = []
    var isLoading = false
    var searchQuery = ""

    var filteredFiles: [FileItem] {
        if searchQuery.isEmpty {
            return files
        }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private init() {
        loadIndexCache()
        scanCurrentDirectory()
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
            saveIndexCache()
        }
    }

    func loadFileContent(_ item: FileItem) async throws -> String {
        return try String(contentsOf: item.url, encoding: .utf8)
    }

    private func loadIndexCache() {
        // 从SQLite或UserDefaults加载索引
        // 简化实现，实际使用Core Data或SQLite
    }

    private func saveIndexCache() {
        // 保存索引到本地
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
