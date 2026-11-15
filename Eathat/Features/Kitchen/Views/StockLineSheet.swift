import SwiftUI

/// A product, as Crouton's "Add to Groceries" sheet: an X and a centred title, white rounded rows on grey, and two
/// buttons at the bottom ("Jeté" in light blue, "Tout mangé" in blue).
struct StockLineSheet: View {
    @Environment(KitchenStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let line: StockLine
    @State private var partAmount = ""
    @State private var bestBefore = Date.now
    @State private var isWasting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    SheetRow { InfoLine(label: "Reste", value: StockFormat.quantity(line.quantity, unit: line.unit)) }
                    SheetRow { InfoLine(label: "Lieu", value: line.location.title) }
                    SheetRow { InfoLine(label: "Date limite", value: dateText) }
                    moves
                    partRow
                    dateRow
                }
                .padding(16)
            }
            .background(Crouton.canvas)
            .navigationTitle("\(line.emoji) \(line.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                        .tint(.primary)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .confirmationDialog("Pourquoi jeté ?", isPresented: $isWasting, titleVisibility: .visible) { wasteReasons }
            .onAppear { bestBefore = line.bestBefore.flatMap(KitchenDay.date(from:)) ?? .now }
        }
        .tint(Crouton.blue)
    }

    private var dateText: String {
        guard let day = line.bestBefore else { return "Aucune" }
        let label = "\(KitchenDay.label(day)) · \(StockFormat.days(line.daysLeft).lowercased())"
        return line.bestBeforeIsEstimate ? "\(label) (estimée)" : label
    }

    @ViewBuilder private var moves: some View {
        if line.status == .dispo {
            SheetButton(title: "Je l'ai ouvert", systemImage: "seal") { run(.open) }
        }
        ForEach(StorageLocation.allCases.filter { $0 != line.location }, id: \.self) { place in
            SheetButton(title: moveTitle(place), systemImage: place.systemImage) { run(.move(place)) }
        }
    }

    private func moveTitle(_ place: StorageLocation) -> String {
        switch place {
        case .congelateur: "Congeler"
        case .frigo: line.location == .congelateur ? "Décongeler au frigo" : "Mettre au frigo"
        case .placard: "Mettre au placard"
        }
    }

    private var partRow: some View {
        SheetRow {
            HStack {
                TextField("Manger une partie (\(line.unit))", text: $partAmount)
                    .keyboardType(.decimalPad)
                Button("Retirer") { run(.consume(quantity: part)) }
                    .fontWeight(.semibold)
                    .disabled(part == nil)
            }
        }
    }

    private var dateRow: some View {
        SheetRow {
            HStack {
                DatePicker("Vraie date", selection: $bestBefore, displayedComponents: .date)
                Button("OK") { run(.setBestBefore(KitchenDay.string(from: bestBefore))) }
                    .fontWeight(.semibold)
            }
        }
    }

    /// Crouton's bottom bar: the secondary action in light blue, the main one in blue.
    private var bottomBar: some View {
        CroutonBottomBar(
            secondary: "Jeté",
            primary: "Tout mangé",
            secondaryAction: { isWasting = true },
            primaryAction: { run(.consume(quantity: nil)) }
        )
    }

    /// The part typed in, when it is a positive number ("0,5" works too).
    private var part: Double? {
        Double(partAmount.replacing(",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
    }

    @ViewBuilder private var wasteReasons: some View {
        ForEach(["Périmé", "Moisi", "Oublié", "Trop préparé"], id: \.self) { reason in
            Button(reason, role: .destructive) { run(.waste(quantity: part, reason: reason.lowercased())) }
        }
    }

    private func run(_ action: StockAction) {
        Task {
            await store.perform(action, on: line)
            dismiss()
        }
    }
}

/// A white rounded row on the grey sheet.
private struct SheetRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.system(size: 17))
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Crouton.card, in: .rect(cornerRadius: 18))
    }
}

private struct InfoLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A row that does something: its symbol and its words in blue.
private struct SheetButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SheetRow {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(Crouton.blue)
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    StockLineSheet(line: PreviewKitchenService.lines[2])
        .environment(KitchenStore(service: PreviewKitchenService()))
}
#endif
