import SwiftUI
import SwiftData
import TimelordKit

struct SavedTimersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<TimeEntry> {
        $0.endDate != nil
    }, sort: \TimeEntry.startDate, order: .reverse)
    private var recentEntries: [TimeEntry]

    var viewModel: TimerViewModel

    private var savedTimers: [SavedTimer] {
        var seen = Set<String>()
        var result: [SavedTimer] = []

        for entry in recentEntries {
            guard let project = entry.project else { continue }
            let key = "\(project.id.uuidString)|\(entry.notes ?? "")"
            if seen.insert(key).inserted {
                result.append(SavedTimer(project: project, notes: entry.notes))
            }
            if result.count >= 20 { break }
        }
        return result
    }

    var body: some View {
        Group {
            if savedTimers.isEmpty {
                ContentUnavailableView(
                    "No Saved Timers",
                    systemImage: "bookmark",
                    description: Text("Your recent project and notes combinations will appear here")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(savedTimers) { timer in
                            SavedTimerCard(timer: timer) {
                                viewModel.startSavedTimer(project: timer.project, notes: timer.notes)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - SavedTimer Model

struct SavedTimer: Identifiable {
    let project: Project
    let notes: String?

    var id: String {
        "\(project.id.uuidString)|\(notes ?? "")"
    }
}

// MARK: - Saved Timer Card

private struct SavedTimerCard: View {
    let timer: SavedTimer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: timer.project.resolvedColorHex))
                        .frame(width: 12, height: 12)

                    Text(timer.project.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                if let clientName = timer.project.client?.name {
                    Text(clientName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let notes = timer.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: timer.project.resolvedColorHex))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(Color(hex: timer.project.resolvedColorHex).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(hex: timer.project.resolvedColorHex).opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SavedTimersView(viewModel: TimerViewModel(timerService: TimerService()))
            .navigationTitle("Saved Timers")
    }
    .modelContainer(try! ModelContainerFactory.preview())
}
#endif
