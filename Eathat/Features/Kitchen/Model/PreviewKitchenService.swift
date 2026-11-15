#if DEBUG
import Foundation

/// A made-up kitchen for `#Preview`s and screenshots (`-preview-kitchen`): no network, every action answered
/// at once. Photos are TheMealDB's.
nonisolated struct PreviewKitchenService: KitchenService {
    /// A line of the made-up stock.
    private struct Item {
        let name: String
        let location: StorageLocation
        let daysLeft: Int
        let quantity: Double
        let unit: String
        /// TheMealDB's ingredient name, for its packshot.
        let image: String
    }

    /// A made-up dish: its title, time, TheMealDB photo id and method.
    private struct Dish {
        let title: String
        let minutes: Int
        let photo: String
        let steps: [String]
        let ingredients: [Recipe.Ingredient]
    }

    private static let items: [Item] = [
        Item(name: "Baguette", location: .placard, daysLeft: 1, quantity: 2, unit: "baguette", image: "Bread"),
        Item(name: "Épinards frais", location: .frigo, daysLeft: 2, quantity: 300, unit: "g", image: "Spinach"),
        Item(name: "Courgettes", location: .frigo, daysLeft: 6, quantity: 1000, unit: "g", image: "Courgettes"),
        Item(name: "Mozzarella", location: .frigo, daysLeft: 9, quantity: 2, unit: "boule 125 g", image: "Mozzarella"),
        Item(name: "Œufs", location: .frigo, daysLeft: 18, quantity: 6, unit: "œuf", image: "Eggs"),
        Item(name: "Beurre doux", location: .frigo, daysLeft: 40, quantity: 250, unit: "g", image: "Butter"),
        Item(name: "Lait demi-écrémé", location: .placard, daysLeft: 70, quantity: 4, unit: "bouteille 1 L",
             image: "Milk"),
        Item(name: "Pâtes penne", location: .placard, daysLeft: 300, quantity: 1000, unit: "g", image: "Penne Rigate"),
        Item(name: "Lentilles corail", location: .placard, daysLeft: 320, quantity: 500, unit: "g", image: "Lentils"),
        Item(name: "Tomates concassées", location: .placard, daysLeft: 400, quantity: 2, unit: "boîte",
             image: "Chopped Tomatoes"),
        Item(name: "Baguette", location: .congelateur, daysLeft: 80, quantity: 1, unit: "baguette", image: "Bread"),
        Item(name: "Petits pois", location: .congelateur, daysLeft: 200, quantity: 750, unit: "g", image: "Peas"),
    ]

    private static let dishes: [Dish] = [
        Dish(title: "Penne aux courgettes et mozzarella", minutes: 20, photo: "ustsqw1468250014",
             steps: ["Cuire les penne.", "Faire revenir les courgettes en dés.",
                     "Ajouter la mozzarella hors du feu."],
             ingredients: [use("Penne", 8, 250, "g"), use("Courgettes", 3, 400, "g"),
                           use("Mozzarella", 4, 1, "boule")]),
        Dish(title: "Ratatouille du placard", minutes: 40, photo: "wrpwuu1511786491",
             steps: ["Couper les légumes.", "Les faire revenir un à un.", "Mijoter 30 minutes avec les tomates."],
             ingredients: [use("Courgettes", 3, 500, "g"), use("Tomates concassées", 10, 1, "boîte")]),
        Dish(title: "Shakshuka aux épinards", minutes: 25, photo: "g373701551450225",
             steps: ["Faire réduire les tomates.", "Ajouter les épinards.",
                     "Casser les œufs dessus, couvrir 6 minutes."],
             ingredients: [use("Tomates concassées", 10, 1, "boîte"), use("Épinards", 2, 150, "g"),
                           use("Œufs", 5, 4, "œuf")]),
        Dish(title: "Lentilles corail au tahini", minutes: 30, photo: "vpxyqt1511464175",
             steps: ["Rincer les lentilles.", "Cuire 15 minutes.", "Servir avec le tahini et du pain."],
             ingredients: [use("Lentilles corail", 9, 200, "g"), use("Baguette", 1, 1, "baguette")]),
        Dish(title: "Pancakes du dimanche", minutes: 20, photo: "rwuyqx1511383174",
             steps: ["Mélanger les œufs, le lait et la farine.", "Laisser reposer.", "Cuire au beurre."],
             ingredients: [use("Œufs", 5, 2, "œuf"), use("Lait", 7, 25, "cl"), use("Beurre", 6, 20, "g")]),
        Dish(title: "Chili de lentilles", minutes: 45, photo: "uwxqwy1483389553",
             steps: ["Faire revenir les épices.", "Ajouter lentilles et tomates.", "Mijoter 30 minutes."],
             ingredients: [use("Lentilles corail", 9, 250, "g"), use("Tomates concassées", 10, 1, "boîte")]),
    ]

    /// The planned week: which dish (1-based), how many days from today, at noon or in the evening.
    private static let week: [(dish: Int, slot: (offset: Int, MealSlot))] = [
        (1, (0, .soir)), (3, (1, .midi)), (2, (1, .soir)), (4, (2, .soir)), (5, (3, .midi)), (6, (4, .soir)),
    ]

    static let lines: [StockLine] = items.enumerated().map { index, item in
        let id = index + 1
        let name = item.image.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.image
        return StockLine(
            id: id, productId: id, name: item.name, brand: nil, category: "frais", quantity: item.quantity,
            initialQuantity: id == 3 ? item.quantity * 2 : item.quantity, unit: item.unit, location: item.location,
            bestBefore: day(in: item.daysLeft), bestBeforeIsEstimate: true, daysLeft: item.daysLeft, openedAt: nil,
            status: .dispo, imageUrl: URL(string: "https://www.themealdb.com/images/ingredients/\(name)-Small.png")
        )
    }

    static let recipes: [Recipe] = dishes.enumerated().map { index, dish in
        Recipe(
            id: index + 1, title: dish.title, servings: 2, prepMinutes: dish.minutes,
            steps: dish.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"),
            tags: ["anti-gaspi"], rating: nil, notes: nil, createdAt: "2026-11-14T18:00:00Z",
            ingredients: dish.ingredients,
            imageUrl: URL(string: "https://www.themealdb.com/images/media/meals/\(dish.photo).jpg")
        )
    }

    private static func use(_ name: String, _ productId: Int, _ quantity: Double, _ unit: String) -> Recipe.Ingredient {
        .init(name: name, productId: productId, quantity: quantity, unit: unit, optional: false)
    }

    private static func day(in days: Int) -> String {
        KitchenDay.string(from: .now.addingTimeInterval(Double(days) * 86_400))
    }

    func stock() throws -> [StockLine] { Self.lines }

    func perform(_ action: StockAction, on id: Int) throws -> StockLine {
        guard var line = Self.lines.first(where: { $0.id == id }) else {
            throw APIError.status(404, message: nil)
        }
        if case let .move(location) = action { line.location = location }
        return line
    }

    func recipes() throws -> [Recipe] { Self.recipes }

    func cook(recipeId: Int) throws -> CookedMeal {
        CookedMeal(mealId: 1, recipeId: recipeId, taken: [], skipped: [])
    }

    func plan() throws -> [PlannedMeal] {
        Self.week.enumerated().map { index, meal in
            let recipe = Self.recipes[meal.dish - 1]
            return PlannedMeal(
                id: index + 1, day: Self.day(in: meal.slot.offset), slot: meal.slot.1, recipeId: recipe.id,
                title: recipe.title, imageUrl: recipe.imageUrl, prepMinutes: recipe.prepMinutes
            )
        }
    }

    func addToPlan(day: String, slot: MealSlot, recipeId: Int) throws -> PlannedMeal {
        PlannedMeal(id: Int.random(in: 2...9999), day: day, slot: slot, recipeId: recipeId, title: "Recette")
    }

    func removeFromPlan(id _: Int) throws {}

    func preferences() throws -> [String: String] {
        ["foyer": "3 personnes", "regime": "Végétarien", "aime": "Riz, soupes, fromage"]
    }
}
#endif
