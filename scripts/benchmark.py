#!/usr/bin/env python3
"""Reproducible synthetic-library benchmark. Never reads the user's Steam data."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("sidequest", ROOT / "scripts/sidequest.py")
sq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sq)


def summary(values):
    values = sorted(values)
    return {"median_ms": round(statistics.median(values), 2), "p95_ms": round(values[min(len(values)-1, int(len(values)*.95))], 2), "max_ms": round(max(values), 2)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--games", type=int, default=1000)
    parser.add_argument("--runs", type=int, default=20)
    args = parser.parse_args()
    if not 1 <= args.games <= 4000 or not 3 <= args.runs <= 100:
        parser.error("games must be 1–4000; runs 3–100")
    with tempfile.TemporaryDirectory(prefix="sidequest-benchmark-") as temp:
        root = Path(temp) / "Steam"
        common = root / "steamapps/common"; common.mkdir(parents=True)
        for i in range(args.games):
            (common / f"Quest {i}").mkdir()
            (root / f"steamapps/appmanifest_{700000+i}.acf").write_text(f'"AppState" {{ "appid" "{700000+i}" "name" "Synthetic Quest {i}" "StateFlags" "4" "installdir" "Quest {i}" "SizeOnDisk" "1234567890" }}')
        scans = []; end_to_end = []
        # A separate interpreter measures Python startup + parse + JSON + journal.
        runner = Path(temp) / "runner.py"
        runner.write_text("import sys,json\n" + f"sys.path.insert(0,{str(ROOT / 'scripts')!r})\nimport sidequest as s\n" + f"print(json.dumps(s.handle({{'action':'scan'}}, s.Journal({str(Path(temp)/'state')!r}), lambda:s.scan_library([{str(root)!r}]))))\n")
        for _ in range(args.runs):
            start = time.perf_counter(); result = sq.scan_library([root]); scans.append((time.perf_counter()-start)*1000)
            assert len(result["games"]) == args.games
            start = time.perf_counter()
            result = subprocess.run([sys.executable, str(runner)], capture_output=True, check=True, timeout=20)
            assert len(json.loads(result.stdout)["library"]["games"]) == args.games
            end_to_end.append((time.perf_counter()-start)*1000)
        print(json.dumps({"fixture_games": args.games, "runs": args.runs, "python": sys.version.split()[0], "scan": summary(scans), "helper_process": summary(end_to_end)}, indent=2))


if __name__ == "__main__":
    main()
