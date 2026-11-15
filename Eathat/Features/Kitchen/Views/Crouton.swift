import SwiftUI

/// The palette, light and dark.
enum Crouton {
    static let blue = Color(light: 0x2E93EC, dark: 0x4AA6F5)
    static let canvas = Color(light: 0xF4F5F7, dark: 0x000000)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let softBlue = Color(light: 0xD5E9F8, dark: 0x16324A)
    static let mint = Color(light: 0xCDF2E3, dark: 0x1D3B2F)
    static let green = Color(light: 0x2DBE6C, dark: 0x3DD27D)
    static let peach = Color(light: 0xFDEFD3, dark: 0x45331A)
    static let orange = Color(light: 0xF5A623, dark: 0xF7B547)
    static let lavender = Color(light: 0xE3E3FA, dark: 0x2B2B4D)
    static let purple = Color(light: 0x5B5BE0, dark: 0x8585F0)
    static let time = Color(light: 0xF2B33D, dark: 0xF5C25E)
    static let heat = Color(light: 0xF07A4E, dark: 0xF5926C)
    static let pill = Color(light: 0x6B6B70, dark: 0xB0B0B5)
}

extension View {
    /// Keeps a column of content readable on iPad: at most `width` wide, centred; untouched on iPhone.
    func readableWidth(_ width: CGFloat = 720) -> some View {
        frame(maxWidth: width, alignment: .leading).frame(maxWidth: .infinity)
    }

    /// Crouton's white card: big corners, a whisper of shadow.
    func croutonCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Crouton.card, in: .rect(cornerRadius: 26))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

/// A recipe's picture: its photo, darker at the top so a white title reads on it, as on Crouton's tiles. Without a
/// photo (or while it loads), a deep food colour with the dish's emoji.
struct RecipePhoto: View {
    let recipe: Recipe
    var emojiSize: CGFloat = 76

    var body: some View {
        Color.clear
            .overlay {
                RemoteImage(url: recipe.imageUrl) { stand }
            }
            .clipped()
            .overlay {
                LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
            }
            .accessibilityHidden(true)
    }

    private var stand: some View {
        recipe.tone.photoColor
            .overlay(alignment: .bottomTrailing) {
                Text(recipe.emoji)
                    .font(.system(size: emojiSize))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                    .padding(.trailing, emojiSize * 0.2)
                    .padding(.bottom, emojiSize * 0.05)
            }
    }
}

/// A little photo on a soft rounded square, the emoji until it loads (or when there is none), as Crouton's Meal Plan
/// thumbnails. Dish photos fill the square; product packshots fit inside it.
struct RemoteThumb: View {
    let url: URL?
    let emoji: String
    var size: CGFloat = 30
    var fills = false

    var body: some View {
        RemoteImage(url: url, contentMode: fills ? .fill : .fit) {
            Text(emoji).font(.system(size: size * 0.57))
        }
        .padding(fills ? 0 : size * 0.08)
        .frame(width: size, height: size)
        .background(Color(light: 0xF3F1EC, dark: 0x2C2A26))
        .clipShape(.rect(cornerRadius: size * 0.27))
        .accessibilityHidden(true)
    }
}

/// A product's little picture.
struct ProductThumb: View {
    let line: StockLine
    var size: CGFloat = 30

    var body: some View {
        RemoteThumb(url: line.imageUrl, emoji: line.emoji, size: size)
    }
}

extension Recipe {
    var tone: RecipeTone {
        RecipeTone.of(emoji: emoji)
    }
}

extension RecipeTone {
    /// Deep, photo-like colours, so a white title reads on them.
    var photoColor: Color {
        switch self {
        case .wheat: Color(light: 0xD39A4F, dark: 0x8E6230)
        case .garden: Color(light: 0x6F9D5C, dark: 0x45683A)
        case .tomato: Color(light: 0xCF5F45, dark: 0x8C3B2A)
        case .dairy: Color(light: 0xB9A585, dark: 0x7A6A52)
        }
    }
}

nonisolated extension Color {
    /// A colour with its own light and dark values, as 0xRRGGBB. Nonisolated: UIKit resolves it on any thread
    /// (a timer's text is drawn off the main one), so the provider must not be tied to the main actor.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { @Sendable traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let channel = { (shift: UInt32) in CGFloat((hex >> shift) & 0xFF) / 255 }
            return UIColor(red: channel(16), green: channel(8), blue: channel(0), alpha: 1)
        })
    }
}
