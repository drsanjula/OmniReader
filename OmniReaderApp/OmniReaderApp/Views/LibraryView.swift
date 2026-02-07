import SwiftUI

/// Library view showing all imported books in a grid
struct LibraryView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Binding var selectedBook: Book?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            if libraryViewModel.books.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(libraryViewModel.books) { book in
                        BookCoverView(book: book, isSelected: selectedBook?.id == book.id)
                            .onTapGesture {
                                selectedBook = book
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    libraryViewModel.deleteBook(book)
                                    if selectedBook?.id == book.id {
                                        selectedBook = nil
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    libraryViewModel.showImportPanel()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Import Book")
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Your Library is Empty")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Drop PDF or EPUB files here to get started")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Import Book") {
                libraryViewModel.showImportPanel()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Individual book cover view in the library grid
struct BookCoverView: View {
    let book: Book
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Cover image
            ZStack {
                if let coverData = book.coverData,
                   let nsImage = NSImage(data: coverData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Placeholder cover
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay {
                            VStack {
                                Image(systemName: book.fileType == .pdf ? "doc.text" : "book")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(book.title)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, 8)
                            }
                        }
                }
            }
            .frame(width: 150, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isSelected ? .accentColor : .black.opacity(0.2), radius: isSelected ? 8 : 4)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            )
            
            // Title
            Text(book.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 150)
            
            // Author
            if let author = book.author {
                Text(author)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

