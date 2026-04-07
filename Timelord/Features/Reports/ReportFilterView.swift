import SwiftUI
import SwiftData
import TimelordKit

struct ReportFilterView: View {
    @Bindable var viewModel: ReportsViewModel
    @Query(sort: \Client.name) private var clients: [Client]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                clientSection
                billableSection
                roundingSection
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.filterClient = nil
                        viewModel.filterBillable = .all
                        viewModel.roundingRule = .none
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var clientSection: some View {
        Section("Client") {
            Button {
                viewModel.filterClient = nil
            } label: {
                HStack {
                    Text("All Clients")
                        .foregroundStyle(.primary)
                    Spacer()
                    if viewModel.filterClient == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }

            ForEach(clients) { client in
                Button {
                    viewModel.filterClient = client
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: client.colorHex))
                            .frame(width: 10, height: 10)
                        Text(client.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.filterClient === client {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
    }

    private var billableSection: some View {
        Section("Billable Status") {
            Picker("Filter", selection: $viewModel.filterBillable) {
                ForEach(BillableFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var roundingSection: some View {
        Section("Duration Rounding") {
            Picker("Rounding Rule", selection: $viewModel.roundingRule) {
                ForEach(RoundingRule.allCases, id: \.self) { rule in
                    Text(rule.displayName).tag(rule)
                }
            }
        }
    }
}
