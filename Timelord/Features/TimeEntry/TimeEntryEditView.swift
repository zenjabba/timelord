import SwiftUI
import SwiftData
import TimelordKit

struct TimeEntryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { !$0.isArchived },
           sort: \Client.name)
    private var clients: [Client]
    @State private var viewModel = TimeEntryViewModel()
    @State private var showingDeleteConfirmation = false

    let entry: TimeEntry

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & Time") {
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)

                    DatePicker("Start", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)

                    DatePicker("End", selection: $viewModel.endTime, displayedComponents: .hourAndMinute)

                    LabeledContent("Duration", value: viewModel.duration.hoursMinutes)
                        .foregroundColor(viewModel.isValid ? .primary : .red)
                }

                Section("Project") {
                    ProjectPickerView(
                        selectedProject: $viewModel.selectedProject,
                        clients: clients
                    )
                }

                Section("Details") {
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)

                    Toggle("Billable", isOn: $viewModel.isBillable)
                }

                Section {
                    Button("Delete Entry", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.update(entry: entry)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .alert("Delete Time Entry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.delete(entry: entry, context: modelContext)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this time entry? This action cannot be undone.")
            }
            .onAppear {
                viewModel.loadFromEntry(entry)
            }
        }
    }
}
