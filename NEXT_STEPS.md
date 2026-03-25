# Next Steps - Agent Orchestration Integration

## Quick Start Integration

Follow these steps to integrate the agent orchestration feature into your Ghostty fork:

### 1. Build System Integration (5 min)

Edit `build.zig`:
```zig
// Add after other modules
const orchestration_mod = b.addModule("orchestration", .{
    .root_source_file = .{ .path = "src/orchestration.zig" },
});

// Add to exe modules
exe.root_module.addImport("orchestration", orchestration_mod);
```

Test the build:
```bash
zig build
```

### 2. Core Integration (10 min)

**Edit `src/App.zig`:**
```zig
const orchestration = @import("orchestration.zig");

pub const App = struct {
    // ... existing fields ...
    orchestrator: ?orchestration.Orchestrator = null,
    
    pub fn create(alloc: Allocator) !*App {
        // ... existing init ...
        
        if (config.orchestration_enabled) {
            const orch_config = orchestration.OrchestrationConfig{
                .idle_timeout_ms = config.orchestration_idle_timeout_ms,
                .update_interval_ms = config.orchestration_update_interval_ms,
            };
            app.orchestrator = try orchestration.Orchestrator.init(alloc, orch_config);
        }
        
        return app;
    }
    
    pub fn deinit(self: *App) void {
        if (self.orchestrator) |*orch| {
            orch.deinit();
        }
        // ... existing cleanup ...
    }
};
```

**Edit `src/Surface.zig`:**
```zig
// In init or after PTY creation:
pub fn init(...) !Surface {
    // ... existing init ...
    
    if (self.app.orchestrator) |*orch| {
        try orch.state_tracker.registerSurface(self.id);
    }
    
    return self;
}

// In PTY output handler:
fn handlePtyData(self: *Surface, data: []const u8) !void {
    // ... existing handling ...
    
    if (self.app.orchestrator) |*orch| {
        try orch.processPtyOutput(self.id, data);
    }
}

// In deinit:
pub fn deinit(self: *Surface) void {
    if (self.app.orchestrator) |*orch| {
        orch.state_tracker.unregisterSurface(self.id);
    }
    // ... existing cleanup ...
}
```

### 3. Configuration (5 min)

**Edit `src/config.zig`:**
```zig
pub const Config = struct {
    // ... existing fields ...
    
    orchestration_enabled: bool = true,
    orchestration_idle_timeout_ms: i64 = 30000,
    orchestration_update_interval_ms: u32 = 500,
    orchestration_panel_width: u16 = 300,
};
```

### 4. Swift Bridge (20 min)

**Create `src/orchestration/c_api.zig`:**
```zig
const std = @import("std");
const orchestration = @import("orchestration.zig");

export fn ghostty_orchestration_get_state(
    app: *anyopaque,
    surface_id: u64,
    out_state: *OrchestrationStateC,
) bool {
    const app_ptr: *App = @ptrCast(@alignCast(app));
    
    if (app_ptr.orchestrator) |*orch| {
        if (orch.state_tracker.getState(surface_id)) |state| {
            // Convert Zig state to C-compatible struct
            out_state.* = stateToC(state);
            return true;
        }
    }
    return false;
}

const OrchestrationStateC = extern struct {
    surface_id: u64,
    cwd: [*:0]const u8,
    active_process: [*:0]const u8,
    // ... other fields ...
};
```

**Update `OrchestrationViewModel.swift`:**
```swift
func refresh() {
    guard let app = ghosttyApp else { return }
    
    var surfaces: [SurfaceDisplayState] = []
    
    // Call C bridge to get states
    for surface in app.getAllSurfaces() {
        var state = OrchestrationStateC()
        if ghostty_orchestration_get_state(app.pointer, surface.id, &state) {
            surfaces.append(SurfaceDisplayState(from: state))
        }
    }
    
    self.surfaces = surfaces
}
```

### 5. UI Integration (15 min)

**Edit `macos/Sources/Ghostty/Ghostty.App.swift`:**
```swift
class App: ObservableObject {
    @Published var isOrchestrationPanelVisible = false
    private var orchestrationViewModel: OrchestrationViewModel?
    
    init() {
        // ... existing init ...
        self.orchestrationViewModel = OrchestrationViewModel(app: self)
    }
    
    func toggleOrchestrationPanel() {
        isOrchestrationPanelVisible.toggle()
    }
}

// In the main window view:
struct GhosttyMainWindow: View {
    @ObservedObject var app: Ghostty.App
    
    var body: some View {
        HStack(spacing: 0) {
            if app.isOrchestrationPanelVisible {
                OrchestrationPanel(viewModel: app.orchestrationViewModel!)
                    .frame(width: 300)
                Divider()
            }
            
            // ... main content ...
        }
    }
}
```

**Edit `macos/Sources/Ghostty/AppDelegate.swift`:**
```swift
// Add menu item
@IBAction func toggleOrchestrationPanel(_ sender: Any) {
    Ghostty.App.shared.toggleOrchestrationPanel()
}

// Add to View menu in MainMenu.xib
```

### 6. Test with AI Tools (10 min)

**Test GitHub Copilot CLI:**
```bash
# In a Ghostty terminal
gh copilot explain "how to reverse a string"
# Watch orchestration panel show "GitHub Copilot CLI" with waiting_input state
```

**Test Aider:**
```bash
# Install aider if needed
pip install aider-chat

# Run aider
aider myfile.py
# Panel should show "Aider" with waiting_input state
```

### 7. Verify Everything Works

**Checklist:**
- [ ] Orchestration panel appears in UI
- [ ] Terminals show correct working directory
- [ ] Active process names are displayed
- [ ] AI tools are detected (Copilot, Aider)
- [ ] AI state changes (waiting → processing → done)
- [ ] Click-to-focus works
- [ ] Multiple Ghostty windows show all terminals
- [ ] No crashes or memory leaks

## Troubleshooting

**Panel doesn't appear:**
- Check `isOrchestrationPanelVisible` is toggled
- Verify SwiftUI view hierarchy includes `OrchestrationPanel`
- Check Xcode project includes all 4 Swift files

**AI detection not working:**
- Verify PTY output is being processed
- Add debug logging in `AIDetector.detect()`
- Check AI tool process name matches patterns

**State not updating:**
- Verify `processPtyOutput` is called on PTY data
- Check timer is running in `OrchestrationViewModel`
- Ensure mutex isn't deadlocked

**Compilation errors:**
- Run `zig fmt src/orchestration/*.zig`
- Check all imports are correct
- Verify Zig version compatibility

## Performance Tuning

If experiencing lag with many terminals:

1. **Increase update interval:**
   ```zig
   orchestration_update_interval_ms: u32 = 1000, // 1 second
   ```

2. **Reduce output buffer:**
   ```zig
   max_output_lines: usize = 20, // Fewer lines
   ```

3. **Disable AI detection for specific terminals:**
   ```zig
   // In AIDetector, add process blacklist
   ```

## Future Enhancements

Once basic integration works, consider:

1. **Complete IPC:** Implement Unix socket communication
2. **GTK UI:** Add Linux support
3. **Custom patterns:** UI for editing AI detection patterns
4. **Terminal groups:** Organize terminals by project
5. **Remote terminals:** SSH session tracking

## Getting Help

- Review `ORCHESTRATION.md` for architecture details
- Check `src/orchestration/README.md` for API docs
- See existing Ghostty features for integration examples
- Test individual components with unit tests

## Estimated Integration Time

- **Minimal (macOS, single instance):** 1-2 hours
- **Full (macOS, multi-instance, IPC):** 4-6 hours
- **Complete (macOS + GTK):** 8-12 hours

Good luck! 🚀
