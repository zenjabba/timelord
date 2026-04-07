import SwiftUI
import Charts
import TimelordKit

// MARK: - Daily Hours Bar Chart

struct DailyHoursChart: View {
    let dailyHours: [(date: Date, hours: Double)]

    private var isMonthView: Bool {
        dailyHours.count > 7
    }

    var body: some View {
        Chart {
            ForEach(dailyHours, id: \.date) { item in
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Hours", item.hours)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(2)
            }
        }
        .chartXAxis {
            if isMonthView {
                // Month: show weekly labels to avoid crowding
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                }
            } else {
                // Week: show each day
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(hours, specifier: "%.1f")h")
                    }
                }
            }
        }
        .chartYScale(domain: 0 ... max(maxHours, 1))
        .frame(height: 200)
    }

    private var maxHours: Double {
        (dailyHours.map(\.hours).max() ?? 0) * 1.15
    }
}

// MARK: - Client Breakdown Sector Chart

struct ClientBreakdownChart: View {
    let breakdown: [(clientName: String, colorHex: String, hours: Double, amount: Decimal, currencyCode: String)]

    var body: some View {
        if breakdown.isEmpty {
            ContentUnavailableView("No Data", systemImage: "chart.pie", description: Text("No entries for this period."))
        } else {
            VStack(alignment: .leading, spacing: 16) {
                sectorChart
                legendList
            }
        }
    }

    @ViewBuilder
    private var sectorChart: some View {
        Chart {
            ForEach(breakdown, id: \.clientName) { item in
                SectorMark(
                    angle: .value("Hours", item.hours),
                    innerRadius: .ratio(0.5),
                    angularInset: 1
                )
                .foregroundStyle(Color(hex: item.colorHex))
                .cornerRadius(4)
            }
        }
        .frame(height: 200)
    }

    private var legendList: some View {
        VStack(spacing: 8) {
            ForEach(breakdown, id: \.clientName) { item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: item.colorHex))
                        .frame(width: 12, height: 12)

                    Text(item.clientName)
                        .font(.subheadline)

                    Spacer()

                    Text(String(format: "%.1fh", item.hours))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if item.amount > 0 {
                        Text(CurrencyService.format(amount: item.amount, currencyCode: item.currencyCode))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Client Breakdown Horizontal Bar Chart

struct ClientBreakdownBarChart: View {
    let breakdown: [(clientName: String, colorHex: String, hours: Double, amount: Decimal, currencyCode: String)]

    private var maxHours: Double {
        breakdown.map(\.hours).max() ?? 1
    }

    var body: some View {
        if breakdown.isEmpty {
            ContentUnavailableView("No Data", systemImage: "chart.bar", description: Text("No entries for this period."))
        } else {
            Chart {
                ForEach(breakdown, id: \.clientName) { item in
                    BarMark(
                        x: .value("Hours", item.hours),
                        y: .value("Client", item.clientName)
                    )
                    .foregroundStyle(Color(hex: item.colorHex))
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(hours, specifier: "%.1f")h")
                        }
                    }
                }
            }
            .frame(height: max(CGFloat(breakdown.count) * 44, 100))
        }
    }
}
