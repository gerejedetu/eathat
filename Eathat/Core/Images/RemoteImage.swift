import SwiftUI
import UIKit

/// Photos fetched once and kept in memory, so a recipe's photo seen in the grid shows at once on its page.
/// The kitchen has a few dozen photos at most, so they all stay.
final class PhotoCache {
    private var images: [URL: UIImage] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func cached(_ url: URL) -> UIImage? {
        images[url]
    }

    /// The photo at `url`, from memory or the network; nil when it can't be had (offline, cancelled, not an image).
    func image(at url: URL) async -> UIImage? {
        if let known = cached(url) { return known }
        guard let (data, _) = try? await session.data(from: url), let image = UIImage(data: data) else { return nil }
        images[url] = image
        return image
    }
}

extension PhotoCache {
    /// The app's cache, shared by every screen; tests and previews can put their own in the environment.
    static let app = PhotoCache()
}

extension EnvironmentValues {
    @Entry var photoCache = PhotoCache.app
}

/// A remote photo, `placeholder` until it is there. Unlike AsyncImage, a load cut short (a page pushed or popped
/// mid-way) is tried again the next time the view appears, instead of leaving the placeholder for good.
struct RemoteImage<Placeholder: View>: View {
    @Environment(\.photoCache) private var cache
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder let placeholder: Placeholder
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let shown = image ?? url.flatMap(cache.cached) {
                Image(uiImage: shown)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .accessibilityHidden(true)
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = await cache.image(at: url)
        }
    }
}
