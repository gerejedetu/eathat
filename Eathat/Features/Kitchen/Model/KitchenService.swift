import Foundation

/// The kitchen as the API keeps it: stock, quick actions, recipes, meals.
nonisolated protocol KitchenService: Sendable {
    func stock() async throws -> [StockLine]
    /// Applies `action` to line `id` and returns the line as it now is.
    func perform(_ action: StockAction, on id: Int) async throws -> StockLine
    func recipes() async throws -> [Recipe]
    /// Logs a meal of `recipeId` and takes its ingredients off the stock.
    func cook(recipeId: Int) async throws -> CookedMeal
    /// The meals already cooked, newest first.
    func meals() async throws -> [EatenMeal]
    /// The user's preferences, by key, as Claude keeps them.
    func preferences() async throws -> [String: String]
    /// The meals planned from today for a week.
    func plan() async throws -> [PlannedMeal]
    func addToPlan(day: String, slot: MealSlot, recipeId: Int) async throws -> PlannedMeal
    func removeFromPlan(id: Int) async throws
}

/// `KitchenService` over the Worker's REST API (`/v1`).
nonisolated struct APIKitchenService: KitchenService {
    let client: any HTTPClient

    private struct StockAnswer: Decodable {
        let items: [StockLine]
    }

    private struct RecipesAnswer: Decodable {
        let recipes: [Recipe]
    }

    private struct PreferencesAnswer: Decodable {
        let preferences: [String: String]
    }

    private struct PlanAnswer: Decodable {
        let meals: [PlannedMeal]
    }

    private struct MealsAnswer: Decodable {
        let meals: [EatenMeal]
    }

    private struct PlanRequest: Encodable {
        let day: String
        let slot: MealSlot
        let recipeId: Int
    }

    private struct Removed: Decodable {
        let removed: Bool
    }

    func stock() async throws -> [StockLine] {
        try await get(StockAnswer.self, .get("v1/stock")).items
    }

    func perform(_ action: StockAction, on id: Int) async throws -> StockLine {
        let body = try JSONEncoder().encode(action.payload)
        return try await get(StockLine.self, .post("v1/stock/\(id)/\(action.pathComponent)", body: body))
    }

    func recipes() async throws -> [Recipe] {
        try await get(RecipesAnswer.self, .get("v1/recipes")).recipes
    }

    func cook(recipeId: Int) async throws -> CookedMeal {
        try await get(CookedMeal.self, .post("v1/recipes/\(recipeId)/cooked"))
    }

    func meals() async throws -> [EatenMeal] {
        try await get(MealsAnswer.self, .get("v1/meals")).meals
    }

    func preferences() async throws -> [String: String] {
        try await get(PreferencesAnswer.self, .get("v1/preferences")).preferences
    }

    func plan() async throws -> [PlannedMeal] {
        try await get(PlanAnswer.self, .get("v1/plan")).meals
    }

    func addToPlan(day: String, slot: MealSlot, recipeId: Int) async throws -> PlannedMeal {
        let body = try JSONEncoder().encode(PlanRequest(day: day, slot: slot, recipeId: recipeId))
        return try await get(PlannedMeal.self, .post("v1/plan", body: body))
    }

    func removeFromPlan(id: Int) async throws {
        _ = try await get(Removed.self, .delete("v1/plan/\(id)"))
    }

    private func get<Answer: Decodable>(_ type: Answer.Type, _ request: HTTPRequest) async throws -> Answer {
        try JSONDecoder().decode(type, from: try await client.send(request))
    }
}
