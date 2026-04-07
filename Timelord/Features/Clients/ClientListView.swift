import SwiftUI
import SwiftData
import TimelordKit

struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Client> { !$0.isArchived },
           sort: \Client.name)
    private var clients: [Client]

    @State private var viewModel = ClientsViewModel()
    @State private var showingAddProject = false

    var body: some View {
        Group {
            if clients.isEmpty {
                ContentUnavailableView(
                    "No Clients",
                    systemImage: "person.2",
                    description: Text("Add your first client to start tracking time")
                )
            } else {
                List {
                    ForEach(clients) { client in
                        NavigationLink(value: client) {
                            ClientRowView(client: client)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.archiveClient(clients[index])
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Client.self) { client in
            ClientDetailView(client: client)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddProject = true
                    } label: {
                        Label("New Project", systemImage: "folder.badge.plus")
                    }

                    Button {
                        viewModel.showingAddClient = true
                    } label: {
                        Label("New Client", systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddClient) {
            AddClientSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectStandaloneView()
        }
    }
}

struct ClientRowView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: client.colorHex))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.body)

                let projectCount = client.activeProjects.count
                Text("\(projectCount) project\(projectCount == 1 ? "" : "s") \u{00B7} \(client.defaultCurrencyCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AddClientSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ClientsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Client Name", text: $viewModel.newClientName)
                    TextField("Email (optional)", text: $viewModel.newClientEmail)
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
                                    if viewModel.newClientColorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    viewModel.newClientColorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Currency") {
                    Picker("Default Currency", selection: $viewModel.newClientCurrency) {
                        ForEach(CurrencyService.commonCurrencies, id: \.code) { currency in
                            Text("\(currency.symbol) \(currency.code) — \(currency.name)")
                                .tag(currency.code)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $viewModel.newClientNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.createClient(context: modelContext)
                        dismiss()
                    }
                    .disabled(viewModel.newClientName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ClientListView()
            .navigationTitle("Clients")
    }
    .modelContainer(try! ModelContainerFactory.preview())
}
#endif
