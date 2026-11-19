@testable import Eathat
import Foundation
import Testing

@Suite("Kitchen store journal")
struct KitchenStoreJournalTests {
    private func eaten(_ id: Int) -> EatenMeal {
        let day = KitchenDay.string(from: .now)
        return EatenMeal(id: id, day: day, eatenAt: "\(day)T12:00:00Z", recipeId: 1, title: "Pâtes")
    }

    @Test("loads the meal log, by day")
    func loadsMealLog() async {
        let service = FakeKitchenService()
        await service.setEaten([eaten(4)])
        let store = KitchenStore(service: service)
        await store.load()
        #expect(store.journal.map(\.day) == [KitchenDay.string(from: .now)])
        #expect(store.journal.first?.meals.map(\.id) == [4])
    }

    @Test("cooking a recipe puts the meal in the log")
    func cookReloadsLog() async {
        let service = FakeKitchenService(recipes: [.sample()])
        let store = KitchenStore(service: service)
        await store.load()
        await service.setEaten([eaten(9)])
        _ = await store.cook(store.recipes[0])
        #expect(store.eaten.map(\.id) == [9])
    }

    @Test("a failed log load leaves the rest of the kitchen loaded")
    func logFailureIsQuiet() async {
        let store = KitchenStore(service: FakeKitchenService(recipes: [.sample()]))
        await store.load()
        #expect(store.phase == .loaded)
        #expect(store.journal.isEmpty)
    }
}
