# Validation — 0.1.0

Tested on September 7, 2026 with Omarchy 4.0.2, Hyprland 0.56.2, Quickshell 0.3.1, Qt 6.11.2, and Python 3.14.7.

## Automated checks

- 41 Python cases: bounded Valve KeyValues parsing; multiple/legacy/offline libraries; bad manifests; runtime filtering; local artwork fallback; corrupt/private/atomic state; concurrent writes; notes; reversible hiding; exact launch arguments; a real process handoff to an isolated fake Steam executable; shuffle bag behavior and injection rejection.
- Five JavaScript cases: search ranking, fuzzy abbreviations, filters, honest timestamps, and fictional fixture isolation.
- 21 QtQuick cases (23 results including setup/cleanup): keyboard actions, input focus, note save, draft preservation across uninstall/reinstall, separate demo/live drafts, Unicode character limits, literal markup, hidden/empty/error states, compact layout, help, and stopped animation when closed. Runtime QML warnings fail these tests. `qmllint` reports no warnings for the portable view and components.
- The real Quickshell/Python bridge passed two sequential scans and concurrent-request rejection, with no worker left running.
- Isolated bridge fault tests passed malformed JSON, exit-code failure, and the ten-second stall deadline. Each recovered on the next request without overlapping helpers.

## Live Omarchy checks

Native checks passed on three displays, including a rotated portrait display at 1.5 scale. Each display passed summon, local library loading, switching to fictional demo data, native keyboard note editing and saving, two-stage Escape, and three rapid close/reopen cycles. All display instances shared the same request counter and library backend. After closing, no helper remained and the request count stayed unchanged.

The local Steam index recognized all four installed games and filtered five runtime/support packages. Native screenshots were cropped to the fictional demo panel and inspected locally. Public assets use only the portable synthetic demo; no real library data or game artwork is included.

Disabling and re-enabling the plugin passed. During development, Omarchy retained an earlier QML component after a git update; restarting the shell loaded the updated component. This did not affect running applications. Fresh-install/removal checks are recorded with the release acceptance results.

No real game was launched as an unattended test. The real process-launch integration check used a temporary `steam` executable and verified that it received exactly the expected numeric game URI.

## Performance

These are local measurements, not universal timing guarantees. The synthetic fixtures contain installed-game manifests and empty installation directories; they do not include artwork or populated journals. Filesystem caches were warm.

| Workload | Runs | Median scan | Median helper including Python startup and JSON |
| --- | ---: | ---: | ---: |
| 1,000 synthetic installed games | 20 | 28.66 ms | 53.50 ms |
| 4,000 synthetic installed games | 5 | 122.91 ms | 149.30 ms |

The 1,000-game helper's measured p95 was 59.20 ms. The 4,000-game helper's maximum was 155.94 ms. Reproduce with `python3 scripts/benchmark.py`.

A separate 30-scan sample of the small installed library measured 2.12 ms median within the same Python process. Native summon-to-ready measured 136.46 ms median across three displays, including shell IPC and asynchronous helper startup; this is a small smoke-test sample, not a frame-time benchmark.

Search is in-memory, the list virtualizes rows, and cached artwork decodes asynchronously at a bounded requested size. Closed panels perform no polling or animation. The production plugin starts no service or persistent observer.
