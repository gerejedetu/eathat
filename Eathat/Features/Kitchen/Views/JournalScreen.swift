import SwiftUI

/// The journal: what was cooked, day by day, the newest day first, in Crouton's day cards (the grey header capsule
/// with the day and its date, then each meal with its photo, title and hour). Tap a meal to open its recipe.
struct JournalScreen: View {
    @Environment(KitchenStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView { content }
                .background(Crouton.canvas)
                .navigationBarTitleDisplayMode(.inline)
                .refreshable { await store.load() }
                .overlay { KitchenPlaceholder() }
                .navigationDestination(for: Recipe.ID.self) { RecipeDetailScreen(recipeId: $0) }
                .kitchenErrorAlert()
        }
        .tint(Crouton.blue)
    }
}

private extension JournalScreen {
    var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            CroutonTitle("Déjà cuisiné")
            if store.journal.isEmpty, store.phase == .loaded {
                ContentUnavailableView(
                    "Rien pour l'instant",
                    systemImage: "fork.knife",
                    description: Text(
                        "Les repas cuisinés (« Je l'ai cuisinée » ou avec Claude) s'affichent ici, jour par jour."
                    )
                )
                .padding(.top, 40)
            }
            ForEach(store.journal) { day in
                JournalDayCard(day: day)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .readableWidth()
    }
}

/// A day of the journal: its header capsule, then the meals eaten that day.
private struct JournalDayCard: View {
    let day: MealLog.Day

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ForEach(day.meals) { meal in
                EatenRow(meal: meal)
                    .padding(.horizontal, 6)
            }
        }
        .padding(8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Crouton.card, in: .rect(cornerRadius: 26))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(day.title)
                .font(.system(size: 17, weight: .medium))
            if let date = day.date {
                Text(date)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(day.countText)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(light: 0xF0F0F4, dark: 0x2C2C2E), in: .capsule)
    }
}

/// A meal eaten: its little photo, its title and note, the hour at the right.
private struct EatenRow: View {
    @Environment(KitchenStore.self) private var store
    let meal: EatenMeal

    private var recipe: Recipe? {
        meal.recipeId.flatMap { store.recipe(id: $0) }
    }

    var body: some View {
        if let recipe {
            NavigationLink(value: recipe.id) { row(emoji: recipe.emoji) }
                .buttonStyle(.plain)
        } else {
            row(emoji: "🍽️")
        }
    }

    private func row(emoji: String) -> some View {
        HStack(spacing: 10) {
            RemoteThumb(url: meal.imageUrl, emoji: emoji, size: 34, fills: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(meal.displayTitle)
                    .font(.system(size: 17))
                    .foregroundStyle(meal.title == nil ? .secondary : .primary)
                    .lineLimit(1)
                if let note = meal.note {
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let time = meal.time {
                Text(time)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contentShape(.rect)
    }
}

#if DEBUG
#Preview {
    let store = KitchenStore(service: PreviewKitchenService())
    JournalScreen()
        .environment(store)
        .task { await store.load() }
}
#endif
