@testable import Eathat
import Testing

@Suite("Recipe search and highlights")
struct RecipeSearchTests {
    private var recipes: [Recipe] {
        var pasta = Recipe.sample(id: 1, ingredients: [Recipe.Ingredient(name: "Courgettes", optional: false)])
        pasta.title = "Penne aux courgettes"
        var bread = Recipe.sample(id: 2, ingredients: [Recipe.Ingredient(name: "Œufs", optional: false)])
        bread.title = "Pain perdu"
        return [pasta, bread]
    }

    @Test("finds by title or ingredient, accents and case aside")
    func search() {
        #expect(RecipeSearch.filter(recipes, query: "PAIN").map(\.id) == [2])
        #expect(RecipeSearch.filter(recipes, query: "courgette").map(\.id) == [1])
        #expect(RecipeSearch.filter(recipes, query: "").map(\.id) == [1, 2])
        let none = RecipeSearch.filter(recipes, query: "pain courgette")
        #expect(none.isEmpty)
    }

    @Test("ingredient names in a step are found, plural or not")
    func pieces() {
        let step = "Faire revenir la courgette et l'Oignon."
        let pieces = RecipeSteps.pieces(of: step, ingredients: ["Courgettes", "Oignon"])
        #expect(pieces.filter(\.isIngredient).map(\.text) == ["courgette", "Oignon"])
        #expect(pieces.map(\.text).joined() == "Faire revenir la courgette et l'Oignon.")
    }

    @Test("a name inside another word is left alone")
    func wholeWords() {
        #expect(RecipeSteps.pieces(of: "Saler selon le goût.", ingredients: ["Sel"]).allSatisfy { !$0.isIngredient })
    }

    @Test("tile colours follow the main food")
    func tones() {
        #expect(RecipeTone.of(emoji: "🍝") == .tomato)
        #expect(RecipeTone.of(emoji: "🍞") == .wheat)
        #expect(RecipeTone.of(emoji: "🥒") == .garden)
    }
}

@Suite("Crouton colours and scaling")
struct CroutonDetailTests {
    @Test("times and temperatures are picked out too")
    func timesAndTemperatures() {
        let step = "Cuire 10-12 minutes à 180 °C, puis laisser 5 min avec le beurre."
        let pieces = RecipeSteps.pieces(of: step, ingredients: ["Beurre"])
        #expect(pieces.filter { $0.kind == .time }.map(\.text) == ["10-12 minutes", "5 min"])
        #expect(pieces.filter { $0.kind == .temperature }.map(\.text) == ["180 °C"])
        #expect(pieces.filter { $0.kind == .ingredient }.map(\.text) == ["beurre"])
        #expect(pieces.map(\.text).joined() == step)
    }

    @Test("Scale multiplies amounts and leaves words alone")
    func scale() {
        let penne = Recipe.Ingredient(name: "Penne", quantity: 250, unit: "g", optional: false)
        let salt = Recipe.Ingredient(name: "Sel", quantityText: "1 pincée", optional: false)
        #expect(penne.amount(scaledBy: 2) == "500 g")
        #expect(penne.amount(scaledBy: 0.5) == "125 g")
        #expect(salt.amount(scaledBy: 2) == "1 pincée")
    }
}
