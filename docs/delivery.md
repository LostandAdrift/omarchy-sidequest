# Delivering a local quest journal with AI assistance

Sidequest starts with an ordinary problem: returning to a game and forgetting the next useful action. The product response is a short note beside each installed game, with a shuffle bag for choosing what to play.

## My contribution

I direct the product and agent-assisted delivery workflow: define the use case, set behavior and privacy requirements, inspect the resulting experience, and require verification before describing it as working. AI agents perform substantial implementation work. The public Python and QML source and tests make that work reviewable.

## Decisions worth inspecting

- Choosing a game and launching it are separate actions. Typing in a note or search field must never become a launch shortcut.
- Notes stay local, bounded, and atomically saved. A corrupt journal is reported rather than silently replaced.
- Monitor panels share one backend, and closed panels do not poll or animate.
- Public demonstrations use fictional games and original artwork. The demo can be inspected without exposing a real Steam library.

## Current reproducible evidence

On September 9, 2026, `bash scripts/check.sh` passed on source commit `d28563623719f8f68b65c92bab1a9214a8b68983`: 41 Python tests, five JavaScript tests, and 24 QtQuick results including setup and cleanup, with zero failures. The script also ran the plugin manifest validator. This documentation update changes no runtime code.

The checks cover parser input, isolated launch arguments, local state, search behavior, keyboard interactions, compact layout, and draft preservation. They use synthetic data and offscreen UI execution. They do not constitute a new native installation or real-game launch test.

The [September 7 validation record](validation.md) separately documents earlier native checks and local benchmarks. Its measurements retain their original date and environment.

## Walkthrough

Start with the [10-second demo](assets/sidequest.webm), then inspect [architecture](architecture.md) and the test commands in the [README](../README.md). The core question is whether the implementation satisfies the user’s workflow and failure cases, including when a helper stalls or a note has not yet been saved.
