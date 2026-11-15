import SwiftUI

/// Settings as Crouton's: a large title, then white rounded cards of rows with thin separators and grey notes
/// under them. Shows where the kitchen lives and the preferences Claude cooks by.
struct SettingsScreen: View {
    @Environment(KitchenStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    CroutonTitle("Réglages")
                    kitchen
                    preferences
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .readableWidth()
            }
            .background(Crouton.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.load() }
        }
        .tint(Crouton.blue)
    }

    private var kitchen: some View {
        SettingsCard {
            SettingsRow(title: "Synchronisation", detail: syncText) {
                Button("Actualiser") { Task { await store.load() } }
                    .fontWeight(.medium)
            }
            Divider().padding(.horizontal, 16)
            SettingsRow(title: "En stock", detail: nil) {
                Text("\(store.shelves.flatMap(\.lines).count) produits").foregroundStyle(.secondary)
            }
            Divider().padding(.horizontal, 16)
            SettingsRow(title: "Recettes", detail: nil) {
                Text("\(store.recipes.count)").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var preferences: some View {
        Text("Préférences")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 16)
        if !store.preferences.isEmpty {
            SettingsCard {
                ForEach(store.preferences) { preference in
                    SettingsRow(title: preference.label, detail: preference.value) { EmptyView() }
                    if preference != store.preferences.last {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
        }
        Text("Claude lit ces préférences avant chaque recette. Pour en changer une, dis-le-lui.")
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    private var syncText: String {
        switch store.phase {
        case .idle, .loading: "Chargement…"
        case .loaded: "À jour avec Claude"
        case let .failed(message): message
        }
    }
}

/// Crouton's settings card: white, big corners.
private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Crouton.card, in: .rect(cornerRadius: 26))
    }
}

/// A settings row: its title, a grey line under it, something at the right.
private struct SettingsRow<Accessory: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                if let detail {
                    Text(detail)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 50)
    }
}

#if DEBUG
#Preview {
    let store = KitchenStore(service: PreviewKitchenService())
    SettingsScreen()
        .environment(store)
        .task { await store.load() }
}
#endif
