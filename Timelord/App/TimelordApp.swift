import SwiftUI
import SwiftData
import TimelordKit

@main
struct TimelordApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerFactory.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
                .onAppear {
                    WatchSyncService.shared.activate()
                }
        }
        .modelContainer(modelContainer)
    }
}
