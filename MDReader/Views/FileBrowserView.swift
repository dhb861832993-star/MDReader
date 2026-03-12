import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var fileManager: FileSystemManager
    @Binding var selectedFile: FileItem?
    @State private var viewMode: ViewMode = .list
    @State private var showSearch = false
    @State private var showingDocumentPicker = false

    enum ViewMode {
        case list, grid
    }

    var body: some View {
        VStack(spacing: 0) {
            // 路径导航栏
            PathNavigationBar()
                .padding(.horizontal)

            // 搜索栏
            if showSearch {
                SearchBar(text: $fileManager.searchQuery)
                    .padding(.horizontal)
                    .transition(.move(edge: .top))
            }

            // 筛选标签
            FilterTabs()
                .padding(.horizontal)

            // 文件列表
            Group {
                if viewMode == .list {
                    FileListView(selectedFile: $selectedFile)
                } else {
                    FileGridView(selectedFile: $selectedFile)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showSearch.toggle() }) {
                    Image(systemName: "magnifyingglass")
                }

                Button(action: { viewMode = viewMode == .list ? .grid : .list }) {
                    Image(systemName: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                }

                Menu {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("导入文件", systemImage: "folder.badge.plus")
                    }

                    Button {
                        createNewFolder()
                    } label: {
                        Label("新建文件夹", systemImage: "folder.badge.plus")
                    }

                    Button {
                        createNewFile()
                    } label: {
                        Label("新建文档", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func createNewFolder() {
        // 创建新文件夹
    }

    private func createNewFile() {
        // 创建新文档
    }
}

struct PathNavigationBar: View {
    @EnvironmentObject var fileManager: FileSystemManager

    var body: some View {
        HStack {
            if fileManager.currentDirectory.path != FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
                Button(action: { fileManager.navigateUp() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
            }

            Text(fileManager.currentDirectory.lastPathComponent)
                .font(.headline)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("搜索文件...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct FilterTabs: View {
    @State private var selectedTab = 0
    let tabs = ["全部", "最近", "收藏", "代码", "文档"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    FilterTabButton(
                        title: tabs[index],
                        isSelected: selectedTab == index
                    ) {
                        selectedTab = index
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct FilterTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct FileListView: View {
    @EnvironmentObject var fileManager: FileSystemManager
    @Binding var selectedFile: FileItem?

    var body: some View {
        List(selection: $selectedFile) {
            Section {
                ForEach(fileManager.filteredFiles) { file in
                    FileListRow(file: file, isSelected: selectedFile?.id == file.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if file.isDirectory {
                                fileManager.navigateToDirectory(file.url)
                            } else {
                                selectedFile = file
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                // 删除
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                fileManager.toggleFavorite(file)
                            } label: {
                                Label("收藏", systemImage: file.isFavorite ? "star.fill" : "star")
                            }
                            .tint(.yellow)
                        }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            fileManager.scanCurrentDirectory()
        }
    }
}

struct FileListRow: View {
    let file: FileItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(file.fileType.color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: file.isDirectory ? "folder" : file.fileType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(file.isDirectory ? .orange : file.fileType.color)
            }

            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !file.isDirectory {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if file.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            }

            Spacer()

            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct FileGridView: View {
    @EnvironmentObject var fileManager: FileSystemManager
    @Binding var selectedFile: FileItem?

    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(fileManager.filteredFiles) { file in
                    FileGridItem(file: file, isSelected: selectedFile?.id == file.id)
                        .onTapGesture {
                            if file.isDirectory {
                                fileManager.navigateToDirectory(file.url)
                            } else {
                                selectedFile = file
                            }
                        }
                }
            }
            .padding()
        }
    }
}

struct FileGridItem: View {
    let file: FileItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(file.fileType.color.opacity(0.1))
                    .frame(height: 80)

                Image(systemName: file.isDirectory ? "folder.fill" : file.fileType.icon)
                    .font(.system(size: 40))
                    .foregroundColor(file.isDirectory ? .orange : file.fileType.color)

                if file.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }

            Text(file.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(12)
    }
}
