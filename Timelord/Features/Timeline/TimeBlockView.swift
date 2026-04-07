import SwiftUI
import TimelordKit

struct TimeBlockView: View {
    let entry: TimeEntry
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left color border
                RoundedRectangle(cornerRadius: 2)
                    .fill(projectColor)
                    .frame(width: 3)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.project?.name ?? "No Project")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(entry.project != nil ? .primary : .secondary)
                        .lineLimit(1)

                    if height >= 40 {
                        Text(timeRangeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if height >= 60 {
                        Text(entry.duration.hoursMinutes)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(projectColor.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var projectColor: Color {
        if let hex = entry.project?.resolvedColorHex {
            Color(hex: hex)
        } else {
            .gray
        }
    }

    private var timeRangeText: String {
        let start = entry.startDate.shortTimeString
        if let end = entry.endDate {
            return "\(start) – \(end.shortTimeString)"
        } else {
            return "\(start) – now"
        }
    }
}
