import Foundation

/// A meal already cooked, as the API's log sends it (`GET /v1/meals`).
nonisolated struct EatenMeal: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    /// The kitchen day it was eaten, 'YYYY-MM-DD' in Paris.
    var day: String
    /// When it was logged, ISO 8601 UTC.
    var eatenAt: String
    /// Nil once the recipe is deleted.
    var recipeId: Int?
    var title: String?
    var imageUrl: URL?
    var servings: Int?
    var note: String?
}

extension EatenMeal {
    var displayTitle: String {
        title ?? "Recette supprimée"
    }

    /// "12:30", in Paris time.
    var time: String? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: eatenAt) ?? ISO8601DateFormatter().date(from: eatenAt) else { return nil }
        return KitchenDay.format(date, .dateTime.hour().minute())
    }
}

/// The journal: what was eaten, day by day, the newest day first.
enum MealLog {
    struct Day: Identifiable, Equatable {
        /// 'YYYY-MM-DD'.
        let day: String
        /// "Aujourd'hui", "Hier", or the weekday ("Lundi").
        let title: String
        /// "16 nov.".
        let date: String?
        /// The newest meal first.
        let meals: [EatenMeal]

        var id: String { day }

        var countText: String {
            "\(meals.count) repas"
        }
    }

    static func days(_ meals: [EatenMeal], today: Date = .now) -> [Day] {
        let byDay = Dictionary(grouping: meals, by: \.day)
        return byDay.keys.sorted(by: >).map { key in
            let newestFirst = (byDay[key] ?? []).sorted { ($0.eatenAt, $0.id) > ($1.eatenAt, $1.id) }
            let date = KitchenDay.date(from: key)
            return Day(
                day: key,
                title: title(key, date: date, today: today),
                date: date.map { KitchenDay.format($0, .dateTime.day().month(.abbreviated)) },
                meals: newestFirst
            )
        }
    }

    private static func title(_ key: String, date: Date?, today: Date) -> String {
        if key == KitchenDay.string(from: today) { return "Aujourd'hui" }
        if key == KitchenDay.string(from: KitchenDay.adding(-1, to: today)) { return "Hier" }
        guard let date else { return key }
        return KitchenDay.format(date, .dateTime.weekday(.wide)).capitalized(with: KitchenDay.locale)
    }
}
