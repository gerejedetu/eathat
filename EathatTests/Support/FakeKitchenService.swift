@testable import Eathat
import Foundation

/// A kitchen in memory: canned answers, and a record of what was asked.
actor FakeKitchenService: KitchenService {
    struct Failure: Error, LocalizedError {
        var errorDescription: String? { "Hors ligne" }
    }

    var lines: [StockLine]
    var savedRecipes: [Recipe]
    var fails = false
    /// What `perform` answers, by line id; the line unchanged when absent.
    var results: [Int: StockLine] = [:]
    var meal = CookedMeal(mealId: 1, recipeId: 1, taken: [], skipped: [])
    var savedPreferences: [String: String] = [:]
    var meals: [PlannedMeal] = []
    private(set) var removed: [Int] = []
    var preferencesFail = false
    private(set) var performed: [(StockAction, Int)] = []
    private(set) var cooked: [Int] = []
    private(set) var stockLoads = 0

    init(lines: [StockLine] = [], recipes: [Recipe] = [], preferencesFail: Bool = false) {
        self.lines = lines
        self.savedRecipes = recipes
        self.preferencesFail = preferencesFail
    }

    func failing() -> Self {
        fails = true
        return self
    }

    func setFails(_ value: Bool) {
        fails = value
    }

    func setResult(_ line: StockLine) {
        results[line.id] = line
    }

    func setLines(_ value: [StockLine]) {
        lines = value
    }

    func setMeals(_ value: [PlannedMeal]) {
        meals = value
    }

    func setPreferences(_ value: [String: String]) {
        savedPreferences = value
    }

    func stock() throws -> [StockLine] {
        stockLoads += 1
        if fails { throw Failure() }
        return lines
    }

    func perform(_ action: StockAction, on id: Int) throws -> StockLine {
        performed.append((action, id))
        if fails { throw Failure() }
        guard let line = results[id] ?? lines.first(where: { $0.id == id }) else { throw Failure() }
        return line
    }

    func recipes() throws -> [Recipe] {
        if fails { throw Failure() }
        return savedRecipes
    }

    func cook(recipeId: Int) throws -> CookedMeal {
        cooked.append(recipeId)
        if fails { throw Failure() }
        return meal
    }

    func preferences() throws -> [String: String] {
        if fails || preferencesFail { throw Failure() }
        return savedPreferences
    }

    func plan() throws -> [PlannedMeal] {
        if fails { throw Failure() }
        return meals
    }

    func addToPlan(day: String, slot: MealSlot, recipeId: Int) throws -> PlannedMeal {
        if fails { throw Failure() }
        let planned = PlannedMeal(id: meals.count + 100, day: day, slot: slot, recipeId: recipeId, title: "Recette")
        meals.append(planned)
        return planned
    }

    func removeFromPlan(id: Int) throws {
        if fails { throw Failure() }
        removed.append(id)
        meals.removeAll { $0.id == id }
    }
}
