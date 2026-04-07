#if os(iOS)
@preconcurrency import EventKit
import Foundation
import SwiftData

public enum CalendarImportService {
    nonisolated(unsafe) private static let store = EKEventStore()

    public static func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    public static func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }

    @MainActor
    public static func importEvents(
        from calendarIDs: [String],
        startDate: Date,
        endDate: Date,
        defaultProject: Project?,
        context: ModelContext
    ) async throws -> Int {
        let calendars = store.calendars(for: .event).filter {
            calendarIDs.contains($0.calendarIdentifier)
        }

        guard !calendars.isEmpty else { return 0 }

        let predicate = store.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        let events = store.events(matching: predicate)

        var importedCount = 0

        for event in events {
            guard let eventID = event.eventIdentifier else { continue }

            // Deduplicate: skip if already imported
            let descriptor = FetchDescriptor<TimeEntry>(
                predicate: #Predicate { $0.calendarEventID == eventID }
            )
            let existing = (try? context.fetchCount(descriptor)) ?? 0
            guard existing == 0 else { continue }

            guard let eventStart = event.startDate,
                  let eventEnd = event.endDate else { continue }

            let entry = TimeEntry(
                startDate: eventStart,
                endDate: eventEnd,
                project: defaultProject,
                notes: event.title,
                isBillable: false,
                isManual: true
            )
            entry.isFromCalendar = true
            entry.calendarEventID = eventID

            context.insert(entry)
            importedCount += 1
        }

        try context.save()
        return importedCount
    }
}
#endif
