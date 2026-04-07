import SwiftUI
import SwiftData
import TimelordKit

struct InvoicePreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var invoice: Invoice
    @State private var pdfData: Data?
    @State private var isGeneratingPDF = false
    @State private var errorMessage: String?
    @State private var viewModel = InvoicesViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                Divider()
                clientSection
                Divider()
                lineItemsSection
                Divider()
                totalsSection

                if let notes = invoice.notes, !notes.isEmpty {
                    Divider()
                    notesSection(notes)
                }
            }
            .padding()
        }
        .navigationTitle(invoice.invoiceNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let pdfData {
                    ShareLink(
                        item: pdfData,
                        preview: SharePreview(
                            "\(invoice.invoiceNumber).pdf",
                            image: Image(systemName: "doc.text.fill")
                        )
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                Menu {
                    if invoice.isDraft {
                        Button {
                            viewModel.markAsSent(invoice)
                        } label: {
                            Label("Mark as Sent", systemImage: "paperplane")
                        }
                    }
                    if invoice.isDraft || invoice.isSent {
                        Button {
                            viewModel.markAsPaid(invoice)
                        } label: {
                            Label("Mark as Paid", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isGeneratingPDF {
                ProgressView("Generating PDF...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            await generatePDF()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let name = invoice.businessName {
                        Text(name)
                            .font(.title2.weight(.bold))
                    }
                    if let address = invoice.businessAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("INVOICE")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.primary)
                    StatusBadge(status: invoice.status)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invoice #")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(invoice.invoiceNumber)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Issue Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(invoice.issueDate.shortDateString)
                        .font(.subheadline)
                }
                if let dueDate = invoice.dueDate {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Due Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(dueDate.shortDateString)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Client

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bill To")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let client = invoice.client {
                Text(client.name)
                    .font(.headline)
                if let email = client.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Hours")
                    .frame(width: 60, alignment: .trailing)
                Text("Rate")
                    .frame(width: 80, alignment: .trailing)
                Text("Amount")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)

            Divider()

            ForEach(invoice.sortedLineItems, id: \.id) { item in
                HStack {
                    Text(item.descriptionText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.quantity.formatted())
                        .frame(width: 60, alignment: .trailing)
                        .monospacedDigit()
                    Text(CurrencyService.format(amount: item.unitPrice, currencyCode: invoice.currencyCode))
                        .frame(width: 80, alignment: .trailing)
                        .monospacedDigit()
                    Text(CurrencyService.format(amount: item.amount, currencyCode: invoice.currencyCode))
                        .frame(width: 80, alignment: .trailing)
                        .monospacedDigit()
                }
                .font(.subheadline)
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Totals

    private var totalsSection: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Text("Subtotal")
                    .foregroundStyle(.secondary)
                Text(CurrencyService.format(amount: invoice.subtotal, currencyCode: invoice.currencyCode))
                    .frame(width: 100, alignment: .trailing)
                    .monospacedDigit()
            }
            .font(.subheadline)

            if let taxRate = invoice.taxRate, taxRate > 0 {
                let taxAmount = invoice.subtotal * taxRate / 100
                HStack {
                    Spacer()
                    Text("Tax (\(taxRate.formatted())%)")
                        .foregroundStyle(.secondary)
                    Text(CurrencyService.format(amount: taxAmount, currencyCode: invoice.currencyCode))
                        .frame(width: 100, alignment: .trailing)
                        .monospacedDigit()
                }
                .font(.subheadline)
            }

            HStack {
                Spacer()
                Text("Total")
                    .fontWeight(.bold)
                Text(CurrencyService.format(amount: invoice.totalAmount, currencyCode: invoice.currencyCode))
                    .frame(width: 100, alignment: .trailing)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .font(.title3)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    // MARK: - PDF Generation

    private func generatePDF() async {
        guard pdfData == nil else { return }
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        do {
            let data = try await PDFGenerationService.generatePDF(for: invoice)
            pdfData = data
            invoice.pdfData = data
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        InvoicePreviewView(
            invoice: Invoice(invoiceNumber: "INV-0001")
        )
    }
    .modelContainer(for: Invoice.self, inMemory: true)
}
#endif
