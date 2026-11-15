#if DEBUG
import Foundation

/// A small kitchen for `#Preview`s: no network, every action answered at once.
nonisolated struct PreviewKitchenService: KitchenService {
    static let lines: [StockLine] = [
        line(1, "Baguette", .placard, daysLeft: 1, (4, "baguette")),
        line(2, "Lardons", .frigo, daysLeft: -1, (200, "g")),
        line(3, "Courgettes", .frigo, daysLeft: 6, (1000, "g")),
        line(4, "Mozzarella", .frigo, daysLeft: 13, (3, "boule 125 g")),
        line(5, "Pâtes penne rigate", .placard, daysLeft: 364, (2000, "g")),
        line(6, "Baguette", .congelateur, daysLeft: 90, (2, "baguette")),
    ]

    static let recipes: [Recipe] = [
        Recipe(
            id: 1,
            title: "Penne aux courgettes et mozzarella",
            servings: 2,
            prepMinutes: 20,
            steps: """
            1. Cuire les penne.
            2. Faire revenir les courgettes en dés.
            3. Ajouter la mozzarella hors du feu.
            """,
            tags: ["rapide", "anti-gaspi"],
            rating: nil,
            notes: nil,
            createdAt: "2026-11-14T18:00:00Z",
            ingredients: [
                .init(name: "Penne", productId: 5, quantity: 250, unit: "g", optional: false),
                .init(name: "Courgettes", productId: 3, quantity: 400, unit: "g", optional: false),
                .init(name: "Mozzarella", productId: 4, quantity: 1, unit: "boule", optional: false),
                .init(name: "Sel", quantityText: "1 pincée", optional: false),
            ]
        ),
        Recipe(
            id: 2,
            title: "Pain perdu à la vanille",
            servings: 2,
            prepMinutes: 15,
            steps: "1. Battre les œufs avec le lait.\n2. Tremper la baguette.\n3. Dorer au beurre.",
            tags: ["anti-gaspi"],
            rating: nil,
            notes: nil,
            createdAt: "2026-11-14T19:00:00Z",
            ingredients: [
                .init(name: "Baguette", productId: 1, quantity: 1, unit: "baguette", optional: false),
                .init(name: "Œufs", productId: 9, quantity: 2, unit: "œuf", optional: false),
                .init(name: "Lait", productId: 8, quantity: 25, unit: "cl", optional: false),
            ]
        ),
    ]

    private static func line(
        _ id: Int,
        _ name: String,
        _ location: StorageLocation,
        daysLeft: Int,
        _ amount: (quantity: Double, unit: String)
    ) -> StockLine {
        let (quantity, unit) = amount
        return StockLine(
            id: id, productId: id, name: name, brand: nil, category: "frais", quantity: quantity,
            initialQuantity: id == 3 ? quantity * 2 : quantity, unit: unit, location: location,
            bestBefore: "2026-11-20",
            bestBeforeIsEstimate: true, daysLeft: daysLeft, openedAt: nil, status: .dispo
        )
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
        let today = KitchenDay.string(from: .now)
        return [PlannedMeal(id: 1, day: today, slot: .soir, recipeId: 1, title: Self.recipes[0].title, prepMinutes: 20)]
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
