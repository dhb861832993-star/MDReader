import SwiftUI

// MARK: - JSON Reader
struct JSONReaderView: View {
    let file: FileItem
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var showTree = true

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if showTree {
                    JSONTreeView(jsonString: content)
                } else {
                    CodeTextView(content: content, language: "json")
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $showTree) {
                        Image(systemName: showTree ? "list.bullet.indent" : "doc.plaintext")
                    }
                    .toggleStyle(.button)
                }
            }
        }
        .task {
            await loadContent()
        }
    }

    private func loadContent() async {
        isLoading = true
        do {
            content = try await FileSystemManager.shared.loadFileContent(file)
        } catch {
            content = "加载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct JSONTreeView: View {
    let jsonString: String
    @State private var rootNode: JSONNode?
    @State private var expandedNodes: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let root = rootNode {
                    JSONNodeView(node: root, level: 0, expandedNodes: $expandedNodes)
                } else {
                    Text("无效的 JSON")
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .task {
            parseJSON()
        }
    }

    private func parseJSON() {
        guard let data = jsonString.data(using: .utf8) else { return }

        do {
            let json = try JSONSerialization.jsonObject(with: data)
            rootNode = JSONNode.from(json, key: "root")
            // 默认展开根节点
            if let root = rootNode {
                expandedNodes.insert(root.id)
            }
        } catch {
            rootNode = nil
        }
    }
}

struct JSONNode: Identifiable {
    let id = UUID().uuidString
    let key: String
    let value: JSONValue
    let children: [JSONNode]
    let path: String

    static func from(_ object: Any, key: String, path: String = "") -> JSONNode {
        let currentPath = path.isEmpty ? key : "\(path).\(key)"

        switch object {
        case let dict as [String: Any]:
            let children = dict.map { (k, v) in
                JSONNode.from(v, key: k, path: currentPath)
            }.sorted { $0.key < $1.key }
            return JSONNode(key: key, value: .object, children: children, path: currentPath)

        case let array as [Any]:
            let children = array.enumerated().map { (index, element) in
                JSONNode.from(element, key: "[\(index)]", path: currentPath)
            }
            return JSONNode(key: key, value: .array(count: array.count), children: children, path: currentPath)

        case let string as String:
            return JSONNode(key: key, value: .string(string), children: [], path: currentPath)

        case let number as NSNumber:
            if number === kCFBooleanTrue || number === kCFBooleanFalse {
                return JSONNode(key: key, value: .bool(number.boolValue), children: [], path: currentPath)
            }
            return JSONNode(key: key, value: .number(number), children: [], path: currentPath)

        default:
            return JSONNode(key: key, value: .null, children: [], path: currentPath)
        }
    }
}

enum JSONValue {
    case object
    case array(count: Int)
    case string(String)
    case number(NSNumber)
    case bool(Bool)
    case null

    var displayText: String {
        switch self {
        case .object: return "{}"
        case .array(let count): return "[\(count)]"
        case .string(let s): return "\"\(s)\""
        case .number(let n): return "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        }
    }

    var color: Color {
        switch self {
        case .object: return .blue
        case .array: return .purple
        case .string: return .green
        case .number: return .orange
        case .bool: return .pink
        case .null: return .gray
        }
    }

    var isContainer: Bool {
        switch self {
        case .object, .array: return true
        default: return false
        }
    }
}

struct JSONNodeView: View {
    let node: JSONNode
    let level: Int
    @Binding var expandedNodes: Set<String>

    var isExpanded: Bool {
        expandedNodes.contains(node.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.value.isContainer {
                    toggleExpanded()
                }
            } label: {
                HStack(spacing: 6) {
                    // 缩进
                    HStack(spacing: 0) {
                        ForEach(0..<level, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 20, height: 28)
                        }
                    }

                    // 展开箭头
                    if node.value.isContainer {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 16)
                    }

                    // Key
                    Text(node.key)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.primary)

                    Text(":")
                        .foregroundColor(.secondary)

                    // Value
                    Text(node.value.displayText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(node.value.color)
                        .lineLimit(1)
                }
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Children
            if isExpanded && !node.children.isEmpty {
                ForEach(node.children) { child in
                    JSONNodeView(node: child, level: level + 1, expandedNodes: $expandedNodes)
                }
            }
        }
    }

    private func toggleExpanded() {
        if expandedNodes.contains(node.id) {
            expandedNodes.remove(node.id)
        } else {
            expandedNodes.insert(node.id)
        }
    }
}
