import SwiftUI
import TimelordKit

struct WatchTimerView: View {
    var connectivity: WatchConnectivityManager

    @State private var timerState: TimerState?
    @State private var elapsed: TimeInterval = 0
    @State private var projectName: String?
    @State private var projectColorHex: String?
    @State private var selectedProjectID: UUID?
    @State private var showingProjectPicker = false
    @State private var localProjects: [SharedProject] = []

    private var allProjects: [SharedProject] {
        let wcProjects = connectivity.projects
        return wcProjects.isEmpty ? localProjects : wcProjects
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    timerDisplay
                    projectPickerButton
                    controlButtons
                    projectListSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Timelord")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refresh() }
            .onReceive(timer) { _ in tick() }
            .onChange(of: connectivity.timerState) {
                // Phone pushed a timer state update — sync to local
                if let state = connectivity.timerState {
                    timerState = state
                    elapsed = state.elapsed
                    projectName = connectivity.currentProjectName
                    projectColorHex = connectivity.currentProjectColorHex
                    selectedProjectID = state.projectID
                } else {
                    timerState = nil
                    elapsed = 0
                    projectName = nil
                    projectColorHex = nil
                    selectedProjectID = nil
                }
            }
            .sheet(isPresented: $showingProjectPicker) {
                WatchProjectPickerView(
                    projects: allProjects,
                    selectedID: $selectedProjectID,
                    onSelect: { project in
                        selectProject(project)
                        showingProjectPicker = false
                    }
                )
            }
        }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        VStack(spacing: 4) {
            Text(elapsed.hoursMinutesSeconds)
                .font(.system(.title, design: .monospaced, weight: .medium))
                .foregroundStyle(timerTint)
                .contentTransition(.numericText())

            if let name = projectName {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: projectColorHex ?? "#007AFF"))
                        .frame(width: 6, height: 6)
                    Text(name)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }

            if isPaused {
                Text("Paused")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Project Picker Button

    private var projectPickerButton: some View {
        Button {
            showingProjectPicker = true
        } label: {
            HStack(spacing: 6) {
                if let project = selectedProject {
                    Circle()
                        .fill(Color(hex: project.colorHex))
                        .frame(width: 8, height: 8)
                    Text(project.name)
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Image(systemName: "folder")
                        .font(.caption2)
                    Text("Select Project")
                        .font(.caption)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.darkGray).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 16) {
            if !isActive {
                Button {
                    start()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.green, in: Circle())
                }
                .buttonStyle(.plain)
            } else if isPaused {
                Button {
                    resume()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.green, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.red, in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.orange, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.red, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick-Start Project List

    private var projectListSection: some View {
        Group {
            if !allProjects.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Projects")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(allProjects.prefix(5)) { project in
                        Button {
                            selectProject(project)
                            start()
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: project.colorHex))
                                    .frame(width: 8, height: 8)

                                Text(project.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "play.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color(hex: project.colorHex))
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - State

    private var selectedProject: SharedProject? {
        allProjects.first { $0.id == selectedProjectID }
    }

    private var isActive: Bool {
        timerState != nil
    }

    private var isPaused: Bool {
        timerState != nil && !(timerState?.isRunning ?? true)
    }

    private var timerTint: Color {
        if isPaused {
            .orange
        } else if timerState?.isRunning == true {
            Color(hex: projectColorHex ?? "#34C759")
        } else {
            .primary
        }
    }

    // MARK: - Project Selection

    private func selectProject(_ project: SharedProject?) {
        selectedProjectID = project?.id
        projectName = project?.name
        projectColorHex = project?.colorHex

        TimerState.shared.set(project?.name, forKey: "com.timelord.currentProjectName")
        TimerState.shared.set(project?.colorHex, forKey: "com.timelord.currentProjectColorHex")

        // Update running timer's project if active
        if var state = timerState, isActive {
            state.projectID = project?.id
            state.save()
            timerState = state
        }
    }

    // MARK: - Timer Actions

    private func tick() {
        // Check if phone pushed a timer state update via WatchConnectivity
        if let wcState = connectivity.timerState, wcState != timerState {
            timerState = wcState
            elapsed = wcState.elapsed
            projectName = connectivity.currentProjectName
            projectColorHex = connectivity.currentProjectColorHex
            selectedProjectID = wcState.projectID
            return
        }

        guard let state = timerState, state.isRunning else { return }
        elapsed = state.elapsed
    }

    private func refresh() {
        timerState = TimerState.load()
        elapsed = timerState?.elapsed ?? 0
        projectName = TimerState.shared.string(forKey: "com.timelord.currentProjectName")
        projectColorHex = TimerState.shared.string(forKey: "com.timelord.currentProjectColorHex")
        localProjects = SharedProjectSync.read()
        connectivity.requestProjects()

        // Restore selected project from timer state
        if let pid = timerState?.projectID {
            selectedProjectID = pid
        }
    }

    private func start() {
        var state = TimerState()
        state.isRunning = true
        state.startDate = Date()
        state.accumulatedBeforePause = 0
        state.projectID = selectedProjectID
        state.save()
        timerState = state
        elapsed = 0

        connectivity.sendTimerAction(
            "start",
            projectID: selectedProjectID,
            projectName: projectName,
            colorHex: projectColorHex
        )
    }

    private func pause() {
        guard var state = timerState else { return }
        state.accumulatedBeforePause = state.elapsed
        state.isRunning = false
        state.save()
        timerState = state
        elapsed = state.accumulatedBeforePause

        connectivity.sendTimerAction("pause")
    }

    private func resume() {
        guard var state = timerState else { return }
        state.isRunning = true
        state.startDate = Date()
        state.save()
        timerState = state

        connectivity.sendTimerAction("resume")
    }

    private func stop() {
        TimerState.clear()
        timerState = nil
        elapsed = 0
        projectName = nil
        projectColorHex = nil
        selectedProjectID = nil

        connectivity.sendTimerAction("stop")
    }
}

#Preview {
    WatchTimerView(connectivity: WatchConnectivityManager.shared)
}
