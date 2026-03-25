/// Terminal state tracking for orchestration
/// Monitors PTY output and maintains state metadata for each surface
const std = @import("std");
const Allocator = std.mem.Allocator;
const state = @import("state.zig");
const SurfaceState = state.SurfaceState;
const ActivityState = state.ActivityState;

const StateTracker = @This();

allocator: Allocator,
states: std.AutoHashMap(u64, SurfaceState),
mutex: std.Thread.Mutex,
config: state.OrchestrationConfig,

pub fn init(allocator: Allocator, config: state.OrchestrationConfig) StateTracker {
    return .{
        .allocator = allocator,
        .states = std.AutoHashMap(u64, SurfaceState).init(allocator),
        .mutex = .{},
        .config = config,
    };
}

pub fn deinit(self: *StateTracker) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    var it = self.states.iterator();
    while (it.next()) |entry| {
        var surface_state = entry.value_ptr;
        surface_state.deinit(self.allocator);
    }
    self.states.deinit();
}

/// Register a new surface for tracking
pub fn registerSurface(self: *StateTracker, surface_id: u64) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.contains(surface_id)) {
        return; // Already registered
    }
    
    const surface_state = try SurfaceState.init(self.allocator, surface_id);
    try self.states.put(surface_id, surface_state);
}

/// Unregister a surface
pub fn unregisterSurface(self: *StateTracker, surface_id: u64) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.fetchRemove(surface_id)) |entry| {
        var surface_state = entry.value;
        surface_state.deinit(self.allocator);
    }
}

/// Update working directory for a surface
pub fn updateCwd(self: *StateTracker, surface_id: u64, cwd: []const u8) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.getPtr(surface_id)) |surface_state| {
        try surface_state.updateCwd(self.allocator, cwd);
    }
}

/// Update active process for a surface
pub fn updateProcess(self: *StateTracker, surface_id: u64, process_name: []const u8, pid: ?std.os.pid_t) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.getPtr(surface_id)) |surface_state| {
        try surface_state.updateProcess(self.allocator, process_name, pid);
    }
}

/// Update last command for a surface
pub fn updateCommand(self: *StateTracker, surface_id: u64, command: []const u8) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.getPtr(surface_id)) |surface_state| {
        try surface_state.updateCommand(self.allocator, command);
    }
}

/// Update title for a surface
pub fn updateTitle(self: *StateTracker, surface_id: u64, title: []const u8) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.getPtr(surface_id)) |surface_state| {
        self.allocator.free(surface_state.title);
        surface_state.title = try self.allocator.dupe(u8, title);
    }
}

/// Process PTY output for a surface
pub fn processPtyOutput(self: *StateTracker, surface_id: u64, output: []const u8) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.getPtr(surface_id)) |surface_state| {
        // Append to recent output buffer
        try surface_state.appendOutput(self.allocator, output, self.config.max_output_lines);
        
        // Detect activity state from output
        if (output.len > 0) {
            surface_state.activity_state = .busy;
        }
    }
}

/// Update activity state for a surface
pub fn updateActivityState(self: *StateTracker, surface_id: u64, activity_state: ActivityState) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.getPtr(surface_id)) |surface_state| {
        surface_state.activity_state = activity_state;
        surface_state.last_activity_time = std.time.milliTimestamp();
    }
}

/// Get state for a surface (creates a copy)
pub fn getState(self: *StateTracker, surface_id: u64) ?SurfaceState {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    if (self.states.get(surface_id)) |surface_state| {
        // Return a copy (shallow, strings are shared)
        return surface_state;
    }
    return null;
}

/// Get all surface states (creates copies)
pub fn getAllStates(self: *StateTracker, allocator: Allocator) ![]SurfaceState {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    var states_list = std.ArrayList(SurfaceState).init(allocator);
    errdefer states_list.deinit();
    
    var it = self.states.iterator();
    while (it.next()) |entry| {
        try states_list.append(entry.value_ptr.*);
    }
    
    return states_list.toOwnedSlice();
}

/// Update idle states based on timeout
pub fn updateIdleStates(self: *StateTracker) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    var it = self.states.iterator();
    while (it.next()) |entry| {
        var surface_state = entry.value_ptr;
        
        if (surface_state.activity_state == .busy and 
            surface_state.isIdle(self.config.idle_timeout_ms)) {
            surface_state.activity_state = .idle;
        }
    }
}

/// Parse OSC sequences from PTY output
pub fn parseOscSequence(self: *StateTracker, surface_id: u64, osc_data: []const u8) !void {
    // OSC sequences for shell integration:
    // OSC 7 ; file://host/path ST - Current working directory
    // OSC 133 ; A ST - Prompt start
    // OSC 133 ; B ST - Prompt end
    // OSC 133 ; C ST - Command start
    // OSC 133 ; D ; [exit code] ST - Command end
    
    if (std.mem.startsWith(u8, osc_data, "7;")) {
        // Working directory update: OSC 7;file://host/path
        const path_start = std.mem.indexOf(u8, osc_data, "file://");
        if (path_start) |start| {
            const path_data = osc_data[start + 7 ..];
            // Skip host part
            if (std.mem.indexOf(u8, path_data, "/")) |first_slash| {
                const path = path_data[first_slash..];
                try self.updateCwd(surface_id, path);
            }
        }
    } else if (std.mem.startsWith(u8, osc_data, "133;")) {
        // Shell integration markers
        const marker = osc_data[4..];
        
        if (marker.len > 0) {
            switch (marker[0]) {
                'A' => {
                    // Prompt start - terminal is waiting for input
                    self.updateActivityState(surface_id, .waiting_input);
                },
                'C' => {
                    // Command start - capture command if available
                    if (marker.len > 2 and marker[1] == ';') {
                        const command = marker[2..];
                        try self.updateCommand(surface_id, command);
                    }
                    self.updateActivityState(surface_id, .busy);
                },
                'D' => {
                    // Command end - back to idle/waiting
                    self.updateActivityState(surface_id, .waiting_input);
                },
                else => {},
            }
        }
    }
}

test "StateTracker basic operations" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    const config = state.OrchestrationConfig{};
    var tracker = StateTracker.init(allocator, config);
    defer tracker.deinit();
    
    // Register surface
    try tracker.registerSurface(1);
    
    // Update various fields
    try tracker.updateCwd(1, "/home/user/projects");
    try tracker.updateProcess(1, "bash", 12345);
    try tracker.updateCommand(1, "ls -la");
    
    // Get state
    const surface_state = tracker.getState(1).?;
    try testing.expectEqualStrings("/home/user/projects", surface_state.cwd);
    try testing.expectEqualStrings("bash", surface_state.active_process);
    try testing.expectEqualStrings("ls -la", surface_state.last_command);
    try testing.expectEqual(@as(?std.os.pid_t, 12345), surface_state.active_pid);
    
    // Unregister
    tracker.unregisterSurface(1);
    try testing.expect(tracker.getState(1) == null);
}
