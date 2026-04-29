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
        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: dateRangeStart)
        let rangeEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: dateRangeEnd)) ?? dateRangeEnd

        return entries.filter { entry in
            guard entry.isBillable else { return false }
            guard !entry.isRunning else { return false }

            if let selectedClient {
                guard entry.project?.client?.id == selectedClient.id else { return false }
            } else {
                return false
            }

            let existingLineItems = entry.invoiceLineItems ?? []
            guard existingLineItems.isEmpty else { return false }

            guard entry.startDate >= rangeStart else { return false }
            guard entry.startDate <= rangeEnd else { return false }

            return true
        }
    }

    // MARK: - Line Item Generation

    private struct ProjectGroup {
        let project: Project
        let entries: [TimeEntry]
    }

    private func groupedByProject(_ entries: [TimeEntry]) -> [ProjectGroup] {
        var grouped: [UUID: ProjectGroup] = [:]
        for entry in entries {
            guard let project = entry.project else { continue }
            let existing = grouped[project.id]?.entries ?? []
            grouped[project.id] = ProjectGroup(project: project, entries: existing + [entry])
        }
        return grouped.values.sorted { $0.project.name < $1.project.name }
    }

    func generateLineItems(from entries: [TimeEntry]) -> [InvoiceLineItem] {
        let groups = groupedByProject(unbilledEntries(from: entries))

        return groups.enumerated().map { index, group in
            let totalDuration = group.entries.reduce(TimeInterval.zero) { $0 + $1.duration }
            let hours = RoundingService.roundedHours(duration: totalDuration, rule: roundingRule)
            let rate = group.project.hourlyRate ?? 0

            return InvoiceLineItem(
                descriptionText: group.project.name,
                quantity: hours,
                unitPrice: rate,
                sortOrder: index
            )
        }
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

        let groups = groupedByProject(unbilledEntries(from: entries))
        context.insert(invoice)

        var lineItems: [InvoiceLineItem] = []
        for (index, group) in groups.enumerated() {
            let totalDuration = group.entries.reduce(TimeInterval.zero) { $0 + $1.duration }
            let hours = RoundingService.roundedHours(duration: totalDuration, rule: roundingRule)
            let rate = group.project.hourlyRate ?? 0

            let item = InvoiceLineItem(
                descriptionText: group.project.name,
                quantity: hours,
                unitPrice: rate,
                sortOrder: index
            )
            item.invoice = invoice
            context.insert(item)

            for entry in group.entries {
                var existing = entry.invoiceLineItems ?? []
                existing.append(item)
                entry.invoiceLineItems = existing
            }
            item.timeEntries = group.entries

            lineItems.append(item)
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
