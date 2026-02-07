import Foundation

// MARK: - Wrapper functions for calling UniFFI in detached context
// These exist at module level to avoid name shadowing with RustBridge methods

private func callExtractPdfMetadata(_ path: String) throws -> BookMetadata {
    try extractPdfMetadata(filePath: path)
}

private func callRenderPdfPage(_ path: String, _ page: UInt32, _ width: UInt32) throws -> Data {
    try renderPdfPage(filePath: path, pageNumber: page, width: width)
}

private func callGetPdfPageCount(_ path: String) throws -> UInt32 {
    try getPdfPageCount(filePath: path)
}

private func callExtractEpubMetadata(_ path: String) throws -> BookMetadata {
    try extractEpubMetadata(filePath: path)
}

private func callGetEpubToc(_ path: String) throws -> [TocEntry] {
    try getEpubToc(filePath: path)
}

private func callGetEpubChapter(_ path: String, _ index: UInt32) throws -> EpubChapter {
    try getEpubChapter(filePath: path, chapterIndex: index)
}

private func callGetEpubChapterCount(_ path: String) throws -> UInt32 {
    try getEpubChapterCount(filePath: path)
}

private func callGetEpubCover(_ path: String) throws -> Data? {
    try getEpubCover(filePath: path)
}

/// Bridge to Rust core library via UniFFI
/// Provides Swift-friendly async wrappers around Rust functions
@MainActor
class RustBridge: ObservableObject {
    static let shared = RustBridge()
    
    /// Whether the Rust library is properly loaded
    @Published private(set) var isReady = false
    @Published private(set) var lastError: String?
    
    private init() {
        // Library will be loaded when first called
        isReady = true
    }
    
    // MARK: - PDF Functions
    
    /// Extract metadata from a PDF file
    func extractPdfMetadata(filePath: String) async throws -> BookMetadata {
        try await Task.detached {
            try callExtractPdfMetadata(filePath)
        }.value
    }
    
    /// Render a PDF page to PNG data
    func renderPdfPage(filePath: String, pageNumber: UInt32, width: UInt32) async throws -> Data {
        try await Task.detached {
            try callRenderPdfPage(filePath, pageNumber, width)
        }.value
    }
    
    /// Get total page count for a PDF
    func getPdfPageCount(filePath: String) async throws -> UInt32 {
        try await Task.detached {
            try callGetPdfPageCount(filePath)
        }.value
    }
    
    // MARK: - EPUB Functions
    
    /// Extract metadata from an EPUB file
    func extractEpubMetadata(filePath: String) async throws -> BookMetadata {
        try await Task.detached {
            try callExtractEpubMetadata(filePath)
        }.value
    }
    
    /// Get table of contents for an EPUB
    func getEpubToc(filePath: String) async throws -> [TocEntry] {
        try await Task.detached {
            try callGetEpubToc(filePath)
        }.value
    }
    
    /// Get chapter content by index
    func getEpubChapter(filePath: String, chapterIndex: UInt32) async throws -> EpubChapter {
        try await Task.detached {
            try callGetEpubChapter(filePath, chapterIndex)
        }.value
    }
    
    /// Get total chapter count for an EPUB
    func getEpubChapterCount(filePath: String) async throws -> UInt32 {
        try await Task.detached {
            try callGetEpubChapterCount(filePath)
        }.value
    }
    
    /// Get EPUB cover image data
    func getEpubCover(filePath: String) async throws -> Data? {
        try await Task.detached {
            try callGetEpubCover(filePath)
        }.value
    }
    
    // MARK: - High-Level Helpers
    
    /// Import a book file and extract its metadata
    func importBook(from url: URL) async throws -> (metadata: BookMetadata, fileType: BookType) {
        let ext = url.pathExtension.lowercased()
        let filePath = url.path
        
        switch ext {
        case "pdf":
            let metadata = try await extractPdfMetadata(filePath: filePath)
            return (metadata, .pdf)
        case "epub":
            let metadata = try await extractEpubMetadata(filePath: filePath)
            return (metadata, .epub)
        default:
            throw OmniReaderError.UnsupportedFormat(extension: ext)
        }
    }
}
