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

    // Where to inject the keystroke.
    //
    // The HID tap behaves as if the keys were really pressed, which is the only
    // way to reach Spotlight: it takes keyboard input without ever becoming the
    // frontmost application, so anything posted to the session tap goes to the
    // app behind it instead. That is exactly the bug this pairing fixes.
    //
    // The catch is that a HID-level ⌘ merges into the system's global modifier
    // state, and if the user is still physically holding the hotkey it can stay
    // latched, which is the "cannot type anywhere until I lock the screen" bug
    // on macOS 15. Waiting for the keyboard to go idle prevents that, and the
    // gate above does the waiting. Only when the wait times out with modifiers
    // still down do we fall back to the session tap: a paste that misses
    // Spotlight is a nuisance, a keyboard that stops responding is not.
    static func tap(flags: NSEvent.ModifierFlags) -> CGEventTapLocation {
        flags.intersection(blocking).isEmpty ? .cghidEventTap : .cgAnnotatedSessionEventTap
    }
}
