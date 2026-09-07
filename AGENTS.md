# Sidequest

Native Omarchy Quattro gaming plugin. Runtime dependencies are Python standard library, QtQuick, Quickshell, and Steam installed by the user.

- Never modify packaged Omarchy or Steam files.
- Read only Steam libraryfolders.vdf, appmanifest files, and cached cover artwork. Never read credentials or browser/account data.
- Launch only a selected installed numeric Steam app ID after an explicit Play action. Never interpolate into shell commands.
- Keep notes and preferences local, bounded, atomic, and private. No runtime network requests.
- No background scanning or animation when closed. Use one shared backend across monitors.
- Tests use synthetic libraries; public artwork and screenshots use fictional games.
- Verify engine behavior, keyboard access, compact layouts, performance, and native install/disable/removal before release.
