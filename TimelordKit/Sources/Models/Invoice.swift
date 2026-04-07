import Foundation
import SwiftData

@Model
public final class Invoice {
    public var id: UUID = UUID()
    public var invoiceNumber: String = ""
    public var issueDate: Date = Date()
    public var dueDate: Date?
    public var status: String = "draft"
    public var currencyCode: String = "USD"
    public var subtotal: Decimal = 0
    public var taxRate: Decimal?
    public var totalAmount: Decimal = 0
    public var notes: String?
    public var pdfData: Data?
    public var createdAt: Date = Date()

    public var businessName: String?
    public var businessAddress: String?
    public var businessLogoData: Data?

    public var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \InvoiceLineItem.invoice)
    public var lineItems: [InvoiceLineItem]? = []

    public init(
        invoiceNumber: String,
        client: Client? = nil,
        currencyCode: String = "USD",
        issueDate: Date = Date(),
        dueDate: Date? = nil
    ) {
        self.id = UUID()
        self.invoiceNumber = invoiceNumber
        self.client = client
        self.currencyCode = currencyCode
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.createdAt = Date()
    }

    public var isDraft: Bool { status == "draft" }
    public var isSent: Bool { status == "sent" }
    public var isPaid: Bool { status == "paid" }

    public var sortedLineItems: [InvoiceLineItem] {
        (lineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    public func recalculateTotals() {
        subtotal = sortedLineItems.reduce(Decimal.zero) { $0 + $1.amount }
        if let taxRate {
            totalAmount = subtotal + (subtotal * taxRate / 100)
        } else {
            totalAmount = subtotal
        }
    }
}
