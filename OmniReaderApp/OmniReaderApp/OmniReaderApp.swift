import SwiftUI

/// Main entry point for OmniReader macOS app
@main
struct OmniReaderApp: App {
    @StateObject private var libraryViewModel = LibraryViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryViewModel)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Book...") {
                    libraryViewModel.showImportPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
