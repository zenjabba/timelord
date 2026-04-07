import SwiftUI
import SwiftData
import TimelordKit

struct ClientDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var client: Client
    @State private var viewModel = ClientsViewModel()
    @State private var isEditing = false
    @State private var showingInvoiceEditor = false

    var body: some View {
        List {
            Section("Client Info") {
                HStack {
                    Circle()
                        .fill(Color(hex: client.colorHex))
                        .frame(width: 16, height: 16)
                    Text(client.name)
                        .font(.headline)
                }

                if let email = client.email, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }

                LabeledContent("Currency", value: "\(CurrencyService.symbol(for: client.defaultCurrencyCode)) \(client.defaultCurrencyCode)")

                if let notes = client.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(client.activeProjects) { project in
                    NavigationLink(value: project) {
                        ProjectRowView(project: project)
                    }
                }
                .onDelete { indexSet in
                    let projects = client.activeProjects
                    for index in indexSet {
                        viewModel.archiveProject(projects[index])
                    }
                }

                Button {
                    viewModel.selectedClient = client
                    viewModel.showingAddProject = true
                } label: {
                    Label("Add Project", systemImage: "plus")
                }
            } header: {
                Text("Projects")
            }

            Section {
                let clientInvoices = client.invoices ?? []
                if clientInvoices.isEmpty {
                    Text("No invoices yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(clientInvoices.sorted(by: { $0.createdAt > $1.createdAt })) { invoice in
                        NavigationLink(value: invoice) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(invoice.invoiceNumber)
                                            .font(.subheadline.weight(.medium))
                                        StatusBadge(status: invoice.status)
                                    }
                                    Text(invoice.issueDate.shortDateString)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text(CurrencyService.format(amount: invoice.totalAmount, currencyCode: invoice.currencyCode))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                }

                Button {
                    showingInvoiceEditor = true
                } label: {
                    Label("Create Invoice", systemImage: "plus")
                }
            } header: {
                Text("Invoices")
            }
        }
        .navigationTitle(client.name)
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .navigationDestination(for: Invoice.self) { invoice in
            InvoicePreviewView(invoice: invoice)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditClientSheet(client: client)
        }
        .sheet(isPresented: $viewModel.showingAddProject) {
            AddProjectSheet(viewModel: viewModel, client: client)
        }
        .sheet(isPresented: $showingInvoiceEditor) {
            NavigationStack {
                InvoiceEditorView(preselectedClient: client)
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: project.resolvedColorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)

                HStack(spacing: 4) {
                    if let rate = project.hourlyRate {
                        Text(CurrencyService.format(amount: rate, currencyCode: project.resolvedCurrencyCode) + "/hr")
                    }
                    if !project.isBillable {
                        Text("Non-billable")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct EditClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var client: Client

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Client Name", text: $client.name)
                    TextField("Email", text: Binding(
                        get: { client.email ?? "" },
                        set: { client.email = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(Color.clientColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if client.colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    client.colorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Currency") {
                    Picker("Default Currency", selection: $client.defaultCurrencyCode) {
                        ForEach(CurrencyService.commonCurrencies, id: \.code) { currency in
                            Text("\(currency.symbol) \(currency.code) — \(currency.name)")
                                .tag(currency.code)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: Binding(
                        get: { client.notes ?? "" },
                        set: { client.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AddProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ClientsViewModel
    let client: Client

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $viewModel.newProjectName)

                    Toggle("Billable", isOn: $viewModel.newProjectIsBillable)

                    if viewModel.newProjectIsBillable {
                        TextField("Hourly Rate", text: $viewModel.newProjectRate)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Currency Override") {
                    Picker("Currency", selection: Binding(
                        get: { viewModel.newProjectCurrency ?? client.defaultCurrencyCode },
                        set: { viewModel.newProjectCurrency = $0 == client.defaultCurrencyCode ? nil : $0 }
                    )) {
                        ForEach(CurrencyService.commonCurrencies, id: \.code) { currency in
                            Text("\(currency.symbol) \(currency.code)")
                                .tag(currency.code)
                        }
                    }

                    if viewModel.newProjectCurrency == nil {
                        Text("Using client default: \(client.defaultCurrencyCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.createProject(for: client, context: modelContext)
                        dismiss()
                    }
                    .disabled(viewModel.newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let container = try! ModelContainerFactory.preview()
    let client = Client(name: "Acme Corp", colorHex: "#FF3B30", defaultCurrencyCode: "USD")
    let project = Project(name: "Website Redesign", client: client, hourlyRate: 150)
    container.mainContext.insert(client)
    container.mainContext.insert(project)

    return NavigationStack {
        ClientDetailView(client: client)
    }
    .modelContainer(container)
}
#endif
