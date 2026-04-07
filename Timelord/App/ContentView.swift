import SwiftUI
import TimelordKit

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .timer
    @State private var timerService = TimerService()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var showingManualEntry = false
    @State private var showingSettings = false

    enum Tab: String, CaseIterable {
        case timer = "Timer"
        case timeline = "Timeline"
        case clients = "Clients"
        case projects = "Projects"
        case reports = "Reports"

        var systemImage: String {
            switch self {
            case .timer: return "timer"
            case .timeline: return "calendar.day.timeline.left"
            case .clients: return "person.2"
            case .projects: return "folder"
            case .reports: return "chart.bar"
            }
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            liveActivityManager.wire(to: timerService)
            // End any orphaned Live Activities from a previous session before restoring
            if TimerState.load() == nil {
                liveActivityManager.endOrphanedActivities()
            }
            timerService.restore()
            setupWatchSync()
            ScreenshotDataSeeder.seedIfNeeded(context: modelContext)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - iPhone (Tab Bar)

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
    }

    // MARK: - iPad (Sidebar)

    private var iPadLayout: some View {
        NavigationSplitView {
            sidebarList
                .navigationTitle("Timelord")
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button {
                                showingManualEntry = true
                            } label: {
                                Label("New Entry", systemImage: "plus.circle")
                            }

                            Spacer()

                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
        } detail: {
            detailContent(for: selectedTab)
        }
    }

    private var sidebarList: some View {
        List {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                }
                .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.15) : nil)
            }
        }
    }

    // MARK: - Content Builders

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .timer:
            NavigationStack {
                TimerView(timerService: timerService, selectedTab: $selectedTab)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showingManualEntry = true
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
            }
        case .timeline:
            NavigationStack {
                DayTimelineView()
                    .navigationTitle("Timeline")
            }
        case .clients:
            NavigationStack {
                ClientListView()
                    .navigationTitle("Clients")
            }
        case .projects:
            NavigationStack {
                ProjectListView()
                    .navigationTitle("Projects")
            }
        case .reports:
            ReportsView()
        }
    }

    @ViewBuilder
    private func detailContent(for tab: Tab) -> some View {
        switch tab {
        case .timer:
            NavigationStack {
                TimerView(timerService: timerService, selectedTab: $selectedTab)
                    .navigationTitle("Timer")
            }
        case .timeline:
            NavigationStack {
                DayTimelineView()
                    .navigationTitle("Timeline")
            }
        case .clients:
            NavigationStack {
                ClientListView()
                    .navigationTitle("Clients")
            }
        case .projects:
            NavigationStack {
                ProjectListView()
                    .navigationTitle("Projects")
            }
        case .reports:
            ReportsView()
        }
    }

    // MARK: - Watch Sync

    private func setupWatchSync() {
        // When watch sends a timer action, mirror it on this device
        WatchSyncService.shared.onTimerAction = { [timerService] action, projectID, projectName, colorHex in
            timerService.handleWatchAction(action, projectID: projectID, projectName: projectName, colorHex: colorHex)
        }

        // When phone timer changes, sync state to watch
        timerService.onStateChange = {
            WatchSyncService.shared.syncTimerState()
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(try! ModelContainerFactory.preview())
}
#endif
