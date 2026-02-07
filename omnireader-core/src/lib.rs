//! OmniReader Core - Privacy-first ebook reader engine
//!
//! This crate provides the core functionality for OmniReader:
//! - Book parsing (PDF, EPUB)
//! - Local SQLite database
//! - Annotation management
//! - UniFFI bindings for Swift/Kotlin

pub mod annotation;
pub mod book;
pub mod db;
pub mod epub;
pub mod error;
pub mod pdf;

use uniffi;

pub use annotation::{Annotation, AnnotationType, ReadingPosition};
pub use book::{Book, BookType};
pub use db::Database;
pub use error::OmniReaderError;

uniffi::setup_scaffolding!();
