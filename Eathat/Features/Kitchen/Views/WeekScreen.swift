import SwiftUI

/// The week as Crouton's "Meal Plan": "…" in a circle at the top right, a large title, then one white
/// card per day for the next seven days (today's ringed in blue), each with its grey header ("Lundi 16 nov.", "+",
/// "…"), slot pills (Midi, Soir) and the recipes planned, by Claude or with "+". Tap a recipe to open it.
struct WeekScreen: View {
    @Environment(KitchenStore.self) private var store
    @State private var adding: MealWeek.Day?

    var body: some View {
        NavigationStack {
            ScrollView { days }
            .background(Crouton.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Plus", systemImage: "ellipsis") {
                        Button("Actualiser", systemImage: "arrow.clockwise") { Task { await store.load() } }
                    }
                    .tint(.primary)
                }
            }
            .refreshable { await store.load() }
            .overlay { KitchenPlaceholder() }
            .navigationDestination(for: Recipe.ID.self) { RecipeDetailScreen(recipeId: $0) }
            .sheet(item: $adding) { AddMealSheet(day: $0) }
            .kitchenErrorAlert()
        }
        .tint(Crouton.blue)
    }
}

private extension WeekScreen {
    var days: some View {
        VStack(alignment: .leading, spacing: 12) {
            CroutonTitle("Ma semaine")
            ForEach(store.week) { day in
                DayCard(day: day) { adding = day }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .readableWidth()
    }
}

/// Loading and failure over a kitchen screen.
struct KitchenPlaceholder: View {
    @Environment(KitchenStore.self) private var store

    var body: some View {
        switch store.phase {
        case .idle, .loading:
            ProgressView()

        case let .failed(message) where store.lines.isEmpty:
            ContentUnavailableView(
                "Stock indisponible",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )

        default:
            EmptyView()
        }
    }
}

extension View {
    /// "Ça n'a pas marché" when a quick action failed.
    func kitchenErrorAlert() -> some View {
        modifier(KitchenErrorAlert())
    }
}

private struct KitchenErrorAlert: ViewModifier {
    @Environment(KitchenStore.self) private var store

    func body(content: Content) -> some View {
        content.alert("Ça n'a pas marché", isPresented: hasError) {
            Button("OK", role: .cancel) { store.actionError = nil }
        } message: {
            Text(store.actionError ?? "")
        }
    }

    private var hasError: Binding<Bool> {
        Binding { store.actionError != nil } set: { if !$0 { store.actionError = nil } }
    }
}

#if DEBUG
#Preview {
    let store = KitchenStore(service: PreviewKitchenService())
    WeekScreen()
        .environment(store)
        .task { await store.load() }
}
#endif
