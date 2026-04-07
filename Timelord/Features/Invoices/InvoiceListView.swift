import SwiftUI
import SwiftData
import TimelordKit

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Invoice.createdAt, order: .reverse) private var invoices: [Invoice]
    @State private var statusFilter: StatusFilter = .all
    @State private var showingEditor = false

    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case draft = "Draft"
        case sent = "Sent"
        case paid = "Paid"

        var statusValue: String? {
            switch self {
            case .all: return nil
            case .draft: return "draft"
            case .sent: return "sent"
            case .paid: return "paid"
            }
        }
    }

    private var filteredInvoices: [Invoice] {
        guard let status = statusFilter.statusValue else { return invoices }
        return invoices.filter { $0.status == status }
    }

    var body: some View {
        List {
            if filteredInvoices.isEmpty {
                ContentUnavailableView {
                    Label("No Invoices", systemImage: "doc.text")
                } description: {
                    Text(statusFilter == .all
                         ? "Create your first invoice to get started."
                         : "No \(statusFilter.rawValue.lowercased()) invoices found.")
                }
            } else {
                ForEach(filteredInvoices) { invoice in
                    NavigationLink(value: invoice) {
                        InvoiceRow(invoice: invoice)
                    }
                }
                .onDelete(perform: deleteInvoices)
            }
        }
        .navigationTitle("Invoices")
        .navigationDestination(for: Invoice.self) { invoice in
            InvoicePreviewView(invoice: invoice)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Filter", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("New Invoice", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                InvoiceEditorView()
            }
        }
    }

    private func deleteInvoices(at offsets: IndexSet) {
        for index in offsets {
            let invoice = filteredInvoices[index]
            modelContext.delete(invoice)
        }
    }
}

// MARK: - Invoice Row

private struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(invoice.invoiceNumber)
                        .font(.headline)
                    StatusBadge(status: invoice.status)
                }
                if let clientName = invoice.client?.name {
                    Text(clientName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(invoice.issueDate.shortDateString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(CurrencyService.format(amount: invoice.totalAmount, currencyCode: invoice.currencyCode))
                .font(.headline.monospacedDigit())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String

    private var color: Color {
        switch status {
        case "sent": return .blue
        case "paid": return .green
        default: return .gray
        }
    }

    private var label: String {
        status.capitalized
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        InvoiceListView()
    }
    .modelContainer(for: Invoice.self, inMemory: true)
}
#endif
