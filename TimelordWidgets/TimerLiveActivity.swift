import ActivityKit
import SwiftUI
import WidgetKit
import TimelordKit

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // MARK: - Lock Screen / Banner Presentation
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.7))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Region
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: context.state.colorHex))
                            .frame(width: 12, height: 12)

                        Text(context.state.projectName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Label("Paused", systemImage: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        timerText(
                            startDate: context.attributes.startDate,
                            accumulated: context.state.accumulatedBeforePause
                        )
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color(hex: context.state.colorHex))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let clientName = context.state.clientName {
                        HStack {
                            Image(systemName: "building.2")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(clientName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {}
            } compactLeading: {
                // MARK: - Compact Leading
                Circle()
                    .fill(Color(hex: context.state.colorHex))
                    .frame(width: 10, height: 10)
                    .padding(.leading, 4)
            } compactTrailing: {
                // MARK: - Compact Trailing
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    timerText(
                        startDate: context.attributes.startDate,
                        accumulated: context.state.accumulatedBeforePause
                    )
                    .font(.caption2.monospacedDigit())
                }
            } minimal: {
                // MARK: - Minimal
                Circle()
                    .fill(Color(hex: context.state.colorHex))
                    .frame(width: 10, height: 10)
            }
        }
    }

    // MARK: - Helpers

    /// Builds a system-rendered live timer `Text` that counts up from the effective start,
    /// accounting for any previously accumulated time.
    private func timerText(startDate: Date, accumulated: TimeInterval) -> Text {
        let effectiveStart = startDate.addingTimeInterval(-accumulated)
        return Text(
            timerInterval: effectiveStart...Date.distantFuture,
            countsDown: false
        )
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        HStack(spacing: 12) {
            // Project color indicator
            Circle()
                .fill(Color(hex: context.state.colorHex))
                .frame(width: 12, height: 12)

            // Project & client name
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.projectName)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                if let clientName = context.state.clientName {
                    Text(clientName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Timer display
            if context.state.isPaused {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.accumulatedBeforePause.hoursMinutesSeconds)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(isLuminanceReduced ? 0.6 : 1.0))

                    Label("Paused", systemImage: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } else {
                timerText(
                    startDate: context.attributes.startDate,
                    accumulated: context.state.accumulatedBeforePause
                )
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(isLuminanceReduced ? 0.6 : 1.0))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func timerText(startDate: Date, accumulated: TimeInterval) -> Text {
        let effectiveStart = startDate.addingTimeInterval(-accumulated)
        return Text(
            timerInterval: effectiveStart...Date.distantFuture,
            countsDown: false
        )
    }
}
