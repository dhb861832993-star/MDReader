import SwiftUI

struct ReaderContainerView: View {
    let file: FileItem
    @State private var showReaderSettings = false
    @State private var showOutline = false

    var body: some View {
        Group {
            switch file.fileType {
            case .markdown:
                MarkdownReaderView(file: file)
            case .json:
                JSONReaderView(file: file)
            case .yaml, .code:
                CodeReaderView(file: file)
            case .text:
                TextReaderView(file: file)
            case .image:
                ImageReaderView(file: file)
            case .other:
                TextReaderView(file: file)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showOutline = true
                    } label: {
                        Label("大纲", systemImage: "list.bullet.rectangle")
                    }

                    Button {
                        showReaderSettings = true
                    } label: {
                        Label("阅读设置", systemImage: "textformat.size")
                    }

                    Divider()

                    Button {
                        UIPasteboard.general.string = file.url.absoluteString
                    } label: {
                        Label("复制路径", systemImage: "doc.on.doc")
                    }

                    ShareLink(item: file.url) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        // 删除
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showReaderSettings) {
            ReaderSettingsView()
        }
        .sheet(isPresented: $showOutline) {
            OutlineView(file: file)
        }
    }
}

struct ReaderSettingsView: View {
    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerLineSpacing") private var lineSpacing: Double = 1.5
    @AppStorage("readerTheme") private var theme: ReaderTheme = .light
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("字体大小") {
                    HStack {
                        Text("A")
                            .font(.caption)
                        Slider(value: $fontSize, in: 12...32, step: 1)
                        Text("A")
                            .font(.title)
                    }
                    Text("当前: \(Int(fontSize))pt")
                        .foregroundColor(.secondary)
                }

                Section("行间距") {
                    Slider(value: $lineSpacing, in: 1.0...2.5, step: 0.1)
                    Text("当前: \(String(format: "%.1f", lineSpacing))")
                        .foregroundColor(.secondary)
                }

                Section("主题") {
                    ForEach(ReaderTheme.allCases, id: \.self) { t in
                        Button(action: { theme = t }) {
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(t.backgroundColor)
                                    .stroke(Color.gray, lineWidth: 1)
                                    .frame(width: 30, height: 30)

                                Text(t.name)
                                    .foregroundColor(.primary)

                                Spacer()

                                if theme == t {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 大纲项模型
struct OutlineItem: Identifiable {
    let id = UUID()
    let level: Int
    let title: String
    let lineNumber: Int
}

// MARK: - 大纲视图
struct OutlineView: View {
    let file: FileItem
    @Environment(\.dismiss) private var dismiss
    @State private var outlineItems: [OutlineItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else if outlineItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("未找到标题")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("文档中没有标题（# 开头的行）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(outlineItems) { item in
                            HStack(spacing: 0) {
                                // 缩进
                                ForEach(0..<item.level, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 20)
                                }

                                // 标题
                                Text(item.title)
                                    .font(item.level == 1 ? .headline : (item.level == 2 ? .subheadline : .body))
                                    .foregroundColor(item.level == 1 ? .primary : .secondary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // TODO: 跳转到对应行
                                dismiss()
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("大纲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadOutline()
        }
    }

    private func loadOutline() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let content = try await FileSystemManager.shared.loadFileContent(file)
            outlineItems = parseOutline(from: content)
        } catch {
            outlineItems = []
        }
    }

    private func parseOutline(from content: String) -> [OutlineItem] {
        var items: [OutlineItem] = []
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 匹配标题 # ## ### 等
            if trimmed.hasPrefix("#") {
                var level = 0
                for char in trimmed {
                    if char == "#" {
                        level += 1
                    } else {
                        break
                    }
                }

                // 只处理 1-6 级标题
                if level >= 1 && level <= 6 {
                    let title = String(trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces))
                    if !title.isEmpty {
                        items.append(OutlineItem(level: level, title: title, lineNumber: index + 1))
                    }
                }
            }
        }

        return items
    }
}
