import AppKit
import SwiftUI

// Screenshot mode only: a full screen sheet of the brand gradient behind the
// panel, so App Store captures show the real glass blurring a real backdrop
// instead of a cut-out window pasted onto a colour.
@MainActor
final class DemoBackdrop {
    private var window: NSWindow?

    func show() {
        guard let screen = NSScreen.main else { return }
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .normal
        window.isOpaque = true
        window.contentView = NSHostingView(rootView: DemoBackdropView())
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        self.window = window
    }
}

private struct DemoBackdropView: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.69, blue: 0.29), Color(red: 0.91, green: 0.33, blue: 0.13)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
