# Fork Setup Guide

This fork of Ghostty includes the **Agent Orchestration** feature and modified GitHub Actions workflows.

## Quick Start

### 1. Enable GitHub Actions

```bash
# Repository Settings → Actions → General
# Set: "Allow all actions and reusable workflows"
```

### 2. Trigger First Build

```bash
git add .
git commit -m "Initial fork setup with orchestration"
git push
```

The workflow will automatically:
- Build for macOS and Linux
- Run tests
- Create a GitHub Release

### 3. Download Built Artifacts

After the workflow completes (5-10 minutes):

```
https://github.com/zabrodsk/ghostty.agent.orchestration-/releases
```

## What's Included

### Agent Orchestration Feature
- Real-time terminal state tracking across all windows
- AI assistant detection (Copilot CLI, Aider, Claude)
- Multi-instance coordination
- Native macOS sidebar UI

See [ORCHESTRATION.md](../ORCHESTRATION.md) for details.

### Modified GitHub Actions
- Works without custom runners or secrets
- Builds automatically on push to main
- Uploads to GitHub Releases
- No Cloudflare R2 or Sparkle signing required

See [workflows/README.md](workflows/README.md) for details.

## Building Locally

### macOS

```bash
# Install Zig
brew install zig

# Build
zig build

# Run
./zig-out/bin/ghostty
```

### Linux (Ubuntu/Debian)

```bash
# Install dependencies
sudo apt-get install -y \
  libgtk-4-dev \
  libadwaita-1-dev \
  desktop-file-utils \
  blueprint-compiler

# Install Zig
wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar xf zig-linux-x86_64-0.13.0.tar.xz
export PATH="$PWD/zig-linux-x86_64-0.13.0:$PATH"

# Build
zig build

# Run
./zig-out/bin/ghostty
```

## Testing

```bash
# Run all tests
zig build test

# Test orchestration module
zig build test -Dtest-filter=orchestration

# Test Swift components (macOS only)
cd macos/Sources/Features/Orchestration
swiftc -o test TestOrchestration.swift && ./test
```

## Syncing with Upstream

To keep your fork updated with the original Ghostty repository:

```bash
# Add upstream remote (one time)
git remote add upstream https://github.com/ghostty-org/ghostty.git

# Fetch and merge updates
git fetch upstream
git merge upstream/main

# Resolve conflicts (orchestration files are new, shouldn't conflict)
git push
```

## Repository Structure

```
ghostty.agent.orchestration-/
├── src/orchestration/          # Zig orchestration core
├── macos/Sources/Features/     # Swift UI components
│   └── Orchestration/
├── .github/workflows/          # Fixed GitHub Actions
├── ORCHESTRATION.md            # Feature documentation
├── NEXT_STEPS.md              # Integration guide
└── TEST_REPORT.md             # Test results
```

## Troubleshooting

### Actions Not Running
- Check Actions tab is enabled in Settings
- Verify workflow file is in `.github/workflows/`
- Ensure you pushed to `main` branch

### Build Failures
- Check Actions logs for specific errors
- Verify Zig version compatibility
- Ensure all dependencies installed

### macOS App Not Opening
- Right-click → Open (to bypass Gatekeeper)
- Or: System Settings → Privacy & Security → Open Anyway
- Builds are unsigned in fork (original uses Sparkle signing)

## Next Steps

1. **Integrate Orchestration** - Follow [NEXT_STEPS.md](../NEXT_STEPS.md)
2. **Test with AI Tools** - Try GitHub Copilot CLI or Aider
3. **Customize Workflows** - Add code signing, Windows builds, etc.
4. **Contribute Back** - Consider upstreaming the orchestration feature

## Support

- Original Ghostty: https://github.com/ghostty-org/ghostty
- Original Docs: https://ghostty.org/docs
- This Fork: https://github.com/zabrodsk/ghostty.agent.orchestration-
