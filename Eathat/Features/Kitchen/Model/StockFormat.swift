import Foundation

/// How alarming a date is, for its colour.
enum UrgencyTone: Equatable, Sendable {
    case expired
    case urgent
    case soon
    case calm
}

/// The words the stock screens show, kept out of the views so they can be tested.
enum StockFormat {
    /// "250 g", "1,5 kg", "20 × bouteille 1 L".
    static func quantity(_ value: Double, unit: String) -> String {
        if unit == "g" {
            return value >= 1000 ? "\(number(value / 1000)) kg" : "\(number(value)) g"
        }
        return "\(number(value)) × \(unit)"
    }

    /// "Périmé depuis 2 j", "Aujourd'hui", "Demain", "Dans 5 j", "Sans date".
    static func days(_ daysLeft: Int?) -> String {
        guard let daysLeft else { return "Sans date" }
        switch daysLeft {
        case ..<0: return "Périmé depuis \(-daysLeft) j"
        case 0: return "Aujourd'hui"
        case 1: return "Demain"
        default: return "Dans \(daysLeft) j"
        }
    }

    static func tone(_ daysLeft: Int?) -> UrgencyTone {
        guard let daysLeft else { return .calm }
        switch daysLeft {
        case ..<0: return .expired
        case 0...2: return .urgent
        case 3...7: return .soon
        default: return .calm
        }
    }

    /// A French number with up to two decimals: "1,5", "250".
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "fr_FR")))
    }
}
