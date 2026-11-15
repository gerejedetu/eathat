import SwiftUI

/// A day of Crouton's Meal Plan: a white card, a grey header capsule ("Lundi" then "16 nov." in grey, "+" and "…"
/// at the right), then slot pills (Midi, Soir) with their recipes, a photo and the title each. Today's card is
/// ringed in light blue, its weekday in blue. Tap a recipe to open it; press and hold to take it off.
struct DayCard: View {
    @Environment(KitchenStore.self) private var store
    let day: MealWeek.Day
    let add: () -> Void

    private var isToday: Bool { day.offset == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if day.meals.isEmpty {
                Text("Aucune recette")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            ForEach(day.bySlot, id: \.slot) { part in
                VStack(alignment: .leading, spacing: 8) {
                    SlotPill(slot: part.slot)
                    ForEach(part.meals) { meal in
                        MealRow(meal: meal)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Crouton.card, in: .rect(cornerRadius: 26))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 26).strokeBorder(Crouton.blue.opacity(0.35), lineWidth: 1.5)
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var header: some View {
        let (title, date) = StockTimeline.header(.day(day.offset))
        return HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isToday ? Crouton.blue : Color.primary)
            if let date {
                Text(date)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Ajouter une recette", systemImage: "plus", action: add)
                .frame(width: 32, height: 32)
            Menu("Plus", systemImage: "ellipsis") {
                Button("Vider la journée", systemImage: "minus.circle", role: .destructive) {
                    Task { await store.removeFromPlan(day.meals) }
                }
                .disabled(day.meals.isEmpty)
            }
            .frame(width: 32, height: 32)
        }
        .labelStyle(.iconOnly)
        .fontWeight(.semibold)
        .foregroundStyle(.primary)
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: 38)
        .background(Color(light: 0xF0F0F4, dark: 0x2C2C2E), in: .capsule)
    }
}

/// Crouton's section pill ("☀️ Lunch"): here noon or evening.
private struct SlotPill: View {
    let slot: MealSlot

    var body: some View {
        Label(slot.title, systemImage: slot.systemImage)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(light: 0xF0F0F4, dark: 0x2C2C2E), in: .capsule)
            .padding(.top, 4)
    }
}

/// A planned recipe: its little photo and its title, as Crouton's Meal Plan lines.
private struct MealRow: View {
    @Environment(KitchenStore.self) private var store
    let meal: PlannedMeal

    private var emoji: String {
        store.recipe(id: meal.recipeId)?.emoji ?? "🍽️"
    }

    var body: some View {
        NavigationLink(value: meal.recipeId) {
            HStack(spacing: 10) {
                RemoteThumb(url: meal.imageUrl, emoji: emoji, size: 34, fills: true)
                Text(meal.title)
                    .font(.system(size: 17))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Retirer du planning", systemImage: "minus.circle", role: .destructive) {
                Task { await store.removeFromPlan([meal]) }
            }
        }
    }
}
