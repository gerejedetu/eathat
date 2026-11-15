import SwiftUI

@main
struct EathatApp: App {
    @State private var store = KitchenStore(service: AppConfiguration.kitchenService())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
