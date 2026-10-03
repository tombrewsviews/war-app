import SwiftUI

@main struct MyApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environment(environment)
        }
    }
}
