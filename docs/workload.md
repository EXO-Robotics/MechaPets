# Codex workload reaction

MechaPets 0.2 adds a workshop that responds to the number of active local Codex tasks.

![Animated workshop levels](workload.gif)

[Static preview](workload.png)

## Behavior

| Active tasks | Level | Hammer strikes per second | Sparks per strike |
| --- | --- | --- | --- |
| 0 | Idle, cool anvil | 0 | 0 |
| 1 | Calm | 1 | 5 |
| 2 | Busy | 2 | 10 |
| 3 or more | Frenzy | 3.3 | 16 |

Intensity caps at three tasks even if the displayed count is higher. Sparks follow hammer impacts and use a bounded procedural animation. During a swing or jump-dash, the workshop disappears; it returns when the pet settles. Reduced motion stops hammer and spark animation while retaining a static workshop.

## Controls

- **React to Codex workload** is on by default and persists as a MechaPets preference. Turning it off removes the workshop and stops polling.
- **Choose Codex data folder…** selects a local Codex data directory. The selection is saved in MechaPets preferences; it does not modify Codex configuration. Otherwise the app uses `CODEX_HOME` when present in its launch environment, then `~/.codex`.
- **Preview workshop** shows idle, calm, busy, or frenzy for 12 seconds. The menu says **Preview:** during this override, then returns to live status. Previews can be used with workload reaction off.
- **Gentle motion** and macOS Reduce Motion make the workshop static.
- **Pause & hide pet** hides the pet and workshop. Use the separate reaction toggle to stop workload polling.

## Local adapter

The monitor samples every two seconds on a background queue. It opens `thread_history_1.sqlite` and `state_5.sqlite` read-only and joins task metadata with each task’s latest lifecycle row, ordered by `rollout_ordinal`.

A candidate must have `inProgress` status, be unarchived, have a top-level source (`vscode`, `cli`, or `exec`), and have no subagent path. The monitor then invokes the system `lsof` command for only the candidate `thread-writer-locks/<task-id>.lock` paths. A candidate counts only when the command named `codex` has that writer file open. Matching both conditions excludes old incomplete lifecycle records whose writer process has exited, and avoids counting completed tasks whose writers remain open.

The monitor reads command names and exact file-path matches. An open writer handle is a liveness signal, not proof of an exclusive file lock. `lsof` can return exit code 1 when some candidate files are not open; valid output is still accepted. Errors and timeouts produce unavailable status.

The adapter does not query task prompts, titles, messages, or tool output. The user-facing status contains only a count and activity label. It does not connect to Codex IPC, change Codex configuration, start tasks, or send data over the network.

## Limits and failure behavior

- These database schemas and writer filenames are private Codex implementation details, not a supported public API. Future Codex updates may require an adapter update.
- Only local tasks visible in the selected data directory are represented. Remote and cloud tasks are excluded.
- Subagents and internal helper tasks are excluded. Top-level local CLI and automation tasks can contribute to the count.
- `inProgress` can include approval or input waits. The count does not prove that a model is generating or that CPU work is occurring.
- Status is sampled rather than instantaneous. Task transitions normally appear at the next successful poll.
- Unknown lifecycle statuses, missing or incompatible schema, failed reads, and timed-out writer checks show **Codex status unavailable**. The workshop disappears instead of displaying an invented workload. The UI also discards results older than eight seconds.
- The candidate count is bounded at 128. An oversized candidate set becomes unavailable rather than being partially counted.

If status is unavailable, verify the selected directory and Codex version. If Codex is absent or uses an unsupported format, the cursor-avoidance pet still works and the labeled workshop previews remain available.

## Verification

```sh
./build.sh
./MechaPets.app/Contents/MacOS/MechaPets --self-test
./MechaPets.app/Contents/MacOS/MechaPets --workload-status
./MechaPets.app/Contents/MacOS/MechaPets --ui-smoke-test
```

The build already runs `--self-test`; rerun it directly when useful during development. The suite includes 33 workload and forge assertions using synthetic lifecycle databases and injected writer handles, covering count changes, terminal states, helpers, stale records, reader failures, unknown schema, intensity caps, and reduced motion.

`--workload-status` prints JSON containing `status` and, when available, `activeCount`. An unavailable result omits the count and has a nonzero exit status. This command uses `CODEX_HOME`, falling back to `~/.codex`; it does not use the desktop app’s saved folder-picker preference.

The UI smoke test needs a logged-in graphical macOS session. It exercises native controls and visual state changes; it does not establish exhaustive screen-layout or live multi-task behavior. Use the four labeled previews to inspect animation levels, then observe a normal local task start and finish to check the live adapter. Do not publish private task data or desktop content as test evidence.

### Expressive workshop artwork

Version 0.3 adds planted feet, breathing, short blinks, head and antenna follow-through,
a poised hammer wind-up, rigid tool geometry, and an impact recoil. Sparks vary by
strike and render in front of the arm; level two emits 28 sparks per strike at 2.8 strikes/second, and level three emits
72 per strike at 5 strikes/second. Up to five generations (360 sparks) overlap
for a dense frenzy, with a wider, taller spread and stronger body recoil.
Reduced motion uses a relaxed, fully static pose with no emitted particles.

To check native artwork bounds and reduced-motion stability on a Mac with a desktop session:

```sh
./MechaPets.app/Contents/MacOS/MechaPets --art-self-test
```

This rasterizes 1,200 frames across all workload levels and compares reduced-motion
pixels over time. It also measures 270 effect frames to require a strong visual
increase between levels. The normal build checks hammer contact and cadence.
