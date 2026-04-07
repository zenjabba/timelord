import ActivityKit
import SwiftUI
import WidgetKit
import TimelordKit

// MARK: - Widget Bundle

@main
struct TimelordWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
        QuickTimerWidget()
    }
}

// MARK: - Quick Timer Widget

struct QuickTimerWidget: Widget {
    let kind: String = "QuickTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickTimerProvider()) { entry in
            QuickTimerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Timer")
        .description("Start and track your timer from the home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Entry

struct QuickTimerEntry: TimelineEntry {
    let date: Date
    let timerState: TimerState?
    let projectName: String?
    let projectColorHex: String?
    let recentProjects: [RecentProjectEntry]

    struct RecentProjectEntry: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
    }
}

// MARK: - Timeline Provider

struct QuickTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickTimerEntry {
        QuickTimerEntry(
            date: Date(),
            timerState: nil,
            projectName: "My Project",
            projectColorHex: "#007AFF",
            recentProjects: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickTimerEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickTimerEntry>) -> Void) {
        let entry = buildEntry()
        // Refresh every 60 seconds so the static elapsed display stays roughly current.
        // The system may coalesce updates; Live Activity handles live counting separately.
        let refreshDate = Date().addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func buildEntry() -> QuickTimerEntry {
        let timerState = TimerState.load()
        let recentProjects = loadRecentProjects()
        let projectName = loadCurrentProjectName()
        let projectColorHex = loadCurrentProjectColorHex()

        return QuickTimerEntry(
            date: Date(),
            timerState: timerState,
            projectName: projectName,
            projectColorHex: projectColorHex,
            recentProjects: recentProjects
        )
    }

    // MARK: Shared UserDefaults helpers

    /// The main app writes the current project name to shared UserDefaults
    /// under "com.timelord.currentProjectName" so the widget can display it.
    private func loadCurrentProjectName() -> String? {
        TimerState.shared.string(forKey: "com.timelord.currentProjectName")
    }

    private func loadCurrentProjectColorHex() -> String? {
        TimerState.shared.string(forKey: "com.timelord.currentProjectColorHex")
    }

    /// Recent projects are stored as JSON array of {id, name, colorHex} in shared UserDefaults.
    private func loadRecentProjects() -> [QuickTimerEntry.RecentProjectEntry] {
        guard let data = TimerState.shared.data(forKey: "com.timelord.recentProjects"),
              let decoded = try? JSONDecoder().decode([RecentProjectDTO].self, from: data)
        else { return [] }

        return decoded.prefix(3).map {
            QuickTimerEntry.RecentProjectEntry(id: $0.id, name: $0.name, colorHex: $0.colorHex)
        }
    }
}

/// Lightweight DTO matching what the main app writes to shared UserDefaults.
private struct RecentProjectDTO: Codable {
    let id: UUID
    let name: String
    let colorHex: String
}

// MARK: - Widget View

struct QuickTimerWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: QuickTimerEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - System Small

    private var smallView: some View {
        VStack(spacing: 8) {
            if let timerState = entry.timerState, timerState.isRunning {
                runningTimerSmallView(timerState)
            } else {
                stoppedTimerSmallView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runningTimerSmallView(_ timerState: TimerState) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color(hex: entry.projectColorHex ?? "#007AFF"))
                .frame(width: 10, height: 10)

            if let projectName = entry.projectName {
                Text(projectName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }

            Text(timerState.elapsed.hoursMinutesSeconds)
                .font(.title2.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: entry.projectColorHex ?? "#007AFF"))
                .minimumScaleFactor(0.7)

            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stoppedTimerSmallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            Text("Start Timer")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - System Medium

    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left: current timer status
            VStack(spacing: 6) {
                if let timerState = entry.timerState, timerState.isRunning {
                    runningTimerSmallView(timerState)
                } else {
                    stoppedTimerSmallView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .padding(.vertical, 12)

            // Right: recent projects quick-start list
            VStack(alignment: .leading, spacing: 8) {
                if entry.recentProjects.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("No recent projects")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Recent")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(entry.recentProjects) { project in
                        Link(destination: URL(string: "timelord://start?projectID=\(project.id.uuidString)")!) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: project.colorHex))
                                    .frame(width: 8, height: 8)

                                Text(project.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "play.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color(hex: project.colorHex))
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
