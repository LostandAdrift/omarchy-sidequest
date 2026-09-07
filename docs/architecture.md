# Architecture

`Sidequest.qml` is the Omarchy integration: a `Ui.Panel`, bar button, keyboard panel, lock handling, and deliberately limited introspection/demo IPC. `SidequestView.qml` is portable QtQuick UI. UI actions are signals, so tests cannot accidentally launch games.

`runtime/Library.qml` is a singleton shared by all bar instances and monitors. It keeps the latest index in memory for immediate reopening. Each explicit action runs `scripts/sidequest.py` once, passes one bounded JSON object over stdin, and joins both process exit and stdout completion before releasing ownership. A second request is rejected while one is in flight. A ten-second deadline terminates only that owned helper, with a one-second kill fallback. Closing the panel does not poll, rescan, animate, or kill a game.

The helper discovers standard Steam roots and libraries, parses bounded text KeyValues documents, and emits only whitelisted game metadata and journal entries. Malformed manifests are isolated; disconnected libraries are reported. Only numeric app IDs belonging to currently installed entries can be launched. Launch requests use argument arrays and the fixed `steam://rungameid/<id>` protocol. Neither game names nor notes enter a shell command. Steam owns its game process independently of the panel.

State writes use an exclusive nonblocking lock, a private temporary file, fsync, atomic replacement, and directory fsync. Broken files are never reset automatically. Hiding, favouriting, or changing a note updates only the intended fields. A save cannot launch a game. A roll writes only the shuffle history.

The shuffle bag tracks IDs already drawn. When the current pool has no unseen IDs, only that pool is reset, so changing filters does not erase unrelated draw history. Duplicate IDs do not weight the draw. Hidden/uninstalled IDs are rejected. At a cycle boundary, the immediately previous game is excluded when more than one candidate remains. There is no cloud recommendation algorithm or inferred genre/time classification.

Rendering is static apart from a short roll flash. Local artwork is asynchronously decoded at a bounded requested width. Missing artwork gets a deterministic procedural landscape. The game list virtualizes delegates; search and filtering use the in-memory model. The isolated demo has synthetic games and cannot reach the live action helper.
