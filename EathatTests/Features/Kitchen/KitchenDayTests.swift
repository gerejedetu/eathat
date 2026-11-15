@testable import Eathat
import Testing

@Suite("Kitchen days and recipe words")
struct KitchenDayTests {
    @Test("a day goes to a date and back")
    func roundTrip() throws {
        let date = try #require(KitchenDay.date(from: "2026-11-15"))
        #expect(KitchenDay.string(from: date) == "2026-11-15")
        #expect(KitchenDay.date(from: "pas une date") == nil)
    }

    @Test("a day reads in French")
    func label() {
        #expect(KitchenDay.label("2026-11-15").hasPrefix("15 nov"))
    }

    @Test(
        "ingredient amounts",
        arguments: [
            (Recipe.Ingredient(name: "penne", quantity: 250, unit: "g", optional: false), "250 g"),
            (Recipe.Ingredient(name: "mozza", quantity: 1, unit: "boule", optional: false), "1 boule"),
            (Recipe.Ingredient(name: "Baguette", quantity: 1, unit: "baguette", optional: false), "1"),
            (Recipe.Ingredient(name: "Œufs", quantity: 2, unit: "œuf", optional: false), "2"),
            (Recipe.Ingredient(name: "sel", quantityText: "1 pincée", optional: false), "1 pincée"),
            (Recipe.Ingredient(name: "œufs", quantity: 2, optional: false), "2"),
        ]
    )
    func amount(ingredient: Recipe.Ingredient, expected: String) {
        #expect(ingredient.amount == expected)
    }

    @Test("an ingredient without quantity has no amount")
    func noAmount() {
        #expect(Recipe.Ingredient(name: "poivre", optional: false).amount == nil)
    }

    @Test("the summary names what was taken and what was missing")
    func summary() {
        let meal = CookedMeal(
            mealId: 1,
            recipeId: 1,
            taken: [.init(inventoryId: 13, name: "Penne", quantity: 250, unit: "g")],
            skipped: [.init(name: "sel", reason: "pas lié au stock"), .init(name: "œufs", reason: "il manquait 2")]
        )
        #expect(meal.summary == "Retiré du stock : Penne (250 g).\nPas assez en stock : œufs.")
    }
}

@Suite("Recipe meta")
struct RecipeMetaTests {
    @Test("time, servings and stock coverage")
    func line() {
        let recipe = Recipe.sample(ingredients: [.sample(productId: 1), .sample(productId: 2)])
        #expect(RecipeMeta.line(recipe, inStock: 1) == "20 min · 2 pers. · 1/2 en stock")
    }
}
