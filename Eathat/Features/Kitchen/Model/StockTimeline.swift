import Foundation

/// The stock laid out in time, as Structured lays out a day: what is past, then each of the next days, then later.
enum StockTimeline {
    /// Days shown one by one, from today; beyond them, "Plus tard".
    static let horizon = 7

    enum Kind: Hashable, Sendable {
        case expired
        /// Days from today: 0 is today.
        case day(Int)
        case later
        case noDate
    }

    struct Group: Identifiable, Equatable {
        let kind: Kind
        let title: String
        let lines: [StockLine]

        var id: Kind { kind }

        /// The group's lines by place, as Crouton splits a day into Breakfast, Lunch and Dinner: fridge, cupboard,
        /// freezer, empty places left out.
        var byLocation: [(location: StorageLocation, lines: [StockLine])] {
            StorageLocation.allCases.compactMap { location in
                let members = lines.filter { $0.location == location }
                return members.isEmpty ? nil : (location, members)
            }
        }
    }

    /// A day card's header, as Crouton writes "Monday Jun 8": the weekday, then the date in grey.
    /// Groups that are not a single day have a title only.
    static func header(_ kind: Kind, today: Date = .now) -> (title: String, date: String?) {
        guard case let .day(offset) = kind else { return (title(kind, today: today), nil) }
        let date = KitchenDay.adding(offset, to: today)
        let weekday = KitchenDay.format(date, .dateTime.weekday(.wide)).capitalized(with: KitchenDay.locale)
        return (weekday, KitchenDay.format(date, .dateTime.day().month(.abbreviated)))
    }

    /// Active lines of `location` (all places when nil) grouped by when they expire, in time order;
    /// empty groups are left out, and lines in a group are sorted by name.
    static func groups(_ lines: [StockLine], location: StorageLocation?, today: Date = .now) -> [Group] {
        let shown = lines.filter { $0.isActive && (location == nil || $0.location == location) }
        let byKind = Dictionary(grouping: shown) { kind(daysLeft: $0.daysLeft) }
        let order: [Kind] = [.expired] + (0..<horizon).map(Kind.day) + [.later, .noDate]
        return order.compactMap { kind in
            guard let members = byKind[kind] else { return nil }
            let sorted = members.sorted { lhs, rhs in
                if lhs.daysLeft != rhs.daysLeft { return (lhs.daysLeft ?? .max) < (rhs.daysLeft ?? .max) }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return Group(kind: kind, title: title(kind, today: today), lines: sorted)
        }
    }

    static func kind(daysLeft: Int?) -> Kind {
        guard let daysLeft else { return .noDate }
        if daysLeft < 0 { return .expired }
        return daysLeft < horizon ? .day(daysLeft) : .later
    }

    /// "Déjà périmé", "Aujourd'hui", "Demain", "Jeudi 19", "Plus tard", "Sans date".
    static func title(_ kind: Kind, today: Date = .now) -> String {
        switch kind {
        case .expired: return "Déjà périmé"
        case .day(0): return "Aujourd'hui"
        case .day(1): return "Demain"

        case let .day(offset):
            let date = KitchenDay.adding(offset, to: today)
            return KitchenDay.format(date, .dateTime.weekday(.wide).day()).capitalized(with: KitchenDay.locale)

        case .later: return "Plus tard"
        case .noDate: return "Sans date"
        }
    }
}
