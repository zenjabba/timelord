import Foundation
import SwiftData

@Model
public final class Client {
    public var id: UUID = UUID()
    public var name: String = ""
    public var email: String?
    public var colorHex: String = "#007AFF"
    public var defaultCurrencyCode: String = "USD"
    public var notes: String?
    public var isArchived: Bool = false
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Project.client)
    public var projects: [Project]? = []

    @Relationship(deleteRule: .nullify, inverse: \Invoice.client)
    public var invoices: [Invoice]? = []

    public init(
        name: String,
        email: String? = nil,
        colorHex: String = "#007AFF",
        defaultCurrencyCode: String = "USD",
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.colorHex = colorHex
        self.defaultCurrencyCode = defaultCurrencyCode
        self.notes = notes
        self.createdAt = Date()
    }

    public var activeProjects: [Project] {
        (projects ?? []).filter { !$0.isArchived }
    }

    public var displayColor: String {
        colorHex
    }
}
