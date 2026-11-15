import SwiftUI

/// A row of Crouton's Groceries list: a white rounded bar with a grey square to tick, the amount in blue, the name.
/// Ticked, the square turns blue with a check and the words fade.
struct GroceryRow: View {
    let lead: String?
    let name: String
    /// The product's thumbnail, after the tick box; none for a plain shopping item.
    var thumb: StockLine?
    var trailing: String?
    var trailingColor: Color = .secondary
    let isChecked: Bool
    let toggle: () -> Void
    /// What a tap on the words does; ticks the row when nil.
    var open: (() -> Void)?

    var body: some View {
        HStack(spacing: 9) {
            Button(action: toggle) { CheckSquare(isChecked: isChecked) }
                .buttonStyle(.plain)
                .accessibilityLabel(isChecked ? "Décocher \(name)" : "Cocher \(name)")
            Button { (open ?? toggle)() } label: {
                HStack(spacing: 8) {
                    if let thumb { ProductThumb(line: thumb, size: 32) }
                    words
                    Spacer(minLength: 8)
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 15))
                            .foregroundStyle(trailingColor)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 46)
        .background(Crouton.card, in: .rect(cornerRadius: 22))
    }

    private var words: Text {
        let nameText = Text(name).foregroundStyle(isChecked ? Color.secondary : Color.primary)
        guard let lead else { return nameText.font(.system(size: 17)) }
        let leadText = Text(lead).foregroundStyle(Crouton.blue.opacity(isChecked ? 0.45 : 1))
        return Text("\(leadText) \(nameText)").font(.system(size: 17))
    }
}

/// Crouton's tick box: a soft grey rounded square, blue with a white check once ticked.
private struct CheckSquare: View {
    let isChecked: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isChecked ? Crouton.blue : Color(light: 0xF0F0F6, dark: 0x2C2C2E))
            .frame(width: 25, height: 25)
            .overlay {
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
    }
}

/// Crouton's floating bottom bar ("Select All" / "Add 6 Items"): a light blue button and a blue one in a white
/// rounded tray.
struct CroutonBottomBar: View {
    let secondary: String
    let primary: String
    let secondaryAction: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: secondaryAction) {
                Text(secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(Crouton.blue)
                    .background(Crouton.softBlue, in: .capsule)
            }
            Button(action: primaryAction) {
                Text(primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(Crouton.blue, in: .capsule)
            }
        }
        .font(.system(size: 18, weight: .semibold))
        .buttonStyle(.plain)
        .padding(10)
        .background(Crouton.card, in: .rect(cornerRadius: 32))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 2)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .readableWidth(560)
    }
}

/// A large title as Crouton sets it, inside the scrolling content.
struct CroutonTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
    }
}
