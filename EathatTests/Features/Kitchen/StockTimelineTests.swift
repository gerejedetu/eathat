@testable import Eathat
import Foundation
import Testing

@Suite("Stock timeline")
struct StockTimelineTests {
    /// Saturday 14 November 2026, noon in Paris.
    private let saturday = KitchenDay.date(from: "2026-11-14") ?? .now

    @Test(
        "kinds by days left",
        arguments: [
            (-2, StockTimeline.Kind.expired), (0, .day(0)), (1, .day(1)), (6, .day(6)), (7, .later), (300, .later),
        ]
    )
    func kind(daysLeft: Int, expected: StockTimeline.Kind) {
        #expect(StockTimeline.kind(daysLeft: daysLeft) == expected)
        #expect(StockTimeline.kind(daysLeft: nil) == .noDate)
    }

    @Test("titles say the day in French")
    func titles() {
        #expect(StockTimeline.title(.expired, today: saturday) == "Déjà périmé")
        #expect(StockTimeline.title(.day(0), today: saturday) == "Aujourd'hui")
        #expect(StockTimeline.title(.day(1), today: saturday) == "Demain")
        #expect(StockTimeline.title(.day(5), today: saturday) == "Jeudi 19")
        #expect(StockTimeline.title(.later, today: saturday) == "Plus tard")
    }

    @Test("groups in time order, empty ones left out, names sorted inside")
    func groups() {
        let lines: [StockLine] = [
            .sample(id: 1, name: "Riz", daysLeft: 300),
            .sample(id: 2, name: "Courgettes", daysLeft: 6),
            .sample(id: 3, name: "Aubergines", daysLeft: 6),
            .sample(id: 4, name: "Lardons", daysLeft: -1),
            .sample(id: 5, name: "Sel", daysLeft: nil),
            .sample(id: 6, name: "Fini", daysLeft: 1, status: .fini),
        ]
        let groups = StockTimeline.groups(lines, location: nil, today: saturday)
        #expect(groups.map(\.kind) == [.expired, .day(6), .later, .noDate])
        #expect(groups[1].lines.map(\.name) == ["Aubergines", "Courgettes"])
        #expect(groups[1].title == "Vendredi 20")
    }

    @Test("keeps only the chosen place")
    func location() {
        let lines: [StockLine] = [.sample(id: 1, location: .frigo), .sample(id: 2, location: .placard)]
        #expect(StockTimeline.groups(lines, location: .placard).flatMap(\.lines).map(\.id) == [2])
    }

    @Test("a day header is the weekday, then the date")
    func header() {
        #expect(StockTimeline.header(.day(5), today: saturday) == ("Jeudi", "19 nov."))
        #expect(StockTimeline.header(.later, today: saturday) == ("Plus tard", nil))
    }

    @Test("a group splits by place: fridge, cupboard, freezer")
    func byLocation() {
        let lines: [StockLine] = [
            .sample(id: 1, location: .congelateur),
            .sample(id: 2, location: .frigo),
            .sample(id: 3, location: .frigo),
        ]
        let group = StockTimeline.groups(lines, location: nil, today: saturday)[0]
        #expect(group.byLocation.map(\.location) == [.frigo, .congelateur])
        #expect(group.byLocation[0].lines.map(\.id) == [2, 3])
    }
}
