import Foundation
import UIKit

/// 大文件分页加载管理器
/// 支持分片读取，虚拟滚动
class LargeFileLoader {
    private let fileURL: URL
    private let fileHandle: FileHandle?
    private let fileSize: UInt64
    private let chunkSize: Int = 64 * 1024 // 64KB 分片

    var totalLines: Int = 0
    var lineOffsets: [UInt64] = [0] // 每行的字节偏移

    init?(url: URL) {
        self.fileURL = url

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.fileSize = (attributes?[.size] as? UInt64) ?? 0

        do {
            self.fileHandle = try FileHandle(forReadingFrom: url)
            buildLineIndex()
        } catch {
            return nil
        }
    }

    deinit {
        fileHandle?.closeFile()
    }

    /// 建立行索引（后台异步）
    private func buildLineIndex() {
        guard let handle = fileHandle else { return }

        handle.seek(toFileOffset: 0)
        var offset: UInt64 = 0
        var buffer = Data()
        let chunkSize = 1024 * 1024 // 1MB 读取

        while offset < fileSize {
            autoreleasepool {
                handle.seek(toFileOffset: offset)
                let data = handle.readData(ofLength: chunkSize)
                if data.isEmpty { return }

                buffer.append(data)

                // 查找换行符
                var searchStart = 0
                while let range = buffer.range(of: Data([0x0A]), // \n
                                                in: searchStart..<buffer.count) {
                    lineOffsets.append(offset + UInt64(range.lowerBound + 1))
                    searchStart = range.upperBound
                    totalLines += 1
                }

                // 保留未处理的部分
                if searchStart < buffer.count {
                    buffer = buffer.subdata(in: searchStart..<buffer.count)
                } else {
                    buffer.removeAll()
                }

                offset += UInt64(data.count)
            }
        }
    }

    /// 加载指定范围的行
    func loadLines(range: Range<Int>) -> [String] {
        guard let handle = fileHandle else { return [] }
        guard range.lowerBound < lineOffsets.count else { return [] }

        let startOffset = lineOffsets[range.lowerBound]
        let endIndex = min(range.upperBound, lineOffsets.count - 1)
        let endOffset = endIndex < lineOffsets.count ? lineOffsets[endIndex] : fileSize

        let length = Int(endOffset - startOffset)
        guard length > 0 else { return [] }

        handle.seek(toFileOffset: startOffset)
        let data = handle.readData(ofLength: length)

        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return text.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    /// 快速获取文件前 N 行（用于预览）
    func previewLines(count: Int) -> String {
        let lines = loadLines(range: 0..<min(count, totalLines))
        return lines.joined(separator: "\n")
    }
}

/// 虚拟列表数据源
class VirtualListDataSource<T> {
    private var items: [T?] // 稀疏数组，只加载可见项
    private let totalCount: Int
    private let loadBatch: Int
    private let loadHandler: (Range<Int>) async -> [T]

    init(totalCount: Int, loadBatch: Int = 50, loadHandler: @escaping (Range<Int>) async -> [T]) {
        self.totalCount = totalCount
        self.loadBatch = loadBatch
        self.loadHandler = loadHandler
        self.items = Array(repeating: nil, count: totalCount)
    }

    func item(at index: Int) async -> T? {
        if let cached = items[index] {
            return cached
        }

        // 预加载周围数据
        let start = max(0, index - loadBatch / 2)
        let end = min(totalCount, index + loadBatch / 2)
        let range = start..<end

        let loaded = await loadHandler(range)
        for (offset, item) in loaded.enumerated() {
            let idx = start + offset
            if idx < items.count {
                items[idx] = item
            }
        }

        return items[index]
    }

    func prefetch(range: Range<Int>) async {
        let start = max(0, range.lowerBound)
        let end = min(totalCount, range.upperBound)

        // 检查是否需要加载
        let needsLoad = (start..<end).contains { items[$0] == nil }
        guard needsLoad else { return }

        let loaded = await loadHandler(start..<end)
        for (offset, item) in loaded.enumerated() {
            let idx = start + offset
            if idx < items.count {
                items[idx] = item
            }
        }
    }

    func clearCache() {
        items = Array(repeating: nil, count: totalCount)
    }
}

/// 图片异步加载器
class AsyncImageLoader {
    static let shared = AsyncImageLoader()
    private var loadingTasks: [URL: Task<UIImage?, Never>] = [:]
    private let imageCache = NSCache<NSURL, UIImage>()

    private init() {
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func loadImage(from url: URL) async -> UIImage? {
        // 检查缓存
        if let cached = imageCache.object(forKey: url as NSURL) {
            return cached
        }

        // 检查是否已有加载任务
        if let existingTask = loadingTasks[url] {
            return await existingTask.value
        }

        // 创建新任务
        let task = Task<UIImage?, Never> {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                loadingTasks.removeValue(forKey: url)
                return nil
            }

            // 存入缓存
            let cost = Int(data.count)
            imageCache.setObject(image, forKey: url as NSURL, cost: cost)
            loadingTasks.removeValue(forKey: url)

            return image
        }

        loadingTasks[url] = task
        return await task.value
    }

    func preloadImages(urls: [URL]) {
        Task {
            for url in urls {
                _ = await loadImage(from: url)
            }
        }
    }

    func clearCache() {
        imageCache.removeAllObjects()
    }
}

/// 后台文件监控
class FileChangeMonitor {
    static let shared = FileChangeMonitor()
    private var monitoredDirectories: [URL: DispatchSourceFileSystemObject] = [:]
    private var changeHandlers: [URL: () -> Void] = [:]

    private init() {}

    func startMonitoring(directory: URL, onChange: @escaping () -> Void) {
        // 停止之前的监控
        stopMonitoring(directory: directory)

        let fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: DispatchQueue.global()
        )

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        monitoredDirectories[directory] = source
        changeHandlers[directory] = onChange
    }

    func stopMonitoring(directory: URL) {
        if let source = monitoredDirectories[directory] {
            source.cancel()
            monitoredDirectories.removeValue(forKey: directory)
            changeHandlers.removeValue(forKey: directory)
        }
    }

    func stopAllMonitoring() {
        for (url, source) in monitoredDirectories {
            source.cancel()
        }
        monitoredDirectories.removeAll()
        changeHandlers.removeAll()
    }
}
