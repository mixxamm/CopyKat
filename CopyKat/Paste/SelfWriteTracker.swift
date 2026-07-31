import CryptoKit
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

    // Must produce the same digest the store uses for its content hashes, or a
    // recorded write never matches the capture and the suppression silently
    // stops working. A test pins the two together.
    static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
