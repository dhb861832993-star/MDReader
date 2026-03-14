import SwiftUI

struct ContentView: View {
    @State private var selectedFile: FileItem?

    var body: some View {
        ZStack {
            FileBrowserView(selectedFile: $selectedFile)

            // 阅读器全屏覆盖
            if let file = selectedFile {
                ReaderFullScreenView(file: file) {
                    selectedFile = nil
                }
                .transition(.move(edge: .trailing))
            }
        }
        .onChange(of: selectedFile) { _, newFile in
            if let file = newFile {
                FileSystemManager.shared.recordFileOpened(file)
            }
        }
    }
}

// MARK: - 全屏阅读器视图
struct ReaderFullScreenView: View {
    let file: FileItem
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ReaderContainerView(file: file)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                    }
                }
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
}