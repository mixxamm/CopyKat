import SwiftUI

@main
struct CopyCatApp: App {
    var body: some Scene {
        MenuBarExtra("CopyCat", systemImage: "doc.on.clipboard") {
            Button("Quit CopyCat") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
