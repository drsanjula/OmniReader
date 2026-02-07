//! Error types for OmniReader

use thiserror::Error;
use uniffi;

#[derive(Debug, Error, uniffi::Error)]
pub enum OmniReaderError {
    #[error("Database error: {message}")]
    Database { message: String },

    #[error("File not found: {path}")]
    FileNotFound { path: String },

    #[error("Unsupported format: {extension}")]
    UnsupportedFormat { extension: String },

    #[error("Parse error: {message}")]
    ParseError { message: String },

    #[error("IO error: {message}")]
    IoError { message: String },
}

impl From<rusqlite::Error> for OmniReaderError {
    fn from(e: rusqlite::Error) -> Self {
        OmniReaderError::Database {
            message: e.to_string(),
        }
    }
}

impl From<std::io::Error> for OmniReaderError {
    fn from(e: std::io::Error) -> Self {
        OmniReaderError::IoError {
            message: e.to_string(),
        }
    }
}
