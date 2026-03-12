import SwiftUI

struct ContentView: View {
    @StateObject private var fileManager = FileSystemManager.shared
    @State private var selectedFile: FileItem?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileBrowserView(selectedFile: $selectedFile)
                .navigationTitle("MD阅读器")
        } detail: {
            if let file = selectedFile {
                ReaderContainerView(file: file)
            } else {
                EmptyStateView()
            }
        }
        .environmentObject(fileManager)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("选择文件开始阅读")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
