import SwiftUI

/// The white ingredients card: the amount in blue, the name in black, one per line.
struct IngredientsCard: View {
    @Environment(KitchenStore.self) private var store
    let recipe: Recipe
    let scale: Double
    let showsMissing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                HStack(alignment: .firstTextBaseline) {
                    Text(words(ingredient))
                    Spacer(minLength: 8)
                    if showsMissing, store.stockLine(for: ingredient) == nil, !ingredient.optional {
                        Text("à acheter")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Crouton.orange)
                    }
                }
            }
        }
        .font(.system(size: 19))
        .croutonCard(padding: 18)
    }

    private func words(_ ingredient: Recipe.Ingredient) -> AttributedString {
        var text = AttributedString()
        if let amount = ingredient.amount(scaledBy: scale) {
            var part = AttributedString(amount + " ")
            part.foregroundColor = Crouton.blue
            text += part
        }
        text += AttributedString(ingredient.optional ? "\(ingredient.name) (facultatif)" : ingredient.name)
        return text
    }
}

/// "Préparation", then one white card per step: a blue round number, the text with ingredients in blue, times
/// in amber and temperatures in orange.
struct MethodCards: View {
    let recipe: Recipe

    var body: some View {
        let names = recipe.ingredients.map(\.name)
        VStack(alignment: .leading, spacing: 14) {
            Text("Préparation")
                .font(.system(size: 21, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.top, 12)
            ForEach(Array(RecipeSteps.parse(recipe.steps).enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Crouton.blue, in: .circle)
                    Text(colored(step, names: names))
                        .font(.system(size: 19))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .croutonCard(padding: 16)
            }
        }
    }

    private func colored(_ step: String, names: [String]) -> AttributedString {
        RecipeSteps.pieces(of: step, ingredients: names).reduce(into: AttributedString()) { text, piece in
            var part = AttributedString(piece.text)
            switch piece.kind {
            case .ingredient: part.foregroundColor = Crouton.blue
            case .time: part.foregroundColor = Crouton.time
            case .temperature: part.foregroundColor = Crouton.heat
            case .plain: break
            }
            text += part
        }
    }
}

/// "Enregistrée par Claude ♥" under the last step, as Crouton signs shared recipes.
struct SharedBy: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Enregistrée par Claude")
                .foregroundStyle(.secondary)
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink)
                .accessibilityHidden(true)
        }
        .font(.system(size: 18))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

/// The timer as Crouton's: the time left in amber on a soft peach card, under the recipe's name.
struct TimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State private var span: ClosedRange<Date>

    init(title: String, minutes: Int) {
        self.title = title
        _span = State(initialValue: CookTimer.span(minutes: minutes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Minuteur · \(title)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(timerInterval: span, countsDown: true)
                .font(.system(size: 56, weight: .semibold).monospacedDigit())
                .foregroundStyle(Crouton.time)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Crouton.peach, in: .rect(cornerRadius: 22))
            Button("Arrêter") { dismiss() }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Crouton.blue)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.height(250)])
    }
}
