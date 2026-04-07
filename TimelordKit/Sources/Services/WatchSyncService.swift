#if os(iOS)
@preconcurrency import WatchConnectivity
import Foundation

/// Bidirectional sync between iPhone and Apple Watch via WatchConnectivity.
@MainActor
public final class WatchSyncService: NSObject, WCSessionDelegate {
    public static let shared = WatchSyncService()

    private var session: WCSession?

    /// Called when the watch sends a timer action (start/pause/resume/stop).
    public var onTimerAction: ((_ action: String, _ projectID: UUID?, _ projectName: String?, _ colorHex: String?) -> Void)?

    override private init() {
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    /// Send the full project list to the watch.
    public func syncProjects(_ projects: [SharedProject]) {
        guard let session, session.activationState == .activated, session.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(projects) else { return }

        var context = session.applicationContext
        context["projects"] = data
        try? session.updateApplicationContext(context)

        session.transferUserInfo(["projects": data])
    }

    /// Send current timer state to the watch so it mirrors the phone.
    public func syncTimerState() {
        guard let session, session.activationState == .activated, session.isWatchAppInstalled else { return }

        let state = TimerState.load()
        let projName = state?.projectName
        let projColor = state?.colorHex

        // Send as a message for immediate delivery if watch is reachable
        if session.isReachable {
            var message: [String: Any] = [:]
            if let state, let data = try? JSONEncoder().encode(state) {
                message["timerState"] = data
                message["currentProjectName"] = projName as Any
                message["currentProjectColorHex"] = projColor as Any
            } else {
                message["timerCleared"] = true
            }
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }

        // Also update applicationContext for when watch next launches
        var context = session.applicationContext
        if let state, let data = try? JSONEncoder().encode(state) {
            context["timerState"] = data
            context["currentProjectName"] = projName as Any
            context["currentProjectColorHex"] = projColor as Any
        } else {
            context.removeValue(forKey: "timerState")
            context.removeValue(forKey: "currentProjectName")
            context.removeValue(forKey: "currentProjectColorHex")
        }
        try? session.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Watch sent a message with reply handler (e.g. requestProjects).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let action = message["action"] as? String
        if action == "requestProjects" {
            let projects = SharedProjectSync.read()
            if let data = try? JSONEncoder().encode(projects) {
                replyHandler(["projects": data])
            } else {
                replyHandler([:])
            }
        } else {
            replyHandler([:])
        }
    }

    /// Watch sent a fire-and-forget message (timer actions).
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        let action = message["action"] as? String
        let projectIDString = message["projectID"] as? String
        let projectID = projectIDString.flatMap { UUID(uuidString: $0) }
        let projectName = message["projectName"] as? String
        let colorHex = message["colorHex"] as? String

        if let action {
            Task { @MainActor in
                self.onTimerAction?(action, projectID, projectName, colorHex)
            }
        }
    }
}
#endif
