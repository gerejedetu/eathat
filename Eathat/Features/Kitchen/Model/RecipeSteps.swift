import Foundation

/// A recipe's markdown steps as a list: one entry per numbered or bulleted line, the number or bullet dropped.
/// Lines that continue a step are joined to it; a recipe without numbers is one step per paragraph.
enum RecipeSteps {
    static func parse(_ markdown: String) -> [String] {
        var steps: [String] = []
        var startsNew = true
        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else {
                startsNew = true
                continue
            }
            if let text = stripMarker(line) {
                steps.append(text)
                startsNew = false
            } else if startsNew || steps.isEmpty {
                steps.append(line)
                startsNew = false
            } else {
                steps[steps.count - 1] += " " + line
            }
        }
        return steps
    }

    /// The text after "1. ", "2) ", "- " or "* ", or nil when the line has no marker.
    private static func stripMarker(_ line: String) -> String? {
        if let match = line.firstMatch(of: /^\d+[.)]\s+(.+)$/) { return String(match.1) }
        if let match = line.firstMatch(of: /^[-*•]\s+(.+)$/) { return String(match.1) }
        return nil
    }
}

extension RecipeSteps {
    /// A piece of a step, as Crouton colours them: ingredient names in blue, times in amber, temperatures in orange.
    struct Piece: Equatable {
        enum Kind: Equatable {
            case plain
            case ingredient
            case time
            case temperature
        }

        let text: String
        let kind: Kind

        var isIngredient: Bool { kind == .ingredient }
    }

    /// Splits a step into coloured pieces. Ingredient names match whole words, case and accents aside, plural or
    /// singular; times are "10 min", "10-12 minutes", "1 h"; temperatures are "180 °C", "180°".
    static func pieces(of step: String, ingredients names: [String]) -> [Piece] {
        let characters = Array(fold(step))
        var kinds = [Piece.Kind](repeating: .plain, count: characters.count)
        mark(&kinds, ranges: patternRanges(step, Self.temperature), as: .temperature)
        mark(&kinds, ranges: patternRanges(step, Self.duration), as: .time)
        for key in keys(names) {
            let pattern = Array(key)
            var index = 0
            while index + pattern.count <= characters.count {
                if kinds[index] == .plain, isWord(characters, at: index, length: pattern.count),
                   Array(characters[index..<index + pattern.count]) == pattern {
                    mark(&kinds, ranges: [index..<index + pattern.count], as: .ingredient)
                    index += pattern.count
                } else {
                    index += 1
                }
            }
        }
        return group(Array(step), kinds: kinds)
    }

    private static let duration = /\d+(\s?[-–à]\s?\d+)?\s?(minutes?|min|heures?|h)\b/
    private static let temperature = /\d+\s?°\s?C?/

    private static func keys(_ names: [String]) -> [String] {
        names
            .flatMap { name -> [String] in
                let folded = fold(name)
                return folded.hasSuffix("s") ? [folded, String(folded.dropLast())] : [folded]
            }
            .filter { $0.count >= 3 }
            .sorted { $0.count > $1.count }
    }

    /// Where `regex` matches in `text`, as character offsets.
    private static func patternRanges(_ text: String, _ regex: some RegexComponent) -> [Range<Int>] {
        text.matches(of: regex).map { match in
            let start = text.distance(from: text.startIndex, to: match.range.lowerBound)
            return start..<(start + text[match.range].count)
        }
    }

    private static func mark(_ kinds: inout [Piece.Kind], ranges: [Range<Int>], as kind: Piece.Kind) {
        for range in ranges {
            for index in range where index < kinds.count && kinds[index] == .plain { kinds[index] = kind }
        }
    }

    /// Whether `length` characters at `start` make a whole word, a plural "s" allowed after it.
    private static func isWord(_ characters: [Character], at start: Int, length: Int) -> Bool {
        let isLetter = { (index: Int) in index >= 0 && index < characters.count && characters[index].isLetter }
        guard !isLetter(start - 1) else { return false }
        let end = start + length
        return !isLetter(end) || (characters[end] == "s" && !isLetter(end + 1))
    }

    /// Lower case without accents, one character for one, so positions match the original text.
    static func fold(_ text: String) -> String {
        let french = Locale(identifier: "fr_FR")
        return String(text.lowercased().map { character in
            String(character).folding(options: .diacriticInsensitive, locale: french).first ?? character
        })
    }

    private static func group(_ characters: [Character], kinds: [Piece.Kind]) -> [Piece] {
        var pieces: [Piece] = []
        var current = ""
        var currentKind = kinds.first ?? .plain
        for (character, kind) in zip(characters, kinds) {
            if kind != currentKind, !current.isEmpty {
                pieces.append(Piece(text: current, kind: currentKind))
                current = ""
            }
            currentKind = kind
            current.append(character)
        }
        if !current.isEmpty { pieces.append(Piece(text: current, kind: currentKind)) }
        return pieces
    }
}

/// The search field of the recipe list: a recipe matches when its title or one of its ingredients contains
/// every word typed, accents and case aside.
enum RecipeSearch {
    static func filter(_ recipes: [Recipe], query: String) -> [Recipe] {
        let words = RecipeSteps.fold(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return recipes }
        return recipes.filter { recipe in
            let text = RecipeSteps.fold(([recipe.title] + recipe.ingredients.map(\.name)).joined(separator: " "))
            return words.allSatisfy { text.contains($0) }
        }
    }
}

/// A recipe's colour, from its main food, for the tile that stands in for a photo.
enum RecipeTone: Sendable {
    case wheat
    case garden
    case tomato
    case dairy

    static func of(emoji: String) -> Self {
        switch emoji {
        case "🥖", "🍞", "🥣", "🍚", "🥔", "🌾", "🍌", "🍫": .wheat
        case "🍝", "🍅", "🫑", "🍲", "🫘", "🥕": .tomato
        case "🧀", "🥛", "🥚", "🧈": .dairy
        default: .garden
        }
    }
}
