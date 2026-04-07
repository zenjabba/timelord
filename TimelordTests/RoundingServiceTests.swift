import Foundation
import Testing
@testable import TimelordKit

@Suite("RoundingService Tests")
struct RoundingServiceTests {
    @Test("No rounding returns original duration")
    func noRounding() {
        let duration: TimeInterval = 754 // 12m 34s
        let result = RoundingService.round(duration: duration, rule: .none)
        #expect(result == duration)
    }

    @Test("Round to nearest 5 minutes")
    func nearestFive() {
        // 12m 34s → 15m (closer to 15 than 10)
        let result = RoundingService.round(duration: 754, rule: .nearest5)
        #expect(result == 900) // 15 * 60

        // 12m 00s → 10m (closer to 10 than 15)
        let result2 = RoundingService.round(duration: 720, rule: .nearest5)
        #expect(result2 == 600) // 10 * 60
    }

    @Test("Round up to 15 minutes")
    func roundUpFifteen() {
        // 1m → 15m
        let result = RoundingService.round(duration: 60, rule: .roundUp15)
        #expect(result == 900)

        // 16m → 30m
        let result2 = RoundingService.round(duration: 960, rule: .roundUp15)
        #expect(result2 == 1800)

        // Exactly 15m → 15m
        let result3 = RoundingService.round(duration: 900, rule: .roundUp15)
        #expect(result3 == 900)
    }

    @Test("Round to nearest 6 minutes (1/10 hour)")
    func nearestSix() {
        // 7m → 6m
        let result = RoundingService.round(duration: 420, rule: .nearest6)
        #expect(result == 360)

        // 10m → 12m
        let result2 = RoundingService.round(duration: 600, rule: .nearest6)
        #expect(result2 == 720)
    }

    @Test("Rounded hours calculation")
    func roundedHours() {
        // 90 minutes → 1.5 hours, no rounding
        let hours = RoundingService.roundedHours(duration: 5400, rule: .none)
        #expect(hours == Decimal(1.5))
    }
}
