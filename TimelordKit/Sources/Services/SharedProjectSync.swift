import Foundation

/// Lightweight project representation shared via App Group UserDefaults
/// so the watch app and widgets can read the project list without SwiftData.
public struct SharedProject: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let colorHex: String
    public let clientName: String?

    public init(id: UUID, name: String, colorHex: String, clientName: String?) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.clientName = clientName
    }

    public var displayName: String {
        if let clientName {
            return "\(clientName) — \(name)"
        }
        return name
    }
}

/// Reads and writes the shared project list to App Group UserDefaults.
public enum SharedProjectSync {
    private static let key = "com.timelord.allProjects"

    public static func write(_ projects: [SharedProject]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        TimerState.shared.set(data, forKey: key)
    }

    public static func read() -> [SharedProject] {
        guard let data = TimerState.shared.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SharedProject].self, from: data)
        else { return [] }
        return decoded
    }
}
