import Foundation
import FuzzyMatch

// Damerau-Levenshtein matching, so a query still finds an item when a letter is
// swapped or missing. Scores run from 0 (no match) upwards; higher is better.
struct FuzzyMatcher {
    private let matcher = FuzzyMatch.FuzzyMatcher()

    // Scored per line, best line wins. The matcher only finds a needle within
    // the first stretch of a haystack, so a word deep inside a long text (OCR
    // output most of all) would silently stop matching if scored whole.
    func score(_ query: String, in text: String) -> Double? {
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return nil }
        return Self.normalize(text)
            .split(whereSeparator: \.isNewline)
            .compactMap { matcher.score(String($0), against: needle)?.score }
            .max()
    }

    private static func normalize(_ string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
