import Foundation
import Observation

/// The kitchen: its stock and Claude's recipes, shared by every screen.
@Observable
final class KitchenStore {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var lines: [StockLine] = []
    private(set) var recipes: [Recipe] = []
    /// The user's preferences, for Réglages; empty until they load.
    private(set) var preferences: [Preference] = []
    /// The meals planned for the week; empty until they load.
    private(set) var plan: [PlannedMeal] = []
    private(set) var phase: Phase = .idle
    /// The place the stock screen shows; nil shows them all.
    var location: StorageLocation?
    /// Why the last action failed, until the user dismisses it.
    var actionError: String?

    private let service: any KitchenService

    init(service: any KitchenService) {
        self.service = service
    }

    /// The stock in time order: past, each of the next days, later.
    var timeline: [StockTimeline.Group] {
        StockTimeline.groups(lines, location: location)
    }

    /// The next seven days and their planned meals, as Crouton's Meal Plan.
    var week: [MealWeek.Day] {
        MealWeek.days(plan)
    }

    /// The stock by place, as Crouton's Groceries list.
    var shelves: [StockShelves.Shelf] {
        StockShelves.sections(lines)
    }

    /// Loads the stock and the recipes together.
    func load() async {
        if lines.isEmpty { phase = .loading }
        do {
            async let stock = service.stock()
            async let saved = service.recipes()
            (lines, recipes) = try await (stock, saved)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
        if let values = try? await service.preferences() { preferences = Preference.list(values) }
        if let meals = try? await service.plan() { plan = meals }
    }

    /// Runs a quick action and puts the line's new state in place; a finished or thrown-away line leaves the list.
    func perform(_ action: StockAction, on line: StockLine) async {
        do {
            let updated = try await service.perform(action, on: line.id)
            if updated.isActive {
                lines = lines.map { $0.id == updated.id ? updated : $0 }
            } else {
                lines.removeAll { $0.id == updated.id }
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    /// The same action on several lines, one after the other (the Stock list's bottom bar).
    func perform(_ action: StockAction, onAll targets: [StockLine]) async {
        for line in targets {
            await perform(action, on: line)
        }
    }

    /// Plans `recipe` for `day` ('YYYY-MM-DD') at `slot`.
    func addToPlan(_ recipe: Recipe, day: String, slot: MealSlot) async {
        do {
            plan.append(try await service.addToPlan(day: day, slot: slot, recipeId: recipe.id))
        } catch {
            actionError = error.localizedDescription
        }
    }

    /// Takes meals off the plan, one after the other.
    func removeFromPlan(_ meals: [PlannedMeal]) async {
        for meal in meals {
            do {
                try await service.removeFromPlan(id: meal.id)
                plan.removeAll { $0.id == meal.id }
            } catch {
                actionError = error.localizedDescription
                return
            }
        }
    }

    /// Logs a meal of `recipe`, then reloads the stock it changed. Nil when it failed (see `actionError`).
    func cook(_ recipe: Recipe) async -> CookedMeal? {
        do {
            let meal = try await service.cook(recipeId: recipe.id)
            lines = try await service.stock()
            return meal
        } catch {
            actionError = error.localizedDescription
            return nil
        }
    }

    /// The line an ingredient would come from: the product's line that expires first. Nil when not in stock.
    func stockLine(for ingredient: Recipe.Ingredient) -> StockLine? {
        guard let productId = ingredient.productId else { return nil }
        return lines
            .filter { $0.productId == productId && $0.isActive }
            .min { ($0.daysLeft ?? .max) < ($1.daysLeft ?? .max) }
    }

    /// How many of a recipe's ingredients are in the stock right now.
    func inStockCount(for recipe: Recipe) -> Int {
        recipe.ingredients.count { stockLine(for: $0) != nil }
    }

    /// What a recipe saves: its ingredients in the kitchen that expire within the week, most urgent first.
    func rescued(by recipe: Recipe) -> [StockLine] {
        RecipeRescue.rescued(recipe) { stockLine(for: $0) }
    }

    /// The recipes, those that save the most urgent food first.
    var recipesByUrgency: [Recipe] {
        RecipeRescue.byUrgency(recipes) { stockLine(for: $0) }
    }

    func recipe(id: Recipe.ID) -> Recipe? {
        recipes.first { $0.id == id }
    }
}
