/// Orchestration module - Terminal state tracking and AI assistant detection
/// Public API for the orchestration system
pub const state = @import("state.zig");
pub const StateTracker = @import("StateTracker.zig");
pub const AIDetector = @import("AIDetector.zig");

pub const SurfaceState = state.SurfaceState;
pub const AIState = state.AIState;
pub const ActivityState = state.ActivityState;
pub const OrchestrationConfig = state.OrchestrationConfig;

/// Combined orchestration manager
pub const Orchestrator = struct {
    state_tracker: StateTracker,
    ai_detector: AIDetector,
    
    pub fn init(allocator: std.mem.Allocator, config: OrchestrationConfig) !Orchestrator {
        return .{
            .state_tracker = StateTracker.init(allocator, config),
            .ai_detector = try AIDetector.init(allocator),
        };
    }
    
    pub fn deinit(self: *Orchestrator) void {
        self.state_tracker.deinit();
        self.ai_detector.deinit();
    }
    
    /// Process PTY output and update AI state
    pub fn processPtyOutput(
        self: *Orchestrator,
        surface_id: u64,
        output: []const u8,
    ) !void {
        // Update state tracker
        try self.state_tracker.processPtyOutput(surface_id, output);
        
        // Get current state
        if (self.state_tracker.getState(surface_id)) |current_state| {
            // Detect AI state from output and process
            const detection = self.ai_detector.detect(
                current_state.recent_output,
                current_state.active_process,
            );
            
            // Update AI state in tracker
            self.state_tracker.mutex.lock();
            defer self.state_tracker.mutex.unlock();
            
            if (self.state_tracker.states.getPtr(surface_id)) |surface_state| {
                surface_state.ai_state = detection.ai_state;
                
                // Update tool name if detected
                if (detection.tool_name) |tool_name| {
                    if (surface_state.ai_tool_name == null or
                        !std.mem.eql(u8, surface_state.ai_tool_name.?, tool_name)) {
                        if (surface_state.ai_tool_name) |old_name| {
                            self.state_tracker.allocator.free(old_name);
                        }
                        surface_state.ai_tool_name = try self.state_tracker.allocator.dupe(u8, tool_name);
                    }
                }
            }
        }
    }
};

const std = @import("std");

test "orchestration module" {
    const testing = std.testing;
    _ = testing;
    
    // Import all submodules to ensure they compile
    _ = state;
    _ = StateTracker;
    _ = AIDetector;
}
