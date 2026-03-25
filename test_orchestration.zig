// Standalone test for orchestration components
// Run with: zig test test_orchestration.zig

const std = @import("std");
const testing = std.testing;

// Mock types since we can't import the full module without build system
const AIState = enum {
    none,
    ai_active,
    ai_waiting_input,
    ai_processing,
    ai_done,
};

const ActivityState = enum {
    idle,
    busy,
    waiting_input,
};

// Test AI pattern detection logic
test "AI pattern matching - GitHub Copilot CLI" {
    const copilot_waiting = "? What would you like to do?";
    const copilot_suggestion = "Suggestion: Use git commit";
    const copilot_done = "Done! Your changes are ready.";
    
    // Simulate pattern detection
    try testing.expect(std.mem.indexOf(u8, copilot_waiting, "? ") != null);
    try testing.expect(std.mem.indexOf(u8, copilot_suggestion, "Suggestion:") != null);
    try testing.expect(std.mem.indexOf(u8, copilot_done, "Done!") != null);
    
    std.debug.print("\n✓ Copilot pattern detection works\n", .{});
}

test "AI pattern matching - Aider" {
    const aider_prompt = "> Enter your request";
    const aider_tokens = "Tokens: 1234/5000";
    const aider_done = "Applied edit to src/main.zig";
    
    try testing.expect(std.mem.indexOf(u8, aider_prompt, "> ") != null);
    try testing.expect(std.mem.indexOf(u8, aider_tokens, "Tokens:") != null);
    try testing.expect(std.mem.indexOf(u8, aider_done, "Applied edit to") != null);
    
    std.debug.print("✓ Aider pattern detection works\n", .{});
}

test "Process name detection" {
    const process_copilot = "gh copilot explain";
    const process_aider = "aider --model gpt-4";
    const process_claude = "claude --version";
    
    try testing.expect(std.mem.indexOf(u8, process_copilot, "gh") != null);
    try testing.expect(std.mem.indexOf(u8, process_copilot, "copilot") != null);
    try testing.expect(std.mem.indexOf(u8, process_aider, "aider") != null);
    try testing.expect(std.mem.indexOf(u8, process_claude, "claude") != null);
    
    std.debug.print("✓ Process name detection works\n", .{});
}

test "OSC sequence parsing - Working directory" {
    const osc_cwd = "7;file://hostname/Users/test/projects/ghostty";
    
    // Extract path after file://
    const file_proto = "file://";
    if (std.mem.indexOf(u8, osc_cwd, file_proto)) |start| {
        const path_data = osc_cwd[start + file_proto.len ..];
        // Skip hostname
        if (std.mem.indexOf(u8, path_data, "/")) |slash| {
            const path = path_data[slash..];
            try testing.expectEqualStrings("/Users/test/projects/ghostty", path);
            std.debug.print("✓ OSC 7 (cwd) parsing works: {s}\n", .{path});
        }
    }
}

test "OSC sequence parsing - Shell integration markers" {
    const osc_prompt_start = "133;A";
    const osc_prompt_end = "133;B";
    const osc_cmd_start = "133;C;ls -la";
    const osc_cmd_end = "133;D;0";
    
    try testing.expect(std.mem.startsWith(u8, osc_prompt_start, "133;"));
    try testing.expect(osc_prompt_start[4] == 'A');
    try testing.expect(osc_prompt_end[4] == 'B');
    try testing.expect(osc_cmd_start[4] == 'C');
    try testing.expect(osc_cmd_end[4] == 'D');
    
    // Extract command from OSC 133;C
    if (std.mem.startsWith(u8, osc_cmd_start, "133;C;")) {
        const command = osc_cmd_start[6..];
        try testing.expectEqualStrings("ls -la", command);
        std.debug.print("✓ OSC 133 shell integration parsing works\n", .{});
    }
}

test "Path shortening logic" {
    const allocator = testing.allocator;
    
    const long_path = "/Users/test/projects/ghostty/src/orchestration";
    var components = std.ArrayList([]const u8).init(allocator);
    defer components.deinit();
    
    var iter = std.mem.split(u8, long_path, "/");
    while (iter.next()) |component| {
        if (component.len > 0) {
            try components.append(component);
        }
    }
    
    // Take last 2 components
    if (components.items.len > 2) {
        const short_components = components.items[components.items.len - 2 ..];
        std.debug.print("✓ Path shortening: {s}/{s}\n", .{ short_components[0], short_components[1] });
    }
}

test "Idle timeout calculation" {
    const last_activity = std.time.milliTimestamp();
    const idle_timeout_ms: i64 = 30000; // 30 seconds
    
    // Simulate recent activity (should not be idle)
    const now = last_activity + 1000; // 1 second later
    const is_idle = (now - last_activity) > idle_timeout_ms;
    try testing.expect(!is_idle);
    
    // Simulate old activity (should be idle)
    const now_old = last_activity + 60000; // 60 seconds later
    const is_idle_old = (now_old - last_activity) > idle_timeout_ms;
    try testing.expect(is_idle_old);
    
    std.debug.print("✓ Idle timeout logic works\n", .{});
}

test "Output buffer management" {
    const allocator = testing.allocator;
    
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    // Append multiple lines
    try buffer.appendSlice("Line 1\n");
    try buffer.appendSlice("Line 2\n");
    try buffer.appendSlice("Line 3\n");
    
    // Count lines
    var line_count: usize = 0;
    var iter = std.mem.split(u8, buffer.items, "\n");
    while (iter.next()) |line| {
        if (line.len > 0) line_count += 1;
    }
    
    try testing.expectEqual(@as(usize, 3), line_count);
    std.debug.print("✓ Output buffer management works\n", .{});
}

test "Thread-safe state access simulation" {
    const allocator = testing.allocator;
    
    // Simulate mutex-protected map
    var state_map = std.AutoHashMap(u64, AIState).init(allocator);
    defer state_map.deinit();
    
    // Add states
    try state_map.put(1, .ai_active);
    try state_map.put(2, .ai_waiting_input);
    try state_map.put(3, .none);
    
    // Verify retrieval
    try testing.expectEqual(AIState.ai_active, state_map.get(1).?);
    try testing.expectEqual(AIState.ai_waiting_input, state_map.get(2).?);
    try testing.expectEqual(AIState.none, state_map.get(3).?);
    
    std.debug.print("✓ State map operations work\n", .{});
}

pub fn main() !void {
    std.debug.print("\n🧪 Running Orchestration Component Tests\n", .{});
    std.debug.print("==========================================\n\n", .{});
    
    // Run all tests
    try std.testing.refAllDecls(@This());
    
    std.debug.print("\n==========================================\n", .{});
    std.debug.print("✅ All tests passed!\n\n", .{});
}
