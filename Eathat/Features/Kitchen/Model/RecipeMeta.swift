import Foundation

enum RecipeMeta {
    /// "20 min · 2 pers. · 3/4 en stock".
    static func line(_ recipe: Recipe, inStock: Int) -> String {
        var parts = [timing(recipe)]
        if !recipe.ingredients.isEmpty { parts.append("\(inStock)/\(recipe.ingredients.count) en stock") }
        return parts.joined(separator: " · ")
    }

    /// "20 min · 2 pers.".
    static func timing(_ recipe: Recipe) -> String {
        var parts: [String] = []
        if let minutes = recipe.prepMinutes { parts.append("\(minutes) min") }
        parts.append("\(recipe.servings) pers.")
        return parts.joined(separator: " · ")
    }
}

extension Recipe {
    /// The dish's picture: from its title, else from its first ingredient.
    var emoji: String {
        let fromTitle = FoodEmoji.emoji(name: title)
        guard fromTitle == "🍽️", let first = ingredients.first else { return fromTitle }
        return FoodEmoji.emoji(name: first.name)
    }
}

extension RecipeMeta {
    /// The list's second line: "15 min · sauve baguette, lait", or "15 min · 2 pers." when it saves nothing.
    static func subtitle(_ recipe: Recipe, rescued: [StockLine]) -> String {
        guard !rescued.isEmpty else { return timing(recipe) }
        let names = rescued.prefix(3).map { recipe.ingredientName(for: $0).lowercased() }
        let time = recipe.prepMinutes.map { "\($0) min · " } ?? ""
        return time + "sauve " + names.joined(separator: ", ")
    }

    /// The recipe page's sentence: "À finir bientôt : baguette (demain), lait (dans 4 j)."
    static func rescueSentence(_ recipe: Recipe, rescued: [StockLine]) -> String? {
        guard !rescued.isEmpty else { return nil }
        let parts = rescued.map { line in
            "\(recipe.ingredientName(for: line).lowercased()) (\(StockFormat.days(line.daysLeft).lowercased()))"
        }
        return "À finir bientôt : " + parts.joined(separator: ", ") + "."
    }
}
