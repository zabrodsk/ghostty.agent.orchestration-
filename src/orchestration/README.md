# Orchestration Module

This module provides terminal state tracking and AI assistant detection for the Ghostty terminal orchestration feature.

## Module Structure

```
src/orchestration/
├── state.zig              # State types and configuration
├── StateTracker.zig       # Terminal state tracking
├── AIDetector.zig         # AI assistant detection
├── IPCOrchestrator.zig    # Cross-process coordination
└── README.md             # This file
```

## Quick Start

```zig
const orchestration = @import("orchestration.zig");

// Create orchestrator
const config = orchestration.OrchestrationConfig{
    .idle_timeout_ms = 30000,
    .update_interval_ms = 500,
};

var orch = try orchestration.Orchestrator.init(allocator, config);
defer orch.deinit();

// Register a surface
try orch.state_tracker.registerSurface(surface_id);

// Process PTY output
try orch.processPtyOutput(surface_id, pty_output);

// Get state
if (orch.state_tracker.getState(surface_id)) |state| {
    std.log.info("Surface {d}: AI State = {}, Process = {s}", .{
        surface_id,
        state.ai_state,
        state.active_process,
    });
}
```

## Running Tests

```bash
zig build test -Dtest-filter=StateTracker
zig build test -Dtest-filter=AIDetector
zig build test -Dtest-filter=orchestration
```

## See Also

- `/ORCHESTRATION.md` - Full feature documentation
- `/plan.md` - Implementation plan and architecture
