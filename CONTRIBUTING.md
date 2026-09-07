# Contributing

Keep Sidequest small, responsive, private, and native to Omarchy. See `AGENTS.md` and `docs/architecture.md` before changing launch, state, or lifecycle behavior.

Run `bash scripts/check.sh` for Python, model, manifest, and portable UI checks. Run `bash scripts/check-store.sh` for the real Quickshell/Python bridge. Render full and compact previews with `scripts/render.sh`. Use only fictional fixture games in screenshots, recordings, tests, and issue examples. Never commit a real journal, Steam metadata, or machine-specific logs.

For native integration changes, test opening/closing, three quick reopen cycles, multi-monitor state sharing, lock handling, disable/re-enable, and removal in a user-owned installation. Launcher changes must retain exact argument-array tests. Do not launch someone's real games as an unattended test; use an isolated stub Steam executable for integration tests.
