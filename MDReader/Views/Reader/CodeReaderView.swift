import SwiftUI

// MARK: - Code Reader
struct CodeReaderView: View {
    let file: FileItem
    @State private var content: String = ""
    @State private var isLoading = true

    var language: String {
        file.url.pathExtension.lowercased()
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else {
                CodeTextView(content: content, language: language)
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

// MARK: - Text Reader
struct TextReaderView: View {
    let file: FileItem
    @State private var content: String = ""
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(size: 16))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Image Reader
struct ImageReaderView: View {
    let file: FileItem
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let img = image {
                ZoomableImageView(image: img, scale: $scale)
            } else {
                Text("无法加载图片")
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        if let data = try? Data(contentsOf: file.url),
           let img = UIImage(data: data) {
            image = img
        }
        isLoading = false
    }
}

struct ZoomableImageView: View {
    let image: UIImage
    @Binding var scale: CGFloat

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = value
                        }
                )
        }
    }
}

// MARK: - 通用代码/文本视图
struct CodeTextView: UIViewRepresentable {
    let content: String
    let language: String

    @AppStorage("readerFontSize") private var fontSize: Double = 14
    @AppStorage("readerTheme") private var theme: ReaderTheme = .light

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.showsVerticalScrollIndicator = true
        textView.font = UIFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.text = content
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // 应用主题背景色
        textView.backgroundColor = UIColor(theme.backgroundColor)

        // 代码高亮
        textView.attributedText = SyntaxHighlighter.highlight(content, language: language, fontSize: CGFloat(fontSize), theme: theme)
    }
}

// MARK: - 语法高亮器
class SyntaxHighlighter {
    static func highlight(_ code: String, language: String, fontSize: CGFloat, theme: ReaderTheme) -> NSAttributedString {
        let result = NSMutableAttributedString(string: code)
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // 根据主题设置基础颜色
        let textColor: UIColor = UIColor(theme.textColor)
        let isDark = (theme == .dark || theme == .midnight)

        // 基础属性
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        result.addAttributes(baseAttributes, range: NSRange(location: 0, length: result.length))

        // 根据语言应用高亮规则
        switch language {
        case "json":
            highlightJSON(result, code: code, fontSize: fontSize, isDark: isDark)
        case "swift":
            highlightSwift(result, code: code, fontSize: fontSize, isDark: isDark)
        case "py", "python":
            highlightPython(result, code: code, fontSize: fontSize, isDark: isDark)
        case "js", "ts", "javascript", "typescript":
            highlightJavaScript(result, code: code, fontSize: fontSize, isDark: isDark)
        case "yaml", "yml":
            highlightYAML(result, code: code, fontSize: fontSize, isDark: isDark)
        default:
            break
        }

        return result
    }

    private static func highlightJSON(_ result: NSMutableAttributedString, code: String, fontSize: CGFloat, isDark: Bool) {
        let stringColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0) : .systemGreen
        let numberColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0) : .systemOrange
        let keywordColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0) : .systemPink
        let keyColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0) : .systemBlue

        // 字符串
        applyPattern(result, pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: stringColor)
        // 数字
        applyPattern(result, pattern: "\\b-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", color: numberColor)
        // 关键字
        applyPattern(result, pattern: "\\b(true|false|null)\\b", color: keywordColor)
        // 键（字符串后跟冒号）
        applyPattern(result, pattern: "\"[^\"]+\"(?=\\s*:)", color: keyColor)
    }

    private static func highlightSwift(_ result: NSMutableAttributedString, code: String, fontSize: CGFloat, isDark: Bool) {
        let keywordColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0) : .systemPink
        let stringColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0) : .systemRed
        let commentColor: UIColor = isDark ? .lightGray : .systemGray
        let typeColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0) : .systemOrange

        let keywords = ["import", "class", "struct", "enum", "protocol", "extension",
                       "func", "var", "let", "if", "else", "guard", "switch", "case",
                       "for", "while", "return", "throw", "try", "catch", "init",
                       "self", "super", "public", "private", "internal", "static"]

        for keyword in keywords {
            applyPattern(result, pattern: "\\b\(keyword)\\b", color: keywordColor)
        }

        // 字符串
        applyPattern(result, pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: stringColor)
        // 注释
        applyPattern(result, pattern: "//.*$", color: commentColor, options: .anchorsMatchLines)
        // 多行注释
        applyPattern(result, pattern: "/\\*.*?\\*/", color: commentColor, options: .dotMatchesLineSeparators)
        // 类型名（首字母大写的标识符）
        applyPattern(result, pattern: "\\b[A-Z][a-zA-Z0-9_]*\\b", color: typeColor)
    }

    private static func highlightPython(_ result: NSMutableAttributedString, code: String, fontSize: CGFloat, isDark: Bool) {
        let keywordColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0) : .systemPink
        let stringColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0) : .systemGreen
        let commentColor: UIColor = isDark ? .lightGray : .systemGray
        let funcColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0) : .systemBlue
        let classColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0) : .systemOrange

        let keywords = ["def", "class", "if", "elif", "else", "for", "while",
                       "try", "except", "finally", "with", "import", "from",
                       "return", "yield", "pass", "break", "continue", "lambda",
                       "None", "True", "False", "and", "or", "not", "in", "is"]

        for keyword in keywords {
            applyPattern(result, pattern: "\\b\(keyword)\\b", color: keywordColor)
        }

        // 字符串
        applyPattern(result, pattern: "[rfb]*\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: stringColor)
        applyPattern(result, pattern: "[rfb]*'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", color: stringColor)
        // 注释
        applyPattern(result, pattern: "#.*$", color: commentColor, options: .anchorsMatchLines)
        // 函数定义
        applyPattern(result, pattern: "(?<=def\\s)\\w+", color: funcColor)
        // 类定义
        applyPattern(result, pattern: "(?<=class\\s)\\w+", color: classColor)
    }

    private static func highlightJavaScript(_ result: NSMutableAttributedString, code: String, fontSize: CGFloat, isDark: Bool) {
        let keywordColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0) : .systemPink
        let stringColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0) : .systemGreen
        let commentColor: UIColor = isDark ? .lightGray : .systemGray
        let funcColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0) : .systemBlue

        let keywords = ["const", "let", "var", "function", "class", "if", "else",
                       "for", "while", "return", "import", "export", "from",
                       "async", "await", "try", "catch", "new", "this", "typeof"]

        for keyword in keywords {
            applyPattern(result, pattern: "\\b\(keyword)\\b", color: keywordColor)
        }

        // 字符串
        applyPattern(result, pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", color: stringColor)
        applyPattern(result, pattern: "'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", color: stringColor)
        applyPattern(result, pattern: "`[^`\\\\]*(?:\\\\.[^`\\\\]*)*`", color: stringColor)
        // 注释
        applyPattern(result, pattern: "//.*$", color: commentColor, options: .anchorsMatchLines)
        // 函数调用
        applyPattern(result, pattern: "\\w+(?=\\s*\\()", color: funcColor)
    }

    private static func highlightYAML(_ result: NSMutableAttributedString, code: String, fontSize: CGFloat, isDark: Bool) {
        let keyColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0) : .systemBlue
        let commentColor: UIColor = isDark ? .lightGray : .systemGray
        let keywordColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0) : .systemPink
        let numberColor: UIColor = isDark ? UIColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0) : .systemOrange
        let stringColor: UIColor = isDark ? UIColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 1.0) : .systemGreen

        // 键
        applyPattern(result, pattern: "^[a-zA-Z_][a-zA-Z0-9_]*(?=\\s*:)", color: keyColor, options: .anchorsMatchLines)
        // 注释
        applyPattern(result, pattern: "#.*$", color: commentColor, options: .anchorsMatchLines)
        // 布尔值和null
        applyPattern(result, pattern: "\\b(true|false|yes|no|on|off|null|~)\\b", color: keywordColor)
        // 数字
        applyPattern(result, pattern: "\\b-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", color: numberColor)
        // 字符串
        applyPattern(result, pattern: "\"[^\"]*\"|'[^']*'", color: stringColor)
    }

    private static func applyPattern(_ result: NSMutableAttributedString,
                                     pattern: String,
                                     color: UIColor,
                                     options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }

        let range = NSRange(location: 0, length: result.length)
        let matches = regex.matches(in: result.string, options: [], range: range)

        for match in matches.reversed() {
            result.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
