#!/usr/bin/env python3
"""Opt-in native Omarchy test. Moves focus, opens the panel, edits DEMO notes only."""
import argparse
import json
from pathlib import Path
import re
import statistics
import subprocess
import time

PLUGIN = "io.github.lostandadrift.sidequest"


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=12).strip()


def state():
    return json.loads(run("omarchy-shell", "sidequest", "state"))


def wait_for(predicate, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = state()
        if predicate(value):
            return value
        time.sleep(.025)
    raise AssertionError("Timed out waiting for native state")


def focus(name):
    if not re.fullmatch(r"[A-Za-z0-9_.:-]+", name):
        raise ValueError("Unsupported monitor name in test")
    run("hyprctl", "dispatch", f'hl.dsp.focus({{ monitor = "{name}" }})')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", type=Path, help="Optional folder for cropped, demo-only screenshots")
    parser.add_argument("--keyboard", action="store_true", help="Type only in the fictional demo note editor")
    args = parser.parse_args()
    monitors = json.loads(run("hyprctl", "-j", "monitors"))
    original = next((m["name"] for m in monitors if m.get("focused")), monitors[0]["name"])
    reports = []; opens = []
    try:
        run("omarchy-shell", "shell", "hide", PLUGIN)
        for monitor in monitors:
            focus(monitor["name"])
            start = time.perf_counter()
            run("omarchy-shell", "shell", "summon", PLUGIN, "{}")
            current = wait_for(lambda s: s["opened"] and s["ready"] and not s["busy"])
            opens.append((time.perf_counter() - start) * 1000)
            assert current["screen"] == monitor["name"]
            assert not current["error"] and not current["running"]
            if not current["demo"]:
                run("omarchy-shell", "sidequest", "demo")
            current = wait_for(lambda s: s["demo"] and s["games"] == 8)
            all_states = json.loads(run("omarchy-shell", "sidequest", "allStates"))
            assert len({s["requests"] for s in all_states}) == 1, "Backend must be shared"
            assert sum(s["opened"] for s in all_states) == 1, "One active panel expected"
            if args.captures:
                args.captures.mkdir(parents=True, exist_ok=True)
                time.sleep(.3)
                current = state(); assert current["demo"] and current["opened"]
                panel = current["panel"]
                geometry = f'{monitor["x"]+panel["x"]},{monitor["y"]+panel["y"]} {panel["width"]}x{panel["height"]}'
                run("grim", "-g", geometry, str(args.captures / f'{monitor["name"]}.png'))
            if args.keyboard:
                # The panel has keyboard ownership and its independent demo is
                # verified immediately before typing. No real journal is edited.
                assert state()["opened"] and state()["demo"]
                run("wtype", "-k", "n")
                run("wtype", "-M", "ctrl", "-k", "a", "-m", "ctrl", "Synthetic native quest note")
                wait_for(lambda s: s["dirty"])
                run("wtype", "-M", "ctrl", "-k", "s", "-m", "ctrl")
                wait_for(lambda s: not s["dirty"])
                run("wtype", "-k", "Escape")
                assert state()["opened"], "First Escape leaves the note editor"
                run("wtype", "-k", "Escape")
                wait_for(lambda s: not s["opened"])
                run("omarchy-shell", "shell", "summon", PLUGIN, "{}")
            for _ in range(3):
                run("omarchy-shell", "shell", "hide", PLUGIN)
                run("omarchy-shell", "shell", "summon", PLUGIN, "{}")
                assert state()["opened"]
            run("omarchy-shell", "sidequest", "demo")
            wait_for(lambda s: not s["demo"] and not s["busy"])
            run("omarchy-shell", "shell", "hide", PLUGIN)
            reports.append({"monitor": monitor["name"], "demo": "passed", "keyboard": "passed" if args.keyboard else "not-run", "rapid_reopen": "passed"})
        closed = state(); count = closed["requests"]
        time.sleep(2)
        closed = state()
        assert not closed["opened"] and not closed["running"] and count == closed["requests"]
        print(json.dumps({"checks": reports, "closed_idle": "passed", "shared_backend": "passed", "open_ready_median_ms": round(statistics.median(opens), 2)}, indent=2))
    finally:
        run("omarchy-shell", "shell", "hide", PLUGIN)
        focus(original)


if __name__ == "__main__":
    main()
