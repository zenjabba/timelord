import SwiftUI
import TimelordKit

@main
struct TimelordWatchApp: App {
    @State private var connectivityManager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            WatchTimerView(connectivity: connectivityManager)
                .onAppear {
                    connectivityManager.activate()
                }
        }
    }
}
