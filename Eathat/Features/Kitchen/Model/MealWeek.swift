import Foundation

/// When in the day a meal is planned: Crouton's Lunch and Dinner sections.
nonisolated enum MealSlot: String, Codable, CaseIterable, Sendable {
    case midi
    case soir

    var title: String {
        switch self {
        case .midi: "Midi"
        case .soir: "Soir"
        }
    }

    var systemImage: String {
        switch self {
        case .midi: "sun.max"
        case .soir: "fork.knife"
        }
    }
}

/// A recipe planned for a day, as the API sends it.
nonisolated struct PlannedMeal: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var day: String
    var slot: MealSlot
    var recipeId: Int
    var title: String
    var imageUrl: URL?
    var prepMinutes: Int?
}

/// The week as Crouton's Meal Plan: today and the next six days, each with its meals by slot.
enum MealWeek {
    struct Day: Identifiable, Equatable {
        /// 'YYYY-MM-DD'.
        let day: String
        /// Days from today: 0 is today.
        let offset: Int
        let meals: [PlannedMeal]

        var id: String { day }

        /// The day's meals by slot, noon first, empty slots left out.
        var bySlot: [(slot: MealSlot, meals: [PlannedMeal])] {
            MealSlot.allCases.compactMap { slot in
                let here = meals.filter { $0.slot == slot }
                return here.isEmpty ? nil : (slot, here)
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.day == rhs.day && lhs.offset == rhs.offset && lhs.meals == rhs.meals
        }
    }

    static let length = 7

    static func days(_ meals: [PlannedMeal], today: Date = .now) -> [Day] {
        (0..<length).map { offset in
            let day = KitchenDay.string(from: KitchenDay.adding(offset, to: today))
            return Day(day: day, offset: offset, meals: meals.filter { $0.day == day })
        }
    }
}
