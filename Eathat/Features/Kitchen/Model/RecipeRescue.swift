import Foundation

/// What a recipe saves from the bin: its ingredients that are in the kitchen and expire within the week.
enum RecipeRescue {
    /// The days ahead that count as "soon": the timeline's week.
    static let soon = StockTimeline.horizon - 1

    /// The stock lines a recipe would use up that expire soon, most urgent first.
    static func rescued(_ recipe: Recipe, lineFor: (Recipe.Ingredient) -> StockLine?) -> [StockLine] {
        recipe.ingredients
            .compactMap(lineFor)
            .filter { ($0.daysLeft ?? .max) <= soon }
            .reduce(into: [StockLine]()) { lines, line in
                if !lines.contains(where: { $0.id == line.id }) { lines.append(line) }
            }
            .sorted { ($0.daysLeft ?? .max) < ($1.daysLeft ?? .max) }
    }

    /// How urgent cooking it is: each rescued line weighs more the sooner it expires (past dates weigh most).
    static func score(_ rescued: [StockLine]) -> Int {
        rescued.reduce(0) { total, line in total + max(1, soon + 1 - max(line.daysLeft ?? soon, 0)) }
    }

    /// Recipes in the order to cook them: those that save the most urgent food first, then the newest.
    static func byUrgency(_ recipes: [Recipe], lineFor: (Recipe.Ingredient) -> StockLine?) -> [Recipe] {
        let scores = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, score(rescued($0, lineFor: lineFor))) })
        return recipes.enumerated()
            .sorted { lhs, rhs in
                let left = scores[lhs.element.id] ?? 0
                let right = scores[rhs.element.id] ?? 0
                return left != right ? left > right : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

extension Recipe {
    /// What the recipe calls a stock line ("Lait"), rather than the product's full name ("Lait demi-écrémé GrandLait").
    func ingredientName(for line: StockLine) -> String {
        ingredients.first { $0.productId == line.productId }?.name ?? line.name
    }
}
