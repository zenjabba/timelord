import Combine
import Foundation
import SwiftData

@MainActor
@Observable
public final class TimerService {

    // MARK: - Published State

    public private(set) var isRunning: Bool = false
    public private(set) var isPaused: Bool = false
    public private(set) var elapsed: TimeInterval = 0
    public var currentProjectID: UUID?
    public var currentNotes: String = ""

    // MARK: - Private

    private var startDate: Date = Date()
    private var accumulatedBeforePause: TimeInterval = 0
    private var tickCancellable: AnyCancellable?

    // Live Activity metadata (public so the activity manager can read them)
    public private(set) var currentProjectName: String?
    public private(set) var currentClientName: String?
    public private(set) var currentColorHex: String = "#007AFF"
    public var currentStartDate: Date { startDate }
    public var currentAccumulatedBeforePause: TimeInterval { accumulatedBeforePause }

    /// Called after every timer state change so external systems (e.g. Watch) can sync.
    public var onStateChange: (() -> Void)?

    /// Called when a Live Activity should be started/updated/ended.
    public var onLiveActivityStart: (() -> Void)?
    public var onLiveActivityUpdate: (() -> Void)?
    public var onLiveActivityEnd: (() -> Void)?

    // MARK: - Init

    public init() {}

    // MARK: - Core Methods

    public func start(
        projectID: UUID? = nil,
        notes: String? = nil,
        projectName: String? = nil,
        clientName: String? = nil,
        colorHex: String? = nil
    ) {
        stopTick()

        startDate = Date()
        accumulatedBeforePause = 0
        isRunning = true
        isPaused = false
        currentProjectID = projectID
        currentNotes = notes ?? ""
        elapsed = 0

        currentProjectName = projectName
        currentClientName = clientName
        currentColorHex = colorHex ?? "#007AFF"

        persistState()
        startTick()
        onLiveActivityStart?()
        onStateChange?()
    }

    public func stop(context: ModelContext) {
        stopTick()

        let endDate = Date()
        let totalDuration = accumulatedBeforePause + (isRunning && !isPaused
            ? endDate.timeIntervalSince(startDate)
            : 0)

        // Look up the project if we have an ID
        var project: Project?
        if let projectID = currentProjectID {
            let descriptor = FetchDescriptor<Project>(
                predicate: #Predicate { $0.id == projectID }
            )
            project = try? context.fetch(descriptor).first
        }

        let entry = TimeEntry(
            startDate: endDate.addingTimeInterval(-totalDuration),
            endDate: endDate,
            project: project,
            notes: currentNotes.isEmpty ? nil : currentNotes,
            isBillable: project?.isBillable ?? true
        )
        context.insert(entry)

        onLiveActivityEnd?()
        resetState()
        TimerState.clear()
        onStateChange?()
    }

    public func pause() {
        guard isRunning, !isPaused else { return }

        stopTick()

        let now = Date()
        accumulatedBeforePause += now.timeIntervalSince(startDate)
        isPaused = true
        elapsed = accumulatedBeforePause

        persistState()
        onLiveActivityUpdate?()
        onStateChange?()
    }

    public func resume() {
        guard isRunning, isPaused else { return }

        startDate = Date()
        isPaused = false

        persistState()
        startTick()
        onLiveActivityUpdate?()
        onStateChange?()
    }

    public func discard() {
        stopTick()
        onLiveActivityEnd?()
        resetState()
        TimerState.clear()
        onStateChange?()
    }

    /// Handle a timer command from the Apple Watch.
    public func handleWatchAction(_ action: String, projectID: UUID?, projectName: String?, colorHex: String?) {
        switch action {
        case "start":
            start(projectID: projectID, projectName: projectName, colorHex: colorHex)
        case "pause":
            pause()
        case "resume":
            resume()
        case "stop":
            discard()
        default:
            break
        }
    }

    public func restore() {
        guard let state = TimerState.load() else { return }

        currentProjectID = state.projectID
        currentNotes = state.notes ?? ""
        accumulatedBeforePause = state.accumulatedBeforePause
        startDate = state.startDate
        currentProjectName = state.projectName
        currentClientName = state.clientName
        currentColorHex = state.colorHex ?? "#007AFF"

        if state.isRunning {
            isRunning = true
            isPaused = false
            elapsed = Date().timeIntervalSince(state.startDate) + state.accumulatedBeforePause
            startTick()
            onLiveActivityStart?()
        } else {
            isRunning = true
            isPaused = true
            elapsed = state.accumulatedBeforePause
            onLiveActivityStart?()
        }
        onStateChange?()
    }

    // MARK: - Timer Tick

    private func startTick() {
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsed = self.accumulatedBeforePause + Date().timeIntervalSince(self.startDate)
            }
    }

    private func stopTick() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    // MARK: - Persistence

    private func persistState() {
        let state = TimerState(
            isRunning: isRunning && !isPaused,
            startDate: startDate,
            accumulatedBeforePause: accumulatedBeforePause,
            projectID: currentProjectID,
            notes: currentNotes.isEmpty ? nil : currentNotes,
            projectName: currentProjectName,
            clientName: currentClientName,
            colorHex: currentColorHex == "#007AFF" ? nil : currentColorHex
        )
        state.save()
    }

    private func resetState() {
        isRunning = false
        isPaused = false
        elapsed = 0
        accumulatedBeforePause = 0
        currentProjectID = nil
        currentNotes = ""
        currentProjectName = nil
        currentClientName = nil
        currentColorHex = "#007AFF"
    }
}
