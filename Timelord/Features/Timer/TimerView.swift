import SwiftUI
import SwiftData
import TimelordKit

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TimeEntry.startDate, order: .reverse)
    private var allEntries: [TimeEntry]

    private var todayEntries: [TimeEntry] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { $0.startDate >= startOfToday }
    }

    @Query(filter: #Predicate<Project> { !$0.isArchived },
           sort: \Project.name)
    private var projects: [Project]

    @State private var viewModel: TimerViewModel
    @State private var editingEntry: TimeEntry?
    @Binding var selectedTab: ContentView.Tab

    init(timerService: TimerService, selectedTab: Binding<ContentView.Tab>) {
        _viewModel = State(initialValue: TimerViewModel(timerService: timerService))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                timerDisplay
                controlButtons
                projectPicker
                notesField
                todaySection
            }
            .padding()
        }
        .onAppear {
            restoreSelectedProject()
            syncProjectsToSharedDefaults()
        }
        .onChange(of: projects) { syncProjectsToSharedDefaults() }
        .navigationTitle("Timer")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingSavedTimers = true
                } label: {
                    Image(systemName: "bookmark")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSavedTimers) {
            NavigationStack {
                SavedTimersView(viewModel: viewModel)
                    .navigationTitle("Saved Timers")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                viewModel.showingSavedTimers = false
                            }
                        }
                    }
            }
        }
        .sheet(item: $editingEntry) { entry in
            TimeEntryEditView(entry: entry)
        }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text(viewModel.timerService.elapsed.hoursMinutesSeconds)
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .foregroundStyle(viewModel.timerTint)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: viewModel.timerService.elapsed)

            if let project = viewModel.selectedProject {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: project.resolvedColorHex))
                        .frame(width: 8, height: 8)

                    Text(project.name)
                        .font(.subheadline.weight(.medium))

                    if let clientName = project.client?.name {
                        Text("· \(clientName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if viewModel.isActive {
                Text("No Project")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if viewModel.timerService.isPaused {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 20) {
            if !viewModel.isActive {
                // Stopped state: Play button
                Button {
                    viewModel.start()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(.green, in: Circle())
                }

            } else if viewModel.timerService.isPaused {
                // Paused state: Resume + Stop
                Button {
                    viewModel.resume()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.green, in: Circle())
                }

                Button {
                    viewModel.stop(context: modelContext)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.red, in: Circle())
                }

                Button {
                    viewModel.discard()
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                        .background(.red.opacity(0.12), in: Circle())
                }

            } else {
                // Running state: Pause + Stop
                Button {
                    viewModel.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.orange, in: Circle())
                }

                Button {
                    viewModel.stop(context: modelContext)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.red, in: Circle())
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Project Picker

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Menu {
                Button {
                    viewModel.selectProject(nil)
                } label: {
                    if viewModel.selectedProject == nil {
                        Label("No Project", systemImage: "checkmark")
                    } else {
                        Text("No Project")
                    }
                }

                Divider()

                ForEach(projects) { project in
                    Button {
                        viewModel.selectProject(project)
                    } label: {
                        if viewModel.selectedProject?.id == project.id {
                            Label {
                                Text(project.displayName)
                            } icon: {
                                Image(systemName: "checkmark")
                            }
                        } else {
                            Text(project.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if let project = viewModel.selectedProject {
                        Circle()
                            .fill(Color(hex: project.resolvedColorHex))
                            .frame(width: 10, height: 10)

                        Text(project.displayName)
                            .foregroundStyle(.primary)
                    } else {
                        Text("No Project")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Notes Field

    private var notesField: some View {
        TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
            .lineLimit(1...3)
            .textFieldStyle(.roundedBorder)
            .onChange(of: viewModel.notes) {
                if viewModel.isActive {
                    viewModel.timerService.currentNotes = viewModel.notes
                }
            }
    }

    // MARK: - Restore Project Selection

    private func restoreSelectedProject() {
        guard viewModel.selectedProject == nil,
              let projectID = viewModel.timerService.currentProjectID,
              let project = projects.first(where: { $0.id == projectID }) else { return }
        viewModel.selectedProject = project
    }

    // MARK: - Shared Project Sync

    private func syncProjectsToSharedDefaults() {
        let shared = projects.map {
            SharedProject(
                id: $0.id,
                name: $0.name,
                colorHex: $0.resolvedColorHex,
                clientName: $0.client?.name
            )
        }
        SharedProjectSync.write(shared)
        WatchSyncService.shared.syncProjects(shared)
    }

    // MARK: - Today's Entries

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)

                Spacer()

                let totalDuration = todayEntries.reduce(TimeInterval.zero) { $0 + $1.duration }
                Text(totalDuration.hoursMinutes)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if todayEntries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No entries today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(todayEntries) { entry in
                        TodayEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingEntry = entry
                            }
                            .onLongPressGesture {
                                selectedTab = .timeline
                            }

                        if entry.id != todayEntries.last?.id {
                            Divider()
                                .padding(.leading, 28)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Today Entry Row

private struct TodayEntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(projectColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.project?.name ?? "No Project")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 4) {
                    Text(entry.startDate.shortTimeString)
                    if let end = entry.endDate {
                        Text("–")
                        Text(end.shortTimeString)
                    } else {
                        Text("– running")
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(entry.duration.hoursMinutes)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var projectColor: Color {
        if let hex = entry.project?.resolvedColorHex {
            Color(hex: hex)
        } else {
            .gray
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var tab: ContentView.Tab = .timer
    NavigationStack {
        TimerView(timerService: TimerService(), selectedTab: $tab)
    }
    .modelContainer(try! ModelContainerFactory.preview())
}
#endif
