/// AI assistant detection and state classification
/// Detects AI coding tools via pattern matching and process detection
const std = @import("std");
const Allocator = std.mem.Allocator;
const state = @import("state.zig");
const AIState = state.AIState;

const AIDetector = @This();

allocator: Allocator,
patterns: std.ArrayList(AIPattern),
process_patterns: std.ArrayList(ProcessPattern),

/// AI tool output pattern for detection
pub const AIPattern = struct {
    tool_name: []const u8,
    waiting_pattern: []const u8,
    processing_pattern: []const u8,
    done_pattern: []const u8,
    active_pattern: []const u8, // Generic "AI is running" pattern
};

/// Process name pattern for AI tool detection
pub const ProcessPattern = struct {
    tool_name: []const u8,
    process_names: []const []const u8, // e.g., ["gh", "copilot"]
    env_vars: []const []const u8, // Required environment variables
};

pub fn init(allocator: Allocator) !AIDetector {
    var detector = AIDetector{
        .allocator = allocator,
        .patterns = std.ArrayList(AIPattern).init(allocator),
        .process_patterns = std.ArrayList(ProcessPattern).init(allocator),
    };
    
    // Initialize with default AI tool patterns
    try detector.addDefaultPatterns();
    
    return detector;
}

pub fn deinit(self: *AIDetector) void {
    for (self.patterns.items) |pattern| {
        self.allocator.free(pattern.tool_name);
        self.allocator.free(pattern.waiting_pattern);
        self.allocator.free(pattern.processing_pattern);
        self.allocator.free(pattern.done_pattern);
        self.allocator.free(pattern.active_pattern);
    }
    self.patterns.deinit();
    
    for (self.process_patterns.items) |pattern| {
        self.allocator.free(pattern.tool_name);
        for (pattern.process_names) |name| {
            self.allocator.free(name);
        }
        self.allocator.free(pattern.process_names);
        for (pattern.env_vars) |env| {
            self.allocator.free(env);
        }
        self.allocator.free(pattern.env_vars);
    }
    self.process_patterns.deinit();
}

/// Add default patterns for known AI tools
fn addDefaultPatterns(self: *AIDetector) !void {
    // GitHub Copilot CLI
    try self.patterns.append(.{
        .tool_name = try self.allocator.dupe(u8, "GitHub Copilot CLI"),
        .waiting_pattern = try self.allocator.dupe(u8, "? "),
        .processing_pattern = try self.allocator.dupe(u8, "Suggestion:"),
        .done_pattern = try self.allocator.dupe(u8, "Done!"),
        .active_pattern = try self.allocator.dupe(u8, "Welcome to GitHub Copilot"),
    });
    
    const copilot_processes = try self.allocator.alloc([]const u8, 2);
    copilot_processes[0] = try self.allocator.dupe(u8, "gh");
    copilot_processes[1] = try self.allocator.dupe(u8, "copilot");
    
    const copilot_env = try self.allocator.alloc([]const u8, 0);
    
    try self.process_patterns.append(.{
        .tool_name = try self.allocator.dupe(u8, "GitHub Copilot CLI"),
        .process_names = copilot_processes,
        .env_vars = copilot_env,
    });
    
    // Aider
    try self.patterns.append(.{
        .tool_name = try self.allocator.dupe(u8, "Aider"),
        .waiting_pattern = try self.allocator.dupe(u8, "> "),
        .processing_pattern = try self.allocator.dupe(u8, "Tokens:"),
        .done_pattern = try self.allocator.dupe(u8, "Applied edit to"),
        .active_pattern = try self.allocator.dupe(u8, "Aider v"),
    });
    
    const aider_processes = try self.allocator.alloc([]const u8, 1);
    aider_processes[0] = try self.allocator.dupe(u8, "aider");
    
    const aider_env = try self.allocator.alloc([]const u8, 0);
    
    try self.process_patterns.append(.{
        .tool_name = try self.allocator.dupe(u8, "Aider"),
        .process_names = aider_processes,
        .env_vars = aider_env,
    });
    
    // Claude CLI / Custom AI
    try self.patterns.append(.{
        .tool_name = try self.allocator.dupe(u8, "Claude"),
        .waiting_pattern = try self.allocator.dupe(u8, "[Y/n]"),
        .processing_pattern = try self.allocator.dupe(u8, "Thinking..."),
        .done_pattern = try self.allocator.dupe(u8, "Task complete"),
        .active_pattern = try self.allocator.dupe(u8, "Claude"),
    });
    
    const claude_processes = try self.allocator.alloc([]const u8, 1);
    claude_processes[0] = try self.allocator.dupe(u8, "claude");
    
    const claude_env = try self.allocator.alloc([]const u8, 0);
    
    try self.process_patterns.append(.{
        .tool_name = try self.allocator.dupe(u8, "Claude"),
        .process_names = claude_processes,
        .env_vars = claude_env,
    });
    
    // Cursor / Codex
    try self.patterns.append(.{
        .tool_name = try self.allocator.dupe(u8, "Codex"),
        .waiting_pattern = try self.allocator.dupe(u8, "Continue?"),
        .processing_pattern = try self.allocator.dupe(u8, "Generating"),
        .done_pattern = try self.allocator.dupe(u8, "Complete"),
        .active_pattern = try self.allocator.dupe(u8, "Codex"),
    });
}

/// Add custom AI pattern
pub fn addPattern(self: *AIDetector, pattern: AIPattern) !void {
    const owned_pattern = AIPattern{
        .tool_name = try self.allocator.dupe(u8, pattern.tool_name),
        .waiting_pattern = try self.allocator.dupe(u8, pattern.waiting_pattern),
        .processing_pattern = try self.allocator.dupe(u8, pattern.processing_pattern),
        .done_pattern = try self.allocator.dupe(u8, pattern.done_pattern),
        .active_pattern = try self.allocator.dupe(u8, pattern.active_pattern),
    };
    try self.patterns.append(owned_pattern);
}

/// Detect AI state from terminal output
pub fn detectFromOutput(self: *AIDetector, output: []const u8) AIState {
    if (output.len == 0) return .none;
    
    // Check each pattern
    for (self.patterns.items) |pattern| {
        // Check waiting pattern (highest priority)
        if (std.mem.indexOf(u8, output, pattern.waiting_pattern)) |_| {
            return .ai_waiting_input;
        }
        
        // Check processing pattern
        if (std.mem.indexOf(u8, output, pattern.processing_pattern)) |_| {
            return .ai_processing;
        }
        
        // Check done pattern
        if (std.mem.indexOf(u8, output, pattern.done_pattern)) |_| {
            return .ai_done;
        }
        
        // Check active pattern
        if (std.mem.indexOf(u8, output, pattern.active_pattern)) |_| {
            return .ai_active;
        }
    }
    
    return .none;
}

/// Detect AI tool from process name
pub fn detectFromProcess(self: *AIDetector, process_name: []const u8) ?[]const u8 {
    if (process_name.len == 0) return null;
    
    for (self.process_patterns.items) |pattern| {
        for (pattern.process_names) |proc_name| {
            if (std.mem.indexOf(u8, process_name, proc_name)) |_| {
                return pattern.tool_name;
            }
        }
    }
    
    return null;
}

/// Detect AI tool and state from both output and process
pub fn detect(
    self: *AIDetector,
    output: []const u8,
    process_name: []const u8,
) struct { ai_state: AIState, tool_name: ?[]const u8 } {
    // First check process name
    const tool_from_process = self.detectFromProcess(process_name);
    
    // Then check output patterns
    const state_from_output = self.detectFromOutput(output);
    
    // Determine final state
    const final_state = if (state_from_output != .none)
        state_from_output
    else if (tool_from_process != null)
        .ai_active
    else
        .none;
    
    return .{
        .ai_state = final_state,
        .tool_name = tool_from_process,
    };
}

/// Get tool name from output patterns
pub fn getToolNameFromOutput(self: *AIDetector, output: []const u8) ?[]const u8 {
    for (self.patterns.items) |pattern| {
        if (std.mem.indexOf(u8, output, pattern.active_pattern)) |_| {
            return pattern.tool_name;
        }
    }
    return null;
}

test "AIDetector basic detection" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var detector = try AIDetector.init(allocator);
    defer detector.deinit();
    
    // Test GitHub Copilot CLI detection
    const copilot_output = "? What would you like to do?";
    const state = detector.detectFromOutput(copilot_output);
    try testing.expectEqual(AIState.ai_waiting_input, state);
    
    // Test process detection
    const tool = detector.detectFromProcess("gh copilot");
    try testing.expect(tool != null);
    try testing.expectEqualStrings("GitHub Copilot CLI", tool.?);
    
    // Test Aider detection
    const aider_output = "Applied edit to file.txt";
    const aider_state = detector.detectFromOutput(aider_output);
    try testing.expectEqual(AIState.ai_done, aider_state);
}

test "AIDetector combined detection" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var detector = try AIDetector.init(allocator);
    defer detector.deinit();
    
    // Test combined detection
    const result = detector.detect("Tokens: 1234", "aider");
    try testing.expectEqual(AIState.ai_processing, result.ai_state);
    try testing.expect(result.tool_name != null);
    try testing.expectEqualStrings("Aider", result.tool_name.?);
}
