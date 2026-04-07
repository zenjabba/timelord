import Foundation

public enum RoundingRule: String, Codable, CaseIterable, Sendable {
    case none
    case nearest5
    case nearest6
    case nearest10
    case nearest15
    case roundUp5
    case roundUp6
    case roundUp10
    case roundUp15

    public var displayName: String {
        switch self {
        case .none: return "No rounding"
        case .nearest5: return "Nearest 5 min"
        case .nearest6: return "Nearest 6 min (1/10 hr)"
        case .nearest10: return "Nearest 10 min"
        case .nearest15: return "Nearest 15 min (1/4 hr)"
        case .roundUp5: return "Round up 5 min"
        case .roundUp6: return "Round up 6 min (1/10 hr)"
        case .roundUp10: return "Round up 10 min"
        case .roundUp15: return "Round up 15 min (1/4 hr)"
        }
    }

    public var minutes: Double {
        switch self {
        case .none: return 0
        case .nearest5, .roundUp5: return 5
        case .nearest6, .roundUp6: return 6
        case .nearest10, .roundUp10: return 10
        case .nearest15, .roundUp15: return 15
        }
    }

    public var roundsUp: Bool {
        switch self {
        case .roundUp5, .roundUp6, .roundUp10, .roundUp15: return true
        default: return false
        }
    }
}
