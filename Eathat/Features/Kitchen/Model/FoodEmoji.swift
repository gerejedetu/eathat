import Foundation

/// An emoji for a food, from words in its name, else from its category: the picture each stock line wears.
nonisolated enum FoodEmoji {
    /// The word met first in the name wins ("Penne aux courgettes" is pasta); on the same spot, the earlier entry
    /// here wins, so "pain de mie" is sliced bread before it is "pain".
    private static let byWord: [(String, String)] = [
        ("pain de mie", "🍞"), ("baguette", "🥖"), ("pain", "🍞"),
        ("cereale", "🥣"), ("flakes", "🥣"),
        ("tartiner", "🍫"), ("nutella", "🍫"), ("chocolat", "🍫"),
        ("lait", "🥛"), ("yaourt", "🥛"), ("creme", "🥛"),
        ("emmental", "🧀"), ("mozzarella", "🧀"), ("fromage", "🧀"), ("comte", "🧀"),
        ("beurre", "🧈"), ("oeuf", "🥚"),
        ("tomate", "🍅"), ("haricot", "🫘"), ("lentille", "🫘"), ("pois chiche", "🫘"),
        ("penne", "🍝"), ("spaghetti", "🍝"), ("pates", "🍝"), ("riz", "🍚"),
        ("ail", "🧄"), ("oignon", "🧅"), ("poivron", "🫑"), ("aubergine", "🍆"),
        ("carotte", "🥕"), ("courgette", "🥒"), ("concombre", "🥒"), ("pomme de terre", "🥔"), ("pommes de terre", "🥔"),
        ("salade", "🥬"), ("epinard", "🥬"), ("champignon", "🍄"),
        ("banane", "🍌"), ("pomme", "🍎"), ("orange", "🍊"), ("citron", "🍋"), ("fraise", "🍓"),
        ("bouillon", "🍲"), ("soupe", "🍲"), ("thon", "🐟"), ("saumon", "🐟"), ("poisson", "🐟"),
        ("poulet", "🍗"), ("sel", "🧂"), ("poivre", "🧂"), ("huile", "🫒"), ("sucre", "🍯"),
        ("eau", "💧"), ("jus", "🧃"), ("cafe", "☕️"), ("the", "🍵"),
    ]

    private static let byCategory: [String: String] = [
        "frais": "🧊", "legumes": "🥬", "fruits": "🍎", "feculents": "🌾", "epicerie": "🥫",
        "pain": "🥖", "boissons": "🥤", "petit_dej": "🥣", "viande": "🍗", "poisson": "🐟", "surgeles": "❄️",
    ]

    static func emoji(name: String, category: String? = nil) -> String {
        let folded = fold(name)
        let words = " \(folded) "
        let found = byWord.compactMap { word, emoji -> (offset: Int, emoji: String)? in
            guard let range = words.range(of: " \(word)") else { return nil }
            return (words.distance(from: words.startIndex, to: range.lowerBound), emoji)
        }
        if let first = found.min(by: { $0.offset < $1.offset }) { return first.emoji }
        return category.flatMap { byCategory[fold($0)] } ?? "🍽️"
    }

    /// Lower case, no accents, no ligatures, punctuation as spaces: "Œufs frais" → "oeufs frais".
    private static func fold(_ text: String) -> String {
        text.lowercased()
            .replacing("œ", with: "oe")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .map { $0.isLetter || $0 == "_" ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
    }
}
