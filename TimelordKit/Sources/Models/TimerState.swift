import Foundation

public struct TimerState: Codable, Sendable, Equatable {
    public var isRunning: Bool
    public var startDate: Date
    public var accumulatedBeforePause: TimeInterval
    public var projectID: UUID?
    public var notes: String?
    public var projectName: String?
    public var clientName: String?
    public var colorHex: String?

    public init(
        isRunning: Bool = false,
        startDate: Date = Date(),
        accumulatedBeforePause: TimeInterval = 0,
        projectID: UUID? = nil,
        notes: String? = nil,
        projectName: String? = nil,
        clientName: String? = nil,
        colorHex: String? = nil
    ) {
        self.isRunning = isRunning
        self.startDate = startDate
        self.accumulatedBeforePause = accumulatedBeforePause
        self.projectID = projectID
        self.notes = notes
        self.projectName = projectName
        self.clientName = clientName
        self.colorHex = colorHex
    }

    public var elapsed: TimeInterval {
        guard isRunning else { return accumulatedBeforePause }
        return Date().timeIntervalSince(startDate) + accumulatedBeforePause
    }

    public static let userDefaultsKey = "com.timelord.timerState"

    public static var shared: UserDefaults {
        UserDefaults(suiteName: "group.com.digitalmonks.timelord.app") ?? .standard
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.shared.set(data, forKey: Self.userDefaultsKey)
    }

    public static func load() -> TimerState? {
        guard let data = shared.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(TimerState.self, from: data)
    }

    public static func clear() {
        shared.removeObject(forKey: userDefaultsKey)
    }
}
