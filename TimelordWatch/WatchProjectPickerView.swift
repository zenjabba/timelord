import SwiftUI
import TimelordKit

struct WatchProjectPickerView: View {
    let projects: [SharedProject]
    @Binding var selectedID: UUID?
    let onSelect: (SharedProject?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Text("No Project")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if selectedID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                ForEach(projects) { project in
                    Button {
                        onSelect(project)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: project.colorHex))
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(project.name)
                                    .font(.body)
                                    .lineLimit(1)

                                if let client = project.clientName {
                                    Text(client)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if selectedID == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Project")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
