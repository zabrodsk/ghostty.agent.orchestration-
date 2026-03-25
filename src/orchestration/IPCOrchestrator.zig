/// IPC Orchestrator - Cross-process terminal state aggregation
/// Discovers and communicates with multiple Ghostty instances
const std = @import("std");
const Allocator = std.mem.Allocator;
const state = @import("state.zig");
const SurfaceState = state.SurfaceState;

const IPCOrchestrator = @This();

allocator: Allocator,
instance_id: u64,
socket_path: []const u8,
known_instances: std.ArrayList(InstanceInfo),
mutex: std.Thread.Mutex,

/// Information about a Ghostty instance
pub const InstanceInfo = struct {
    instance_id: u64,
    socket_path: []const u8,
    last_seen: i64, // Unix timestamp
    surfaces: std.ArrayList(SurfaceState),
    
    pub fn init(allocator: Allocator, instance_id: u64, socket_path: []const u8) InstanceInfo {
        return .{
            .instance_id = instance_id,
            .socket_path = socket_path,
            .last_seen = std.time.milliTimestamp(),
            .surfaces = std.ArrayList(SurfaceState).init(allocator),
        };
    }
    
    pub fn deinit(self: *InstanceInfo, allocator: Allocator) void {
        allocator.free(self.socket_path);
        self.surfaces.deinit();
    }
};

/// IPC message types
pub const IPCMessage = union(enum) {
    /// Announce this instance's existence
    announce: struct {
        instance_id: u64,
        socket_path: []const u8,
    },
    
    /// Request state from all instances
    state_request: struct {
        requester_id: u64,
    },
    
    /// Response with surface states
    state_response: struct {
        instance_id: u64,
        surfaces: []const SurfaceState,
    },
    
    /// Request focus on a specific surface
    focus_request: struct {
        surface_id: u64,
        requester_id: u64,
    },
    
    /// Heartbeat to keep instance alive
    heartbeat: struct {
        instance_id: u64,
        timestamp: i64,
    },
};

pub fn init(allocator: Allocator) !IPCOrchestrator {
    // Generate unique instance ID
    var prng = std.rand.DefaultPrng.init(@bitCast(std.time.milliTimestamp()));
    const instance_id = prng.random().int(u64);
    
    // Create socket path in temp directory
    const socket_path = try std.fmt.allocPrint(
        allocator,
        "/tmp/ghostty-orchestration-{d}.sock",
        .{instance_id},
    );
    
    return .{
        .allocator = allocator,
        .instance_id = instance_id,
        .socket_path = socket_path,
        .known_instances = std.ArrayList(InstanceInfo).init(allocator),
        .mutex = .{},
    };
}

pub fn deinit(self: *IPCOrchestrator) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    for (self.known_instances.items) |*instance| {
        instance.deinit(self.allocator);
    }
    self.known_instances.deinit();
    self.allocator.free(self.socket_path);
    
    // Clean up socket file
    std.fs.deleteFileAbsolute(self.socket_path) catch {};
}

/// Start IPC server to listen for messages
pub fn startServer(self: *IPCOrchestrator) !std.Thread {
    return try std.Thread.spawn(.{}, serverLoop, .{self});
}

fn serverLoop(self: *IPCOrchestrator) void {
    // TODO: Implement Unix socket server
    // Listen on self.socket_path
    // Handle incoming IPC messages
    // For now, this is a placeholder
    _ = self;
}

/// Discover other Ghostty instances
pub fn discoverInstances(self: *IPCOrchestrator) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    // Scan /tmp for ghostty-orchestration-*.sock files
    var tmp_dir = try std.fs.openDirAbsolute("/tmp", .{ .iterate = true });
    defer tmp_dir.close();
    
    var iter = tmp_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        
        // Check if it's a Ghostty orchestration socket
        if (std.mem.startsWith(u8, entry.name, "ghostty-orchestration-") and
            std.mem.endsWith(u8, entry.name, ".sock")) {
            // Extract instance ID from filename
            const id_str = entry.name[22 .. entry.name.len - 5]; // Skip prefix and .sock
            const instance_id = std.fmt.parseInt(u64, id_str, 10) catch continue;
            
            // Skip our own socket
            if (instance_id == self.instance_id) continue;
            
            // Check if already known
            var found = false;
            for (self.known_instances.items) |instance| {
                if (instance.instance_id == instance_id) {
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                const socket_path = try std.fmt.allocPrint(
                    self.allocator,
                    "/tmp/{s}",
                    .{entry.name},
                );
                const instance = InstanceInfo.init(self.allocator, instance_id, socket_path);
                try self.known_instances.append(instance);
            }
        }
    }
}

/// Broadcast state update to all instances
pub fn broadcastState(self: *IPCOrchestrator, surfaces: []const SurfaceState) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    const message = IPCMessage{
        .state_response = .{
            .instance_id = self.instance_id,
            .surfaces = surfaces,
        },
    };
    
    // Send to all known instances
    for (self.known_instances.items) |instance| {
        self.sendMessage(instance.socket_path, message) catch |err| {
            std.log.warn("Failed to send state to instance {d}: {}", .{ instance.instance_id, err });
        };
    }
}

/// Request focus on a surface (possibly in another instance)
pub fn requestFocus(self: *IPCOrchestrator, surface_id: u64) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    const message = IPCMessage{
        .focus_request = .{
            .surface_id = surface_id,
            .requester_id = self.instance_id,
        },
    };
    
    // Broadcast focus request to all instances
    for (self.known_instances.items) |instance| {
        self.sendMessage(instance.socket_path, message) catch |err| {
            std.log.warn("Failed to send focus request to instance {d}: {}", .{ instance.instance_id, err });
        };
    }
}

/// Get all surfaces from all instances
pub fn getAllSurfaces(self: *IPCOrchestrator) ![]SurfaceState {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    var all_surfaces = std.ArrayList(SurfaceState).init(self.allocator);
    errdefer all_surfaces.deinit();
    
    for (self.known_instances.items) |instance| {
        try all_surfaces.appendSlice(instance.surfaces.items);
    }
    
    return all_surfaces.toOwnedSlice();
}

/// Send IPC message to a socket
fn sendMessage(self: *IPCOrchestrator, socket_path: []const u8, message: IPCMessage) !void {
    _ = self;
    _ = socket_path;
    _ = message;
    // TODO: Implement actual socket communication
    // For now, this is a placeholder
    // Use std.net.Stream to connect and send serialized message
}

/// Clean up stale instances
pub fn cleanupStaleInstances(self: *IPCOrchestrator, timeout_ms: i64) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    const now = std.time.milliTimestamp();
    var i: usize = 0;
    
    while (i < self.known_instances.items.len) {
        const instance = &self.known_instances.items[i];
        if (now - instance.last_seen > timeout_ms) {
            // Remove stale instance
            var removed = self.known_instances.orderedRemove(i);
            removed.deinit(self.allocator);
        } else {
            i += 1;
        }
    }
}

test "IPCOrchestrator init and cleanup" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var orchestrator = try IPCOrchestrator.init(allocator);
    defer orchestrator.deinit();
    
    try testing.expect(orchestrator.instance_id != 0);
    try testing.expect(orchestrator.socket_path.len > 0);
}
