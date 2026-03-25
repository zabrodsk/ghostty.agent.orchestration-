/// Shared types for orchestration state tracking
const std = @import("std");

/// AI assistant state classification
pub const AIState = enum {
    none, // No AI tool detected
    ai_active, // AI tool running
    ai_waiting_input, // AI asking question/waiting for user
    ai_processing, // AI generating response
    ai_done, // AI completed task
};

/// Terminal activity state
pub const ActivityState = enum {
    idle, // No recent activity
    busy, // Active command running
    waiting_input, // Shell waiting for input
};

/// Complete orchestration state for a terminal surface
pub const SurfaceState = struct {
    surface_id: u64,
    
    // Working directory
    cwd: []const u8,
    
    // Active process information
    active_process: []const u8,
    active_pid: ?std.os.pid_t,
    
    // Last executed command
    last_command: []const u8,
    
    // Activity tracking
    activity_state: ActivityState,
    last_activity_time: i64, // Unix timestamp in milliseconds
    
    // AI assistant state
    ai_state: AIState,
    ai_tool_name: ?[]const u8, // e.g., "gh copilot", "aider"
    
    // Output buffer (for pattern matching)
    recent_output: []const u8, // Last N lines of output
    
    // Surface metadata
    title: []const u8,
    
    pub fn init(allocator: std.mem.Allocator, surface_id: u64) !SurfaceState {
        return SurfaceState{
            .surface_id = surface_id,
            .cwd = try allocator.dupe(u8, "~"),
            .active_process = try allocator.dupe(u8, ""),
            .active_pid = null,
            .last_command = try allocator.dupe(u8, ""),
            .activity_state = .idle,
            .last_activity_time = std.time.milliTimestamp(),
            .ai_state = .none,
            .ai_tool_name = null,
            .recent_output = try allocator.alloc(u8, 0),
            .title = try allocator.dupe(u8, "Terminal"),
        };
    }
    
    pub fn deinit(self: *SurfaceState, allocator: std.mem.Allocator) void {
        allocator.free(self.cwd);
        allocator.free(self.active_process);
        allocator.free(self.last_command);
        allocator.free(self.recent_output);
        allocator.free(self.title);
        if (self.ai_tool_name) |name| {
            allocator.free(name);
        }
    }
    
    /// Update working directory
    pub fn updateCwd(self: *SurfaceState, allocator: std.mem.Allocator, new_cwd: []const u8) !void {
        allocator.free(self.cwd);
        self.cwd = try allocator.dupe(u8, new_cwd);
        self.last_activity_time = std.time.milliTimestamp();
    }
    
    /// Update active process
    pub fn updateProcess(self: *SurfaceState, allocator: std.mem.Allocator, process_name: []const u8, pid: ?std.os.pid_t) !void {
        allocator.free(self.active_process);
        self.active_process = try allocator.dupe(u8, process_name);
        self.active_pid = pid;
        self.last_activity_time = std.time.milliTimestamp();
    }
    
    /// Update last command
    pub fn updateCommand(self: *SurfaceState, allocator: std.mem.Allocator, command: []const u8) !void {
        allocator.free(self.last_command);
        self.last_command = try allocator.dupe(u8, command);
        self.last_activity_time = std.time.milliTimestamp();
    }
    
    /// Append to recent output buffer (keeping last N lines)
    pub fn appendOutput(self: *SurfaceState, allocator: std.mem.Allocator, output: []const u8, max_lines: usize) !void {
        const max_buffer_size = 4096; // 4KB buffer
        
        // Append new output
        const new_output = try std.mem.concat(allocator, u8, &[_][]const u8{ self.recent_output, output });
        allocator.free(self.recent_output);
        
        // Trim to max lines
        var lines = std.mem.splitBackwards(u8, new_output, "\n");
        var line_count: usize = 0;
        var total_len: usize = 0;
        
        while (lines.next()) |_| {
            line_count += 1;
            if (line_count >= max_lines) break;
        }
        
        // Keep last max_lines or max_buffer_size
        if (new_output.len > max_buffer_size) {
            const start = new_output.len - max_buffer_size;
            self.recent_output = try allocator.dupe(u8, new_output[start..]);
            allocator.free(new_output);
        } else {
            self.recent_output = new_output;
        }
        
        self.last_activity_time = std.time.milliTimestamp();
    }
    
    /// Check if terminal is idle based on timeout
    pub fn isIdle(self: *const SurfaceState, idle_timeout_ms: i64) bool {
        const now = std.time.milliTimestamp();
        return (now - self.last_activity_time) > idle_timeout_ms;
    }
};

/// Configuration for orchestration
pub const OrchestrationConfig = struct {
    enabled: bool = true,
    panel_position: PanelPosition = .left,
    panel_width: u16 = 300,
    auto_hide: bool = false,
    show_ai_indicators: bool = true,
    update_interval_ms: u32 = 500,
    idle_timeout_ms: i64 = 30000, // 30 seconds
    max_output_lines: usize = 50,
    
    pub const PanelPosition = enum {
        left,
        right,
    };
};
