@testable import Eathat
import Foundation
import Testing

@Suite("Meal log")
struct MealLogTests {
    private let today = KitchenDay.date(from: "2026-11-19") ?? .now

    private func meal(_ id: Int, _ day: String, at time: String = "12:00", title: String? = "Pâtes") -> EatenMeal {
        EatenMeal(id: id, day: day, eatenAt: "\(day)T\(time):00.000Z", recipeId: title == nil ? nil : id, title: title)
    }

    @Test("groups the meals by day, newest day first and newest meal first")
    func groups() {
        let meals = [meal(1, "2026-11-17"), meal(2, "2026-11-19", at: "08:00"), meal(3, "2026-11-19", at: "19:00")]
        let days = MealLog.days(meals, today: today)
        #expect(days.map(\.day) == ["2026-11-19", "2026-11-17"])
        #expect(days.first?.meals.map(\.id) == [3, 2])
    }

    @Test("names today and yesterday, then the weekday and date")
    func titles() {
        let days = MealLog.days([meal(1, "2026-11-19"), meal(2, "2026-11-18"), meal(3, "2026-11-16")], today: today)
        #expect(days.map(\.title) == ["Aujourd'hui", "Hier", "Lundi"])
        #expect(days.map(\.date) == ["19 nov.", "18 nov.", "16 nov."])
    }

    @Test("a meal whose recipe was deleted still shows")
    func deletedRecipe() {
        #expect(meal(1, "2026-11-19", title: nil).displayTitle == "Recette supprimée")
    }

    @Test("says how many meals a day holds")
    func count() {
        let days = MealLog.days([meal(1, "2026-11-19"), meal(2, "2026-11-19")], today: today)
        #expect(days.first?.countText == "2 repas")
    }
}
