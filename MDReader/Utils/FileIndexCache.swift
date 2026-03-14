import Foundation

// MARK: - 内存缓存
class MemoryFileCache {
    static let shared = MemoryFileCache()
    private var cache: [String: FileItem] = [:]
    private let lock = NSLock()
    private let maxCount = 1000

    private init() {}

    func get(key: String) -> FileItem? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func set(_ item: FileItem, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        if cache.count >= maxCount {
            // 简单的 LRU：移除第一个
            cache.removeValue(forKey: cache.keys.first ?? "")
        }
        cache[key] = item
    }

    func remove(key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
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