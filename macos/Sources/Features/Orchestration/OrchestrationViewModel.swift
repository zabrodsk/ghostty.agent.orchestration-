import AppKit
import SwiftUI
import GhosttyKit

/// View model for orchestration panel
@MainActor
class OrchestrationViewModel: ObservableObject {
    @Published var surfaces: [SurfaceDisplayState] = []
    @Published var selectedSurfaceId: Ghostty.SurfaceView.ID?

    private var focusHandler: ((Ghostty.SurfaceView) -> Void)?
    private var latestFocusedSurface: Weak<Ghostty.SurfaceView>?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        let trackedNotifications: [Notification.Name] = [
            .orchestrationGlobalStateDidChange,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.willCloseNotification,
            NSApplication.didBecomeActiveNotification
        ]

        observers = trackedNotifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.rebuildFromGlobalState()
            }
        }

        rebuildFromGlobalState()
    }

    deinit {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    func setFocusHandler(_ handler: @escaping (Ghostty.SurfaceView) -> Void) {
        focusHandler = handler
    }

    func update(
        surfaceTree: SplitTree<Ghostty.SurfaceView>,
        focusedSurface: Ghostty.SurfaceView?
    ) {
        _ = surfaceTree
        latestFocusedSurface = .init(focusedSurface)
        rebuildFromGlobalState(preferredFocusedSurface: focusedSurface)
        Self.postGlobalStateDidChange()
    }

    func refresh() {
        rebuildFromGlobalState(preferredFocusedSurface: latestFocusedSurface?.value)
    }

    func focusSurface(surfaceId: Ghostty.SurfaceView.ID) {
        let fallbackSurface = surfaces.first(where: { $0.id == surfaceId })?.surfaceView
        let targetSurface = fallbackSurface ?? allTerminalControllers()
            .flatMap { $0.surfaceTree.map { $0 } }
            .first(where: { $0.id == surfaceId })
        guard let targetSurface else { return }

        selectedSurfaceId = surfaceId
        if let controller = targetSurface.window?.windowController as? BaseTerminalController {
            controller.focusSurface(targetSurface)
            return
        }
        focusHandler?(targetSurface)
    }

    private func rebuildFromGlobalState(preferredFocusedSurface: Ghostty.SurfaceView? = nil) {
        let controllers = allTerminalControllers()
        let mapped = mapGlobalSurfaces(from: controllers)
        surfaces = mapped

        if let selectedSurfaceId, mapped.contains(where: { $0.id == selectedSurfaceId }) {
            return
        }

        let focusedSurface = globallyFocusedSurface(from: controllers) ?? preferredFocusedSurface
        if let focusedSurface,
           mapped.contains(where: { $0.id == focusedSurface.id }) {
            selectedSurfaceId = focusedSurface.id
            return
        }

        selectedSurfaceId = mapped.first?.id
    }

    private func allTerminalControllers() -> [BaseTerminalController] {
        NSApp.windows.compactMap { $0.windowController as? BaseTerminalController }
    }

    private func mapGlobalSurfaces(from controllers: [BaseTerminalController]) -> [SurfaceDisplayState] {
        let orderedWindowIndex = Dictionary(uniqueKeysWithValues: NSApp.orderedWindows.enumerated().map { ($0.element.windowNumber, $0.offset) })
        let sortedControllers = controllers.sorted { lhs, rhs in
            let lhsOrder = lhs.window.flatMap { orderedWindowIndex[$0.windowNumber] } ?? Int.max
            let rhsOrder = rhs.window.flatMap { orderedWindowIndex[$0.windowNumber] } ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return (lhs.window?.windowNumber ?? 0) < (rhs.window?.windowNumber ?? 0)
        }

        var seen = Set<Ghostty.SurfaceView.ID>()
        return sortedControllers.flatMap { controller in
            controller.surfaceTree.compactMap { surface in
                guard seen.insert(surface.id).inserted else { return nil }
                let metadata = OrchestrationSurfaceParser.parse(
                    title: surface.title,
                    cwd: surface.pwd,
                    processExited: surface.processExited
                )
                return SurfaceDisplayState(
                    surfaceView: surface,
                    title: metadata.title,
                    cwd: metadata.cwd,
                    activeProcess: metadata.activeProcessText,
                    lastCommand: "",
                    activityState: metadata.activityState,
                    aiState: .none,
                    aiToolName: nil
                )
            }
        }
    }

    private func globallyFocusedSurface(from controllers: [BaseTerminalController]) -> Ghostty.SurfaceView? {
        if let keyFocused = controllers.first(where: { $0.window?.isKeyWindow == true })?.focusedSurface {
            return keyFocused
        }
        return controllers.first(where: { $0.window?.isMainWindow == true })?.focusedSurface
    }

    private static func postGlobalStateDidChange() {
        NotificationCenter.default.post(name: .orchestrationGlobalStateDidChange, object: nil)
    }
}

extension Notification.Name {
    static let orchestrationGlobalStateDidChange = Notification.Name("com.mitchellh.ghostty.orchestrationGlobalStateDidChange")
}

/// Display state for a terminal surface (Swift representation)
struct SurfaceDisplayState: Identifiable {
    let surfaceView: Ghostty.SurfaceView
    let title: String
    let cwd: String
    let activeProcess: String
    let lastCommand: String
    let activityState: ActivityState
    let aiState: AIState
    let aiToolName: String?

    var id: Ghostty.SurfaceView.ID { surfaceView.id }

    var cwdShort: String {
        OrchestrationSurfaceParser.shortCwd(cwd)
    }

    enum ActivityState {
        case idle
        case busy
        case waiting_input
    }

    enum AIState {
        case none
        case ai_active
        case ai_waiting_input
        case ai_processing
        case ai_done
    }
}

struct ParsedSurfaceMetadata {
    let title: String
    let cwd: String
    let activeProcessText: String
    let activityState: SurfaceDisplayState.ActivityState
}

enum OrchestrationSurfaceParser {
    private static let fallbackTitle = "Terminal"
    private static let fallbackCwd = "~"
    private static let shellProcesses: Set<String> = [
        "bash", "zsh", "sh", "fish", "nu", "pwsh", "powershell", "xonsh"
    ]
    private static let titleSeparators = [" — ", " – ", " - ", " | ", " · "]

    static func parse(title rawTitle: String, cwd rawCwd: String?, processExited: Bool) -> ParsedSurfaceMetadata {
        let cwd = normalizedCwd(rawCwd)
        let cleanedTitle = sanitize(rawTitle)
        let processCandidate = processName(from: cleanedTitle)
        let activityState = activityState(processExited: processExited, processCandidate: processCandidate)
        return .init(
            title: displayTitle(from: cleanedTitle, cwd: cwd),
            cwd: cwd,
            activeProcessText: activeProcessText(
                processExited: processExited,
                processCandidate: processCandidate,
                activityState: activityState
            ),
            activityState: activityState
        )
    }

    static func shortCwd(_ cwd: String) -> String {
        let normalized = normalizedCwd(cwd)
        if normalized == "/" || normalized == fallbackCwd {
            return normalized
        }

        let abbreviated = (normalized as NSString).abbreviatingWithTildeInPath
        let components = abbreviated.split(separator: "/")
        if components.count <= 2 {
            return abbreviated
        }
        return ".../" + components.suffix(2).joined(separator: "/")
    }

    private static func displayTitle(from title: String, cwd: String) -> String {
        guard !isPlaceholderTitle(title) else {
            let cwdLast = (cwd as NSString).lastPathComponent
            if !cwdLast.isEmpty && cwdLast != "/" && cwdLast != fallbackCwd {
                return cwdLast
            }
            return fallbackTitle
        }
        return title
    }

    private static func normalizedCwd(_ rawCwd: String?) -> String {
        guard let rawCwd else { return fallbackCwd }
        var value = sanitize(rawCwd)
        if value.isEmpty { return fallbackCwd }

        if value.hasPrefix("file://"),
           let url = URL(string: value), url.isFileURL {
            let path = url.path.removingPercentEncoding ?? url.path
            value = sanitize(path)
        }

        while value.count > 1 && value.hasSuffix("/") {
            value.removeLast()
        }

        return value.isEmpty ? fallbackCwd : value
    }

    private static func processName(from title: String) -> String? {
        guard !title.isEmpty else { return nil }

        for separator in titleSeparators {
            if let range = title.range(of: separator, options: .backwards) {
                let candidate = sanitize(String(title[range.upperBound...]))
                if isValidProcessCandidate(candidate) {
                    return candidate
                }
            }
        }

        if isValidProcessCandidate(title), title.split(separator: " ").count == 1 {
            return title
        }

        return nil
    }

    private static func activityState(
        processExited: Bool,
        processCandidate: String?
    ) -> SurfaceDisplayState.ActivityState {
        if processExited {
            return .idle
        }

        if let processCandidate,
           shellProcesses.contains(processCandidate.lowercased()) {
            return .waiting_input
        }

        return .busy
    }

    private static func activeProcessText(
        processExited: Bool,
        processCandidate: String?,
        activityState: SurfaceDisplayState.ActivityState
    ) -> String {
        if processExited {
            return "Exited"
        }
        if let processCandidate {
            return processCandidate
        }

        switch activityState {
        case .waiting_input:
            return "Waiting"
        case .busy:
            return "Running"
        case .idle:
            return "Idle"
        }
    }

    private static func sanitize(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func isPlaceholderTitle(_ title: String) -> Bool {
        if title.isEmpty || title == "👻" {
            return true
        }

        let lowered = title.lowercased()
        let punctuationAndSpace = CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines)
        let stripped = lowered.trimmingCharacters(in: punctuationAndSpace)
        return stripped == "ghostty" || stripped == "terminal"
    }

    private static func isValidProcessCandidate(_ candidate: String) -> Bool {
        guard !candidate.isEmpty else { return false }
        guard !isPlaceholderTitle(candidate) else { return false }
        guard candidate.count <= 40 else { return false }
        guard !candidate.contains("/") else { return false }
        guard !candidate.hasPrefix("~") else { return false }
        return true
    }
}
