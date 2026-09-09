# Contributing to MechaPets

Small, focused pull requests are welcome. For larger behavior changes, open an issue describing the interaction first.

## Local workflow

1. Install the Xcode Command Line Tools on macOS 13 or newer.
2. Make your change in a branch.
3. Run `./build.sh` to compile and run the motion, workload, and forge self-tests.
4. Launch `MechaPets.app` and check the visible behavior affected by your change.

Keep cursor avoidance responsive, preserve click passthrough and application focus, and respect reduced-motion settings. For motion changes, check slow and fast approaches, screen edges, repeated approaches, pause/resume, and any monitor arrangements available to you. State what you tested and what remains unverified in the pull request.

Add focused self-tests when changing motion rules. Avoid tests that merely repeat the implementation. Do not commit build products, signing credentials, personal paths, captured private task data, or artwork extracted from other applications. Contributions must be original or have a compatible license with attribution.

## Workload and workshop changes

Read [the workload adapter notes](docs/workload.md) before changing detection. `Sources/Workload.swift` queries local lifecycle metadata with read-only SQLite connections and checks exact candidate writer paths with `lsof`. Keep that boundary: no prompt, title, message, or tool-output queries, no Codex configuration changes, and no network requests. Treat unknown schemas, statuses, and read failures as unavailable. Do not substitute a guessed activity level.

Use synthetic databases and writer-handle fixtures in `Sources/WorkloadTests.swift`. Cover transitions between zero, one, two, and three or more top-level tasks; completion and interruption; helper exclusion; stale rows without open writers; and unavailable status. Avoid copying real databases or task identifiers into fixtures. Status represents local lifecycle activity and can include approval waits.

For artwork changes in `Sources/Forge.swift` or `Sources/Robot.swift`, check all four **Preview workshop** levels, reduced motion, and cursor escapes. Keep particle counts bounded and hide the workshop during escape movement. Previews last 12 seconds and must remain clearly labeled so they cannot be mistaken for live workload.

You can run `./MechaPets.app/Contents/MacOS/MechaPets --workload-status` for count/status-only diagnostics and `./MechaPets.app/Contents/MacOS/MechaPets --ui-smoke-test` in a logged-in graphical macOS session. Report fixture, live-adapter, and visible-animation evidence separately in your pull request.

Bug reports should include macOS version, chip architecture, display arrangement, steps to reproduce, and expected versus observed behavior. Remove private desktop content from screenshots and recordings.

Contributions are submitted under this repository’s MIT license.
