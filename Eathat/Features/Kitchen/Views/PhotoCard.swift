import SwiftUI

/// The photo card: rounded, inset, the title in large white letters at the top left.
struct PhotoCard: View {
    let recipe: Recipe

    var body: some View {
        RecipePhoto(recipe: recipe, emojiSize: 96)
            .frame(height: 174)
            .overlay(alignment: .topLeading) {
                Text(recipe.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 1)
                    .lineLimit(2)
                    .padding(16)
            }
            .clipShape(.rect(cornerRadius: 28))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            .padding(.top, 8)
    }
}

/// "Start" in a mint capsule, then the basket (what to buy) and share circles.
struct ActionRow: View {
    let recipe: Recipe
    let cook: () -> Void
    let basket: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: cook) {
                Label("Cuisiner", systemImage: "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Crouton.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Crouton.mint, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            circle("basket.fill", tint: Crouton.orange, background: Crouton.peach, label: "À acheter", action: basket)
            ShareLink(item: RecipeShare.text(recipe)) {
                CircleIcon(systemImage: "square.and.arrow.up.fill", tint: Crouton.purple, background: Crouton.lavender)
            }
            .accessibilityLabel("Partager")
        }
    }

    private func circle(
        _ systemImage: String,
        tint: Color,
        background: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { CircleIcon(systemImage: systemImage, tint: tint, background: background) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }
}

private struct CircleIcon: View {
    let systemImage: String
    let tint: Color
    let background: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .accessibilityHidden(true)
            .foregroundStyle(tint)
            .frame(width: 50, height: 50)
            .background(background, in: .circle)
    }
}

/// Servings in a white pill, then the prep time in a wide one: clock above, "Prép. 15 min" below.
struct InfoPills: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 14) {
            Label("\(recipe.servings)", systemImage: "person.2.fill")
                .font(.system(size: 20, weight: .medium))
                .labelStyle(PillLabelStyle())
                .padding(.horizontal, 22)
                .frame(height: 56)
                .background(Crouton.card, in: .capsule)
            VStack(spacing: 2) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 17))
                    .accessibilityHidden(true)
                    .foregroundStyle(.secondary)
                Text("\(Text("Prép.").foregroundStyle(.secondary)) \(recipe.prepMinutes ?? 0) min")
                    .font(.system(size: 18))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Crouton.card, in: .capsule)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

private struct PillLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(.secondary)
            configuration.title
        }
    }
}

/// "Ingrédients", with Scale and the settings button in light blue capsules on the right.
struct IngredientsHeader: View {
    @Binding var scale: Double
    @Binding var showsMissing: Bool

    var body: some View {
        HStack {
            Text("Ingrédients")
                .font(.system(size: 21, weight: .medium))
            Spacer()
            scaleMenu
            Menu {
                Toggle("Montrer ce qu'il faut acheter", isOn: $showsMissing)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Crouton.blue)
                    .frame(width: 54, height: 34)
                    .background(Crouton.softBlue, in: .capsule)
            }
            .accessibilityLabel("Réglages des ingrédients")
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }

    private var scaleMenu: some View {
        Menu {
            Picker("Quantités", selection: $scale) {
                Text("× ½").tag(0.5)
                Text("× 1").tag(1.0)
                Text("× 2").tag(2.0)
                Text("× 3").tag(3.0)
            }
        } label: {
            Text(scale == 1 ? "Portions" : "× \(StockFormat.number(scale))")
                .font(.system(size: 18))
                .foregroundStyle(Crouton.blue)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(Crouton.softBlue, in: .capsule)
        }
    }
}
