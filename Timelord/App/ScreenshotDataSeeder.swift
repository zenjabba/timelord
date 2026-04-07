import Foundation
import SwiftData
import TimelordKit

/// Seeds realistic sample data for App Store screenshots.
/// Only runs when launched with `-screenshot-mode` argument.
enum ScreenshotDataSeeder {
    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshot-mode")
    }

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard isScreenshotMode else { return }

        // Check if already seeded
        let existing = (try? context.fetchCount(FetchDescriptor<Client>())) ?? 0
        guard existing == 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())

        // MARK: - Clients

        let acme = Client(name: "Acme Corp", email: "billing@acme.com", colorHex: "#FF6B35", defaultCurrencyCode: "USD")
        let bloom = Client(name: "Bloom Studio", email: "hello@bloom.design", colorHex: "#7B68EE", defaultCurrencyCode: "USD")
        let nexus = Client(name: "Nexus Labs", email: "accounts@nexuslabs.io", colorHex: "#00BFA5", defaultCurrencyCode: "GBP")
        let solar = Client(name: "Solar Media", email: "pay@solarmedia.co", colorHex: "#FF4081", defaultCurrencyCode: "EUR")

        [acme, bloom, nexus, solar].forEach { context.insert($0) }

        // MARK: - Projects

        let website = Project(name: "Website Redesign", client: acme, colorHex: "#FF6B35", hourlyRate: 150, currencyCode: "USD")
        let mobileApp = Project(name: "Mobile App", client: acme, colorHex: "#FF8F65", hourlyRate: 175, currencyCode: "USD")
        let branding = Project(name: "Brand Identity", client: bloom, colorHex: "#7B68EE", hourlyRate: 125, currencyCode: "USD")
        let apiDev = Project(name: "API Development", client: nexus, colorHex: "#00BFA5", hourlyRate: 95, currencyCode: "GBP")
        let campaign = Project(name: "Ad Campaign", client: solar, colorHex: "#FF4081", hourlyRate: 110, currencyCode: "EUR")

        [website, mobileApp, branding, apiDev, campaign].forEach { context.insert($0) }

        // MARK: - Time Entries (today)

        let entries: [(Project, String?, Int, Int, Int, Int)] = [
            // project, notes, startHour, startMin, endHour, endMin
            (website, "Homepage hero section", 8, 30, 10, 15),
            (branding, "Logo exploration round 2", 10, 30, 12, 0),
            (apiDev, "Auth endpoints", 13, 0, 15, 30),
            (mobileApp, "Onboarding flow", 15, 45, 17, 0),
        ]

        for (project, notes, sh, sm, eh, em) in entries {
            let start = Calendar.current.date(bySettingHour: sh, minute: sm, second: 0, of: today)!
            let end = Calendar.current.date(bySettingHour: eh, minute: em, second: 0, of: today)!
            let entry = TimeEntry(startDate: start, endDate: end, project: project, notes: notes)
            context.insert(entry)
        }

        // MARK: - Time Entries (yesterday and this week for reports)

        for dayOffset in 1...6 {
            guard let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let projects = [website, branding, apiDev, mobileApp, campaign]

            // 2-3 entries per day
            let entryCount = dayOffset % 2 == 0 ? 3 : 2
            for i in 0..<entryCount {
                let proj = projects[(dayOffset + i) % projects.count]
                let startHour = 9 + (i * 3)
                let start = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: day)!
                let end = Calendar.current.date(bySettingHour: startHour + 2, minute: 15 * ((dayOffset + i) % 4), second: 0, of: day)!
                let entry = TimeEntry(startDate: start, endDate: end, project: proj, notes: nil)
                context.insert(entry)
            }
        }

        try? context.save()
    }
}
