import SwiftUI
import SwiftData
import TimelordKit

struct DayTimelineView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TimeEntry.startDate)
    private var allEntries: [TimeEntry]

    @State private var viewModel = TimelineViewModel()

    private let hourHeight: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            dateNavigationHeader
            Divider()
            timelineScrollView
        }
        .sheet(isPresented: $viewModel.showingManualEntry) {
            ManualEntryView()
        }
        .sheet(isPresented: $viewModel.showingEditEntry) {
            if let entry = viewModel.selectedEntry {
                TimeEntryEditView(entry: entry)
            }
        }
        .onAppear {
            viewModel.entries = allEntries
        }
        .onChange(of: allEntries) {
            viewModel.entries = allEntries
        }
    }

    // MARK: - Date Navigation Header

    private var dateNavigationHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Button {
                    viewModel.goToPreviousDay()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.medium))
                        .contentShape(Rectangle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(viewModel.dateTitle)
                        .font(.headline)

                    Text(viewModel.totalDuration.hoursMinutes)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.goToNextDay()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.medium))
                        .contentShape(Rectangle())
                }
                .disabled(!viewModel.canGoToNextDay)
            }
            .padding(.horizontal)

            if viewModel.canGoToNextDay {
                Button {
                    viewModel.goToToday()
                } label: {
                    Text("Today")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Timeline Scroll View

    private var timelineScrollView: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Hour grid
                hourGrid

                // Time entry blocks
                timeEntryBlocks

                // Now indicator
                if viewModel.selectedDate.isToday {
                    nowIndicator
                }
            }
            .frame(height: hourHeight * 24)
        }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(hourLabel(for: hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                        .offset(y: -6)

                    VStack(spacing: 0) {
                        Divider()
                            .foregroundStyle(Color(.separator).opacity(0.5))
                        Spacer()
                    }
                }
                .frame(height: hourHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.addEntryAt(hour: hour)
                }
            }
        }
    }

    // MARK: - Time Entry Blocks

    private var timeEntryBlocks: some View {
        let leadingInset: CGFloat = 60

        return ForEach(viewModel.entriesForSelectedDate) { entry in
            let frame = viewModel.timeBlockFrame(for: entry, hourHeight: hourHeight)

            TimeBlockView(
                entry: entry,
                height: frame.height
            ) {
                viewModel.selectEntry(entry)
            }
            .frame(height: frame.height)
            .padding(.trailing, 16)
            .offset(x: leadingInset, y: frame.yOffset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Now Indicator

    private var nowIndicator: some View {
        let now = Date()
        let minutesSinceMidnight = Calendar.current.dateComponents(
            [.hour, .minute],
            from: Calendar.current.startOfDay(for: now),
            to: now
        )
        let totalMinutes = CGFloat(minutesSinceMidnight.hour ?? 0) * 60 + CGFloat(minutesSinceMidnight.minute ?? 0)
        let yPosition = (totalMinutes / 60.0) * hourHeight

        return HStack(spacing: 0) {
            Spacer()
                .frame(width: 52)

            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(.red)
                .frame(height: 1.5)
        }
        .offset(y: yPosition - 4)
    }

    // MARK: - Helpers

    private func hourLabel(for hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DayTimelineView()
    }
    .modelContainer(try! ModelContainerFactory.preview())
}
#endif
