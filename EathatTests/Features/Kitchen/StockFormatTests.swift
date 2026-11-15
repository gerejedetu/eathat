@testable import Eathat
import Testing

@Suite("Stock format")
struct StockFormatTests {
    @Test(
        "quantities",
        arguments: [
            (250.0, "g", "250 g"),
            (1000.0, "g", "1 kg"),
            (1500.0, "g", "1,5 kg"),
            (20.0, "bouteille 1 L", "20 × bouteille 1 L"),
            (0.5, "pot 630 g", "0,5 × pot 630 g"),
        ]
    )
    func quantity(value: Double, unit: String, expected: String) {
        #expect(StockFormat.quantity(value, unit: unit) == expected)
    }

    @Test(
        "days left",
        arguments: [
            (-2, "Périmé depuis 2 j"),
            (-1, "Périmé depuis 1 j"),
            (0, "Aujourd'hui"),
            (1, "Demain"),
            (5, "Dans 5 j"),
        ]
    )
    func days(daysLeft: Int, expected: String) {
        #expect(StockFormat.days(daysLeft) == expected)
    }

    @Test("no date")
    func noDate() {
        #expect(StockFormat.days(nil) == "Sans date")
        #expect(StockFormat.tone(nil) == .calm)
    }

    @Test(
        "tones",
        arguments: [(-1, UrgencyTone.expired), (0, .urgent), (2, .urgent), (3, .soon), (7, .soon), (8, .calm)]
    )
    func tone(daysLeft: Int, expected: UrgencyTone) {
        #expect(StockFormat.tone(daysLeft) == expected)
    }
}
