import Foundation
import WatchConnectivity
import TimelordKit

/// Receives project list and timer state from the iPhone via WatchConnectivity.
@MainActor @Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    var projects: [SharedProject] = []
    var timerState: TimerState?
    var currentProjectName: String?
    var currentProjectColorHex: String?

    override private init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Send a timer action to the iPhone so it mirrors the timer state.
    func sendTimerAction(_ action: String, projectID: UUID? = nil, projectName: String? = nil, colorHex: String? = nil) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }

        var message: [String: Any] = ["action": action]
        if let pid = projectID { message["projectID"] = pid.uuidString }
        if let name = projectName { message["projectName"] = name }
        if let hex = colorHex { message["colorHex"] = hex }

        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// Ask the iPhone to send us the project list via message.
    func requestProjects() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // First, check if there's already a receivedApplicationContext with projects
        let existing = session.receivedApplicationContext
        if let data = existing["projects"] as? Data,
           let decoded = try? JSONDecoder().decode([SharedProject].self, from: data),
           !decoded.isEmpty {
            projects = decoded
            return
        }

        // Otherwise, ask the phone directly
        guard session.isReachable else { return }
        session.sendMessage(["action": "requestProjects"], replyHandler: { reply in
            if let data = reply["projects"] as? Data,
               let decoded = try? JSONDecoder().decode([SharedProject].self, from: data) {
                Task { @MainActor in
                    self.projects = decoded
                }
            }
        }, errorHandler: nil)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            // Read context on this thread before crossing isolation
            let existing = session.receivedApplicationContext
            let projectsData = existing["projects"] as? Data

            Task { @MainActor in
                if let data = projectsData,
                   let decoded = try? JSONDecoder().decode([SharedProject].self, from: data),
                   !decoded.isEmpty {
                    self.projects = decoded
                } else {
                    self.requestProjects()
                }
            }
        }
    }

    /// Called when iPhone sends updated applicationContext.
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let projectsData = applicationContext["projects"] as? Data
        let timerData = applicationContext["timerState"] as? Data
        let projName = applicationContext["currentProjectName"] as? String
        let projColor = applicationContext["currentProjectColorHex"] as? String

        Task { @MainActor in
            processData(projectsData: projectsData, timerData: timerData, projName: projName, projColor: projColor)
        }
    }

    /// Called when iPhone sends a direct message (e.g. timer state update).
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let timerData = message["timerState"] as? Data
        let timerCleared = message["timerCleared"] as? Bool ?? false
        let projName = message["currentProjectName"] as? String
        let projColor = message["currentProjectColorHex"] as? String

        Task { @MainActor in
            if timerCleared {
                self.timerState = nil
                self.currentProjectName = nil
                self.currentProjectColorHex = nil
            } else if let data = timerData,
                      let decoded = try? JSONDecoder().decode(TimerState.self, from: data) {
                self.timerState = decoded
                self.currentProjectName = projName
                self.currentProjectColorHex = projColor
            }
        }
    }

    /// Called when iPhone sends a userInfo transfer.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let projectsData = userInfo["projects"] as? Data

        Task { @MainActor in
            if let data = projectsData,
               let decoded = try? JSONDecoder().decode([SharedProject].self, from: data) {
                self.projects = decoded
            }
        }
    }

    @MainActor
    private func processData(projectsData: Data?, timerData: Data?, projName: String?, projColor: String?) {
        if let data = projectsData,
           let decoded = try? JSONDecoder().decode([SharedProject].self, from: data) {
            projects = decoded
        }

        if let data = timerData,
           let decoded = try? JSONDecoder().decode(TimerState.self, from: data) {
            timerState = decoded
        } else {
            timerState = nil
        }

        currentProjectName = projName
        currentProjectColorHex = projColor
    }
}
