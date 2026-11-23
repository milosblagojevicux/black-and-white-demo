import SwiftUI

@main
struct BlackAndWhiteApp: App {
    private let environment = AppEnvironment.configured

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
