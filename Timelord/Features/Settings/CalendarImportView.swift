import EventKit
import SwiftData
import SwiftUI
import TimelordKit

struct CalendarImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]

    @State private var accessGranted = false
    @State private var accessDenied = false
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendarIDs: Set<String> = []
    @State private var startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedProject: Project?
    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var importHistory: [String] = []

    var body: some View {
        Form {
            if !accessGranted {
                accessSection
            } else {
                calendarSelectionSection
                dateRangeSection
                projectSection
                importSection
                if !importHistory.isEmpty {
                    historySection
                }
            }
        }
        .navigationTitle("Calendar Import")
        .task {
            await checkAccess()
        }
    }

    // MARK: - Access

    private var accessSection: some View {
        Section {
            if accessDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Calendar Access Denied", systemImage: "calendar.badge.exclamationmark")
                        .foregroundStyle(.red)
                    Text("Enable calendar access in Settings to import events.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } else {
                Button {
                    Task { await requestAccess() }
                } label: {
                    Label("Grant Calendar Access", systemImage: "calendar.badge.plus")
                }
            }
        } header: {
            Text("Calendar Access")
        } footer: {
            Text("Timelord needs calendar access to import events as time entries.")
        }
    }

    // MARK: - Calendar Selection

    private var calendarSelectionSection: some View {
        Section("Select Calendars") {
            if calendars.isEmpty {
                Text("No calendars found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(calendars, id: \.calendarIdentifier) { calendar in
                    calendarToggleRow(for: calendar)
                }
            }
        }
    }

    private func calendarToggleRow(for calendar: EKCalendar) -> some View {
        let isSelected = Binding(
            get: { selectedCalendarIDs.contains(calendar.calendarIdentifier) },
            set: { enabled in
                if enabled {
                    selectedCalendarIDs.insert(calendar.calendarIdentifier)
                } else {
                    selectedCalendarIDs.remove(calendar.calendarIdentifier)
                }
            }
        )

        return Toggle(isOn: isSelected) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 12, height: 12)
                Text(calendar.title)
            }
        }
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        Section("Date Range") {
            DatePicker("Start", selection: $startDate, displayedComponents: .date)
            DatePicker("End", selection: $endDate, displayedComponents: .date)
        }
    }

    // MARK: - Project

    private var projectSection: some View {
        Section {
            Picker("Default Project", selection: $selectedProject) {
                Text("None").tag(nil as Project?)
                ForEach(projects) { project in
                    Text(project.displayName).tag(project as Project?)
                }
            }
        } header: {
            Text("Default Project")
        } footer: {
            Text("Assign imported events to this project. You can change it later.")
        }
    }

    // MARK: - Import

    private var importSection: some View {
        Section {
            Button {
                Task { await performImport() }
            } label: {
                HStack {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(isImporting ? "Importing..." : "Import Events")
                }
            }
            .disabled(selectedCalendarIDs.isEmpty || isImporting)

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(statusMessage.contains("Error") ? .red : .green)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        Section("Import History") {
            ForEach(importHistory, id: \.self) { entry in
                Text(entry)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func checkAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            accessGranted = true
            loadCalendars()
        case .denied, .restricted:
            accessDenied = true
        default:
            break
        }
    }

    private func requestAccess() async {
        do {
            let granted = try await CalendarImportService.requestAccess()
            accessGranted = granted
            accessDenied = !granted
            if granted {
                loadCalendars()
            }
        } catch {
            accessDenied = true
        }
    }

    private func loadCalendars() {
        calendars = CalendarImportService.availableCalendars()
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private func performImport() async {
        isImporting = true
        statusMessage = nil

        do {
            let count = try await CalendarImportService.importEvents(
                from: Array(selectedCalendarIDs),
                startDate: startDate,
                endDate: endDate,
                defaultProject: selectedProject,
                context: modelContext
            )

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short

            let rangeText = "\(dateFormatter.string(from: startDate)) – \(dateFormatter.string(from: endDate))"
            statusMessage = "Imported \(count) event\(count == 1 ? "" : "s")"
            importHistory.insert("\(rangeText): \(count) event\(count == 1 ? "" : "s")", at: 0)
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }

        isImporting = false
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CalendarImportView()
    }
    .modelContainer(for: [TimeEntry.self, Project.self])
}
#endif
