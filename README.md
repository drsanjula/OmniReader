# OmniReader

Privacy-first, cross-platform ebook reader with Rust core and native UI.

## Features (MVP - macOS)

- 📚 **Local Library** - Import and organize your DRM-free ebooks
- 📖 **PDF & EPUB Support** - Native rendering with smooth navigation
- ✨ **Annotations** - Highlight text and add notes
- 🔒 **Privacy First** - All data stays on your device, no cloud required

## Architecture

- **Core Engine**: Rust (via UniFFI bindings)
- **macOS UI**: Native SwiftUI
- **Database**: SQLite (local storage)

## Building

### Prerequisites

- Rust 1.70+ (`rustup default stable`)
- Xcode 15+ with Swift 5.9+
- macOS 14.0+ (Sonoma)

### Build Steps

```bash
# 1. Build Rust core
cd omnireader-core
cargo build --release

# 2. Generate Swift bindings
cargo run --bin uniffi-bindgen generate \
  --library target/release/libomnireader_core.dylib \
  --language swift --out-dir ../OmniReaderApp/OmniReaderApp/Generated

# 3. Build macOS app
open OmniReaderApp/OmniReaderApp.xcodeproj
# Build and run from Xcode
```

## License

MIT License - see [LICENSE](LICENSE) for details.
