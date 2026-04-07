import SwiftUI
import SwiftData
import TimelordKit

struct AddProjectStandaloneView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Client> { !$0.isArchived },
           sort: \Client.name)
    private var clients: [Client]

    @State private var projectName = ""
    @State private var selectedClient: Client?
    @State private var isBillable = true
    @State private var rateString = ""
    @State private var currencyOverride: String?
    @State private var showingNewClient = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Project Name", text: $projectName)
                }

                Section("Client") {
                    if clients.isEmpty {
                        Text("No clients yet")
                            .foregroundStyle(.secondary)
                        Button("Create Client First") {
                            showingNewClient = true
                        }
                    } else {
                        Picker("Client", selection: $selectedClient) {
                            Text("Select a client")
                                .tag(nil as Client?)

                            ForEach(clients) { client in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: client.colorHex))
                                        .frame(width: 10, height: 10)
                                    Text(client.name)
                                }
                                .tag(client as Client?)
                            }
                        }

                        Button {
                            showingNewClient = true
                        } label: {
                            Label("New Client", systemImage: "plus")
                        }
                    }
                }

                Section("Billing") {
                    Toggle("Billable", isOn: $isBillable)

                    if isBillable {
                        TextField("Hourly Rate", text: $rateString)
                            .keyboardType(.decimalPad)

                        if let client = selectedClient {
                            let currency = currencyOverride ?? client.defaultCurrencyCode
                            Picker("Currency", selection: Binding(
                                get: { currency },
                                set: { currencyOverride = $0 == client.defaultCurrencyCode ? nil : $0 }
                            )) {
                                ForEach(CurrencyService.commonCurrencies, id: \.code) { c in
                                    Text("\(c.symbol) \(c.code)")
                                        .tag(c.code)
                                }
                            }

                            if currencyOverride == nil {
                                Text("Using client default: \(client.defaultCurrencyCode)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingNewClient) {
                AddClientSheet(viewModel: ClientsViewModel())
            }
            .onChange(of: clients) {
                if selectedClient == nil, let first = clients.first {
                    selectedClient = first
                }
            }
        }
    }

    private var isValid: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty && selectedClient != nil
    }

    private func save() {
        guard let client = selectedClient else { return }

        let rate: Decimal? = if let parsed = Decimal(string: rateString) {
            parsed
        } else {
            nil
        }

        let project = Project(
            name: projectName.trimmingCharacters(in: .whitespaces),
            client: client,
            hourlyRate: rate,
            currencyCode: currencyOverride,
            isBillable: isBillable
        )
        modelContext.insert(project)
    }
}

#if DEBUG
#Preview {
    AddProjectStandaloneView()
        .modelContainer(try! ModelContainerFactory.preview())
}
#endif
