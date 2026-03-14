import SwiftUI

struct MarkdownReaderView: View {
    let file: FileItem
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var readingProgress: Double = 0
    @AppStorage("readerTheme") private var theme: ReaderTheme = .light

    var body: some View {
        ZStack {
            theme.backgroundColor
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    // 进度条
                    GeometryReader { geo in
                        ProgressView(value: readingProgress)
                            .frame(width: geo.size.width * readingProgress, height: 2)
                            .background(Color.blue)
                    }
                    .frame(height: 2)

                    // 内容视图
                    MarkdownTextView(content: content, onScroll: { progress in
                        readingProgress = progress
                    })
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - SwiftUI 包装 TextKit 2 渲染
struct MarkdownTextView: UIViewRepresentable {
    let content: String
    let onScroll: (Double) -> Void

    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerLineSpacing") private var lineSpacing: Double = 1.5
    @AppStorage("readerTheme") private var theme: ReaderTheme = .light

    func makeUIView(context: Context) -> UITextView {
        let textView = MarkdownRenderingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.showsVerticalScrollIndicator = true

        // 配置文本容器
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        textView.textContainer.lineFragmentPadding = 0

        // 设置委托监听滚动
        textView.delegate = context.coordinator
        context.coordinator.onScroll = onScroll
        context.coordinator.textView = textView

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // 应用主题背景色
        textView.backgroundColor = UIColor(theme.backgroundColor)

        // 渲染 Markdown
        let renderer = MarkdownRenderer(fontSize: CGFloat(fontSize), lineSpacing: CGFloat(lineSpacing), theme: theme)
        textView.attributedText = renderer.render(content)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onScroll: ((Double) -> Void)?
        weak var textView: UITextView?

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let textView = textView else { return }
            let contentHeight = textView.contentSize.height
            let visibleHeight = textView.bounds.height
            let offset = textView.contentOffset.y

            if contentHeight > visibleHeight {
                let progress = min(1.0, max(0.0, offset / (contentHeight - visibleHeight)))
                onScroll?(progress)
            }
        }
    }
}

// MARK: - 自定义 TextView
class MarkdownRenderingTextView: UITextView {
    override var canBecomeFirstResponder: Bool {
        return false // 只读模式
    }
}

// MARK: - Markdown 渲染器
class MarkdownRenderer {
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let theme: ReaderTheme

    init(fontSize: CGFloat, lineSpacing: CGFloat, theme: ReaderTheme) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.theme = theme
    }

    // 主题相关颜色
    private var textColor: UIColor {
        UIColor(theme.textColor)
    }

    private var secondaryColor: UIColor {
        theme == .light || theme == .sepia ? .darkGray : .lightGray
    }

    private var codeBackgroundColor: UIColor {
        theme == .light ? UIColor(white: 0.95, alpha: 1.0) :
        theme == .sepia ? UIColor(red: 0.92, green: 0.89, blue: 0.85, alpha: 1.0) :
        UIColor(white: 0.2, alpha: 1.0)
    }

    private var codeTextColor: UIColor {
        theme == .light || theme == .sepia ? .systemPink : UIColor(red: 1.0, green: 0.6, blue: 0.8, alpha: 1.0)
    }

    private var linkColor: UIColor {
        theme == .light || theme == .sepia ? .systemBlue : UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
    }

    func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let attributedLine = parseLine(line)
            result.append(attributedLine)

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        // 设置段落样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * (lineSpacing - 1.0)
        paragraphStyle.paragraphSpacing = fontSize * 0.5

        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func parseLine(_ line: String) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // 标题
        if trimmed.hasPrefix("# ") {
            return heading(text: String(trimmed.dropFirst(2)), level: 1)
        } else if trimmed.hasPrefix("## ") {
            return heading(text: String(trimmed.dropFirst(3)), level: 2)
        } else if trimmed.hasPrefix("### ") {
            return heading(text: String(trimmed.dropFirst(4)), level: 3)
        } else if trimmed.hasPrefix("#### ") {
            return heading(text: String(trimmed.dropFirst(5)), level: 4)
        }

        // 分隔线
        if trimmed == "---" || trimmed == "***" {
            return separator()
        }

        // 代码块
        if trimmed.hasPrefix("```") {
            return codeBlock(text: line)
        }

        // 引用
        if trimmed.hasPrefix("> ") {
            return blockquote(text: String(trimmed.dropFirst(2)))
        }

        // 列表
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return listItem(text: String(trimmed.dropFirst(2)), ordered: false)
        }
        if let _ = Int(String(trimmed.prefix(1))), trimmed.contains(". ") {
            return listItem(text: String(trimmed.dropFirst(3)), ordered: true)
        }

        // 普通段落（处理内联格式）
        return paragraph(text: line)
    }

    private func heading(text: String, level: Int) -> NSAttributedString {
        let size = fontSize * (1.8 - Double(level) * 0.2)
        let font = UIFont.systemFont(ofSize: CGFloat(size), weight: .bold)
        let color: UIColor = level <= 2 ? textColor : secondaryColor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let result = NSMutableAttributedString(string: text, attributes: attributes)

        // 添加间距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = fontSize * 0.5
        paragraphStyle.paragraphSpacing = fontSize * 0.3

        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func paragraph(text: String) -> NSAttributedString {
        return parseInline(text: text, font: UIFont.systemFont(ofSize: fontSize))
    }

    private func parseInline(text: String, font: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text

        let patterns: [(pattern: String, handler: (String) -> NSAttributedString)] = [
            ("`([^`]+)`", { code in
                NSAttributedString(
                    string: code,
                    attributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: self.fontSize * 0.9, weight: .regular),
                        .foregroundColor: self.codeTextColor,
                        .backgroundColor: self.codeBackgroundColor
                    ]
                )
            }),
            ("\\*\\*([^*]+)\\*\\*", { bold in
                NSAttributedString(
                    string: bold,
                    attributes: [
                        .font: UIFont.boldSystemFont(ofSize: self.fontSize),
                        .foregroundColor: self.textColor
                    ]
                )
            }),
            ("\\*([^*]+)\\*", { italic in
                NSAttributedString(
                    string: italic,
                    attributes: [
                        .font: UIFont.italicSystemFont(ofSize: self.fontSize),
                        .foregroundColor: self.textColor
                    ]
                )
            }),
            ("\\[([^\\]]+)\\]\\(([^)]+)\\)", { link in
                NSAttributedString(
                    string: link,
                    attributes: [
                        .foregroundColor: self.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ]
                )
            })
        ]

        while !remaining.isEmpty {
            var matched = false

            for (pattern, handler) in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: remaining, range: NSRange(location: 0, length: remaining.utf16.count)) {

                    let beforeRange = NSRange(location: 0, length: match.range.location)
                    if beforeRange.length > 0,
                       let beforeRangeSwift = Range(beforeRange, in: remaining) {
                        let beforeText = String(remaining[beforeRangeSwift])
                        result.append(NSAttributedString(string: beforeText, attributes: [.font: font]))
                    }

                    let contentRange = match.range(at: 1)
                    if let contentRangeSwift = Range(contentRange, in: remaining) {
                        let content = String(remaining[contentRangeSwift])
                        result.append(handler(content))
                    }

                    let afterStart = match.range.location + match.range.length
                    if afterStart < remaining.utf16.count,
                       let afterRangeSwift = Range(NSRange(location: afterStart, length: remaining.utf16.count - afterStart), in: remaining) {
                        remaining = String(remaining[afterRangeSwift])
                    } else {
                        remaining = ""
                    }

                    matched = true
                    break
                }
            }

            if !matched {
                result.append(NSAttributedString(string: remaining, attributes: [.font: font, .foregroundColor: textColor]))
                break
            }
        }

        return result
    }

    private func codeBlock(text: String) -> NSAttributedString {
        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize * 0.85, weight: .regular),
                .foregroundColor: textColor,
                .backgroundColor: codeBackgroundColor
            ]
        )
    }

    private func blockquote(text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = fontSize * 2

        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.italicSystemFont(ofSize: fontSize),
                .foregroundColor: secondaryColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private func listItem(text: String, ordered: Bool) -> NSAttributedString {
        let prefix = ordered ? "• " : "• "
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = fontSize * 1.5

        return NSAttributedString(
            string: prefix + text,
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private func separator() -> NSAttributedString {
        let result = NSMutableAttributedString(string: "\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}\u{2015}")
        result.addAttribute(
            .foregroundColor,
            value: secondaryColor,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }
}
