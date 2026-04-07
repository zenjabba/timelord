import Foundation
import SwiftData
import SwiftUI
import TimelordKit

@Observable
final class ClientsViewModel {
    var showingAddClient = false
    var showingAddProject = false
    var selectedClient: Client?
    var searchText = ""

    // New client form
    var newClientName = ""
    var newClientEmail = ""
    var newClientColorHex = Color.clientColors[0]
    var newClientCurrency = "USD"
    var newClientNotes = ""

    // New project form
    var newProjectName = ""
    var newProjectColorHex: String?
    var newProjectRate = ""
    var newProjectCurrency: String?
    var newProjectIsBillable = true

    func createClient(context: ModelContext) {
        let client = Client(
            name: newClientName,
            email: newClientEmail.isEmpty ? nil : newClientEmail,
            colorHex: newClientColorHex,
            defaultCurrencyCode: newClientCurrency,
            notes: newClientNotes.isEmpty ? nil : newClientNotes
        )
        context.insert(client)
        resetClientForm()
    }

    func createProject(for client: Client, context: ModelContext) {
        let rate: Decimal? = if let parsed = Decimal(string: newProjectRate) {
            parsed
        } else {
            nil
        }

        let project = Project(
            name: newProjectName,
            client: client,
            colorHex: newProjectColorHex,
            hourlyRate: rate,
            currencyCode: newProjectCurrency,
            isBillable: newProjectIsBillable
        )
        context.insert(project)
        resetProjectForm()
    }

    func archiveClient(_ client: Client) {
        client.isArchived = true
    }

    func archiveProject(_ project: Project) {
        project.isArchived = true
    }

    func deleteClient(_ client: Client, context: ModelContext) {
        context.delete(client)
    }

    func deleteProject(_ project: Project, context: ModelContext) {
        context.delete(project)
    }

    private func resetClientForm() {
        newClientName = ""
        newClientEmail = ""
        newClientColorHex = Color.clientColors[0]
        newClientCurrency = "USD"
        newClientNotes = ""
        showingAddClient = false
    }

    private func resetProjectForm() {
        newProjectName = ""
        newProjectColorHex = nil
        newProjectRate = ""
        newProjectCurrency = nil
        newProjectIsBillable = true
        showingAddProject = false
    }
}
