//! Annotation and reading position models

use uniffi;

/// Type of annotation
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum AnnotationType {
    Highlight,
    Note,
}

/// Highlight color presets
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum HighlightColor {
    Yellow,
    Green,
    Blue,
    Pink,
    Orange,
}

impl HighlightColor {
    /// Get hex color string
    pub fn hex(&self) -> &'static str {
        match self {
            HighlightColor::Yellow => "#FFEB3B",
            HighlightColor::Green => "#4CAF50",
            HighlightColor::Blue => "#2196F3",
            HighlightColor::Pink => "#E91E63",
            HighlightColor::Orange => "#FF9800",
        }
    }

    /// Parse from hex string
    pub fn from_hex(hex: &str) -> Option<Self> {
        match hex.to_uppercase().as_str() {
            "#FFEB3B" => Some(HighlightColor::Yellow),
            "#4CAF50" => Some(HighlightColor::Green),
            "#2196F3" => Some(HighlightColor::Blue),
            "#E91E63" => Some(HighlightColor::Pink),
            "#FF9800" => Some(HighlightColor::Orange),
            _ => None,
        }
    }
}

/// An annotation (highlight or note) on a book
#[derive(Debug, Clone, uniffi::Record)]
pub struct Annotation {
    /// Unique identifier (UUID v4)
    pub id: String,
    /// Reference to parent book
    pub book_id: String,
    /// Type of annotation
    pub annotation_type: AnnotationType,
    /// Start position as percentage (0.0 - 100.0)
    pub start_percent: f64,
    /// End position as percentage (0.0 - 100.0)
    pub end_percent: f64,
    /// Page number (for display purposes)
    pub page_number: u32,
    /// Highlight color (hex string)
    pub color: String,
    /// Selected text content
    pub selected_text: Option<String>,
    /// User's note (optional)
    pub note_text: Option<String>,
    /// Unix timestamp when created
    pub created_at: i64,
}

impl Annotation {
    /// Create a new highlight annotation
    pub fn new_highlight(
        book_id: String,
        start_percent: f64,
        end_percent: f64,
        page_number: u32,
        color: HighlightColor,
        selected_text: Option<String>,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id,
            annotation_type: AnnotationType::Highlight,
            start_percent,
            end_percent,
            page_number,
            color: color.hex().to_string(),
            selected_text,
            note_text: None,
            created_at: chrono::Utc::now().timestamp(),
        }
    }

    /// Create a new note annotation
    pub fn new_note(
        book_id: String,
        start_percent: f64,
        page_number: u32,
        note_text: String,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id,
            annotation_type: AnnotationType::Note,
            start_percent,
            end_percent: start_percent,
            page_number,
            color: HighlightColor::Yellow.hex().to_string(),
            selected_text: None,
            note_text: Some(note_text),
            created_at: chrono::Utc::now().timestamp(),
        }
    }
}

/// Tracks the user's reading position in a book
#[derive(Debug, Clone, uniffi::Record)]
pub struct ReadingPosition {
    /// Reference to book
    pub book_id: String,
    /// Current position as percentage (0.0 - 100.0)
    pub percent: f64,
    /// Current page number
    pub page_number: u32,
    /// Unix timestamp of last update
    pub updated_at: i64,
}

impl ReadingPosition {
    /// Create a new reading position
    pub fn new(book_id: String, percent: f64, page_number: u32) -> Self {
        Self {
            book_id,
            percent,
            page_number,
            updated_at: chrono::Utc::now().timestamp(),
        }
    }
}
