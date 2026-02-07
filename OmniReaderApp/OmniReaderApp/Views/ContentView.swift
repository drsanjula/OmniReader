import SwiftUI

/// Main content view that switches between library and reader
struct ContentView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedBook: Book?
    
    var body: some View {
        NavigationSplitView {
            LibraryView(selectedBook: $selectedBook)
        } detail: {
            if let book = selectedBook {
                ReaderView(book: book)
            } else {
                EmptyLibraryView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        libraryViewModel.importBook(from: url)
                    }
                }
            }
        }
        return true
    }
}

/// Empty state view when no books are in library
struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No Book Selected")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text("Drag & drop PDF or EPUB files to import")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

