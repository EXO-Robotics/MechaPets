# Contributing to MechaPets

Small, focused pull requests are welcome. For larger behavior changes, open an issue describing the interaction first.

## Local workflow

1. Install the Xcode Command Line Tools on macOS 13 or newer.
2. Make your change in a branch.
3. Run `./build.sh` to compile and run the motion self-tests.
4. Launch `MechaPets.app` and check the visible behavior affected by your change.

Keep cursor avoidance responsive, preserve click passthrough and application focus, and respect reduced-motion settings. For motion changes, check slow and fast approaches, screen edges, repeated approaches, pause/resume, and any monitor arrangements available to you. State what you tested and what remains unverified in the pull request.

Add focused self-tests when changing motion rules. Avoid tests that merely repeat the implementation. Do not commit build products, signing credentials, personal paths, captured private task data, or artwork extracted from other applications. Contributions must be original or have a compatible license with attribution.

Bug reports should include macOS version, chip architecture, display arrangement, steps to reproduce, and expected versus observed behavior. Remove private desktop content from screenshots and recordings.

Contributions are submitted under this repository’s MIT license.
