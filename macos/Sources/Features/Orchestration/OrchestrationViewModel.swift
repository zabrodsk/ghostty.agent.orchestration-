import SwiftUI
import GhosttyKit

/// View model for orchestration panel
class OrchestrationViewModel: ObservableObject {
    @Published var surfaces: [SurfaceDisplayState] = []
    @Published var selectedSurfaceId: Ghostty.SurfaceView.ID?

    private var focusHandler: ((Ghostty.SurfaceView) -> Void)?
    private var latestSurfaceTree: SplitTree<Ghostty.SurfaceView> = .init()
    private var latestFocusedSurface: Ghostty.SurfaceView?

    func setFocusHandler(_ handler: @escaping (Ghostty.SurfaceView) -> Void) {
        focusHandler = handler
    }

    func update(
        surfaceTree: SplitTree<Ghostty.SurfaceView>,
        focusedSurface: Ghostty.SurfaceView?
    ) {
        latestSurfaceTree = surfaceTree
        latestFocusedSurface = focusedSurface

        let mapped = surfaceTree.map { surface in
            SurfaceDisplayState(
                surfaceView: surface,
                title: surface.title.isEmpty ? "Terminal" : surface.title,
                cwd: surface.pwd ?? "",
                activeProcess: "",
                lastCommand: "",
                activityState: surface.processExited ? .idle : .busy,
                aiState: .none,
                aiToolName: nil
            )
        }

        surfaces = mapped

        if let focusedSurface, mapped.contains(where: { $0.id == focusedSurface.id }) {
            selectedSurfaceId = focusedSurface.id
            return
        }

        if let selectedSurfaceId, mapped.contains(where: { $0.id == selectedSurfaceId }) {
            return
        }

        selectedSurfaceId = mapped.first?.id
    }

    func refresh() {
        update(surfaceTree: latestSurfaceTree, focusedSurface: latestFocusedSurface)
    }

    func focusSurface(surfaceId: Ghostty.SurfaceView.ID) {
        guard let surface = surfaces.first(where: { $0.id == surfaceId })?.surfaceView else { return }
        selectedSurfaceId = surfaceId
        focusHandler?(surface)
    }
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
        // Get last 2 path components
        let components = cwd.split(separator: "/")
        if components.count > 2 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return cwd
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
