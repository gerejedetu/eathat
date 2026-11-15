import Foundation

/// A recipe Claude saved, as the API sends it.
nonisolated struct Recipe: Identifiable, Hashable, Codable, Sendable {
    struct Ingredient: Hashable, Codable, Sendable {
        var name: String
        /// The product it comes from in the stock, when Claude linked it.
        var productId: Int?
        var quantity: Double?
        var unit: String?
        var quantityText: String?
        var optional: Bool

        init(
            name: String,
            productId: Int? = nil,
            quantity: Double? = nil,
            unit: String? = nil,
            quantityText: String? = nil,
            optional: Bool
        ) {
            self.name = name
            self.productId = productId
            self.quantity = quantity
            self.unit = unit
            self.quantityText = quantityText
            self.optional = optional
        }
    }

    let id: Int
    var title: String
    var servings: Int
    var prepMinutes: Int?
    var steps: String
    var tags: [String]
    var rating: Int?
    var notes: String?
    var createdAt: String
    var ingredients: [Ingredient]
    /// A photo of the dish, when Claude gave one.
    var imageUrl: URL?
}

/// What "Je l'ai cuisinée" did to the stock.
nonisolated struct CookedMeal: Equatable, Codable, Sendable {
    struct Taken: Equatable, Codable, Sendable {
        var inventoryId: Int
        var name: String
        var quantity: Double
        var unit: String
    }

    struct Skipped: Equatable, Codable, Sendable {
        var name: String
        var reason: String
    }

    var mealId: Int
    var recipeId: Int
    var taken: [Taken]
    var skipped: [Skipped]
}
