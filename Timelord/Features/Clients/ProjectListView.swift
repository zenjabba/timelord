import SwiftUI
import SwiftData
import TimelordKit

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Project> { !$0.isArchived },
           sort: \Project.name)
    private var projects: [Project]

    @State private var showingAddProject = false
    @State private var searchText = ""

    private var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.client?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var groupedByClient: [(client: Client?, projects: [Project])] {
        let dict = Dictionary(grouping: filteredProjects) { $0.client }
        return dict
            .map { (client: $0.key, projects: $0.value) }
            .sorted { ($0.client?.name ?? "") < ($1.client?.name ?? "") }
    }

    var body: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("Add your first project to start tracking time")
                )
            } else {
                List {
                    ForEach(groupedByClient, id: \.client?.id) { group in
                        Section {
                            ForEach(group.projects) { project in
                                NavigationLink(value: project) {
                                    ProjectRowView(project: project)
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    group.projects[index].isArchived = true
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                if let client = group.client {
                                    Circle()
                                        .fill(Color(hex: client.colorHex))
                                        .frame(width: 8, height: 8)
                                    Text(client.name)
                                } else {
                                    Text("No Client")
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search projects")
            }
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddProject = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectStandaloneView()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ProjectListView()
            .navigationTitle("Projects")
    }
    .modelContainer(try! ModelContainerFactory.preview())
}
#endif
