import SwiftUI
import GhosttyKit
import Combine

/// View model for orchestration panel
class OrchestrationViewModel: ObservableObject {
    @Published var surfaces: [SurfaceDisplayState] = []
    
    private var updateTimer: Timer?
    private var ghosttyApp: Ghostty.App?
    
    init() {
        // Initialize with app reference if available
    }
    
    func startMonitoring() {
        // Start periodic updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        
        // Initial refresh
        refresh()
    }
    
    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func refresh() {
        // TODO: Query orchestration state from Ghostty core
        // For now, create mock data
        
        DispatchQueue.main.async {
            // This will be replaced with actual bridge to Zig orchestration code
            // self.surfaces = fetchSurfacesFromGhostty()
        }
    }
    
    func focusSurface(surfaceId: UInt64) {
        // TODO: Call Ghostty focus API
        // ghosttyApp?.focusSurface(withId: surfaceId)
        print("Focus surface: \(surfaceId)")
    }
}

/// Display state for a terminal surface (Swift representation)
struct SurfaceDisplayState: Identifiable {
    let surfaceId: UInt64
    let title: String
    let cwd: String
    let activeProcess: String
    let lastCommand: String
    let activityState: ActivityState
    let aiState: AIState
    let aiToolName: String?
    
    var id: UInt64 { surfaceId }
    
    var cwdShort: String {
        // Get last 2 path components
        let components = cwd.split(separator: "/")
        if components.count > 2 {
            return "…/" + components.suffix(2).joined(separator: "/")
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
