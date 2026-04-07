import Foundation
import SwiftData
import SwiftUI
import TimelordKit

@Observable
final class TimeEntryViewModel {
    var date: Date = Date()
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600)
    var selectedProject: Project?
    var notes: String = ""
    var isBillable: Bool = true

    var duration: TimeInterval {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        guard let start = calendar.date(bySettingHour: startComponents.hour ?? 0,
                                        minute: startComponents.minute ?? 0,
                                        second: 0, of: date),
              let end = calendar.date(bySettingHour: endComponents.hour ?? 0,
                                      minute: endComponents.minute ?? 0,
                                      second: 0, of: date) else {
            return 0
        }

        return max(0, end.timeIntervalSince(start))
    }

    var isValid: Bool {
        duration > 0
    }

    func save(context: ModelContext) {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        guard let resolvedStart = calendar.date(bySettingHour: startComponents.hour ?? 0,
                                                minute: startComponents.minute ?? 0,
                                                second: 0, of: date),
              let resolvedEnd = calendar.date(bySettingHour: endComponents.hour ?? 0,
                                              minute: endComponents.minute ?? 0,
                                              second: 0, of: date) else {
            return
        }

        let entry = TimeEntry(
            startDate: resolvedStart,
            endDate: resolvedEnd,
            project: selectedProject,
            notes: notes.isEmpty ? nil : notes,
            isBillable: isBillable,
            isManual: true
        )
        context.insert(entry)
    }

    func update(entry: TimeEntry) {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        guard let resolvedStart = calendar.date(bySettingHour: startComponents.hour ?? 0,
                                                minute: startComponents.minute ?? 0,
                                                second: 0, of: date),
              let resolvedEnd = calendar.date(bySettingHour: endComponents.hour ?? 0,
                                              minute: endComponents.minute ?? 0,
                                              second: 0, of: date) else {
            return
        }

        entry.startDate = resolvedStart
        entry.endDate = resolvedEnd
        entry.duration = resolvedEnd.timeIntervalSince(resolvedStart)
        entry.project = selectedProject
        entry.notes = notes.isEmpty ? nil : notes
        entry.isBillable = isBillable
    }

    func delete(entry: TimeEntry, context: ModelContext) {
        context.delete(entry)
    }

    func loadFromEntry(_ entry: TimeEntry) {
        date = entry.startDate
        startTime = entry.startDate
        endTime = entry.endDate ?? entry.startDate.addingTimeInterval(entry.duration)
        selectedProject = entry.project
        notes = entry.notes ?? ""
        isBillable = entry.isBillable
    }
}
