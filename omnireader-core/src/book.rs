//! Book model and parsing utilities

use uniffi;

/// Type of ebook file
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum BookType {
    Pdf,
    Epub,
}

impl BookType {
    /// Get file extension for this book type
    pub fn extension(&self) -> &'static str {
        match self {
            BookType::Pdf => "pdf",
            BookType::Epub => "epub",
        }
    }

    /// Parse book type from file extension
    pub fn from_extension(ext: &str) -> Option<Self> {
        match ext.to_lowercase().as_str() {
            "pdf" => Some(BookType::Pdf),
            "epub" => Some(BookType::Epub),
            _ => None,
        }
    }
}

/// Represents an ebook in the library
#[derive(Debug, Clone, uniffi::Record)]
pub struct Book {
    /// Unique identifier (UUID v4)
    pub id: String,
    /// Book title (from metadata or filename)
    pub title: String,
    /// Author name (optional)
    pub author: Option<String>,
    /// Absolute path to the book file
    pub file_path: String,
    /// Type of book (PDF or EPUB)
    pub file_type: BookType,
    /// Cover image data (PNG bytes)
    pub cover_data: Option<Vec<u8>>,
    /// Unix timestamp when book was added
    pub added_at: i64,
    /// Unix timestamp of last read (optional)
    pub last_read_at: Option<i64>,
    /// Total pages (for PDF) or chapters (for EPUB)
    pub total_pages: u32,
}

impl Book {
    /// Create a new book with generated UUID
    pub fn new(
        title: String,
        author: Option<String>,
        file_path: String,
        file_type: BookType,
        total_pages: u32,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            title,
            author,
            file_path,
            file_type,
            cover_data: None,
            added_at: chrono::Utc::now().timestamp(),
            last_read_at: None,
            total_pages,
        }
    }
}

/// Metadata extracted from a book file
#[derive(Debug, Clone, uniffi::Record)]
pub struct BookMetadata {
    pub title: Option<String>,
    pub author: Option<String>,
    pub cover_data: Option<Vec<u8>>,
    pub total_pages: u32,
}
