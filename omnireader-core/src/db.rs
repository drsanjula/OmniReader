//! SQLite database layer

use crate::annotation::{Annotation, AnnotationType, ReadingPosition};
use crate::book::{Book, BookType};
use crate::error::OmniReaderError;
use rusqlite::{Connection, params};
use std::sync::Mutex;
use uniffi;

/// Database wrapper for thread-safe access
#[derive(uniffi::Object)]
pub struct Database {
    conn: Mutex<Connection>,
}

#[uniffi::export]
impl Database {
    /// Open or create database at the specified path
    #[uniffi::constructor]
    pub fn open(path: String) -> Result<Self, OmniReaderError> {
        let conn = Connection::open(&path)?;
        let db = Self {
            conn: Mutex::new(conn),
        };
        db.initialize_schema()?;
        Ok(db)
    }

    /// Open an in-memory database (for testing)
    #[uniffi::constructor]
    pub fn open_in_memory() -> Result<Self, OmniReaderError> {
        let conn = Connection::open_in_memory()?;
        let db = Self {
            conn: Mutex::new(conn),
        };
        db.initialize_schema()?;
        Ok(db)
    }
}

impl Database {
    /// Initialize database schema
    fn initialize_schema(&self) -> Result<(), OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS books (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                author TEXT,
                file_path TEXT NOT NULL UNIQUE,
                file_type TEXT NOT NULL,
                cover_data BLOB,
                added_at INTEGER NOT NULL,
                last_read_at INTEGER,
                total_pages INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS annotations (
                id TEXT PRIMARY KEY,
                book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
                annotation_type TEXT NOT NULL,
                start_percent REAL NOT NULL,
                end_percent REAL NOT NULL,
                page_number INTEGER NOT NULL,
                color TEXT NOT NULL,
                selected_text TEXT,
                note_text TEXT,
                created_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS reading_positions (
                book_id TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
                percent REAL NOT NULL,
                page_number INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_annotations_book_id ON annotations(book_id);
            "#,
        )?;
        Ok(())
    }

    // === Book Operations ===

    /// Insert a new book into the database
    pub fn insert_book(&self, book: &Book) -> Result<(), OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            r#"
            INSERT INTO books (id, title, author, file_path, file_type, cover_data, added_at, last_read_at, total_pages)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
            "#,
            params![
                book.id,
                book.title,
                book.author,
                book.file_path,
                book.file_type.extension(),
                book.cover_data,
                book.added_at,
                book.last_read_at,
                book.total_pages,
            ],
        )?;
        Ok(())
    }

    /// Get all books, sorted by recently added
    pub fn get_all_books(&self) -> Result<Vec<Book>, OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, title, author, file_path, file_type, cover_data, added_at, last_read_at, total_pages 
             FROM books ORDER BY added_at DESC"
        )?;

        let books = stmt
            .query_map([], |row| {
                let file_type_str: String = row.get(4)?;
                let file_type = BookType::from_extension(&file_type_str).unwrap_or(BookType::Pdf);
                Ok(Book {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    author: row.get(2)?,
                    file_path: row.get(3)?,
                    file_type,
                    cover_data: row.get(5)?,
                    added_at: row.get(6)?,
                    last_read_at: row.get(7)?,
                    total_pages: row.get(8)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(books)
    }

    /// Get a single book by ID
    pub fn get_book(&self, id: &str) -> Result<Option<Book>, OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, title, author, file_path, file_type, cover_data, added_at, last_read_at, total_pages 
             FROM books WHERE id = ?1"
        )?;

        let mut rows = stmt.query(params![id])?;
        if let Some(row) = rows.next()? {
            let file_type_str: String = row.get(4)?;
            let file_type = BookType::from_extension(&file_type_str).unwrap_or(BookType::Pdf);
            Ok(Some(Book {
                id: row.get(0)?,
                title: row.get(1)?,
                author: row.get(2)?,
                file_path: row.get(3)?,
                file_type,
                cover_data: row.get(5)?,
                added_at: row.get(6)?,
                last_read_at: row.get(7)?,
                total_pages: row.get(8)?,
            }))
        } else {
            Ok(None)
        }
    }

    /// Check if a book with the given file path exists
    pub fn book_exists_by_path(&self, file_path: &str) -> Result<bool, OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM books WHERE file_path = ?1",
            params![file_path],
            |row| row.get(0),
        )?;
        Ok(count > 0)
    }

    /// Delete a book and all its annotations
    pub fn delete_book(&self, id: &str) -> Result<(), OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM books WHERE id = ?1", params![id])?;
        Ok(())
    }

    /// Update book's last_read_at timestamp
    pub fn update_last_read(&self, id: &str) -> Result<(), OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().timestamp();
        conn.execute(
            "UPDATE books SET last_read_at = ?1 WHERE id = ?2",
            params![now, id],
        )?;
        Ok(())
    }

    // === Annotation Operations ===

    /// Insert a new annotation
    pub fn insert_annotation(&self, annotation: &Annotation) -> Result<(), OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        let annotation_type = match annotation.annotation_type {
            AnnotationType::Highlight => "highlight",
            AnnotationType::Note => "note",
        };
        conn.execute(
            r#"
            INSERT INTO annotations (id, book_id, annotation_type, start_percent, end_percent, page_number, color, selected_text, note_text, created_at)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
            "#,
            params![
                annotation.id,
                annotation.book_id,
                annotation_type,
                annotation.start_percent,
                annotation.end_percent,
                annotation.page_number,
                annotation.color,
                annotation.selected_text,
                annotation.note_text,
                annotation.created_at,
            ],
        )?;
        Ok(())
    }

    /// Get all annotations for a book
    pub fn get_annotations(&self, book_id: &str) -> Result<Vec<Annotation>, OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, book_id, annotation_type, start_percent, end_percent, page_number, color, selected_text, note_text, created_at 
             FROM annotations WHERE book_id = ?1 ORDER BY start_percent"
        )?;

        let annotations = stmt
            .query_map(params![book_id], |row| {
                let type_str: String = row.get(2)?;
                let annotation_type = match type_str.as_str() {
                    "note" => AnnotationType::Note,
                    _ => AnnotationType::Highlight,
                };
                Ok(Annotation {
                    id: row.get(0)?,
                    book_id: row.get(1)?,
                    annotation_type,
                    start_percent: row.get(3)?,
                    end_percent: row.get(4)?,
                    page_number: row.get(5)?,
                    color: row.get(6)?,
                    selected_text: row.get(7)?,
                    note_text: row.get(8)?,
                    created_at: row.get(9)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(annotations)
    }

    /// Delete an annotation
    pub fn delete_annotation(&self, id: &str) -> Result<(), OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM annotations WHERE id = ?1", params![id])?;
        Ok(())
    }

    // === Reading Position Operations ===

    /// Save or update reading position
    pub fn save_reading_position(&self, position: &ReadingPosition) -> Result<(), OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            r#"
            INSERT INTO reading_positions (book_id, percent, page_number, updated_at)
            VALUES (?1, ?2, ?3, ?4)
            ON CONFLICT(book_id) DO UPDATE SET
                percent = excluded.percent,
                page_number = excluded.page_number,
                updated_at = excluded.updated_at
            "#,
            params![
                position.book_id,
                position.percent,
                position.page_number,
                position.updated_at,
            ],
        )?;
        Ok(())
    }

    /// Get reading position for a book
    pub fn get_reading_position(
        &self,
        book_id: &str,
    ) -> Result<Option<ReadingPosition>, OmniReaderError> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT book_id, percent, page_number, updated_at FROM reading_positions WHERE book_id = ?1"
        )?;

        let mut rows = stmt.query(params![book_id])?;
        if let Some(row) = rows.next()? {
            Ok(Some(ReadingPosition {
                book_id: row.get(0)?,
                percent: row.get(1)?,
                page_number: row.get(2)?,
                updated_at: row.get(3)?,
            }))
        } else {
            Ok(None)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_database_creation() {
        let db = Database::open_in_memory().unwrap();
        let books = db.get_all_books().unwrap();
        assert!(books.is_empty());
    }

    #[test]
    fn test_book_crud() {
        let db = Database::open_in_memory().unwrap();

        let book = Book::new(
            "Test Book".to_string(),
            Some("Test Author".to_string()),
            "/path/to/book.pdf".to_string(),
            BookType::Pdf,
            100,
        );

        db.insert_book(&book).unwrap();

        let books = db.get_all_books().unwrap();
        assert_eq!(books.len(), 1);
        assert_eq!(books[0].title, "Test Book");

        let fetched = db.get_book(&book.id).unwrap();
        assert!(fetched.is_some());
        assert_eq!(fetched.unwrap().author, Some("Test Author".to_string()));

        db.delete_book(&book.id).unwrap();
        let books = db.get_all_books().unwrap();
        assert!(books.is_empty());
    }

    #[test]
    fn test_annotations() {
        let db = Database::open_in_memory().unwrap();

        let book = Book::new(
            "Test Book".to_string(),
            None,
            "/path/to/book.epub".to_string(),
            BookType::Epub,
            10,
        );
        db.insert_book(&book).unwrap();

        let highlight = Annotation::new_highlight(
            book.id.clone(),
            10.0,
            15.0,
            1,
            crate::annotation::HighlightColor::Yellow,
            Some("Selected text".to_string()),
        );
        db.insert_annotation(&highlight).unwrap();

        let annotations = db.get_annotations(&book.id).unwrap();
        assert_eq!(annotations.len(), 1);
        assert_eq!(
            annotations[0].selected_text,
            Some("Selected text".to_string())
        );
    }

    #[test]
    fn test_reading_position() {
        let db = Database::open_in_memory().unwrap();

        let book = Book::new(
            "Test Book".to_string(),
            None,
            "/path/to/book.pdf".to_string(),
            BookType::Pdf,
            50,
        );
        db.insert_book(&book).unwrap();

        let position = ReadingPosition::new(book.id.clone(), 25.5, 13);
        db.save_reading_position(&position).unwrap();

        let fetched = db.get_reading_position(&book.id).unwrap();
        assert!(fetched.is_some());
        assert_eq!(fetched.unwrap().percent, 25.5);

        // Update position
        let new_position = ReadingPosition::new(book.id.clone(), 50.0, 25);
        db.save_reading_position(&new_position).unwrap();

        let fetched = db.get_reading_position(&book.id).unwrap();
        assert_eq!(fetched.unwrap().percent, 50.0);
    }
}
