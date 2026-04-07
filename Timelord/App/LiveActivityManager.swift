import ActivityKit
import Foundation
import TimelordKit

private struct UncheckedBox: @unchecked Sendable {
    let activity: Activity<TimerActivityAttributes>
    let content: ActivityContent<TimerActivityAttributes.ContentState>
}

/// Manages Live Activity lifecycle from the app target where ActivityKit is available.
@MainActor
final class LiveActivityManager {
    private var currentActivity: Activity<TimerActivityAttributes>?

    /// End any orphaned Live Activities from a previous app session.
    func endOrphanedActivities() {
        for activity in Activity<TimerActivityAttributes>.activities {
            let finalState = TimerActivityAttributes.ContentState(
                projectName: "Timer",
                isPaused: true,
                accumulatedBeforePause: 0
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            let box = UncheckedBox(activity: activity, content: content)
            Task {
                await box.activity.end(box.content, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }

    func wire(to timerService: TimerService) {
        timerService.onLiveActivityStart = { [weak self, weak timerService] in
            guard let self, let timerService else { return }
            self.startActivity(for: timerService)
        }
        timerService.onLiveActivityUpdate = { [weak self, weak timerService] in
            guard let self, let timerService else { return }
            self.updateActivity(for: timerService)
        }
        timerService.onLiveActivityEnd = { [weak self] in
            self?.endActivity()
        }
    }

    private func startActivity(for timer: TimerService) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivityManager] Live Activities not enabled")
            return
        }

        // End any existing activities (including orphans from previous sessions)
        for activity in Activity<TimerActivityAttributes>.activities {
            let finalState = TimerActivityAttributes.ContentState(
                projectName: "Timer",
                isPaused: true,
                accumulatedBeforePause: 0
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            let box = UncheckedBox(activity: activity, content: content)
            Task {
                await box.activity.end(box.content, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil

        let attributes = TimerActivityAttributes(startDate: timer.currentStartDate)
        let state = TimerActivityAttributes.ContentState(
            projectName: timer.currentProjectName ?? "Timer",
            clientName: timer.currentClientName,
            colorHex: timer.currentColorHex,
            isPaused: timer.isPaused,
            accumulatedBeforePause: timer.currentAccumulatedBeforePause
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("[LiveActivityManager] Started activity: \(currentActivity?.id ?? "nil")")
        } catch {
            print("[LiveActivityManager] Failed to start: \(error)")
        }
    }

    private func updateActivity(for timer: TimerService) {
        guard let activity = currentActivity else { return }

        let state = TimerActivityAttributes.ContentState(
            projectName: timer.currentProjectName ?? "Timer",
            clientName: timer.currentClientName,
            colorHex: timer.currentColorHex,
            isPaused: timer.isPaused,
            accumulatedBeforePause: timer.currentAccumulatedBeforePause
        )
        let content = ActivityContent(state: state, staleDate: nil)
        let box = UncheckedBox(activity: activity, content: content)

        Task {
            await box.activity.update(box.content)
        }
    }

    private func endActivity() {
        guard let activity = currentActivity else { return }
        currentActivity = nil

        let finalState = TimerActivityAttributes.ContentState(
            projectName: "Timer",
            isPaused: true,
            accumulatedBeforePause: 0
        )
        let content = ActivityContent(state: finalState, staleDate: nil)
        let box = UncheckedBox(activity: activity, content: content)

        Task {
            await box.activity.end(box.content, dismissalPolicy: .immediate)
        }
    }
}
