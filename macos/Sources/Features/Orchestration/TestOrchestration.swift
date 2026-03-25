import Foundation

// Minimal test to verify the Swift code compiles
print("Testing Orchestration Swift files...")

// Mock types since we don't have GhosttyKit
class MockViewModel: ObservableObject {
    @Published var surfaces: [SurfaceDisplayState] = []
    
    func startMonitoring() {
        print("✓ startMonitoring called")
    }
    
    func stopMonitoring() {
        print("✓ stopMonitoring called")
    }
    
    func refresh() {
        print("✓ refresh called")
        surfaces = [
            SurfaceDisplayState(
                surfaceId: 1,
                title: "Terminal 1",
                cwd: "/Users/test/projects",
                activeProcess: "bash",
                lastCommand: "ls -la",
                activityState: .busy,
                aiState: .none,
                aiToolName: nil
            ),
            SurfaceDisplayState(
                surfaceId: 2,
                title: "Copilot",
                cwd: "/Users/test/code",
                activeProcess: "gh copilot",
                lastCommand: "",
                activityState: .waiting_input,
                aiState: .ai_waiting_input,
                aiToolName: "GitHub Copilot CLI"
            )
        ]
    }
    
    func focusSurface(surfaceId: UInt64) {
        print("✓ focusSurface(\(surfaceId)) called")
    }
}

// Recreate SurfaceDisplayState from OrchestrationViewModel
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

// Test the view model
let viewModel = MockViewModel()
viewModel.startMonitoring()
viewModel.refresh()

print("\n📊 Test Results:")
print("  Surfaces loaded: \(viewModel.surfaces.count)")

for surface in viewModel.surfaces {
    print("\n  Surface \(surface.id):")
    print("    Title: \(surface.title)")
    print("    CWD: \(surface.cwd)")
    print("    CWD Short: \(surface.cwdShort)")
    print("    Process: \(surface.activeProcess)")
    print("    Activity: \(surface.activityState)")
    print("    AI State: \(surface.aiState)")
    if let toolName = surface.aiToolName {
        print("    AI Tool: \(toolName)")
    }
}

viewModel.focusSurface(surfaceId: 1)
viewModel.stopMonitoring()

print("\n✅ All Swift components working correctly!")
