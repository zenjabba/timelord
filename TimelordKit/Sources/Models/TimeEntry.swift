import Foundation
import SwiftData

@Model
public final class TimeEntry {
    public var id: UUID = UUID()
    public var startDate: Date = Date()
    public var endDate: Date?
    public var duration: TimeInterval = 0
    public var notes: String?
    public var isBillable: Bool = true
    public var isManual: Bool = false
    public var isFromCalendar: Bool = false
    public var calendarEventID: String?
    public var createdAt: Date = Date()

    public var project: Project?

    @Relationship(inverse: \InvoiceLineItem.timeEntries)
    public var invoiceLineItems: [InvoiceLineItem]? = []

    public init(
        startDate: Date,
        endDate: Date? = nil,
        project: Project? = nil,
        notes: String? = nil,
        isBillable: Bool = true,
        isManual: Bool = false
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.project = project
        self.notes = notes
        self.isBillable = isBillable
        self.isManual = isManual
        self.createdAt = Date()

        if let endDate {
            self.duration = endDate.timeIntervalSince(startDate)
        }
    }

    public var isRunning: Bool {
        endDate == nil && !isManual
    }

    public func stop(at date: Date = Date()) {
        endDate = date
        duration = date.timeIntervalSince(startDate)
    }

    public var resolvedCurrencyCode: String {
        project?.resolvedCurrencyCode ?? "USD"
    }

    public var billableAmount: Decimal? {
        guard isBillable, let rate = project?.hourlyRate else { return nil }
        let hours = Decimal(duration / 3600)
        return hours * rate
    }
}
