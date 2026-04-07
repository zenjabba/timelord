import SwiftUI
import SwiftData
import TimelordKit

struct InvoiceEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Client.name) private var clients: [Client]
    @Query private var timeEntries: [TimeEntry]
    @State private var viewModel = InvoicesViewModel()
    @State private var createdInvoice: Invoice?
    @State private var showingPreview = false

    /// Optional client to pre-select when opening the editor.
    var preselectedClient: Client?

    private var previewLineItems: [InvoiceLineItem] {
        viewModel.generateLineItems(from: timeEntries)
    }

    private var unbilledCount: Int {
        viewModel.unbilledEntries(from: timeEntries).count
    }

    private var currencyCode: String {
        viewModel.selectedClient?.defaultCurrencyCode ?? "USD"
    }

    var body: some View {
        Form {
            clientSection
            dateRangeSection
            lineItemsPreviewSection
            optionsSection
            businessInfoSection
            notesSection
            generateSection
        }
        .navigationTitle("New Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .navigationDestination(isPresented: $showingPreview) {
            if let invoice = createdInvoice {
                InvoicePreviewView(invoice: invoice)
            }
        }
        .onAppear {
            if let preselectedClient, viewModel.selectedClient == nil {
                viewModel.selectedClient = preselectedClient
            }
        }
    }

    // MARK: - Sections

    private var clientSection: some View {
        Section("Client") {
            Picker("Client", selection: $viewModel.selectedClient) {
                Text("Select a client").tag(nil as Client?)
                ForEach(clients) { client in
                    Text(client.name).tag(client as Client?)
                }
            }
        }
    }

    private var dateRangeSection: some View {
        Section("Date Range") {
            DatePicker("From", selection: $viewModel.dateRangeStart, displayedComponents: .date)
            DatePicker("To", selection: $viewModel.dateRangeEnd, displayedComponents: .date)
            if viewModel.selectedClient != nil {
                Text("\(unbilledCount) unbilled entries found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lineItemsPreviewSection: some View {
        Section("Line Items") {
            if previewLineItems.isEmpty {
                Text("No billable time entries for the selected client and date range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(previewLineItems, id: \.descriptionText) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.descriptionText)
                                .font(.subheadline.weight(.medium))
                            Text("\(item.quantity.formatted()) hrs @ \(CurrencyService.format(amount: item.unitPrice, currencyCode: currencyCode))/hr")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(CurrencyService.format(amount: item.amount, currencyCode: currencyCode))
                            .font(.subheadline.monospacedDigit())
                    }
                }

                HStack {
                    Text("Subtotal")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(CurrencyService.format(
                        amount: previewLineItems.reduce(Decimal.zero) { $0 + $1.amount },
                        currencyCode: currencyCode
                    ))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Picker("Rounding", selection: $viewModel.roundingRule) {
                ForEach(RoundingRule.allCases, id: \.self) { rule in
                    Text(rule.displayName).tag(rule)
                }
            }
            HStack {
                Text("Tax Rate (%)")
                Spacer()
                TextField("0", text: $viewModel.taxRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        }
    }

    private var businessInfoSection: some View {
        Section("Business Info") {
            TextField("Business Name", text: $viewModel.businessName)
            TextField("Business Address", text: $viewModel.businessAddress, axis: .vertical)
                .lineLimit(3)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Invoice notes (optional)", text: $viewModel.invoiceNotes, axis: .vertical)
                .lineLimit(4)
        }
    }

    private var generateSection: some View {
        Section {
            Button {
                generateInvoice()
            } label: {
                HStack {
                    Spacer()
                    Label("Generate Invoice", systemImage: "doc.text.fill")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(previewLineItems.isEmpty || viewModel.selectedClient == nil)
        }
    }

    // MARK: - Actions

    private func generateInvoice() {
        let invoice = viewModel.createInvoice(context: modelContext, entries: timeEntries)
        createdInvoice = invoice
        showingPreview = true
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        InvoiceEditorView()
    }
    .modelContainer(for: Invoice.self, inMemory: true)
}
#endif
