import SwiftUI
import Sentry

@main
struct ScanToCartApp: App {
    init() {
        SubscriptionService.shared.configure()

        let dsn = Config.sentryDSN
        if !dsn.isEmpty {
            #if DEBUG
            let environment = "debug"
            let debugMode = true
            #else
            let environment = "release"
            let debugMode = false
            #endif

            SentrySDK.start { options in
                options.dsn = dsn
                options.environment = environment
                options.tracesSampleRate = 0.1
                options.debug = debugMode
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    await AuthService.shared.bootstrap()
                }
        }
    }
}
