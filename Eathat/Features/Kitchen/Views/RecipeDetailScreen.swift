import SwiftUI

/// Crouton's recipe page: the timer and "…" in a capsule at the top right, the photo card with the
/// title in white, "Start" with the basket and share buttons, the servings and prep pills, "Ingrédients" with
/// Scale, the white ingredients card, then one card per step and the "Shared by" line.
/// "Start" here means "Je l'ai cuisinée": it asks, then takes the ingredients off the stock.
struct RecipeDetailScreen: View {
    @Environment(KitchenStore.self) private var store
    let recipeId: Recipe.ID
    @State private var scale = 1.0
    @State private var showsMissing = true
    @State private var cooked: CookedMeal?
    @State private var isConfirming = false
    @State private var isShowingTimer = false
    @State private var isShowingBasket = false

    var body: some View {
        if let recipe = store.recipe(id: recipeId) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PhotoCard(recipe: recipe)
                    ActionRow(recipe: recipe, cook: { isConfirming = true }, basket: { isShowingBasket = true })
                    InfoPills(recipe: recipe)
                    IngredientsHeader(scale: $scale, showsMissing: $showsMissing)
                    IngredientsCard(recipe: recipe, scale: scale, showsMissing: showsMissing)
                    MethodCards(recipe: recipe)
                    SharedBy()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .readableWidth()
            }
            .background(Crouton.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar(recipe) }
            .tint(Crouton.blue)
            .sheet(isPresented: $isShowingTimer) { TimerSheet(title: recipe.title, minutes: recipe.prepMinutes ?? 10) }
            .confirmationDialog("Tu l'as cuisinée ?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Oui, retirer les ingrédients du stock") { cook(recipe) }
                Button("Annuler", role: .cancel) {}
            }
            .alert("À acheter", isPresented: $isShowingBasket) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(missingText(recipe))
            }
            .alert("Bon appétit !", isPresented: isShowingMeal, presenting: cooked) { _ in
                Button("OK") { cooked = nil }
            } message: { meal in
                Text(meal.summary)
            }
        } else {
            ContentUnavailableView("Recette introuvable", systemImage: "fork.knife")
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ recipe: Recipe) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Minuteur", systemImage: "timer") { isShowingTimer = true }
                .tint(.primary)
            Menu("Plus", systemImage: "ellipsis") {
                ShareLink(item: RecipeShare.text(recipe)) { Label("Partager", systemImage: "square.and.arrow.up") }
                Button("Je l'ai cuisinée", systemImage: "checkmark") { isConfirming = true }
            }
            .tint(.primary)
        }
    }

    private var isShowingMeal: Binding<Bool> {
        Binding { cooked != nil } set: { if !$0 { cooked = nil } }
    }

    private func missingText(_ recipe: Recipe) -> String {
        let missing = recipe.ingredients.filter { store.stockLine(for: $0) == nil && !$0.optional }.map(\.name)
        return missing.isEmpty ? "Tu as tout ce qu'il faut." : missing.joined(separator: ", ")
    }

    private func cook(_ recipe: Recipe) {
        Task { cooked = await store.cook(recipe) }
    }
}

/// The recipe as text, for the share sheet.
enum RecipeShare {
    static func text(_ recipe: Recipe) -> String {
        let ingredients = recipe.ingredients.map { ingredient in
            "• " + [ingredient.amount, ingredient.name].compactMap(\.self).joined(separator: " ")
        }
        let steps = RecipeSteps.parse(recipe.steps).enumerated().map { "\($0.offset + 1). \($0.element)" }
        return ([recipe.title, RecipeMeta.timing(recipe), ""] + ingredients + [""] + steps).joined(separator: "\n")
    }
}

#if DEBUG
#Preview {
    let store = KitchenStore(service: PreviewKitchenService())
    NavigationStack {
        RecipeDetailScreen(recipeId: 1)
    }
    .environment(store)
    .task { await store.load() }
}
#endif
