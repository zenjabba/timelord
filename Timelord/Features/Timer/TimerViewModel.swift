import Foundation
import SwiftData
import SwiftUI
import TimelordKit

@MainActor @Observable
final class TimerViewModel {
    let timerService: TimerService

    var selectedProject: Project?
    var notes: String = ""

    var showingSavedTimers = false

    init(timerService: TimerService) {
        self.timerService = timerService
    }

    // MARK: - Timer Controls

    func start() {
        timerService.start(
            projectID: selectedProject?.id,
            notes: notes.isEmpty ? nil : notes,
            projectName: selectedProject?.name,
            clientName: selectedProject?.client?.name,
            colorHex: selectedProject?.resolvedColorHex
        )
    }

    func stop(context: ModelContext) {
        timerService.stop(context: context)
        notes = ""
    }

    func pause() {
        timerService.pause()
    }

    func resume() {
        timerService.resume()
    }

    func discard() {
        timerService.discard()
        resetForm()
    }

    // MARK: - Project Selection

    func selectProject(_ project: Project?) {
        selectedProject = project
        if timerService.isRunning || timerService.isPaused {
            timerService.currentProjectID = project?.id
        }
    }

    // MARK: - Saved Timer Quick Start

    func startSavedTimer(project: Project, notes savedNotes: String?) {
        selectedProject = project
        notes = savedNotes ?? ""
        timerService.start(
            projectID: project.id,
            notes: savedNotes,
            projectName: project.name,
            clientName: project.client?.name,
            colorHex: project.resolvedColorHex
        )
    }

    // MARK: - Computed Properties

    var isActive: Bool {
        timerService.isRunning || timerService.isPaused
    }

    var timerTint: Color {
        if timerService.isRunning { return .green }
        if timerService.isPaused { return .orange }
        return .secondary
    }

    var todayTotalDuration: TimeInterval {
        // Computed externally from @Query results
        0
    }

    // MARK: - Private

    private func resetForm() {
        selectedProject = nil
        notes = ""
    }
}
