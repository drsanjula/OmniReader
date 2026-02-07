import SwiftUI
import Combine

/// ViewModel for managing the book library
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    private var libraryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let omnireaderDir = appSupport.appendingPathComponent("OmniReader", isDirectory: true)
        
        // Create directory if needed
        if !fileManager.fileExists(atPath: omnireaderDir.path) {
            try? fileManager.createDirectory(at: omnireaderDir, withIntermediateDirectories: true)
        }
        
        return omnireaderDir
    }
    
    init() {
        loadBooks()
    }
    
    /// Load books from persistent storage
    func loadBooks() {
        isLoading = true
        
        // TODO: Load from SQLite via Rust core
        // For now, load from UserDefaults as placeholder
        if let data = UserDefaults.standard.data(forKey: "omnireader.books"),
           let savedBooks = try? JSONDecoder().decode([Book].self, from: data) {
            books = savedBooks.sorted { ($0.addedAt ?? Date()) > ($1.addedAt ?? Date()) }
        }
        
        isLoading = false
    }
    
    /// Save books to persistent storage
    private func saveBooks() {
        // TODO: Save to SQLite via Rust core
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: "omnireader.books")
        }
    }
    
    /// Import a book from a file URL
    func importBook(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access file: \(url.lastPathComponent)"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let ext = url.pathExtension.lowercased()
        guard ext == "pdf" || ext == "epub" else {
            errorMessage = "Unsupported format: \(ext). Only PDF and EPUB are supported."
            return
        }
        
        // Check for duplicates
        if books.contains(where: { $0.filePath == url.path }) {
            errorMessage = "This book is already in your library."
            return
        }
        
        // Copy file to app's library directory
        let destURL = libraryURL.appendingPathComponent(url.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: url, to: destURL)
            
            // Create book entry
            let book = Book(
                id: UUID().uuidString,
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                filePath: destURL.path,
                fileType: ext == "pdf" ? .pdf : .epub,
                coverData: nil,
                addedAt: Date(),
                lastReadAt: nil,
                totalPages: 0
            )
            
            books.insert(book, at: 0)
            saveBooks()
            
            // TODO: Extract metadata and cover via Rust core
            
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }
    }
    
    /// Delete a book from the library
    func deleteBook(_ book: Book) {
        // Remove file
        try? fileManager.removeItem(atPath: book.filePath)
        
        // Remove from list
        books.removeAll { $0.id == book.id }
        saveBooks()
    }
    
    /// Show file import panel
    func showImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .epub]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select PDF or EPUB files to import"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                importBook(from: url)
            }
        }
    }
}
