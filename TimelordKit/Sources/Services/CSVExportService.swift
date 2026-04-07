import Foundation

public enum CSVExportService {

    // MARK: - Public API

    /// Generates a CSV string from the given time entries with optional duration rounding.
    public static func export(entries: [TimeEntry], roundingRule: RoundingRule) -> String {
        var lines: [String] = []

        // Header
        lines.append("Date,Client,Project,Description,Start Time,End Time,Duration (hours),Billable,Rate,Amount,Currency")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        for entry in entries.sorted(by: { $0.startDate < $1.startDate }) {
            let date = dateFormatter.string(from: entry.startDate)
            let clientName = csvEscape(entry.project?.client?.name ?? "")
            let projectName = csvEscape(entry.project?.name ?? "")
            let description = csvEscape(entry.notes ?? "")
            let startTime = timeFormatter.string(from: entry.startDate)
            let endTime = entry.endDate.map { timeFormatter.string(from: $0) } ?? ""

            let roundedDuration = RoundingService.round(duration: entry.duration, rule: roundingRule)
            let hours = roundedDuration / 3600
            let hoursString = String(format: "%.2f", hours)

            let billable = entry.isBillable ? "Yes" : "No"

            let rate: String
            let amount: String
            let currency: String

            if entry.isBillable, let project = entry.project, let hourlyRate = project.hourlyRate {
                rate = "\(hourlyRate)"
                let roundedHours = RoundingService.roundedHours(duration: entry.duration, rule: roundingRule)
                let entryAmount = hourlyRate * roundedHours
                amount = "\(entryAmount)"
                currency = project.resolvedCurrencyCode
            } else {
                rate = ""
                amount = ""
                currency = entry.project?.resolvedCurrencyCode ?? ""
            }

            let fields = [
                date,
                clientName,
                projectName,
                description,
                startTime,
                endTime,
                hoursString,
                billable,
                rate,
                amount,
                currency,
            ]

            lines.append(fields.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    /// Writes the CSV to a temporary file and returns the file URL, or `nil` on failure.
    public static func writeToFile(entries: [TimeEntry], roundingRule: RoundingRule) -> URL? {
        let csv = export(entries: entries, roundingRule: roundingRule)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let fileName = "timelord_export_\(timestamp).csv"
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
