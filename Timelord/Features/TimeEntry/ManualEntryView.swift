import SwiftUI
import SwiftData
import TimelordKit

struct ManualEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Client> { !$0.isArchived },
           sort: \Client.name)
    private var clients: [Client]
    @State private var viewModel = TimeEntryViewModel()

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
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(context: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .onChange(of: viewModel.selectedProject) {
                if let project = viewModel.selectedProject {
                    viewModel.isBillable = project.isBillable
                }
            }
        }
    }
}

// MARK: - Project Picker

struct ProjectPickerView: View {
    @Binding var selectedProject: Project?
    let clients: [Client]

    var body: some View {
        Picker("Project", selection: $selectedProject) {
            Text("No Project")
                .tag(nil as Project?)

            ForEach(clients) { client in
                let projects = client.activeProjects.sorted { $0.name < $1.name }
                if !projects.isEmpty {
                    Section(client.name) {
                        ForEach(projects) { project in
                            Label {
                                Text(project.name)
                            } icon: {
                                Circle()
                                    .fill(Color(hex: project.resolvedColorHex))
                                    .frame(width: 10, height: 10)
                            }
                            .tag(project as Project?)
                        }
                    }
                }
            }
        }
    }
}
