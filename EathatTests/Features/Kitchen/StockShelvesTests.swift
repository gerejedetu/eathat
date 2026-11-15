@testable import Eathat
import Testing

@Suite("Stock shelves")
struct StockShelvesTests {
    @Test("one shelf per place, fridge first, the soonest to expire on top, dated before undated")
    func sections() {
        let lines: [StockLine] = [
            .sample(id: 1, name: "Riz", location: .placard, daysLeft: 300),
            .sample(id: 2, name: "Sel", location: .placard, daysLeft: nil),
            .sample(id: 3, name: "Lait", location: .frigo, daysLeft: 9),
            .sample(id: 4, name: "Beurre", location: .frigo, daysLeft: 2),
            .sample(id: 5, name: "Fini", location: .frigo, daysLeft: 1, status: .fini),
        ]
        let shelves = StockShelves.sections(lines)
        #expect(shelves.map(\.location) == [.frigo, .placard])
        #expect(shelves[0].lines.map(\.name) == ["Beurre", "Lait"])
        #expect(shelves[1].lines.map(\.name) == ["Riz", "Sel"])
    }

    @Test(
        "the blue lead of a line, as Crouton's \"2 cups\"",
        arguments: [
            (250.0, "g", "250 g"), (1500, "g", "1,5 kg"), (0.5, "L", "0,5 L"), (4, "baguette", "4"),
            (20, "bouteille 1 L", "20"),
        ]
    )
    func lead(quantity: Double, unit: String, expected: String) {
        #expect(StockFormat.lead(quantity, unit: unit) == expected)
    }
}
