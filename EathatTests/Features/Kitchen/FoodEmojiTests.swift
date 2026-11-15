@testable import Eathat
import Testing

@Suite("Food emoji")
struct FoodEmojiTests {
    @Test(
        "from words in the name",
        arguments: [
            ("Pain de mie extra moelleux nature", "🍞"),
            ("Baguette", "🥖"),
            ("Œufs frais poules élevées au sol", "🥚"),
            ("Pâtes penne rigate", "🍝"),
            ("Pâte à tartiner noisettes cacao", "🍫"),
            ("Pommes de terre blanches", "🥔"),
            ("Céréales Snow Flakes", "🥣"),
            ("Eau de source plate", "💧"),
            ("Ail blanc bio", "🧄"),
            ("Penne aux courgettes et mozzarella", "🍝"),
            ("Céréales Crocks chocolat noisette", "🥣"),
        ]
    )
    func byName(name: String, expected: String) {
        #expect(FoodEmoji.emoji(name: name) == expected)
    }

    @Test("a word inside another word does not count: \"ail\" is not in \"détail\"")
    func wholeWordStart() {
        #expect(FoodEmoji.emoji(name: "Détail", category: "epicerie") == "🥫")
    }

    @Test("falls back to the category, then to a plate")
    func fallback() {
        #expect(FoodEmoji.emoji(name: "Truc", category: "legumes") == "🥬")
        #expect(FoodEmoji.emoji(name: "Truc") == "🍽️")
    }
}

@Suite("Stock line extras")
struct StockLineExtrasTests {
    @Test("what is left, as a fraction")
    func remaining() {
        var line = StockLine.sample(id: 1)
        line.initialQuantity = 4
        line.quantity = 1
        #expect(line.remainingFraction == 0.25)
        line.initialQuantity = 0
        #expect(line.remainingFraction == 0)
    }
}

@Suite("Recipe steps")
struct RecipeStepsTests {
    @Test("numbered lines become steps, continuations join them")
    func numbered() {
        let steps = RecipeSteps.parse("1. Cuire les pâtes.\n2. Couper\nles courgettes.\n\n3) Servir.")
        #expect(steps == ["Cuire les pâtes.", "Couper les courgettes.", "Servir."])
    }

    @Test("bullets and plain paragraphs work too")
    func plain() {
        #expect(RecipeSteps.parse("- Un\n- Deux") == ["Un", "Deux"])
        #expect(RecipeSteps.parse("Mélanger.\n\nServir chaud.") == ["Mélanger.", "Servir chaud."])
    }
}

@Suite("Recipe pictures and timing")
struct RecipePictureTests {
    @Test("a recipe's emoji comes from its title, else its first ingredient")
    func emoji() {
        var recipe = Recipe.sample(ingredients: [Recipe.Ingredient(name: "Courgettes", optional: false)])
        #expect(recipe.emoji == "🍝")
        recipe.title = "Poêlée du soir"
        #expect(recipe.emoji == "🥒")
    }

    @Test("timing")
    func timing() {
        #expect(RecipeMeta.timing(.sample()) == "20 min · 2 pers.")
    }
}
