import Foundation

/// The composition root: builds the real services from Info.plist (filled by Config/*.xcconfig).
enum AppConfiguration {
    static func kitchenService(bundle: Bundle = .main) -> any KitchenService {
        #if DEBUG
        // `-preview-kitchen` on launch: the preview data instead of the real kitchen, for screenshots.
        if ProcessInfo.processInfo.arguments.contains("-preview-kitchen") { return PreviewKitchenService() }
        #endif
        let urlString = bundle.object(forInfoDictionaryKey: "EathatAPIURL") as? String ?? ""
        let apiKey = bundle.object(forInfoDictionaryKey: "EathatAPIKey") as? String ?? ""
        let baseURL = URL(string: urlString) ?? URL(filePath: "/")
        return APIKitchenService(client: URLSessionHTTPClient(baseURL: baseURL, apiKey: apiKey))
    }
}
