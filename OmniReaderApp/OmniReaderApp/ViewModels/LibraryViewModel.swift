import SwiftUI
import Combine

/// ViewModel for managing the book library
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    private let rustBridge = RustBridge.shared
    
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
        
        // Load from UserDefaults (temporary - will use SQLite via Rust later)
        if let data = UserDefaults.standard.data(forKey: "omnireader.books"),
           let savedBooks = try? JSONDecoder().decode([SerializableBook].self, from: data) {
            books = savedBooks.map { $0.toBook() }
                .sorted { $0.addedAt > $1.addedAt }
        }
        
        isLoading = false
    }
    
    /// Save books to persistent storage
    private func saveBooks() {
        let serializableBooks = books.map { SerializableBook(from: $0) }
        if let data = try? JSONEncoder().encode(serializableBooks) {
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
            
            // Create book entry with current timestamp
            let now = Int64(Date().timeIntervalSince1970)
            let book = Book(
                id: UUID().uuidString,
                title: url.deletingPathExtension().lastPathComponent,
                author: nil,
                filePath: destURL.path,
                fileType: ext == "pdf" ? .pdf : .epub,
                coverData: nil,
                addedAt: now,
                lastReadAt: nil,
                totalPages: 0
            )
            
            books.insert(book, at: 0)
            saveBooks()
            
            // Extract metadata asynchronously via Rust core
            Task {
                await extractMetadata(for: book)
            }
            
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }
    }
    
    /// Extract metadata for a book using Rust core
    private func extractMetadata(for book: Book) async {
        do {
            let (metadata, _) = try await rustBridge.importBook(from: URL(fileURLWithPath: book.filePath))
            
            // Update book with extracted metadata
            if let index = books.firstIndex(where: { $0.id == book.id }) {
                var updatedBook = books[index]
                if let title = metadata.title {
                    updatedBook.title = title
                }
                updatedBook.author = metadata.author
                updatedBook.coverData = metadata.coverData
                updatedBook.totalPages = metadata.totalPages
                
                books[index] = updatedBook
                saveBooks()
            }
        } catch {
            print("Metadata extraction failed: \(error.localizedDescription)")
            // Book is still saved, just without rich metadata
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

// MARK: - Serializable Book for UserDefaults persistence

/// A Codable wrapper for Book to enable JSON serialization
private struct SerializableBook: Codable {
    let id: String
    var title: String
    var author: String?
    let filePath: String
    let fileType: String // "pdf" or "epub"
    var coverData: Data?
    var addedAt: Int64
    var lastReadAt: Int64?
    var totalPages: UInt32
    
    init(from book: Book) {
        self.id = book.id
        self.title = book.title
        self.author = book.author
        self.filePath = book.filePath
        self.fileType = book.fileType == .pdf ? "pdf" : "epub"
        self.coverData = book.coverData
        self.addedAt = book.addedAt
        self.lastReadAt = book.lastReadAt
        self.totalPages = book.totalPages
    }
    
    func toBook() -> Book {
        Book(
            id: id,
            title: title,
            author: author,
            filePath: filePath,
            fileType: fileType == "pdf" ? .pdf : .epub,
            coverData: coverData,
            addedAt: addedAt,
            lastReadAt: lastReadAt,
            totalPages: totalPages
        )
    }
}
