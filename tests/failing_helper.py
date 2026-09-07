"""Copied only into an isolated test config. Production never imports this."""
import json
import os
from pathlib import Path
import time

marker = Path(os.environ["XDG_STATE_HOME"]) / "fault-was-injected"
if marker.exists():
    print(json.dumps({"ok": True, "library": {"games": [], "warnings": [], "libraries": 0, "toolsHidden": 0, "notReady": 0, "scanMs": 0}, "message": "Recovered"}))
else:
    marker.write_text("test fixture")
    mode = os.environ.get("SIDEQUEST_FIXTURE_FAILURE", "malformed")
    if mode == "stall":
        time.sleep(30)
    elif mode == "crash":
        os._exit(7)
    else:
        print("not valid json")
