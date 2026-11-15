import SwiftUI

/// Adding a recipe to a day, as Crouton's sheets: an X and a centred title, Midi or Soir, then a white rounded row
/// per recipe with its photo. Tap one to plan it.
struct AddMealSheet: View {
    @Environment(KitchenStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let day: MealWeek.Day
    @State private var slot = MealSlot.soir

    var body: some View {
        NavigationStack {
            ScrollView { choices }
            .background(Crouton.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                        .tint(.primary)
                }
            }
        }
        .tint(Crouton.blue)
    }

    private var choices: some View {
        VStack(spacing: 10) {
            Picker("Moment", selection: $slot) {
                ForEach(MealSlot.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 6)
            if store.recipes.isEmpty {
                ContentUnavailableView(
                    "Pas encore de recette",
                    systemImage: "fork.knife",
                    description: Text("Demande à Claude : « Qu'est-ce que je cuisine ce soir ? »")
                )
            }
            ForEach(store.recipesByUrgency) { recipe in
                Button { add(recipe) } label: { RecipeChoice(recipe: recipe) }
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    private var title: String {
        let (weekday, date) = StockTimeline.header(.day(day.offset))
        return [weekday, date].compactMap(\.self).joined(separator: " ")
    }

    private func add(_ recipe: Recipe) {
        Task {
            await store.addToPlan(recipe, day: day.day, slot: slot)
            dismiss()
        }
    }
}

/// A recipe to pick: its photo, its title, and how long it takes in grey.
private struct RecipeChoice: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            RemoteThumb(url: recipe.imageUrl, emoji: recipe.emoji, size: 44, fills: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(.system(size: 17, weight: .medium))
                    .lineLimit(2)
                Text(RecipeMeta.timing(recipe))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Crouton.blue)
                .accessibilityHidden(true)
        }
        .padding(10)
        .background(Crouton.card, in: .rect(cornerRadius: 20))
        .contentShape(.rect)
    }
}
