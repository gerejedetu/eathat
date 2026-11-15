import SwiftUI

/// The stock as Crouton's "Groceries": "…" at the top right, a large title, then a white rounded row per
/// product (tick box, amount in blue, name), one group per place. Tick products to eat or throw them all at once
/// from Crouton's bottom bar; tap a name for its sheet.
struct StockScreen: View {
    @Environment(KitchenStore.self) private var store
    @State private var picked: Set<StockLine.ID> = []
    @State private var opened: StockLine?
    @State private var isWasting = false

    var body: some View {
        NavigationStack {
            ScrollView { list }
                .background(Crouton.canvas)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .safeAreaInset(edge: .bottom) {
                    if !picked.isEmpty {
                        CroutonBottomBar(
                            secondary: "Jeté",
                            primary: pickedLines.count == 1 ? "Mangé" : "Mangé (\(pickedLines.count))",
                            secondaryAction: { isWasting = true },
                            primaryAction: { run(.consume(quantity: nil)) }
                        )
                    }
                }
                .refreshable { await store.load() }
                .overlay { KitchenPlaceholder() }
                .sheet(item: $opened) { StockLineSheet(line: $0) }
                .confirmationDialog(wasteQuestion, isPresented: $isWasting, titleVisibility: .visible) {
                    Button("Jeter", role: .destructive) { run(.waste(quantity: nil, reason: nil)) }
                }
                .kitchenErrorAlert()
                .animation(.snappy, value: picked)
        }
        .tint(Crouton.blue)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            CroutonTitle("Mon stock")
            ForEach(store.shelves, id: \.location) { shelf in
                Label(shelf.location.title, systemImage: shelf.location.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
                ForEach(shelf.lines) { line in
                    GroceryRow(
                        lead: StockFormat.lead(line.quantity, unit: line.unit),
                        name: line.name,
                        thumb: line,
                        trailing: dateText(line),
                        trailingColor: dateColor(line),
                        isChecked: picked.contains(line.id),
                        toggle: { toggle(line) },
                        open: { opened = line }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .readableWidth()
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Plus", systemImage: "ellipsis") {
                if picked.isEmpty {
                    Button("Tout cocher", systemImage: "checkmark.circle") {
                        picked = Set(store.shelves.flatMap(\.lines).map(\.id))
                    }
                } else {
                    Button("Tout décocher", systemImage: "circle") { picked = [] }
                }
                Button("Actualiser", systemImage: "arrow.clockwise") { Task { await store.load() } }
            }
            .tint(.primary)
        }
    }

    private var pickedLines: [StockLine] {
        store.shelves.flatMap(\.lines).filter { picked.contains($0.id) }
    }

    private var wasteQuestion: String {
        pickedLines.count == 1 ? "Jeter ce produit ?" : "Jeter ces \(pickedLines.count) produits ?"
    }

    /// The date only when it matters, within the week.
    private func dateText(_ line: StockLine) -> String? {
        StockFormat.tone(line.daysLeft) == .calm ? nil : StockFormat.days(line.daysLeft)
    }

    private func dateColor(_ line: StockLine) -> Color {
        switch StockFormat.tone(line.daysLeft) {
        case .expired: .red
        case .urgent: Crouton.heat
        case .soon, .calm: .secondary
        }
    }

    private func toggle(_ line: StockLine) {
        if picked.contains(line.id) { picked.remove(line.id) } else { picked.insert(line.id) }
    }

    private func run(_ action: StockAction) {
        let targets = pickedLines
        picked = []
        Task { await store.perform(action, onAll: targets) }
    }
}

#if DEBUG
#Preview {
    let store = KitchenStore(service: PreviewKitchenService())
    StockScreen()
        .environment(store)
        .task { await store.load() }
}
#endif
