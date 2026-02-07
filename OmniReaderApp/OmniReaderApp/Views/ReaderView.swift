import SwiftUI
import PDFKit

/// Reader view that displays PDF or EPUB content
struct ReaderView: View {
    let book: Book
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    
    var body: some View {
        VStack(spacing: 0) {
            // Reader content
            Group {
                switch book.fileType {
                case .pdf:
                    PDFReaderView(book: book, currentPage: $currentPage, totalPages: $totalPages)
                case .epub:
                    EPUBReaderView(book: book, currentPage: $currentPage, totalPages: $totalPages)
                }
            }
            
            // Navigation bar
            ReaderNavigationBar(
                currentPage: currentPage,
                totalPages: totalPages,
                onPrevious: { if currentPage > 1 { currentPage -= 1 } },
                onNext: { if currentPage < totalPages { currentPage += 1 } }
            )
        }
        .navigationTitle(book.title)
    }
}

/// PDF reader using PDFKit
struct PDFReaderView: NSViewRepresentable {
    let book: Book
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    
    class Coordinator: NSObject {
        var parent: PDFReaderView
        var observation: NSObjectProtocol?
        
        init(parent: PDFReaderView) {
            self.parent = parent
        }
        
        deinit {
            if let observation = observation {
                NotificationCenter.default.removeObserver(observation)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        
        if let document = PDFDocument(url: URL(fileURLWithPath: book.filePath)) {
            pdfView.document = document
            Task { @MainActor in
                totalPages = document.pageCount
            }
        }
        
        // Observe page changes using coordinator
        context.coordinator.observation = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { [weak pdfView] _ in
            guard let pdfView = pdfView,
                  let page = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: page) else { return }
            Task { @MainActor in
                context.coordinator.parent.currentPage = pageIndex + 1
            }
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
        
        if let document = pdfView.document,
           currentPage > 0,
           currentPage <= document.pageCount,
           let page = document.page(at: currentPage - 1) {
            if pdfView.currentPage != page {
                pdfView.go(to: page)
            }
        }
    }
}

/// EPUB reader using WebKit
struct EPUBReaderView: View {
    let book: Book
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @State private var chapterContent: String = ""
    @State private var chapterTitle: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !chapterTitle.isEmpty {
                        Text(chapterTitle)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    // Render HTML content
                    HTMLContentView(html: wrapHtml(chapterContent))
                        .frame(minHeight: 600)
                }
                .padding(40)
            }
            .background(Color(nsColor: .textBackgroundColor))
            
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading chapter...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .task {
            await loadChapterCount()
            await loadChapter()
        }
        .onChange(of: currentPage) { _, _ in
            Task { await loadChapter() }
        }
    }
    
    private func loadChapterCount() async {
        do {
            let count = try await RustBridge.shared.getEpubChapterCount(filePath: book.filePath)
            totalPages = Int(count)
        } catch {
            print("Failed to get chapter count: \(error)")
        }
    }
    
    private func loadChapter() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let chapter = try await RustBridge.shared.getEpubChapter(
                filePath: book.filePath,
                chapterIndex: UInt32(max(0, currentPage - 1))
            )
            chapterTitle = chapter.title
            chapterContent = chapter.content
        } catch {
            errorMessage = "Failed to load chapter: \(error.localizedDescription)"
            chapterContent = ""
        }
        
        isLoading = false
    }
    
    private func wrapHtml(_ content: String) -> String {
        // If content already has HTML structure, return as-is
        if content.lowercased().contains("<html") {
            return content
        }
        
        // Otherwise, wrap in styled HTML
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: Georgia, serif;
                    font-size: 18px;
                    line-height: 1.8;
                    color: #333;
                    max-width: 700px;
                    margin: 0 auto;
                    padding: 20px;
                }
                h1, h2, h3, h4, h5, h6 {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    line-height: 1.3;
                }
                img { max-width: 100%; height: auto; }
                a { color: #0066cc; }
                @media (prefers-color-scheme: dark) {
                    body { color: #e0e0e0; background: transparent; }
                    a { color: #4da3ff; }
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }
}

import WebKit

/// WebKit view for rendering HTML content
struct HTMLContentView: NSViewRepresentable {
    let html: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

/// Bottom navigation bar for the reader
struct ReaderNavigationBar: View {
    let currentPage: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage <= 1)
            .buttonStyle(.borderless)
            
            Spacer()
            
            Text("Page \(currentPage) of \(totalPages)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPage >= totalPages)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
