import Foundation
import FuzzyMatch

// Damerau-Levenshtein matching, so a query still finds an item when a letter is
// swapped or missing. Scores run from 0 (no match) upwards; higher is better.
struct FuzzyMatcher {
    private let matcher = FuzzyMatch.FuzzyMatcher()

    func score(_ query: String, in text: String) -> Double? {
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return nil }
        return matcher.score(Self.normalize(text), against: needle)?.score
    }

    private static func normalize(_ string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
