//! EPUB parsing using epub crate

use crate::book::BookMetadata;
use crate::error::OmniReaderError;
use epub::doc::EpubDoc;
use std::path::Path;

/// Chapter content from EPUB
#[derive(Debug, Clone, uniffi::Record)]
pub struct EpubChapter {
    pub index: u32,
    pub title: String,
    pub content: String, // HTML content
}

/// Table of contents entry
#[derive(Debug, Clone, uniffi::Record)]
pub struct TocEntry {
    pub index: u32,
    pub title: String,
    pub path: String,
}

/// Extract metadata from an EPUB file
#[uniffi::export]
pub fn extract_epub_metadata(file_path: &str) -> Result<BookMetadata, OmniReaderError> {
    let path = Path::new(file_path);
    if !path.exists() {
        return Err(OmniReaderError::FileNotFound {
            path: file_path.to_string(),
        });
    }

    let mut doc = EpubDoc::new(file_path).map_err(|e| OmniReaderError::ParseError {
        message: format!("Failed to open EPUB: {}", e),
    })?;

    // Extract title using the convenience method, or fall back to mdata
    let title = doc.get_title().or_else(|| {
        path.file_stem()
            .and_then(|s| s.to_str())
            .map(|s| s.to_string())
    });

    // Extract author - mdata returns Option<&MetadataItem>, access .value field
    let author = doc.mdata("creator").map(|item| item.value.clone());

    // Get spine count (number of content documents / chapters)
    let total_pages = doc.get_num_chapters() as u32;

    // Extract cover image
    let cover_data = doc.get_cover().map(|(data, _mime)| data);

    Ok(BookMetadata {
        title,
        author,
        cover_data,
        total_pages,
    })
}

/// Get the table of contents
#[uniffi::export]
pub fn get_epub_toc(file_path: &str) -> Result<Vec<TocEntry>, OmniReaderError> {
    let doc = EpubDoc::new(file_path).map_err(|e| OmniReaderError::ParseError {
        message: format!("Failed to open EPUB: {}", e),
    })?;

    let toc: Vec<TocEntry> = doc
        .toc
        .iter()
        .enumerate()
        .map(|(idx, nav_point)| TocEntry {
            index: idx as u32,
            title: nav_point.label.clone(),
            path: nav_point.content.to_string_lossy().to_string(),
        })
        .collect();

    Ok(toc)
}

/// Get chapter content by index (0-based, from spine)
#[uniffi::export]
pub fn get_epub_chapter(
    file_path: &str,
    chapter_index: u32,
) -> Result<EpubChapter, OmniReaderError> {
    let mut doc = EpubDoc::new(file_path).map_err(|e| OmniReaderError::ParseError {
        message: format!("Failed to open EPUB: {}", e),
    })?;

    let num_chapters = doc.get_num_chapters();
    if chapter_index >= num_chapters as u32 {
        return Err(OmniReaderError::ParseError {
            message: format!(
                "Chapter {} out of range (total: {})",
                chapter_index, num_chapters
            ),
        });
    }

    // Navigate to the chapter
    doc.set_current_chapter(chapter_index as usize);

    // Get chapter content - returns Option<(String, String)>
    let (content, _path) = doc
        .get_current_str()
        .ok_or_else(|| OmniReaderError::ParseError {
            message: "Failed to read chapter content".to_string(),
        })?;

    // Try to get chapter title from TOC
    let title = doc
        .toc
        .get(chapter_index as usize)
        .map(|nav| nav.label.clone())
        .unwrap_or_else(|| format!("Chapter {}", chapter_index + 1));

    Ok(EpubChapter {
        index: chapter_index,
        title,
        content,
    })
}

/// Get total number of chapters (spine items)
#[uniffi::export]
pub fn get_epub_chapter_count(file_path: &str) -> Result<u32, OmniReaderError> {
    let doc = EpubDoc::new(file_path).map_err(|e| OmniReaderError::ParseError {
        message: format!("Failed to open EPUB: {}", e),
    })?;

    Ok(doc.get_num_chapters() as u32)
}

/// Get EPUB cover image data
#[uniffi::export]
pub fn get_epub_cover(file_path: &str) -> Result<Option<Vec<u8>>, OmniReaderError> {
    let mut doc = EpubDoc::new(file_path).map_err(|e| OmniReaderError::ParseError {
        message: format!("Failed to open EPUB: {}", e),
    })?;

    Ok(doc.get_cover().map(|(data, _mime)| data))
}
