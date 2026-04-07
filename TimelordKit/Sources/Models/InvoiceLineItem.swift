import Foundation
import SwiftData

@Model
public final class InvoiceLineItem {
    public var id: UUID = UUID()
    public var descriptionText: String = ""
    public var quantity: Decimal = 0
    public var unitPrice: Decimal = 0
    public var amount: Decimal = 0
    public var sortOrder: Int = 0

    public var invoice: Invoice?
    public var timeEntries: [TimeEntry]? = []

    public init(
        descriptionText: String,
        quantity: Decimal,
        unitPrice: Decimal,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.descriptionText = descriptionText
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.amount = quantity * unitPrice
        self.sortOrder = sortOrder
    }
}
