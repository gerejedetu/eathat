import Foundation

/// The stock as Crouton's Groceries list: one shelf per place, the soonest to expire on top.
nonisolated enum StockShelves {
    struct Shelf: Equatable, Sendable {
        let location: StorageLocation
        let lines: [StockLine]
    }

    static func sections(_ lines: [StockLine]) -> [Shelf] {
        let active = lines.filter(\.isActive).sorted(by: soonestFirst)
        return StorageLocation.allCases.compactMap { place in
            let here = active.filter { $0.location == place }
            return here.isEmpty ? nil : Shelf(location: place, lines: here)
        }
    }

    private static func soonestFirst(_ lhs: StockLine, _ rhs: StockLine) -> Bool {
        let left = lhs.daysLeft ?? .max
        let right = rhs.daysLeft ?? .max
        return left == right ? lhs.name < rhs.name : left < right
    }
}

extension StockFormat {
    /// The blue words before a product's name, as Crouton's "2 cups": a weight or volume with its unit, a count alone.
    static func lead(_ value: Double, unit: String) -> String {
        if unit == "g" { return quantity(value, unit: unit) }
        let measures: Set = ["kg", "l", "cl", "ml"]
        return measures.contains(unit.lowercased()) ? "\(number(value)) \(unit)" : number(value)
    }
}
