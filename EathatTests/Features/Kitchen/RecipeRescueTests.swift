@testable import Eathat
import Testing

@Suite("Recipe rescue")
struct RecipeRescueTests {
    private let lines: [StockLine] = [
        .sample(id: 1, productId: 27, name: "Baguette", daysLeft: 1),
        .sample(id: 2, productId: 25, name: "Courgettes", daysLeft: 6),
        .sample(id: 3, productId: 13, name: "Penne", daysLeft: 300),
    ]

    private func store(_ recipes: [Recipe]) async -> KitchenStore {
        let store = KitchenStore(service: FakeKitchenService(lines: lines, recipes: recipes))
        await store.load()
        return store
    }

    @Test("a recipe saves its ingredients that expire within the week, most urgent first")
    func rescued() async {
        let ingredients: [Recipe.Ingredient] = [.sample(productId: 13), .sample(productId: 25), .sample(productId: 27)]
        let recipe = Recipe.sample(ingredients: ingredients)
        let store = await store([recipe])
        #expect(store.rescued(by: recipe).map(\.name) == ["Baguette", "Courgettes"])
        var named = recipe
        named.ingredients[2].name = "Pain"
        #expect(named.ingredientName(for: store.rescued(by: recipe)[0]) == "Pain")
    }

    @Test("recipes that save the most urgent food come first, the rest keep their order")
    func byUrgency() async {
        let pasta = Recipe.sample(id: 1, ingredients: [.sample(productId: 13), .sample(productId: 25)])
        let bread = Recipe.sample(id: 2, ingredients: [.sample(productId: 27)])
        let rice = Recipe.sample(id: 3, ingredients: [.sample(productId: 13)])
        let store = await store([rice, pasta, bread])
        #expect(store.recipesByUrgency.map(\.id) == [2, 1, 3])
    }
}

@Suite("Recipe words")
struct RecipeWordsTests {
    private let bread = StockLine.sample(id: 1, productId: 27, name: "Baguette", daysLeft: 1)
    private let milk = StockLine.sample(id: 2, productId: 1, name: "Lait demi-écrémé GrandLait", daysLeft: 4)

    private var recipe: Recipe {
        Recipe.sample(ingredients: [
            Recipe.Ingredient(name: "Baguette", productId: 27, optional: false),
            Recipe.Ingredient(name: "Lait", productId: 1, optional: false),
        ])
    }

    @Test("the list says what a recipe saves, or its time and servings")
    func subtitle() {
        #expect(RecipeMeta.subtitle(recipe, rescued: [bread, milk]) == "20 min · sauve baguette, lait")
        #expect(RecipeMeta.subtitle(recipe, rescued: []) == "20 min · 2 pers.")
    }

    @Test("the recipe page says what to finish soon, with when")
    func sentence() {
        #expect(RecipeMeta.rescueSentence(recipe, rescued: [bread, milk])
            == "À finir bientôt : baguette (demain), lait (dans 4 j).")
        #expect(RecipeMeta.rescueSentence(recipe, rescued: []) == nil)
    }
}
