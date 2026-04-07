import Foundation
import Observation
import TimelordKit

// MARK: - Supporting Types

enum DateRange: Equatable {
    case week
    case month
    case custom(start: Date, end: Date)

    static func == (lhs: DateRange, rhs: DateRange) -> Bool {
        switch (lhs, rhs) {
        case (.week, .week): return true
        case (.month, .month): return true
        case let (.custom(s1, e1), .custom(s2, e2)):
            return s1 == s2 && e1 == e2
        default: return false
        }
    }
}

enum BillableFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case billableOnly = "Billable Only"
    case nonBillableOnly = "Non-Billable"

    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
final class ReportsViewModel {

    // MARK: - Properties

    var dateRange: DateRange = .week
    var referenceDate: Date = Date()
    var entries: [TimeEntry] = []
    var filterClient: Client?
    var filterBillable: BillableFilter = .all
    var roundingRule: RoundingRule = .none
    var showingFilterSheet: Bool = false
    var showingShareSheet: Bool = false
    var exportFileURL: URL?

    // MARK: - Date Computation

    var startDate: Date {
        switch dateRange {
        case .week:
            return referenceDate.startOfWeek
        case .month:
            return referenceDate.startOfMonth
        case .custom(let start, _):
            return start
        }
    }

    var endDate: Date {
        let calendar = Calendar.current
        switch dateRange {
        case .week:
            return calendar.date(byAdding: .day, value: 6, to: startDate)?.endOfDay ?? startDate.endOfDay
        case .month:
            return referenceDate.endOfMonth.endOfDay
        case .custom(_, let end):
            return end.endOfDay
        }
    }

    var dateRangeTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)

        let endFormatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate) {
            if calendar.component(.month, from: startDate) == calendar.component(.month, from: endDate) {
                endFormatter.dateFormat = "d, yyyy"
            } else {
                endFormatter.dateFormat = "MMM d, yyyy"
            }
        } else {
            endFormatter.dateFormat = "MMM d, yyyy"
        }
        let end = endFormatter.string(from: endDate)

        return "\(start) \u{2013} \(end)"
    }

    // MARK: - Filtered Entries

    var filteredEntries: [TimeEntry] {
        entries.filter { entry in
            guard entry.startDate >= startDate, entry.startDate <= endDate else { return false }

            if let client = filterClient {
                guard entry.project?.client === client else { return false }
            }

            switch filterBillable {
            case .all:
                break
            case .billableOnly:
                guard entry.isBillable else { return false }
            case .nonBillableOnly:
                guard !entry.isBillable else { return false }
            }

            return true
        }
    }

    // MARK: - Aggregations

    var totalHours: Double {
        filteredEntries.reduce(0.0) { total, entry in
            let rounded = RoundingService.round(duration: entry.duration, rule: roundingRule)
            return total + rounded / 3600
        }
    }

    var billableHours: Double {
        filteredEntries.filter(\.isBillable).reduce(0.0) { total, entry in
            let rounded = RoundingService.round(duration: entry.duration, rule: roundingRule)
            return total + rounded / 3600
        }
    }

    var totalsByCurrency: [(currencyCode: String, amount: Decimal)] {
        var amountsByCurrency: [String: Decimal] = [:]

        for entry in filteredEntries where entry.isBillable {
            guard let project = entry.project, let rate = project.hourlyRate else { continue }
            let hours = RoundingService.roundedHours(duration: entry.duration, rule: roundingRule)
            let amount = rate * hours
            let currency = project.resolvedCurrencyCode
            amountsByCurrency[currency, default: 0] += amount
        }

        return amountsByCurrency
            .map { (currencyCode: $0.key, amount: $0.value) }
            .sorted { $0.currencyCode < $1.currencyCode }
    }

    var dailyHours: [(date: Date, hours: Double)] {
        let calendar = Calendar.current
        var grouped: [Date: Double] = [:]

        // Pre-populate all days in range
        var current = startDate.startOfDay
        let rangeEnd = endDate.startOfDay
        while current <= rangeEnd {
            grouped[current] = 0
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
        }

        for entry in filteredEntries {
            let day = entry.startDate.startOfDay
            let rounded = RoundingService.round(duration: entry.duration, rule: roundingRule)
            grouped[day, default: 0] += rounded / 3600
        }

        return grouped
            .map { (date: $0.key, hours: $0.value) }
            .sorted { $0.date < $1.date }
    }

    var clientBreakdown: [(clientName: String, colorHex: String, hours: Double, amount: Decimal, currencyCode: String)] {
        struct ClientKey: Hashable {
            let name: String
            let colorHex: String
            let currencyCode: String
        }

        var grouped: [ClientKey: (hours: Double, amount: Decimal)] = [:]

        for entry in filteredEntries {
            let clientName = entry.project?.client?.name ?? "No Client"
            let colorHex = entry.project?.client?.colorHex ?? "#8E8E93"
            let currencyCode = entry.project?.resolvedCurrencyCode ?? "USD"
            let key = ClientKey(name: clientName, colorHex: colorHex, currencyCode: currencyCode)

            let rounded = RoundingService.round(duration: entry.duration, rule: roundingRule)
            let hours = rounded / 3600

            var amount: Decimal = 0
            if entry.isBillable, let rate = entry.project?.hourlyRate {
                amount = rate * RoundingService.roundedHours(duration: entry.duration, rule: roundingRule)
            }

            let existing = grouped[key] ?? (hours: 0, amount: 0)
            grouped[key] = (hours: existing.hours + hours, amount: existing.amount + amount)
        }

        return grouped
            .map { (clientName: $0.key.name, colorHex: $0.key.colorHex, hours: $0.value.hours, amount: $0.value.amount, currencyCode: $0.key.currencyCode) }
            .sorted { $0.hours > $1.hours }
    }

    // MARK: - Navigation

    func goToPreviousPeriod() {
        let calendar = Calendar.current
        switch dateRange {
        case .week:
            referenceDate = calendar.date(byAdding: .weekOfYear, value: -1, to: referenceDate) ?? referenceDate
        case .month:
            referenceDate = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        case .custom:
            break
        }
    }

    func goToNextPeriod() {
        let calendar = Calendar.current
        switch dateRange {
        case .week:
            referenceDate = calendar.date(byAdding: .weekOfYear, value: 1, to: referenceDate) ?? referenceDate
        case .month:
            referenceDate = calendar.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
        case .custom:
            break
        }
    }

    // MARK: - Export

    func exportCSV() -> URL? {
        CSVExportService.writeToFile(entries: filteredEntries, roundingRule: roundingRule)
    }
}
