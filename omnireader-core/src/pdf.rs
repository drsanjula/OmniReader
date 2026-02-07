//! PDF parsing and rendering using pdfium-render
//!
//! Uses statically linked PDFium library via the `static` feature.

use crate::book::BookMetadata;
use crate::error::OmniReaderError;
use pdfium_render::prelude::*;
use std::path::Path;

/// Get a Pdfium instance - uses statically linked library
fn get_pdfium() -> Result<Pdfium, OmniReaderError> {
    let bindings =
        Pdfium::bind_to_statically_linked_library().map_err(|e| OmniReaderError::ParseError {
            message: format!("Failed to bind to PDFium: {}", e),
        })?;
    Ok(Pdfium::new(bindings))
}

/// Extract metadata from a PDF file
pub fn extract_pdf_metadata(file_path: &str) -> Result<BookMetadata, OmniReaderError> {
    let path = Path::new(file_path);
    if !path.exists() {
        return Err(OmniReaderError::FileNotFound {
            path: file_path.to_string(),
        });
    }

    let pdfium = get_pdfium()?;

    let document =
        pdfium
            .load_pdf_from_file(file_path, None)
            .map_err(|e| OmniReaderError::ParseError {
                message: format!("Failed to load PDF: {}", e),
            })?;

    let metadata = document.metadata();

    // Extract title - get() returns Option<PdfDocumentMetadataTagValue>
    let title = metadata
        .get(PdfDocumentMetadataTagType::Title)
        .map(|v| v.value().to_string())
        .or_else(|| {
            // Fallback to filename
            path.file_stem()
                .and_then(|s| s.to_str())
                .map(|s| s.to_string())
        });

    // Extract author
    let author = metadata
        .get(PdfDocumentMetadataTagType::Author)
        .map(|v| v.value().to_string());

    // Get page count
    let total_pages = document.pages().len() as u32;

    // Extract cover (first page as thumbnail) - inline to avoid lifetime issues
    let cover_data = {
        let pages = document.pages();
        if let Ok(page) = pages.get(0) {
            render_page_to_png(&page, 300).ok()
        } else {
            None
        }
    };

    Ok(BookMetadata {
        title,
        author,
        cover_data,
        total_pages,
    })
}

/// Render a PDF page to PNG data
pub fn render_pdf_page(
    file_path: &str,
    page_number: u32,
    width: u32,
) -> Result<Vec<u8>, OmniReaderError> {
    let pdfium = get_pdfium()?;

    let document =
        pdfium
            .load_pdf_from_file(file_path, None)
            .map_err(|e| OmniReaderError::ParseError {
                message: format!("Failed to load PDF: {}", e),
            })?;

    let pages = document.pages();
    if page_number >= pages.len() as u32 {
        return Err(OmniReaderError::ParseError {
            message: format!("Page {} out of range (total: {})", page_number, pages.len()),
        });
    }

    let page = pages
        .get(page_number as u16)
        .map_err(|e| OmniReaderError::ParseError {
            message: format!("Failed to get page: {}", e),
        })?;

    render_page_to_png(&page, width)
}

/// Get PDF page count
pub fn get_pdf_page_count(file_path: &str) -> Result<u32, OmniReaderError> {
    let pdfium = get_pdfium()?;

    let document =
        pdfium
            .load_pdf_from_file(file_path, None)
            .map_err(|e| OmniReaderError::ParseError {
                message: format!("Failed to load PDF: {}", e),
            })?;

    Ok(document.pages().len() as u32)
}

/// Render a page to PNG bytes
fn render_page_to_png(page: &PdfPage, width: u32) -> Result<Vec<u8>, OmniReaderError> {
    // Calculate height based on aspect ratio
    let aspect_ratio = page.height().value / page.width().value;
    let height = (width as f32 * aspect_ratio) as i32;

    // Render to bitmap
    let config = PdfRenderConfig::new()
        .set_target_width(width as i32)
        .set_target_height(height);

    let bitmap = page
        .render_with_config(&config)
        .map_err(|e| OmniReaderError::ParseError {
            message: format!("Failed to render page: {}", e),
        })?;

    // Convert to PNG bytes using the image crate
    let image_buf = bitmap.as_image();
    let mut png_data = Vec::new();

    use std::io::Cursor;
    image_buf
        .write_to(&mut Cursor::new(&mut png_data), image::ImageFormat::Png)
        .map_err(|e| OmniReaderError::ParseError {
            message: format!("Failed to encode PNG: {}", e),
        })?;

    Ok(png_data)
}
