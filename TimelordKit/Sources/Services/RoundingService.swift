import Foundation

public enum RoundingService {
    public static func round(duration: TimeInterval, rule: RoundingRule) -> TimeInterval {
        guard rule != .none else { return duration }

        let minutes = duration / 60
        let increment = rule.minutes

        if rule.roundsUp {
            return ceil(minutes / increment) * increment * 60
        } else {
            return Darwin.round(minutes / increment) * increment * 60
        }
    }

    public static func roundedHours(duration: TimeInterval, rule: RoundingRule) -> Decimal {
        let rounded = round(duration: duration, rule: rule)
        return Decimal(rounded / 3600)
    }
}
