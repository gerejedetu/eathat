import Foundation

nonisolated enum StorageLocation: String, Codable, CaseIterable, Sendable {
    case frigo
    case placard
    case congelateur

    var title: String {
        switch self {
        case .frigo: "Frigo"
        case .placard: "Placard"
        case .congelateur: "Congélateur"
        }
    }

    var systemImage: String {
        switch self {
        case .frigo: "refrigerator"
        case .placard: "cabinet"
        case .congelateur: "snowflake"
        }
    }
}

/// One line of the kitchen's stock, as the API sends it. Dates are 'YYYY-MM-DD' kitchen days.
nonisolated struct StockLine: Identifiable, Hashable, Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case dispo
        case entame
        case fini
        case jete
    }

    let id: Int
    let productId: Int
    var name: String
    var brand: String?
    var category: String
    var quantity: Double
    var initialQuantity: Double
    var unit: String
    var location: StorageLocation
    var bestBefore: String?
    var bestBeforeIsEstimate: Bool
    /// Days until the best-before date when the API answered; negative once past.
    var daysLeft: Int?
    var openedAt: String?
    var status: Status
    /// The product's photo, when it has one.
    var imageUrl: URL?

    /// Still in the kitchen: neither finished nor thrown away.
    var isActive: Bool {
        status == .dispo || status == .entame
    }

    /// What is left of what was bought, from 0 to 1.
    var remainingFraction: Double {
        guard initialQuantity > 0 else { return 0 }
        return min(max(quantity / initialQuantity, 0), 1)
    }

    var emoji: String {
        FoodEmoji.emoji(name: name, category: category)
    }
}
