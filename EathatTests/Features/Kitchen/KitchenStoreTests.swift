@testable import Eathat
import Foundation
import Testing

@Suite("Kitchen store")
struct KitchenStoreTests {
    @Test("loads the stock and the recipes")
    func loads() async {
        let service = FakeKitchenService(lines: [.sample(id: 1), .sample(id: 2)], recipes: [.sample()])
        let store = KitchenStore(service: service)
        await store.load()
        #expect(store.phase == .loaded)
        #expect(store.lines.count == 2)
        #expect(store.recipes.count == 1)
    }

    @Test("a failed load says why")
    func loadFails() async {
        let store = KitchenStore(service: await FakeKitchenService().failing())
        await store.load()
        #expect(store.phase == .failed("Hors ligne"))
    }

    @Test("the timeline follows the chosen place")
    func timeline() async {
        let lines: [StockLine] = [.sample(id: 1, location: .frigo), .sample(id: 2, location: .placard)]
        let store = KitchenStore(service: FakeKitchenService(lines: lines))
        await store.load()
        store.location = .frigo
        #expect(store.timeline.flatMap(\.lines).map(\.id) == [1])
    }

    @Test("an action puts the line's new state in place")
    func performUpdates() async {
        let service = FakeKitchenService(lines: [.sample(id: 1, location: .placard)])
        await service.setResult(.sample(id: 1, location: .congelateur, daysLeft: 90))
        let store = KitchenStore(service: service)
        await store.load()
        await store.perform(.move(.congelateur), on: store.lines[0])
        #expect(store.lines.first?.location == .congelateur)
        #expect(await service.performed.map(\.1) == [1])
    }

    @Test("a finished line leaves the list")
    func performRemoves() async {
        let service = FakeKitchenService(lines: [.sample(id: 1), .sample(id: 2)])
        await service.setResult(.sample(id: 1, status: .fini))
        let store = KitchenStore(service: service)
        await store.load()
        await store.perform(.consume(quantity: nil), on: store.lines[0])
        #expect(store.lines.map(\.id) == [2])
    }

    @Test("a failed action keeps the line and says why")
    func performFails() async {
        let service = FakeKitchenService(lines: [.sample(id: 1)])
        let store = KitchenStore(service: service)
        await store.load()
        await service.setFails(true)
        await store.perform(.open, on: store.lines[0])
        #expect(store.lines.map(\.id) == [1])
        #expect(store.actionError == "Hors ligne")
    }

    @Test("cooking logs the meal and reloads the stock")
    func cooks() async {
        let service = FakeKitchenService(lines: [.sample(id: 1)], recipes: [.sample(id: 7)])
        let store = KitchenStore(service: service)
        await store.load()
        await service.setLines([])
        let meal = await store.cook(store.recipes[0])
        #expect(meal != nil)
        #expect(await service.cooked == [7])
        #expect(store.lines.isEmpty)
    }

    @Test("an ingredient comes from its product's line that expires first")
    func stockLineForIngredient() async {
        let lines: [StockLine] = [
            .sample(id: 1, productId: 13, daysLeft: 30),
            .sample(id: 2, productId: 13, daysLeft: 4),
            .sample(id: 3, productId: 9, daysLeft: 1),
        ]
        let store = KitchenStore(service: FakeKitchenService(lines: lines))
        await store.load()
        #expect(store.stockLine(for: .sample(productId: 13))?.id == 2)
        #expect(store.stockLine(for: .sample(productId: 42)) == nil)
        #expect(store.stockLine(for: .sample(productId: nil)) == nil)
    }

    @Test("counts a recipe's ingredients in stock")
    func inStockCount() async {
        let ingredients: [Recipe.Ingredient] = [.sample(productId: 13), .sample(productId: 42), .sample(productId: nil)]
        let recipe = Recipe.sample(ingredients: ingredients)
        let store = KitchenStore(service: FakeKitchenService(lines: [.sample(id: 1, productId: 13)], recipes: [recipe]))
        await store.load()
        #expect(store.inStockCount(for: recipe) == 1)
        #expect(store.recipe(id: recipe.id) == recipe)
    }

    @Test("loads the preferences, labelled and in order, and keeps the stock when they fail")
    func preferences() async {
        let service = FakeKitchenService(lines: [.sample(id: 1)])
        await service.setPreferences(["regime": "Végétarien", "aime": "Pâtes", "zz_autre": "x"])
        let store = KitchenStore(service: service)
        await store.load()
        #expect(store.preferences.map(\.label) == ["Aime", "Régime", "Zz autre"])
        #expect(store.preferences.map(\.value) == ["Pâtes", "Végétarien", "x"])

        let offline = KitchenStore(service: FakeKitchenService(lines: [.sample(id: 1)], preferencesFail: true))
        await offline.load()
        #expect(offline.phase == .loaded)
        #expect(offline.preferences.isEmpty)
    }

    @Test("one action on several lines, each in turn")
    func performAll() async {
        let service = FakeKitchenService(lines: [.sample(id: 1), .sample(id: 2), .sample(id: 3)])
        await service.setResult(.sample(id: 1, status: .fini))
        await service.setResult(.sample(id: 3, status: .fini))
        let store = KitchenStore(service: service)
        await store.load()
        await store.perform(.consume(quantity: nil), onAll: [store.lines[0], store.lines[2]])
        #expect(store.lines.map(\.id) == [2])
        #expect(await service.performed.map(\.1) == [1, 3])
    }

    @Test("loads the plan into the week, adds a meal and takes meals off")
    func plan() async {
        let today = KitchenDay.string(from: .now)
        let service = FakeKitchenService(recipes: [.sample(id: 7)])
        await service.setMeals([.sample(id: 1, day: today)])
        let store = KitchenStore(service: service)
        await store.load()
        #expect(store.week.first?.meals.map(\.id) == [1])

        await store.addToPlan(store.recipes[0], day: today, slot: .midi)
        #expect(store.week.first?.bySlot.map(\.slot) == [.midi, .soir])

        await store.removeFromPlan(store.plan)
        #expect(store.plan.isEmpty)
        #expect(await service.removed.count == 2)
    }

    @Test("a failed plan change says why")
    func planFails() async {
        let service = FakeKitchenService(recipes: [.sample(id: 7)])
        let store = KitchenStore(service: service)
        await store.load()
        await service.setFails(true)
        await store.addToPlan(store.recipes[0], day: "2026-11-16", slot: .soir)
        #expect(store.plan.isEmpty)
        #expect(store.actionError == "Hors ligne")
    }
}
