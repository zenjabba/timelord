import SwiftUI
import TimelordKit

struct RoundingRulesView: View {
    @AppStorage("defaultRoundingRule") private var defaultRoundingRule = "none"

    private var selectedRule: RoundingRule {
        RoundingRule(rawValue: defaultRoundingRule) ?? .none
    }

    var body: some View {
        Form {
            Section {
                ForEach(RoundingRule.allCases, id: \.rawValue) { rule in
                    ruleRow(for: rule)
                }
            } header: {
                Text("Rounding Rule")
            } footer: {
                Text("Rounding is applied at display and invoice time only. Stored durations are never modified.")
            }

            Section("Example") {
                exampleView
            }
        }
        .navigationTitle("Rounding Rules")
    }

    // MARK: - Row

    private func ruleRow(for rule: RoundingRule) -> some View {
        Button {
            defaultRoundingRule = rule.rawValue
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.displayName)
                        .foregroundStyle(.primary)
                    Text(exampleText(for: rule))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedRule == rule {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Example

    private var exampleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(exampleDurations, id: \.self) { minutes in
                let raw = TimeInterval(minutes * 60)
                let rounded = RoundingService.round(duration: raw, rule: selectedRule)
                HStack {
                    Text("\(minutes) min")
                        .monospacedDigit()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rounded.hoursMinutes)
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
                .font(.callout)
            }
        }
    }

    private var exampleDurations: [Int] {
        [7, 13, 23, 45, 52, 68]
    }

    // MARK: - Helpers

    private func exampleText(for rule: RoundingRule) -> String {
        let sample: TimeInterval = 23 * 60 // 23 minutes
        let rounded = RoundingService.round(duration: sample, rule: rule)
        let roundedMinutes = Int(rounded / 60)

        if rule == .none {
            return "23 min stays 23 min"
        }
        return "23 min \u{2192} \(roundedMinutes) min"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        RoundingRulesView()
    }
}
#endif
