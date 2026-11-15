import SwiftUI

/// Crouton's tab bar: four tabs with their symbol and name, the chosen one in blue.
/// The store loads once here and again on each return to the app.
struct RootView: View {
    @Environment(KitchenStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab {
                WeekScreen()
            } label: {
                CroutonTabLabel(title: "Semaine", systemImage: "calendar")
            }
            Tab {
                RecipesScreen()
            } label: {
                CroutonTabLabel(title: "Recettes", systemImage: "list.bullet.rectangle.portrait")
            }
            Tab {
                StockScreen()
            } label: {
                CroutonTabLabel(title: "Stock", systemImage: "basket")
            }
            Tab {
                SettingsScreen()
            } label: {
                CroutonTabLabel(title: "Réglages", systemImage: "ellipsis.circle")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Crouton.blue)
        .fontDesign(.rounded)
        .task(id: scenePhase) {
            if scenePhase == .active { await store.load() }
        }
    }
}

/// Crouton draws its tab symbols in outline, not filled as the system would.
private struct CroutonTabLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .environment(\.symbolVariants, .none)
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(KitchenStore(service: PreviewKitchenService()))
}
#endif
