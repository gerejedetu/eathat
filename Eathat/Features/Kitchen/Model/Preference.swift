import Foundation

/// One of the user's preferences, as Claude keeps them (`preferences` table).
nonisolated struct Preference: Identifiable, Hashable, Sendable {
    let key: String
    let value: String

    var id: String { key }

    /// The key in words: known keys get their French label, others lose their underscores.
    var label: String {
        if let known = Self.labels[key] { return known }
        let words = key.replacing("_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// The preferences sorted by label.
    static func list(_ values: [String: String]) -> [Self] {
        values.map { Self(key: $0.key, value: $0.value) }.sorted { $0.label < $1.label }
    }

    private static let labels = [
        "foyer": "Foyer",
        "regime": "Régime",
        "aime": "Aime",
        "evite": "Évite",
        "cuisinier": "Cuisinier",
        "objectif": "Objectif",
        "magasin": "Magasin",
        "deja_a_la_maison": "Déjà à la maison",
    ]
}
