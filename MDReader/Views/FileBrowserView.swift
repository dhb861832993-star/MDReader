import SwiftUI

// MARK: - 主标签视图
struct FileBrowserView: View {
    @Binding var selectedFile: FileItem?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 全部文件
            AllFilesView(selectedFile: $selectedFile)
                .tabItem {
                    Label("全部", systemImage: "folder")
                }
                .tag(0)

            // 最近
            RecentFilesView(selectedFile: $selectedFile)
                .tabItem {
                    Label("最近", systemImage: "clock")
                }
                .tag(1)

            // 浏览（导入）
            BrowseView()
                .tabItem {
                    Label("浏览", systemImage: "rectangle.and.text.magnifyingglass")
                }
                .tag(2)
        }
    }
}

// MARK: - 排序方式
enum SortMode: String, CaseIterable {
    case modificationDate = "修改时间"
    case name = "名称"
    case size = "大小"
    case type = "类型"

    var icon: String {
        switch self {
        case .modificationDate: return "clock"
        case .name: return "textformat.abc"
        case .size: return "externaldrive"
        case .type: return "square.grid.3x3"
        }
    }
}

// MARK: - 全部文件视图
struct AllFilesView: View {
    @Binding var selectedFile: FileItem?
    @State private var viewMode: ViewMode = .grid
    @State private var sortMode: SortMode = .modificationDate
    @State private var selectedTag: String?
    @State private var searchQuery = ""

    enum ViewMode {
        case list, grid
    }

    var filteredFiles: [FileItem] {
        let files = FileSystemManager.shared.files
        if searchQuery.isEmpty {
            return files
        }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏 - 常驻显示
                SearchBar(text: $searchQuery, showTagFilter: true, selectedTag: $selectedTag, allTags: FileSystemManager.shared.allTags)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // 文件列表
                if viewMode == .list {
                    FileListView(selectedFile: $selectedFile, sortMode: sortMode, selectedTag: selectedTag, searchQuery: searchQuery)
                } else {
                    FileGridView(selectedFile: $selectedFile, sortMode: sortMode, selectedTag: selectedTag, searchQuery: searchQuery)
                }
            }
            .navigationTitle("全部文件")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // 排序选项
                        Section("排序方式") {
                            ForEach(SortMode.allCases, id: \.self) { mode in
                                Button {
                                    sortMode = mode
                                } label: {
                                    HStack {
                                        Label(mode.rawValue, systemImage: mode.icon)
                                        if sortMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            viewMode = viewMode == .list ? .grid : .list
                        } label: {
                            Label(viewMode == .list ? "网格视图" : "列表视图",
                                  systemImage: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

// MARK: - 最近文件视图
struct RecentFilesView: View {
    @Binding var selectedFile: FileItem?
    @State private var searchQuery = ""
    @State private var showTagFilter = false
    @State private var selectedTag: String?

    var recentFiles: [FileItem] {
        let files = FileSystemManager.shared.recentOpenedFiles

        var filtered = files
        if let tag = selectedTag {
            filtered = filtered.filter { $0.tags.contains(tag) }
        }
        if !searchQuery.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
        return filtered
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏 - 常驻显示
                SearchBar(text: $searchQuery, showTagFilter: true, selectedTag: $selectedTag, allTags: FileSystemManager.shared.allTags)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                List {
                    if recentFiles.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("暂无最近文件")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("打开文件后会显示在这里")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(recentFiles) { file in
                            RecentFileRow(file: file, isSelected: selectedFile?.id == file.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedFile = file
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("最近")
        }
    }
}

// MARK: - 最近文件行
struct RecentFileRow: View {
    let file: FileItem
    let isSelected: Bool
    @State private var showFileInfo = false
    @State private var showRename = false
    @State private var showTagEdit = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(file.fileType.color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: file.fileType.icon)
                    .font(.system(size: 28))
                    .foregroundColor(file.fileType.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(file.formattedSize)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(file.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                showFileInfo = true
            } label: {
                Label("显示简介", systemImage: "info.circle")
            }

            Button {
                showRename = true
            } label: {
                Label("重命名", systemImage: "pencil")
            }

            Button {
                showTagEdit = true
            } label: {
                Label("标签", systemImage: "tag")
            }

            Divider()

            Button {
                FileSystemManager.shared.toggleFavorite(file)
            } label: {
                Label(file.isFavorite ? "取消收藏" : "收藏", systemImage: file.isFavorite ? "star.slash" : "star")
            }
        }
        .sheet(isPresented: $showFileInfo) {
            FileInfoSheet(file: file)
        }
        .sheet(isPresented: $showRename) {
            RenameSheet(file: file)
        }
        .sheet(isPresented: $showTagEdit) {
            TagEditSheet(file: file)
        }
    }
}

// MARK: - 浏览视图（导入文件）
struct BrowseView: View {
    @State private var showingDocumentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // 图标
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }

                // 标题和描述
                VStack(spacing: 8) {
                    Text("导入文件")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("从文件 App 或其他位置导入文档")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // 导入按钮
                Button(action: { showingDocumentPicker = true }) {
                    Text("选择文件")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("浏览")
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView()
            }
        }
    }
}

// MARK: - 文档选择器
struct DocumentPickerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("文档选择器")
                .font(.headline)
                .padding()

            Spacer()

            Text("此处将显示系统文件选择器")
                .foregroundColor(.secondary)

            Spacer()

            Button("关闭") {
                dismiss()
            }
            .padding()
        }
    }
}

// MARK: - 搜索栏
struct SearchBar: View {
    @Binding var text: String
    var showTagFilter: Bool = false
    @Binding var selectedTag: String?
    var allTags: [String] = []

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("搜索", text: $text)
                .textFieldStyle(PlainTextFieldStyle())

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            if showTagFilter && !allTags.isEmpty {
                Menu {
                    Button {
                        selectedTag = nil
                    } label: {
                        Label("全部标签", systemImage: selectedTag == nil ? "checkmark" : "")
                    }

                    Divider()

                    ForEach(allTags, id: \.self) { tag in
                        Button {
                            selectedTag = selectedTag == tag ? nil : tag
                        } label: {
                            HStack {
                                Text(tag)
                                if selectedTag == tag {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: selectedTag == nil ? "tag" : "tag.fill")
                        .foregroundColor(selectedTag == nil ? .secondary : .blue)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - 文件列表视图
struct FileListView: View {
    @Binding var selectedFile: FileItem?
    var sortMode: SortMode
    var selectedTag: String?
    var searchQuery: String = ""

    var sortedFiles: [FileItem] {
        var files = FileSystemManager.shared.files

        // 按名称搜索
        if !searchQuery.isEmpty {
            files = files.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }

        // 按标签过滤
        if let tag = selectedTag {
            files = files.filter { $0.tags.contains(tag) }
        }

        switch sortMode {
        case .modificationDate:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.modificationDate > item2.modificationDate
            }
        case .name:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .size:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.size > item2.size
            }
        case .type:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.fileType.rawValue < item2.fileType.rawValue
            }
        }
    }

    var body: some View {
        List {
            if sortedFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("文件夹为空")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击「浏览」导入文件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                ForEach(sortedFiles) { file in
                    FileListRow(file: file, isSelected: selectedFile?.id == file.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if file.isDirectory {
                                FileSystemManager.shared.navigateToDirectory(file.url)
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
                                FileSystemManager.shared.toggleFavorite(file)
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
            FileSystemManager.shared.scanCurrentDirectory()
        }
    }
}

// MARK: - 文件列表行（苹果风格 - 大图标大文字）
struct FileListRow: View {
    let file: FileItem
    let isSelected: Bool
    @State private var showFileInfo = false
    @State private var showRename = false
    @State private var showTagEdit = false

    var body: some View {
        HStack(spacing: 16) {
            // 大图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(file.isDirectory ? Color.orange.opacity(0.15) : file.fileType.color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: file.isDirectory ? "folder.fill" : file.fileType.icon)
                    .font(.system(size: 28))
                    .foregroundColor(file.isDirectory ? .orange : file.fileType.color)
            }

            // 文件信息
            VStack(alignment: .leading, spacing: 6) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !file.isDirectory {
                        Text(file.formattedSize)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(file.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if file.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }

                    if !file.tags.isEmpty {
                        ForEach(file.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()

            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                showFileInfo = true
            } label: {
                Label("显示简介", systemImage: "info.circle")
            }

            Button {
                showRename = true
            } label: {
                Label("重命名", systemImage: "pencil")
            }

            Button {
                showTagEdit = true
            } label: {
                Label("标签", systemImage: "tag")
            }

            Divider()

            Button {
                FileSystemManager.shared.toggleFavorite(file)
            } label: {
                Label(file.isFavorite ? "取消收藏" : "收藏", systemImage: file.isFavorite ? "star.slash" : "star")
            }
        }
        .sheet(isPresented: $showFileInfo) {
            FileInfoSheet(file: file)
        }
        .sheet(isPresented: $showRename) {
            RenameSheet(file: file)
        }
        .sheet(isPresented: $showTagEdit) {
            TagEditSheet(file: file)
        }
    }
}

// MARK: - 文件网格视图
struct FileGridView: View {
    @Binding var selectedFile: FileItem?
    var sortMode: SortMode
    var selectedTag: String?
    var searchQuery: String = ""

    let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 20)
    ]

    var sortedFiles: [FileItem] {
        var files = FileSystemManager.shared.files

        // 按名称搜索
        if !searchQuery.isEmpty {
            files = files.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }

        // 按标签过滤
        if let tag = selectedTag {
            files = files.filter { $0.tags.contains(tag) }
        }

        switch sortMode {
        case .modificationDate:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.modificationDate > item2.modificationDate
            }
        case .name:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .size:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.size > item2.size
            }
        case .type:
            return files.sorted { item1, item2 in
                if item1.isDirectory != item2.isDirectory {
                    return item1.isDirectory
                }
                return item1.fileType.rawValue < item2.fileType.rawValue
            }
        }
    }

    var body: some View {
        ScrollView {
            if sortedFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("文件夹为空")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击「浏览」导入文件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(sortedFiles) { file in
                        FileGridItem(file: file, isSelected: selectedFile?.id == file.id)
                            .onTapGesture {
                                if file.isDirectory {
                                    FileSystemManager.shared.navigateToDirectory(file.url)
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
}

// MARK: - 文件网格项
struct FileGridItem: View {
    let file: FileItem
    let isSelected: Bool
    @State private var showFileInfo = false
    @State private var showRename = false
    @State private var showTagEdit = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(file.isDirectory ? Color.orange.opacity(0.15) : file.fileType.color.opacity(0.15))
                    .frame(height: 100)

                Image(systemName: file.isDirectory ? "folder.fill" : file.fileType.icon)
                    .font(.system(size: 44))
                    .foregroundColor(file.isDirectory ? .orange : file.fileType.color)

                if file.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.callout)
                                .foregroundColor(.yellow)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }

            Text(file.name)
                .font(.subheadline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(16)
        .contextMenu {
            Button {
                showFileInfo = true
            } label: {
                Label("显示简介", systemImage: "info.circle")
            }

            Button {
                showRename = true
            } label: {
                Label("重命名", systemImage: "pencil")
            }

            Button {
                showTagEdit = true
            } label: {
                Label("标签", systemImage: "tag")
            }

            Divider()

            Button {
                FileSystemManager.shared.toggleFavorite(file)
            } label: {
                Label(file.isFavorite ? "取消收藏" : "收藏", systemImage: file.isFavorite ? "star.slash" : "star")
            }
        }
        .sheet(isPresented: $showFileInfo) {
            FileInfoSheet(file: file)
        }
        .sheet(isPresented: $showRename) {
            RenameSheet(file: file)
        }
        .sheet(isPresented: $showTagEdit) {
            TagEditSheet(file: file)
        }
    }
}

// MARK: - 文件简介
struct FileInfoSheet: View {
    let file: FileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("名称")
                        Spacer()
                        Text(file.name)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("类型")
                        Spacer()
                        Text(file.isDirectory ? "文件夹" : file.fileType.rawValue)
                            .foregroundColor(.secondary)
                    }

                    if !file.isDirectory {
                        HStack {
                            Text("大小")
                            Spacer()
                            Text(file.formattedSize)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("修改时间")
                        Spacer()
                        Text(file.modificationDate.formatted(date: .long, time: .shortened))
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }

                    HStack {
                        Text("路径")
                        Spacer()
                        Text(file.url.path)
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }

                if !file.tags.isEmpty {
                    Section("标签") {
                        ForEach(file.tags, id: \.self) { tag in
                            Text(tag)
                        }
                    }
                }
            }
            .navigationTitle("文件简介")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 重命名视图
struct RenameSheet: View {
    let file: FileItem
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("文件名", text: $newName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRename()
                    }
                    .disabled(newName.isEmpty || newName == file.name)
                }
            }
        }
        .presentationDetents([.height(200)])
        .onAppear {
            newName = file.name
        }
    }

    private func saveRename() {
        guard !newName.isEmpty, newName != file.name else { return }

        if FileSystemManager.shared.renameFile(file, to: newName) {
            dismiss()
        } else {
            errorMessage = "重命名失败，请检查文件名是否有效"
        }
    }
}

// MARK: - 标签编辑视图
struct TagEditSheet: View {
    let file: FileItem
    @Environment(\.dismiss) private var dismiss
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @FocusState private var isInputFocused: Bool

    var allTags: [String] {
        FileSystemManager.shared.allTags.filter { !tags.contains($0) }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("添加新标签", text: $newTag)
                        .focused($isInputFocused)
                        .onSubmit {
                            addTag()
                        }

                    if !newTag.isEmpty {
                        Button("添加「\(newTag)」") {
                            addTag()
                        }
                    }
                }

                if !allTags.isEmpty {
                    Section("已有标签") {
                        ForEach(allTags.prefix(10), id: \.self) { tag in
                            Button {
                                tags.append(tag)
                                newTag = ""
                            } label: {
                                HStack {
                                    Text(tag)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                if !tags.isEmpty {
                    Section("当前标签") {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        FileSystemManager.shared.setTags(tags, for: file)
                        dismiss()
                    }
                }
            }
            .onAppear {
                tags = file.tags
            }
        }
        .presentationDetents([.medium])
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }
}