import Foundation
import SwiftData

@Model
public final class Project {
    public var id: UUID = UUID()
    public var name: String = ""
    public var colorHex: String?
    public var hourlyRate: Decimal?
    public var currencyCode: String?
    public var isBillable: Bool = true
    public var isArchived: Bool = false
    public var createdAt: Date = Date()

    public var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    public var timeEntries: [TimeEntry]? = []

    public init(
        name: String,
        client: Client? = nil,
        colorHex: String? = nil,
        hourlyRate: Decimal? = nil,
        currencyCode: String? = nil,
        isBillable: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.client = client
        self.colorHex = colorHex
        self.hourlyRate = hourlyRate
        self.currencyCode = currencyCode
        self.isBillable = isBillable
        self.createdAt = Date()
    }

    public var resolvedColorHex: String {
        colorHex ?? client?.colorHex ?? "#007AFF"
    }

    public var resolvedCurrencyCode: String {
        currencyCode ?? client?.defaultCurrencyCode ?? "USD"
    }

    public var displayName: String {
        if let clientName = client?.name {
            return "\(clientName) — \(name)"
        }
        return name
    }
}
