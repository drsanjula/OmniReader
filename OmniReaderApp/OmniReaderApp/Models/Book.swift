import Foundation
import UniformTypeIdentifiers

/// Represents a book in the library
struct Book: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var author: String?
    let filePath: String
    let fileType: BookType
    var coverData: Data?
    var addedAt: Date?
    var lastReadAt: Date?
    var totalPages: UInt32
    
    /// Preview book for SwiftUI previews
    static var preview: Book {
        Book(
            id: "preview-1",
            title: "Sample Book Title",
            author: "Sample Author",
            filePath: "/path/to/book.pdf",
            fileType: .pdf,
            coverData: nil,
            addedAt: Date(),
            lastReadAt: nil,
            totalPages: 100
        )
    }
}

/// Type of ebook file
enum BookType: String, Codable {
    case pdf
    case epub
}

/// EPUB file type identifier
extension UTType {
    static var epub: UTType {
        UTType(filenameExtension: "epub") ?? .data
    }
}
