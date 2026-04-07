import CloudKit
import SwiftData
import SwiftUI
import TimelordKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"
    @AppStorage("defaultRoundingRule") private var defaultRoundingRule = "none"
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteSuccess = false
    @State private var isDeleting = false
    @State private var showingReimportConfirmation = false
    @State private var showingReimportSuccess = false
    @State private var isReimporting = false

    private var selectedRoundingRule: RoundingRule {
        RoundingRule(rawValue: defaultRoundingRule) ?? .none
    }

    var body: some View {
        Form {
            generalSection
            calendarSection
            brandingSection
            dataSection
            aboutSection
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Delete All Data",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                Task { await deleteAllData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your time entries, clients, projects, and invoices from this device and iCloud. This cannot be undone.")
        }
        .alert("Data Deleted", isPresented: $showingDeleteSuccess) {
            Button("OK") {}
        } message: {
            Text("All data has been removed from this device and iCloud.")
        }
        .confirmationDialog(
            "Re-import from iCloud",
            isPresented: $showingReimportConfirmation,
            titleVisibility: .visible
        ) {
            Button("Re-import") {
                Task { await reimportFromiCloud() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear the local database and re-download all data from iCloud. The app will restart automatically.")
        }
        .alert("Re-import Complete", isPresented: $showingReimportSuccess) {
            Button("OK") {}
        } message: {
            Text("Local data has been cleared. iCloud data will sync automatically over the next few moments.")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            Picker("Appearance", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            currencyPicker
            NavigationLink {
                RoundingRulesView()
            } label: {
                LabeledContent("Rounding") {
                    Text(selectedRoundingRule.displayName)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var currencyPicker: some View {
        Picker("Default Currency", selection: $defaultCurrency) {
            ForEach(CurrencyService.commonCurrencies, id: \.code) { currency in
                Text("\(currency.symbol) \(currency.code) — \(currency.name)")
                    .tag(currency.code)
            }
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        Section("Calendar Import") {
            NavigationLink {
                CalendarImportView()
            } label: {
                Label("Import from Calendar", systemImage: "calendar.badge.plus")
            }
        }
    }

    // MARK: - Branding

    private var brandingSection: some View {
        Section("Invoice Branding") {
            NavigationLink {
                BrandingSettingsView()
            } label: {
                Label("Business Branding", systemImage: "building.2")
            }
        }
    }

    // MARK: - Data Management

    private var dataSection: some View {
        Section {
            Button {
                showingReimportConfirmation = true
            } label: {
                HStack {
                    Label("Re-import from iCloud", systemImage: "icloud.and.arrow.down")
                    Spacer()
                    if isReimporting {
                        ProgressView()
                    }
                }
            }
            .disabled(isReimporting)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Label("Delete All Data", systemImage: "trash")
                    Spacer()
                    if isDeleting {
                        ProgressView()
                    }
                }
            }
            .disabled(isDeleting)
        } header: {
            Text("Data Management")
        } footer: {
            Text("Removes all data from this device and iCloud. Other devices will sync the deletion.")
        }
    }

    private func deleteAllData() async {
        isDeleting = true
        defer { isDeleting = false }

        // Delete all SwiftData model objects (syncs deletion to CloudKit)
        do {
            try modelContext.delete(model: InvoiceLineItem.self)
            try modelContext.delete(model: Invoice.self)
            try modelContext.delete(model: TimeEntry.self)
            try modelContext.delete(model: Project.self)
            try modelContext.delete(model: Client.self)
            try modelContext.save()
        } catch {
            print("Failed to delete local data: \(error)")
        }

        // Clear timer state and shared defaults
        TimerState.clear()
        TimerState.shared.removeObject(forKey: "com.timelord.currentProjectName")
        TimerState.shared.removeObject(forKey: "com.timelord.currentProjectColorHex")
        SharedProjectSync.write([])

        showingDeleteSuccess = true
    }

    private func reimportFromiCloud() async {
        isReimporting = true
        defer { isReimporting = false }

        // Delete all local data — SwiftData will re-download from CloudKit automatically
        do {
            try modelContext.delete(model: InvoiceLineItem.self)
            try modelContext.delete(model: Invoice.self)
            try modelContext.delete(model: TimeEntry.self)
            try modelContext.delete(model: Project.self)
            try modelContext.delete(model: Client.self)
            try modelContext.save()
        } catch {
            print("Failed to clear local data for re-import: \(error)")
        }

        // Give CloudKit a moment to notice the empty store and begin re-syncing
        try? await Task.sleep(for: .seconds(1))

        // Nudge CloudKit by fetching the zone changes
        let container = CKContainer(identifier: "iCloud.com.digitalmonks.timelord.app")
        let database = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")

        do {
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil // Force full re-fetch
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zone.zoneID],
                configurationsByRecordZoneID: [zone.zoneID: config]
            )
            operation.fetchAllChanges = true
            operation.qualityOfService = .userInitiated
            database.add(operation)
        }

        showingReimportSuccess = true
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            Text("DM Time Lord is free and always will be.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
    }
}
#endif
