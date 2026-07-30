import AppKit

// Injecting ⌘V while the user is still physically holding the hotkey's
// modifiers is what lets the real and the synthetic keystroke merge, which is
// how a modifier ends up stuck down. Wait for the keyboard to be idle first,
// but never wait so long that the paste simply never happens.
enum PasteKeystrokeGate {
    static let timeout: TimeInterval = 0.6

    private static let blocking: NSEvent.ModifierFlags = [.command, .shift, .control, .option]

    static func shouldPost(flags: NSEvent.ModifierFlags, waited: TimeInterval) -> Bool {
        flags.intersection(blocking).isEmpty || waited >= timeout
    }
}
