import SwiftUI
import UniformTypeIdentifiers

/// 文档导入视图
struct DocumentImporterView: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType] = [
        .plainText,
        .data,
        UTType(filenameExtension: "md")!,
        UTType(filenameExtension: "markdown")!,
        UTType(filenameExtension: "json")!,
        UTType(filenameExtension: "yaml")!,
        UTType(filenameExtension: "yml")!,
        UTType(filenameExtension: "py")!,
        UTType(filenameExtension: "swift")!,
        UTType(filenameExtension: "js")!,
        UTType(filenameExtension: "ts")!,
        UTType(filenameExtension: "go")!,
        UTType(filenameExtension: "rs")!,
        UTType(filenameExtension: "sql")!,
    ]

    var onImport: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: ([URL]) -> Void

        init(onImport: @escaping ([URL]) -> Void) {
            self.onImport = onImport
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onImport(urls)
        }
    }
}

/// 文件操作菜单
struct FileActionSheet: View {
    let file: FileItem
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 文件信息头部
            VStack(spacing: 8) {
                Image(systemName: file.isDirectory ? "folder" : file.fileType.icon)
                    .font(.system(size: 60))
                    .foregroundColor(file.isDirectory ? .orange : file.fileType.color)

                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    Label(file.formattedSize, systemImage: "doc")
                    Label(file.formattedDate, systemImage: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))

            // 操作按钮
            ScrollView {
                VStack(spacing: 0) {
                    ActionButton(icon: "square.and.arrow.up", title: "分享", color: .blue) {
                        shareFile()
                    }

                    ActionButton(icon: file.isFavorite ? "star.fill" : "star",
                               title: file.isFavorite ? "取消收藏" : "收藏",
                               color: .yellow) {
                        toggleFavorite()
                    }

                    ActionButton(icon: "folder.badge.plus", title: "移动", color: .green) {
                        moveFile()
                    }

                    ActionButton(icon: "doc.on.doc", title: "复制", color: .blue) {
                        duplicateFile()
                    }

                    ActionButton(icon: "pencil", title: "重命名", color: .orange) {
                        renameFile()
                    }

                    Divider()

                    ActionButton(icon: "trash", title: "删除", color: .red) {
                        deleteFile()
                    }
                }
            }

            // 取消按钮
            Button("取消") {
                isPresented = false
            }
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
        }
    }

    private func shareFile() {
        // 分享文件
    }

    private func toggleFavorite() {
        FileSystemManager.shared.toggleFavorite(file)
        isPresented = false
    }

    private func moveFile() {
        // 移动文件
    }

    private func duplicateFile() {
        // 复制文件
    }

    private func renameFile() {
        // 重命名文件
    }

    private func deleteFile() {
        // 删除文件
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
        }

        Divider()
            .padding(.leading, 50)
    }
}

/// 新建文件/文件夹弹窗
struct CreateNewItemView: View {
    @Binding var isPresented: Bool
    @State private var itemName = ""
    let type: ItemType
    let onCreate: (String) -> Void

    enum ItemType {
        case file, folder

        var title: String {
            switch self {
            case .file: return "新建文件"
            case .folder: return "新建文件夹"
            }
        }

        var icon: String {
            switch self {
            case .file: return "doc.badge.plus"
            case .folder: return "folder.badge.plus"
            }
        }

        var defaultName: String {
            switch self {
            case .file: return "未命名.md"
            case .folder: return "新建文件夹"
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: type.icon)
                            .font(.title2)
                            .foregroundColor(.blue)

                        TextField("名称", text: $itemName)
                    }
                }

                Section {
                    Text("将在 \(type == .file ? "当前文件夹" : "此位置") 创建\(type == .file ? "文件" : "文件夹")")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let name = itemName.isEmpty ? type.defaultName : itemName
                        onCreate(name)
                        isPresented = false
                    }
                    .disabled(itemName.isEmpty)
                }
            }
        }
        .onAppear {
            itemName = type.defaultName
        }
    }
}

/// 搜索过滤扩展
extension FileSystemManager {
    func filesByType(_ type: FileType) -> [FileItem] {
        return files.filter { $0.fileType == type }
    }

    var recentFiles: [FileItem] {
        return files
            .filter { !$0.isDirectory }
            .sorted { $0.modificationDate > $1.modificationDate }
            .prefix(20)
            .map { $0 }
    }

    var favoriteFiles: [FileItem] {
        return files.filter { $0.isFavorite }
    }

    var codeFiles: [FileItem] {
        return files.filter { $0.fileType == .code || $0.fileType == .json || $0.fileType == .yaml }
    }

    var documentFiles: [FileItem] {
        return files.filter { $0.fileType == .markdown || $0.fileType == .text }
    }
}
