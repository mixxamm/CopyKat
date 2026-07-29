import Foundation
import Fuse

// Thin wrapper around Fuse (the Fuse.js algorithm) so the rest of the app
// never touches the library directly. Lower scores are better matches; nil
// means no match within the threshold.
struct FuzzyMatcher {
    private let fuse = Fuse(threshold: 0.4)

    func score(_ query: String, in text: String) -> Double? {
        fuse.search(query, in: text)?.score
    }
}
