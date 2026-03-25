# GitHub Actions Workflows - Fixed for Fork

This directory contains GitHub Actions workflows that have been modified to work with your fork of Ghostty.

## Changes from Original

The original Ghostty workflows are hardcoded to only run for `ghostty-org` and require:
- Custom namespace runners
- Cloudflare R2 storage with secrets
- Sparkle signing keys

## New Simplified Workflow

**File:** `build-and-release.yml`

### Features:
✅ Works with standard GitHub runners (no custom infrastructure needed)  
✅ Builds for macOS and Linux automatically  
✅ Uploads artifacts to GitHub Releases  
✅ Creates release on every push to main  
✅ No secrets required  
✅ Includes orchestration feature in release notes  

### Jobs:

1. **build-macos** - Builds macOS app with Zig
2. **build-linux** - Builds Linux binary with GTK4
3. **test** - Runs Zig test suite
4. **release** - Creates GitHub Release with artifacts

### Usage:

The workflow runs automatically on:
- Push to `main` branch
- Pull requests to `main`
- Manual trigger via Actions tab

### Artifacts:

Each commit to main creates a release tagged `tip-<commit>`:
- `ghostty-macos-universal.zip` - macOS .app bundle
- `ghostty-linux-x86_64.tar.gz` - Linux binary

### Download URL Pattern:

```
https://github.com/zabrodsk/ghostty.agent.orchestration-/releases/download/tip-<commit>/ghostty-macos-universal.zip
```

## Enabling the Workflow

1. Commit and push the new workflow:
   ```bash
   git add .github/workflows/build-and-release.yml
   git commit -m "Add fork-compatible build workflow"
   git push
   ```

2. Enable GitHub Actions in your repository:
   - Go to Settings → Actions → General
   - Set "Actions permissions" to "Allow all actions and reusable workflows"

3. The workflow will run automatically on the next push

## Testing Locally

Before pushing, you can test the build locally:

```bash
# Install Zig
brew install zig  # macOS
# or download from https://ziglang.org

# Build
zig build -Doptimize=ReleaseSafe

# Test
zig build test
```

## Differences from Original Workflows

| Feature | Original | This Fork |
|---------|----------|-----------|
| Runners | Custom namespace | Standard GitHub |
| Storage | Cloudflare R2 | GitHub Releases |
| Signing | Sparkle keys | None (unsigned) |
| Owner check | ghostty-org only | Works for any fork |
| Secrets | Required | None needed |

## Future Improvements

Optional enhancements you could add:
- Code signing for macOS builds
- Flatpak/Snap packaging for Linux
- Windows builds
- Automatic version tagging
- Release notes generation from commits

## Troubleshooting

**Build fails on macOS:**
- Xcode Command Line Tools must be installed
- May need to update Zig version in workflow

**Build fails on Linux:**
- GTK4 and Adwaita dependencies required
- Blueprint compiler version must be 0.16.0+

**No releases created:**
- Check Actions tab for workflow run status
- Ensure repository has write permissions for GitHub token
- Verify you're pushing to `main` branch
