import SwiftUI
import SwiftData
import TimelordKit

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    @State private var isEditing = false

    var body: some View {
        List {
            Section("Project Info") {
                HStack {
                    Circle()
                        .fill(Color(hex: project.resolvedColorHex))
                        .frame(width: 16, height: 16)
                    Text(project.name)
                        .font(.headline)
                }

                if let clientName = project.client?.name {
                    LabeledContent("Client", value: clientName)
                }

                LabeledContent("Billable", value: project.isBillable ? "Yes" : "No")

                if let rate = project.hourlyRate {
                    LabeledContent("Rate", value: CurrencyService.format(amount: rate, currencyCode: project.resolvedCurrencyCode) + "/hr")
                }

                LabeledContent("Currency", value: project.resolvedCurrencyCode)
            }

            Section("Time Entries") {
                let entries = (project.timeEntries ?? [])
                    .sorted { $0.startDate > $1.startDate }

                if entries.isEmpty {
                    Text("No time entries yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries.prefix(20)) { entry in
                        TimeEntryRowView(entry: entry)
                    }
                    if entries.count > 20 {
                        Text("\(entries.count - 20) more entries...")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section {
                let totalDuration = (project.timeEntries ?? [])
                    .reduce(TimeInterval.zero) { $0 + $1.duration }
                LabeledContent("Total Time", value: totalDuration.hoursMinutes)

                if let rate = project.hourlyRate {
                    let totalAmount = Decimal(totalDuration / 3600) * rate
                    LabeledContent("Total Amount", value: CurrencyService.format(amount: totalAmount, currencyCode: project.resolvedCurrencyCode))
                }
            } header: {
                Text("Summary")
            }
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditProjectSheet(project: project)
        }
    }
}

struct TimeEntryRowView: View {
    let entry: TimeEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.startDate.shortDateString)
                    .font(.subheadline)

                HStack(spacing: 4) {
                    Text(entry.startDate.shortTimeString)
                    if let end = entry.endDate {
                        Text("–")
                        Text(end.shortTimeString)
                    } else {
                        Text("– running")
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.duration.hoursMinutes)
                    .font(.subheadline.monospacedDigit())

                if !entry.isBillable {
                    Text("Non-billable")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct EditProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    @State private var rateString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Project Name", text: $project.name)
                    Toggle("Billable", isOn: $project.isBillable)

                    if project.isBillable {
                        TextField("Hourly Rate", text: $rateString)
                            .keyboardType(.decimalPad)
                            .onChange(of: rateString) {
                                project.hourlyRate = Decimal(string: rateString)
                            }
                    }
                }

                Section("Currency") {
                    Picker("Currency", selection: Binding(
                        get: { project.currencyCode ?? project.client?.defaultCurrencyCode ?? "USD" },
                        set: { project.currencyCode = $0 }
                    )) {
                        ForEach(CurrencyService.commonCurrencies, id: \.code) { currency in
                            Text("\(currency.symbol) \(currency.code)")
                                .tag(currency.code)
                        }
                    }
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let rate = project.hourlyRate {
                    rateString = "\(rate)"
                }
            }
        }
    }
}
