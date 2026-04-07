import Foundation
import Observation
import TimelordKit

@Observable
final class TimelineViewModel {

    // MARK: - Properties

    var selectedDate: Date = Date()
    var entries: [TimeEntry] = []
    var showingManualEntry: Bool = false
    var showingEditEntry: Bool = false
    var selectedEntry: TimeEntry?
    var manualEntryStartTime: Date?

    // MARK: - Computed Properties

    var dateTitle: String {
        if selectedDate.isToday {
            return "Today"
        } else if selectedDate.isYesterday {
            return "Yesterday"
        } else {
            return "\(selectedDate.dayOfWeekString), \(selectedDate.shortDateString)"
        }
    }

    var totalDuration: TimeInterval {
        entriesForSelectedDate.reduce(0) { $0 + $1.duration }
    }

    var entriesForSelectedDate: [TimeEntry] {
        entries
            .filter { $0.startDate.isSameDay(as: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    var canGoToNextDay: Bool {
        !selectedDate.isToday
    }

    // MARK: - Navigation

    func goToToday() {
        selectedDate = Date()
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    func goToNextDay() {
        guard canGoToNextDay else { return }
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    // MARK: - Entry Actions

    func selectEntry(_ entry: TimeEntry) {
        selectedEntry = entry
        showingEditEntry = true
    }

    func addEntryAt(hour: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = 0
        components.second = 0
        manualEntryStartTime = Calendar.current.date(from: components)
        showingManualEntry = true
    }

    // MARK: - Layout

    func timeBlockFrame(for entry: TimeEntry, hourHeight: CGFloat) -> (yOffset: CGFloat, height: CGFloat) {
        let dayStart = selectedDate.startOfDay
        let dayEnd = selectedDate.endOfDay

        let clampedStart = max(entry.startDate, dayStart)
        let effectiveEnd = entry.endDate ?? Date()
        let clampedEnd = min(effectiveEnd, dayEnd)

        let minutesSinceStartOfDay = clampedStart.timeIntervalSince(dayStart) / 60.0
        let durationMinutes = max(clampedEnd.timeIntervalSince(clampedStart), 0) / 60.0

        let yOffset = (minutesSinceStartOfDay / 60.0) * hourHeight
        let height = max((durationMinutes / 60.0) * hourHeight, 20.0)

        return (yOffset: yOffset, height: height)
    }
}
