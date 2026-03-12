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
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showOutline.toggle() }) {
                    Image(systemName: "list.bullet.rectangle")
                }

                Button(action: { showReaderSettings.toggle() }) {
                    Image(systemName: "textformat.size")
                }

                Menu {
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

struct OutlineView: View {
    let file: FileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Text("文档大纲")
                    .font(.headline)
                // 根据文档内容解析大纲
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
    }
}
