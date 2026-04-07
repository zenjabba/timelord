#if os(iOS)
import ActivityKit
import Foundation

public struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var projectName: String
        public var clientName: String?
        public var colorHex: String
        public var isPaused: Bool
        public var accumulatedBeforePause: TimeInterval

        public init(
            projectName: String,
            clientName: String? = nil,
            colorHex: String = "#007AFF",
            isPaused: Bool = false,
            accumulatedBeforePause: TimeInterval = 0
        ) {
            self.projectName = projectName
            self.clientName = clientName
            self.colorHex = colorHex
            self.isPaused = isPaused
            self.accumulatedBeforePause = accumulatedBeforePause
        }
    }

    public var startDate: Date

    public init(startDate: Date) {
        self.startDate = startDate
    }
}
#endif
