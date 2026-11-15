@testable import Eathat

extension StockLine {
    static func sample(
        id: Int,
        productId: Int? = nil,
        name: String = "Produit",
        location: StorageLocation = .frigo,
        daysLeft: Int? = 10,
        status: Status = .dispo
    ) -> Self {
        Self(
            id: id,
            productId: productId ?? id,
            name: name,
            brand: nil,
            category: "frais",
            quantity: 1,
            initialQuantity: 1,
            unit: "pot",
            location: location,
            bestBefore: daysLeft == nil ? nil : "2026-11-20",
            bestBeforeIsEstimate: true,
            daysLeft: daysLeft,
            openedAt: nil,
            status: status
        )
    }
}

extension Recipe {
    static func sample(id: Int = 1, ingredients: [Ingredient] = []) -> Self {
        Self(
            id: id,
            title: "Pâtes aux courgettes",
            servings: 2,
            prepMinutes: 20,
            steps: "1. Cuire les pâtes.",
            tags: ["rapide"],
            rating: nil,
            notes: nil,
            createdAt: "2026-11-14T18:00:00Z",
            ingredients: ingredients
        )
    }
}

extension Recipe.Ingredient {
    static func sample(productId: Int?, optional: Bool = false) -> Self {
        Self(name: "ingrédient", productId: productId, quantity: 100, unit: "g", quantityText: nil, optional: optional)
    }
}
