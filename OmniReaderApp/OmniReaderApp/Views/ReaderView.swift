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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // Render HTML content
                HTMLContentView(html: chapterContent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(40)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            loadChapter()
        }
        .onChange(of: currentPage) { _, _ in
            loadChapter()
        }
    }
    
    private func loadChapter() {
        // TODO: Load chapter content from Rust core
        // For now, show placeholder
        chapterContent = """
        <html>
        <head>
            <style>
                body { font-family: Georgia, serif; font-size: 18px; line-height: 1.6; }
                h1, h2, h3 { font-family: -apple-system, sans-serif; }
            </style>
        </head>
        <body>
            <h1>Chapter \(currentPage)</h1>
            <p>EPUB content will be loaded here once UniFFI bindings are connected.</p>
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
