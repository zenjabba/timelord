import Foundation
import SwiftData
import TimelordKit

@Observable
final class InvoicesViewModel {
    var selectedClient: Client?
    var dateRangeStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var dateRangeEnd: Date = Date()
    var roundingRule: RoundingRule = .none
    var taxRate: String = ""
    var invoiceNotes: String = ""
    var businessName: String = ""
    var businessAddress: String = ""

    init() {
        businessName = UserDefaults.standard.string(forKey: "invoiceBusinessName") ?? ""
        businessAddress = UserDefaults.standard.string(forKey: "invoiceBusinessAddress") ?? ""
    }

    // MARK: - Filtering

    func unbilledEntries(from entries: [TimeEntry]) -> [TimeEntry] {
        entries.filter { entry in
            guard entry.isBillable else { return false }
            guard !entry.isRunning else { return false }

            // Must belong to selected client
            if let selectedClient {
                guard entry.project?.client?.id == selectedClient.id else { return false }
            } else {
                return false
            }

            // Not already on an invoice
            let existingLineItems = entry.invoiceLineItems ?? []
            guard existingLineItems.isEmpty else { return false }

            // Within date range
            guard entry.startDate >= dateRangeStart else { return false }
            guard entry.startDate <= dateRangeEnd else { return false }

            return true
        }
    }

    // MARK: - Line Item Generation

    func generateLineItems(from entries: [TimeEntry]) -> [InvoiceLineItem] {
        let filtered = unbilledEntries(from: entries)

        // Group by project
        var grouped: [UUID: (project: Project, entries: [TimeEntry])] = [:]
        for entry in filtered {
            guard let project = entry.project else { continue }
            let key = project.id
            if grouped[key] != nil {
                grouped[key]?.entries.append(entry)
            } else {
                grouped[key] = (project: project, entries: [entry])
            }
        }

        var lineItems: [InvoiceLineItem] = []
        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            (grouped[lhs]?.project.name ?? "") < (grouped[rhs]?.project.name ?? "")
        }

        for (index, key) in sortedKeys.enumerated() {
            guard let group = grouped[key] else { continue }
            let project = group.project
            let totalDuration = group.entries.reduce(TimeInterval.zero) { $0 + $1.duration }
            let hours = RoundingService.roundedHours(duration: totalDuration, rule: roundingRule)
            let rate = project.hourlyRate ?? 0

            let item = InvoiceLineItem(
                descriptionText: project.name,
                quantity: hours,
                unitPrice: rate,
                sortOrder: index
            )

            lineItems.append(item)
        }

        return lineItems
    }

    // MARK: - Invoice Creation

    func createInvoice(context: ModelContext, entries: [TimeEntry]) -> Invoice {
        let fetchDescriptor = FetchDescriptor<Invoice>()
        let existingInvoices = (try? context.fetch(fetchDescriptor)) ?? []
        let number = nextInvoiceNumber(existingInvoices: existingInvoices)

        let currencyCode = selectedClient?.defaultCurrencyCode ?? "USD"
        let invoice = Invoice(
            invoiceNumber: number,
            client: selectedClient,
            currencyCode: currencyCode,
            issueDate: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())
        )

        invoice.businessName = businessName.isEmpty ? nil : businessName
        invoice.businessAddress = businessAddress.isEmpty ? nil : businessAddress
        invoice.notes = invoiceNotes.isEmpty ? nil : invoiceNotes

        if let parsedTax = Decimal(string: taxRate), parsedTax > 0 {
            invoice.taxRate = parsedTax
        }

        let lineItems = generateLineItems(from: entries)
        let filtered = unbilledEntries(from: entries)

        // Group entries by project to link them to line items
        var entriesByProject: [UUID: [TimeEntry]] = [:]
        for entry in filtered {
            guard let project = entry.project else { continue }
            entriesByProject[project.id, default: []].append(entry)
        }

        context.insert(invoice)

        for item in lineItems {
            item.invoice = invoice
            context.insert(item)

            // Link time entries to this line item
            let projectEntries = entriesByProject.values.first(where: { entries in
                entries.first?.project?.name == item.descriptionText
            }) ?? []
            for entry in projectEntries {
                var existing = entry.invoiceLineItems ?? []
                existing.append(item)
                entry.invoiceLineItems = existing
            }
            var itemEntries = item.timeEntries ?? []
            itemEntries.append(contentsOf: projectEntries)
            item.timeEntries = itemEntries
        }

        invoice.lineItems = lineItems
        invoice.recalculateTotals()

        saveBusinessInfo()

        return invoice
    }

    // MARK: - Invoice Number

    func nextInvoiceNumber(existingInvoices: [Invoice]) -> String {
        var maxNumber = 0
        for invoice in existingInvoices {
            let parts = invoice.invoiceNumber.split(separator: "-")
            if parts.count == 2, let num = Int(parts[1]) {
                maxNumber = max(maxNumber, num)
            }
        }
        let next = maxNumber + 1
        return String(format: "INV-%04d", next)
    }

    // MARK: - Business Info

    func saveBusinessInfo() {
        UserDefaults.standard.set(businessName, forKey: "invoiceBusinessName")
        UserDefaults.standard.set(businessAddress, forKey: "invoiceBusinessAddress")
    }

    // MARK: - Status Updates

    func markAsSent(_ invoice: Invoice) {
        invoice.status = "sent"
    }

    func markAsPaid(_ invoice: Invoice) {
        invoice.status = "paid"
    }
}
