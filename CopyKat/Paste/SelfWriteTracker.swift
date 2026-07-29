import Foundation

// Pasting puts the item back on the pasteboard. Without this, the monitor
// captures that write as a fresh copy and the store bumps the item to the top,
// which reads as a duplicate. Matching on content rather than on a single
// change count also covers the pasteboard changing more than once for the same
// content (Universal Clipboard echoes, apps that rewrite on paste).
@MainActor
final class SelfWriteTracker {
    private let window: TimeInterval = 5
    private var lastHash: String?
    private var writtenAt: Date?

    func record(hash: String, at date: Date = .now) {
        lastHash = hash
        writtenAt = date
    }

    func isOurOwnWrite(hash: String, at date: Date = .now) -> Bool {
        guard lastHash == hash, let writtenAt, date.timeIntervalSince(writtenAt) <= window else {
            return false
        }
        return true
    }
}
