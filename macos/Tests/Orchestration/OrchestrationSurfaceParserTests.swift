import Testing
@testable import Ghostty

struct OrchestrationSurfaceParserTests {
    @Test func parseUsesDeterministicFallbacksWhenMetadataMissing() {
        let parsed = OrchestrationSurfaceParser.parse(
            title: "",
            cwd: nil,
            processExited: false
        )

        #expect(parsed.title == "Terminal")
        #expect(parsed.cwd == "~")
        #expect(parsed.activeProcessText == "Running")
        #expect(parsed.activityState == .busy)
    }

    @Test func parseUsesCwdNameForPlaceholderTitle() {
        let parsed = OrchestrationSurfaceParser.parse(
            title: "👻",
            cwd: "/Users/alice/workspace/relay",
            processExited: false
        )

        #expect(parsed.title == "relay")
        #expect(parsed.cwd == "/Users/alice/workspace/relay")
    }

    @Test func parseNormalizesFileUrlCwdAndTrimsTrailingSlash() {
        let parsed = OrchestrationSurfaceParser.parse(
            title: "Build",
            cwd: "file://localhost/Users/alice/repo/",
            processExited: false
        )

        #expect(parsed.cwd == "/Users/alice/repo")
    }

    @Test func parseMarksShellAsWaitingInput() {
        let parsed = OrchestrationSurfaceParser.parse(
            title: "zsh",
            cwd: "/Users/alice/repo",
            processExited: false
        )

        #expect(parsed.activityState == .waiting_input)
        #expect(parsed.activeProcessText == "zsh")
    }

    @Test func parseExtractsProcessNameFromComposedTitle() {
        let parsed = OrchestrationSurfaceParser.parse(
            title: "frontend — npm",
            cwd: "/Users/alice/repo",
            processExited: false
        )

        #expect(parsed.title == "frontend — npm")
        #expect(parsed.activeProcessText == "npm")
        #expect(parsed.activityState == .busy)
    }

    @Test func parseHandlesExitedProcessDeterministically() {
        let parsed = OrchestrationSurfaceParser.parse(
            title: "build - clang",
            cwd: "/Users/alice/repo",
            processExited: true
        )

        #expect(parsed.activityState == .idle)
        #expect(parsed.activeProcessText == "Exited")
    }

    @Test func parseRejectsNoisyProcessCandidates() {
        let parsed = OrchestrationSurfaceParser.parse(
            title: "project - /Users/alice/repo",
            cwd: "/Users/alice/repo",
            processExited: false
        )

        #expect(parsed.activeProcessText == "Running")
        #expect(parsed.activityState == .busy)
    }

    @Test func shortCwdFormatsConsistently() {
        #expect(OrchestrationSurfaceParser.shortCwd("/opt/one/two") == ".../one/two")
        #expect(OrchestrationSurfaceParser.shortCwd("/opt/two") == "/opt/two")
        #expect(OrchestrationSurfaceParser.shortCwd("/") == "/")
        #expect(OrchestrationSurfaceParser.shortCwd("") == "~")
    }
}
