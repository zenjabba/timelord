import SwiftUI
import SwiftData
import Charts
import TimelordKit

struct ReportsView: View {
    @State private var viewModel = ReportsViewModel()
    @Query(sort: \TimeEntry.startDate, order: .reverse) private var allEntries: [TimeEntry]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateRangePicker
                    dateNavigator
                    summaryCards
                    dailyHoursSection
                    clientBreakdownSection
                }
                .padding()
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        NavigationLink(value: "invoices") {
                            Image(systemName: "doc.text")
                        }
                        ShareLink(item: exportCSVTransferable) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(viewModel.filteredEntries.isEmpty)
                    }
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "invoices" {
                    InvoiceListView()
                }
            }
            .sheet(isPresented: $viewModel.showingFilterSheet) {
                ReportFilterView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: allEntries) { _, newValue in
                viewModel.entries = newValue
            }
            .onAppear {
                viewModel.entries = allEntries
            }
        }
    }

    // MARK: - Date Range Picker

    private var dateRangePicker: some View {
        Picker("Period", selection: periodBinding) {
            Text("Week").tag(0)
            Text("Month").tag(1)
        }
        .pickerStyle(.segmented)
    }

    private var periodBinding: Binding<Int> {
        Binding<Int>(
            get: {
                switch viewModel.dateRange {
                case .week: return 0
                case .month: return 1
                case .custom: return 0
                }
            },
            set: { newValue in
                viewModel.dateRange = newValue == 0 ? .week : .month
            }
        )
    }

    // MARK: - Date Navigator

    private var dateNavigator: some View {
        HStack {
            Button {
                viewModel.goToPreviousPeriod()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.medium))
            }

            Spacer()

            Text(viewModel.dateRangeTitle)
                .font(.headline)

            Spacer()

            Button {
                viewModel.goToNextPeriod()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.medium))
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Total Hours",
                    value: String(format: "%.1fh", viewModel.totalHours),
                    icon: "clock"
                )
                SummaryCard(
                    title: "Billable Hours",
                    value: String(format: "%.1fh", viewModel.billableHours),
                    icon: "dollarsign.circle"
                )
            }

            if !viewModel.totalsByCurrency.isEmpty {
                ForEach(viewModel.totalsByCurrency, id: \.currencyCode) { total in
                    SummaryCard(
                        title: "Earnings (\(total.currencyCode))",
                        value: CurrencyService.format(amount: total.amount, currencyCode: total.currencyCode),
                        icon: "banknote"
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Charts

    private var dailyHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hours Per Day")
                .font(.headline)

            DailyHoursChart(dailyHours: viewModel.dailyHours)
                .padding(.vertical, 4)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var clientBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Client")
                .font(.headline)

            ClientBreakdownChart(breakdown: viewModel.clientBreakdown)
                .padding(.vertical, 4)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Export

    private var exportCSVTransferable: URL {
        viewModel.exportCSV() ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
#Preview {
    ReportsView()
        .modelContainer(for: [TimeEntry.self, Project.self, Client.self], inMemory: true)
}
#endif
