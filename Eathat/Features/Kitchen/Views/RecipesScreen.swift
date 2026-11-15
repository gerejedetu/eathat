import SwiftUI

/// Crouton's "All Recipes": "+" and "…" in a capsule at the top right, a large title, the search field,
/// then a two-column grid of rounded photo tiles with the title in white and a frosted pill (servings, time).
/// Recipes that save food about to expire come first.
struct RecipesScreen: View {
    @Environment(KitchenStore.self) private var store
    @State private var query = ""
    @State private var isExplainingAdd = false

    /// Two columns on iPhone, as many as fit on iPad.
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 280), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView { grid }
            .background(Crouton.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Ajouter", systemImage: "plus") { isExplainingAdd = true }
                        .tint(.primary)
                    Menu("Plus", systemImage: "ellipsis") {
                        Button("Actualiser", systemImage: "arrow.clockwise") { Task { await store.load() } }
                    }
                    .tint(.primary)
                }
            }
            .alert("Nouvelle recette", isPresented: $isExplainingAdd) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Demande à Claude : il crée la recette avec ce que tu as, et elle apparaît ici.")
            }
            .navigationDestination(for: Recipe.ID.self) { RecipeDetailScreen(recipeId: $0) }
            .refreshable { await store.load() }
        }
        .tint(Crouton.blue)
    }
}

private extension RecipesScreen {
    @ViewBuilder var grid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Toutes les recettes")
                .font(.system(size: 34, weight: .bold))
            SearchField(text: $query)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .readableWidth()
        if store.recipes.isEmpty, store.phase == .loaded {
            ContentUnavailableView(
                "Pas encore de recette",
                systemImage: "fork.knife",
                description: Text("Demande à Claude : « Qu'est-ce que je cuisine ce soir ? »")
            )
        }
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(RecipeSearch.filter(store.recipesByUrgency, query: query)) { recipe in
                NavigationLink(value: recipe.id) { RecipeTile(recipe: recipe) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .readableWidth()
    }
}

/// Crouton's search field: a grey capsule, a black magnifier, a grey prompt.
private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .accessibilityHidden(true)
            TextField("Recettes, ingrédients et plus", text: $text)
                .font(.system(size: 19))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color(light: 0xE6E7EA, dark: 0x2C2C2E), in: .capsule)
    }
}

/// Crouton's tile: the photo, the title in white at the top left, a frosted pill with servings and time.
private struct RecipeTile: View {
    let recipe: Recipe

    var body: some View {
        RecipePhoto(recipe: recipe, emojiSize: 64)
            .frame(height: 138)
            .overlay(alignment: .topLeading) {
                Text(recipe.title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                TilePill(servings: recipe.servings, minutes: recipe.prepMinutes)
                    .padding(8)
            }
            .clipShape(.rect(cornerRadius: 24))
            .contentShape(.rect(cornerRadius: 24))
    }
}

/// "👥 2  🕘 15 min" on a frosted capsule.
private struct TilePill: View {
    let servings: Int
    let minutes: Int?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .accessibilityHidden(true)
                Text("\(servings)")
            }
            if let minutes {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .accessibilityHidden(true)
                    Text("\(minutes) min")
                }
            }
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Crouton.pill)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .capsule)
    }
}

#if DEBUG
#Preview {
    let store = KitchenStore(service: PreviewKitchenService())
    RecipesScreen()
        .environment(store)
        .task { await store.load() }
}
#endif
