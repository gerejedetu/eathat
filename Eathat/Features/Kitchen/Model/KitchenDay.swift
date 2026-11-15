import Foundation

/// Best-before dates travel as 'YYYY-MM-DD' kitchen days (Paris); these turn them into dates and words.
enum KitchenDay {
    nonisolated private static let calendar: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return gregorian
    }()

    static func date(from day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    nonisolated static func string(from date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static let locale = Locale(identifier: "fr_FR")

    /// `date` moved by `days` kitchen days.
    static func adding(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// `date` in French, in Paris time: "sam.", "jeudi 19".
    static func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        var french = style.locale(locale)
        french.timeZone = calendar.timeZone
        return date.formatted(french)
    }

    /// "15 nov. 2026".
    static func label(_ day: String) -> String {
        guard let date = date(from: day) else { return day }
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Locale(identifier: "fr_FR"))
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}

extension Recipe.Ingredient {
    /// How much, as the recipe says it: "250 g", "1 × boule", "1 pincée"; nil when the recipe doesn't say.
    var amount: String? {
        amount(scaledBy: 1)
    }

    /// The amount for `factor` times the recipe ("Scale" in Crouton); words like "1 pincée" stay as written.
    func amount(scaledBy factor: Double) -> String? {
        if let quantityText { return quantityText }
        guard let base = self.quantity else { return nil }
        let quantity = base * factor
        guard let unit, !names(unit) else { return StockFormat.number(quantity) }
        return unit == "g" ? StockFormat.quantity(quantity, unit: unit) : "\(StockFormat.number(quantity)) \(unit)"
    }
}

private extension Recipe.Ingredient {
    /// Whether the unit just repeats the name ("1 baguette Baguette", "2 œuf Œufs").
    func names(_ unit: String) -> Bool {
        let fold = { (text: String) in text.lowercased().folding(options: .diacriticInsensitive, locale: nil) }
        let unitWord = fold(unit)
        return unitWord.count >= 3 && fold(name).hasPrefix(unitWord)
    }
}

extension CookedMeal {
    /// What to tell the user once the meal is logged.
    var summary: String {
        let taken = taken.map { "\($0.name) (\(StockFormat.quantity($0.quantity, unit: $0.unit)))" }
        var parts = [taken.isEmpty ? "Rien n'a été retiré du stock." : "Retiré du stock : \(taken.joined(separator: ", "))."]
        let missing = skipped.filter { $0.reason.hasPrefix("il manquait") }.map(\.name)
        if !missing.isEmpty { parts.append("Pas assez en stock : \(missing.joined(separator: ", ")).") }
        return parts.joined(separator: "\n")
    }
}
