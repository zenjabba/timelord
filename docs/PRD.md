# Timelord — Product Requirements Document

## Vision
A completely free iOS time tracking app for freelancers. No subscription, no paywalls. Deep Apple ecosystem integration with iCloud sync across iPhone and iPad.

## Target User
Freelancers and independent contractors who:
- Bill clients by the hour
- Work with multiple clients, possibly in different currencies
- Need to generate invoices from tracked time
- Want a native iOS experience without monthly fees

## Problem Statement
Every quality time tracking app (Toggl, Timery, Harvest, Clockify Pro) requires a subscription ($5-13/month). Freelancers need a professional tool that respects their budget.

## Core Features (V1)

### 1. Timer
- One-tap start/stop from app, widget, Lock Screen, Dynamic Island
- Saved timer templates per project for instant start
- Timer persists across app kill (timestamp-based)
- Pause/resume support
- Live Activity showing elapsed time on Lock Screen and Dynamic Island

### 2. Manual Time Entry
- Inline time pickers for start/end
- Quick-fill from calendar events
- Retroactive entry ("started 20 min ago")

### 3. Day Timeline View
- Vertical calendar-style visualization of the day
- Color-coded blocks by project/client
- Tap blocks to edit, tap gaps to add entries
- Date navigation (swipe or picker)

### 4. Client & Project Management
- Clients with name, email, color, default currency, notes
- Projects belong to clients with optional rate override
- Archive (soft delete) for completed clients/projects
- Color-coded throughout the app

### 5. Billable Hours & Multi-Currency
- Per-project hourly rates
- Billable/non-billable toggle per entry
- Multi-currency support (ISO 4217)
- Amounts stored in original currency, no conversion
- Reports grouped by currency

### 6. Calendar Import
- Import meetings from iOS Calendar as time entries
- Map calendars to specific projects
- Deduplication on calendar event ID
- On-demand import (not automatic)

### 7. Reports
- Weekly and monthly views
- Bar chart (hours by day), pie chart (by client)
- Filter by client, project, date range, billable status
- Multi-currency sections (separate totals per currency)
- Export as CSV and PDF

### 8. Invoice Generation
- Create invoice from unbilled time entries for a client
- Apply rounding rules to line items
- Editable line item descriptions
- Business branding (logo, name, address)
- Tax rate support
- PDF preview and share (email, AirDrop)
- Invoice status tracking (draft, sent, paid)

### 9. Rounding Rules
- Round to nearest 5, 6, 10, or 15 minutes
- Round up option for each increment
- Applied at invoice/report time only (raw data preserved)

### 10. iCloud Sync
- Automatic sync via CloudKit (SwiftData integration)
- Works across iPhone and iPad
- No account creation required
- Private database only (user's own iCloud)

### 11. Settings
- Default currency
- Rounding rules preference
- Calendar import configuration
- Business branding for invoices
- iCloud sync status
- Appearance (follows system / dark / light)

## Non-Functional Requirements
- **Performance**: Smooth with 1000+ time entries
- **Privacy**: All data in user's iCloud, no third-party servers
- **Accessibility**: VoiceOver, Dynamic Type support
- **Offline**: Full functionality offline, sync when connected

## Success Metrics
- App Store rating 4.5+
- Featured in "free alternatives" lists for time tracking
- Positive reviews highlighting "actually free" nature

## Out of Scope (V1)
- Apple Watch app
- macOS app
- Team/collaboration features
- Automatic screen-time-style tracking
- Integration with external services (Slack, Jira, etc.)
- In-app purchase or monetization
