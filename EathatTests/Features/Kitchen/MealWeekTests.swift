@testable import Eathat
import Foundation
import Testing

extension PlannedMeal {
    static func sample(id: Int, day: String, slot: MealSlot = .soir, recipeId: Int = 1) -> Self {
        Self(id: id, day: day, slot: slot, recipeId: recipeId, title: "Recette \(recipeId)", imageUrl: nil, prepMinutes: 20)
    }
}

@Suite("Meal week")
struct MealWeekTests {
    /// Sunday 15 November 2026, noon in Paris.
    private let sunday = KitchenDay.date(from: "2026-11-15") ?? .now

    @Test("seven days from today, empty ones too, meals outside the week left out")
    func days() {
        let meals: [PlannedMeal] = [
            .sample(id: 1, day: "2026-11-14"),
            .sample(id: 2, day: "2026-11-15"),
            .sample(id: 3, day: "2026-11-17", slot: .midi),
            .sample(id: 4, day: "2026-11-22"),
        ]
        let week = MealWeek.days(meals, today: sunday)
        #expect(week.map(\.day) == (15...21).map { "2026-11-\($0)" })
        #expect(week.map(\.offset) == Array(0..<7))
        #expect(week[0].meals.map(\.id) == [2])
        #expect(week[1].meals.isEmpty)
        #expect(week[2].meals.map(\.id) == [3])
    }

    @Test("a day's meals by slot, noon first, empty slots left out")
    func bySlot() {
        let meals: [PlannedMeal] = [
            .sample(id: 1, day: "2026-11-15", slot: .soir),
            .sample(id: 2, day: "2026-11-15", slot: .midi),
            .sample(id: 3, day: "2026-11-15", slot: .soir),
        ]
        let day = MealWeek.days(meals, today: sunday)[0]
        #expect(day.bySlot.map(\.slot) == [.midi, .soir])
        #expect(day.bySlot[1].meals.map(\.id) == [1, 3])
        #expect(MealWeek.days([], today: sunday)[0].bySlot.isEmpty)
    }
}
