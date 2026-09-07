#!/usr/bin/env python3
"""Sidequest's short-lived, offline Steam index and private quest journal."""
from __future__ import annotations

import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import secrets
import stat
import subprocess
import sys
import tempfile
import time
import unicodedata

VERSION = 1
MAX_GAMES = 4000
MAX_LIBRARIES = 32
MAX_VDF = 4 * 1024 * 1024
MAX_STATE = 4 * 1024 * 1024
MAX_NOTES = 600
APP_ID = re.compile(r"[1-9][0-9]{0,9}\Z")
TOOLS = re.compile(r"^(?:Proton(?:\s|$)|Steam Linux Runtime|Steamworks Common Redistributables|Steam Runtime|Steam Controller Configs)", re.I)
MOODS = ("any", "quick", "deep", "party")


class QuestError(Exception):
    pass


def clean_text(value, limit):
    if not isinstance(value, str):
        return ""
    return "".join(c for c in value if c in "\n\t" or not unicodedata.category(c).startswith("C"))[:limit]


def number(value, default=0):
    try:
        return max(0, min(10**16, int(value)))
    except (TypeError, ValueError, OverflowError):
        return default


def read_bounded(path, maximum):
    with open(path, "rb") as stream:
        data = stream.read(maximum + 1)
    if len(data) > maximum:
        raise QuestError("A local data file is too large to read safely.")
    return data.decode("utf-8", errors="replace")


def parse_vdf(text):
    """Parse Valve's text KeyValues format, including comments and escapes.

    This intentionally does not read Steam's binary account/config formats.
    Depth and token bounds keep malformed manifests cheap to reject.
    """
    if len(text) > MAX_VDF:
        raise QuestError("Steam manifest is too large.")
    tokens = []
    i = 0
    while i < len(text):
        c = text[i]
        if c.isspace() or c == "\ufeff":
            i += 1
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end + 1
        elif c in "{}":
            tokens.append((c, c)); i += 1
        elif c == '"':
            i += 1; value = []
            while i < len(text) and text[i] != '"':
                if text[i] == "\\" and i + 1 < len(text):
                    following = text[i + 1]
                    if following in ('"', "\\"):
                        value.append(following); i += 2; continue
                value.append(text[i]); i += 1
            if i >= len(text):
                raise QuestError("Steam manifest contains an unfinished string.")
            tokens.append(("text", "".join(value))); i += 1
        else:
            end = i
            while end < len(text) and not text[end].isspace() and text[end] not in '{}"':
                end += 1
            if end == i:
                raise QuestError("Invalid Steam manifest.")
            tokens.append(("text", text[i:end])); i = end
        if len(tokens) > 200000:
            raise QuestError("Steam manifest contains too many fields.")
    position = 0

    def block(depth=0, nested=False):
        nonlocal position
        if depth > 24:
            raise QuestError("Steam manifest is nested too deeply.")
        result = {}
        while position < len(tokens):
            kind, key = tokens[position]; position += 1
            if kind == "}" and nested:
                return result
            if kind != "text" or position >= len(tokens):
                raise QuestError("Steam manifest has an invalid field.")
            kind, value = tokens[position]; position += 1
            if kind == "{":
                result[key.casefold()] = block(depth + 1, True)
            elif kind == "text":
                result[key.casefold()] = value
            else:
                raise QuestError("Steam manifest has an invalid value.")
        if nested:
            raise QuestError("Steam manifest is missing a closing brace.")
        return result

    return block()


def steam_roots(home=None):
    home = Path(home or Path.home())
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(home / ".local/share")))
    if not data_home.is_absolute():
        data_home = home / ".local/share"
    candidates = [data_home / "Steam", home / ".local/share/Steam", home / ".steam/steam",
                  home / ".steam/root", home / ".var/app/com.valvesoftware.Steam/data/Steam",
                  home / ".var/app/com.valvesoftware.Steam/.local/share/Steam"]
    roots = []
    for candidate in candidates:
        try:
            root = candidate.resolve()
            if (root / "steamapps").is_dir() and root not in roots:
                roots.append(root)
        except OSError:
            pass
    return roots


def cover_for(root, appid):
    """Use only recognized local library art; never download art or guess hashes."""
    cache = root / "appcache/librarycache"
    if not cache.is_dir():
        return ""
    candidates = [cache / f"{appid}_library_600x900.jpg", cache / f"{appid}_library_600x900.png",
                  cache / appid / "library_600x900.jpg", cache / appid / "library_600x900_2x.jpg"]
    # Current Steam nests known artwork names under a content-hash directory.
    game_cache = cache / appid
    try:
        directories = sorted(game_cache.iterdir())[:32] if game_cache.is_dir() else []
        for directory in directories:
            if directory.is_dir() and re.fullmatch(r"[a-fA-F0-9]{40,64}", directory.name):
                candidates.extend([directory / "library_600x900.jpg", directory / "library_600x900_2x.jpg", directory / "library_capsule.jpg"])
    except OSError:
        pass  # Artwork must never make an otherwise installed game disappear.
    for candidate in candidates:
        try:
            resolved = candidate.resolve()
            if resolved.is_relative_to(cache.resolve()) and resolved.is_file() and resolved.stat().st_size <= 12 * 1024 * 1024:
                return resolved.as_uri()
        except OSError:
            continue
    return ""


def scan_library(roots=None):
    started = time.monotonic()
    roots = steam_roots() if roots is None else [Path(p) for p in roots]
    libraries = {}; warnings = []
    for root in roots[:MAX_LIBRARIES]:
        libraries.setdefault(root.resolve(), root)
        try:
            data = parse_vdf(read_bounded(root / "steamapps/libraryfolders.vdf", MAX_VDF))
            folders = data.get("libraryfolders", {})
            if not isinstance(folders, dict):
                raise QuestError("Invalid Steam library list.")
            for key, entry in folders.items():
                if not key.isdigit():
                    continue
                value = entry.get("path") if isinstance(entry, dict) else entry
                if isinstance(value, str) and value and Path(value).is_absolute():
                    if len(libraries) >= MAX_LIBRARIES:
                        break
                    libraries.setdefault(Path(value).resolve(), root)
        except FileNotFoundError:
            pass
        except (OSError, QuestError):
            warnings.append("One Steam library list could not be read.")
    games = {}; tools_hidden = 0; not_ready = 0; unreadable = 0
    for library, root in libraries.items():
        folder = library / "steamapps"
        if not folder.is_dir():
            warnings.append("A Steam library is offline or unmounted."); continue
        try:
            manifests = sorted(folder.glob("appmanifest_*.acf"))[:MAX_GAMES]
        except OSError:
            warnings.append("A Steam library could not be listed."); continue
        for manifest in manifests:
            if len(games) >= MAX_GAMES:
                warnings.append("Only the first 4,000 installed games are indexed."); break
            try:
                data = parse_vdf(read_bounded(manifest, MAX_VDF)).get("appstate", {})
                if not isinstance(data, dict):
                    raise QuestError("Invalid app manifest.")
                appid = data.get("appid", "")
                if not isinstance(appid, str) or not APP_ID.fullmatch(appid) or manifest.name != f"appmanifest_{appid}.acf":
                    raise QuestError("Invalid app ID.")
                name = clean_text(data.get("name"), 160).replace("\n", " ").strip()
                if not name:
                    raise QuestError("Missing game name.")
                if TOOLS.match(name):
                    tools_hidden += 1; continue
                # FullyInstalled is bit 4. Incomplete installs are never launch candidates.
                if not number(data.get("stateflags")) & 4:
                    not_ready += 1; continue
                install_name = data.get("installdir", "")
                if not isinstance(install_name, str) or not install_name or Path(install_name).name != install_name or install_name in (".", ".."):
                    raise QuestError("Invalid installation directory.")
                if not (folder / "common" / install_name).is_dir():
                    not_ready += 1; continue
                if appid not in games:
                    games[appid] = {"id": appid, "name": name, "bytes": number(data.get("sizeondisk")),
                                    "lastPlayed": number(data.get("lastplayed")), "cover": cover_for(root, appid),
                                    "launcher": "flatpak" if "com.valvesoftware.Steam" in root.parts else "steam"}
            except (OSError, QuestError, ValueError):
                unreadable += 1
    if unreadable:
        warnings.append(f"{unreadable} manifest(s) could not be read; the rest of your library is available.")
    return {"games": sorted(games.values(), key=lambda g: (g["name"].casefold(), g["id"])),
            "libraries": len(libraries), "toolsHidden": tools_hidden, "notReady": not_ready,
            "warnings": list(dict.fromkeys(warnings)), "scanMs": round((time.monotonic() - started) * 1000, 1)}


def default_state():
    return {"version": VERSION, "entries": {}, "bag": [], "lastRoll": ""}


def validate_state(data):
    if not isinstance(data, dict) or data.get("version") != VERSION or not isinstance(data.get("entries"), dict):
        raise QuestError("The quest journal is unreadable. It has been left untouched.")
    if len(data["entries"]) > MAX_GAMES:
        raise QuestError("The quest journal exceeds its entry limit.")
    result = default_state()
    for appid, entry in data["entries"].items():
        if not APP_ID.fullmatch(appid) or not isinstance(entry, dict):
            raise QuestError("The quest journal contains an invalid entry.")
        result["entries"][appid] = {"note": clean_text(entry.get("note", ""), MAX_NOTES),
                                    "favorite": entry.get("favorite") is True,
                                    "mood": entry.get("mood") if entry.get("mood") in MOODS else "any",
                                    "hidden": entry.get("hidden") is True,
                                    "updated": number(entry.get("updated")), "launched": number(entry.get("launched"))}
    result["bag"] = [x for x in data.get("bag", []) if isinstance(x, str) and APP_ID.fullmatch(x)][:MAX_GAMES] if isinstance(data.get("bag"), list) else []
    result["lastRoll"] = data.get("lastRoll", "") if isinstance(data.get("lastRoll"), str) and APP_ID.fullmatch(data.get("lastRoll", "")) else ""
    return result


class Journal:
    def __init__(self, directory=None):
        home = Path.home()
        state_home = Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state")))
        if not state_home.is_absolute():
            state_home = home / ".local/state"
        self.directory = Path(directory) if directory is not None else state_home / "omarchy-sidequest"
        self.path = self.directory / "journal.json"

    @contextlib.contextmanager
    def locked(self):
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = self.directory.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
            raise QuestError("The quest journal directory must be a directory owned by you.")
        os.chmod(self.directory, 0o700)
        fd = os.open(self.directory / ".lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                raise QuestError("Invalid journal lock.")
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise QuestError("The journal is busy. Try again in a moment.") from exc
            yield
        finally:
            os.close(fd)

    def read(self):
        try:
            fd = os.open(self.path, os.O_RDONLY | os.O_NOFOLLOW)
            with os.fdopen(fd, "r", encoding="utf-8") as stream:
                if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                    raise QuestError("Invalid journal file.")
                raw = stream.read(MAX_STATE + 1)
                if len(raw) > MAX_STATE:
                    raise QuestError("The quest journal is too large.")
                return validate_state(json.loads(raw))
        except FileNotFoundError:
            return default_state()
        except (json.JSONDecodeError, UnicodeError) as exc:
            raise QuestError("The quest journal is unreadable. It has been left untouched.") from exc

    def write(self, data):
        raw = json.dumps(validate_state(data), ensure_ascii=False, separators=(",", ":"))
        if len(raw.encode("utf-8")) > MAX_STATE:
            raise QuestError("The quest journal is full. Shorten a note before saving.")
        fd, temp = tempfile.mkstemp(prefix=".journal-", dir=self.directory)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                stream.write(raw + "\n"); stream.flush(); os.fsync(stream.fileno())
            os.replace(temp, self.path)
            dirfd = os.open(self.directory, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(dirfd)
            finally:
                os.close(dirfd)
        finally:
            Path(temp).unlink(missing_ok=True)


def enrich(library, state):
    result = dict(library)
    result["games"] = [dict(game, **state["entries"].get(game["id"], {"note": "", "favorite": False, "mood": "any", "hidden": False, "updated": 0, "launched": 0})) for game in library["games"]]
    return result


def roll(games, state, ids, chooser=secrets.choice):
    if not isinstance(ids, list) or len(ids) > MAX_GAMES or any(not isinstance(x, str) for x in ids):
        raise QuestError("Invalid quest pool.")
    allowed = {g["id"] for g in games if not state["entries"].get(g["id"], {}).get("hidden", False)}
    pool = sorted(set(ids) & allowed)
    if not pool:
        raise QuestError("No games in this quest pool. Change the filter or unhide a game.")
    remaining = [x for x in pool if x not in state["bag"]]
    if not remaining:
        state["bag"] = [x for x in state["bag"] if x not in pool]
        remaining = pool
    # Across the boundary of two complete bags, never immediately repeat a game.
    if len(remaining) > 1 and state["lastRoll"] in remaining:
        remaining = [x for x in remaining if x != state["lastRoll"]]
    picked = chooser(remaining)
    state["bag"] = [x for x in state["bag"] if x in allowed and x != picked] + [picked]
    state["lastRoll"] = picked
    return picked


def launch_game(game):
    appid = game["id"]
    if not APP_ID.fullmatch(appid):
        raise QuestError("Invalid game ID.")
    command = (["flatpak", "run", "com.valvesoftware.Steam"] if game.get("launcher") == "flatpak" else ["steam"])
    command += [f"steam://rungameid/{appid}"]
    try:
        # Steam owns the game process after this request. It must outlive the
        # short-lived indexer and closing the panel must not stop a game.
        subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
    except OSError as exc:
        raise QuestError("Steam could not be opened. Check that it is installed.") from exc


def handle(request, journal=None, scanner=scan_library, launcher=launch_game):
    if not isinstance(request, dict):
        raise QuestError("Invalid request.")
    action = request.get("action", "scan")
    if action not in ("scan", "save", "favorite", "hide", "roll", "launch"):
        raise QuestError("Unknown Sidequest action.")
    journal = journal or Journal()
    library = scanner()
    with journal.locked():
        state = journal.read()
        picked = ""; message = ""
        by_id = {game["id"]: game for game in library["games"]}
        if action in ("save", "favorite", "hide", "launch"):
            appid = request.get("id")
            if not isinstance(appid, str) or appid not in by_id:
                raise QuestError("This game is no longer installed. Refresh your library.")
            entry = state["entries"].setdefault(appid, {"note": "", "favorite": False, "mood": "any", "hidden": False, "updated": 0, "launched": 0})
            if action == "save":
                note = request.get("note", "")
                if not isinstance(note, str) or len(note) > MAX_NOTES or request.get("mood", "any") not in MOODS:
                    raise QuestError("Notes can be up to 600 characters; choose a valid session tag.")
                entry.update(note=clean_text(note, MAX_NOTES), mood=request.get("mood", "any"), updated=int(time.time()))
                message = "Quest saved. Future you says thanks."
            elif action == "favorite":
                entry["favorite"] = not entry["favorite"]
            elif action == "hide":
                entry["hidden"] = not entry["hidden"]
            else:
                entry["launched"] = int(time.time())
                message = "Launch requested from Steam. Have a good quest."
            journal.write(state)
            if action == "launch":
                launcher(by_id[appid])
        elif action == "roll":
            picked = roll(library["games"], state, request.get("ids", []))
            journal.write(state)
            message = "Quest drawn. Play when you're ready."
        return {"ok": True, "library": enrich(library, state), "picked": picked, "message": message}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", help="JSON action (default: read one JSON object from stdin)")
    args = parser.parse_args()
    try:
        raw = args.request if args.request is not None else sys.stdin.read(65537)
        if len(raw) > 65536:
            raise QuestError("Request is too large.")
        result = handle(json.loads(raw or '{"action":"scan"}'))
    except (QuestError, OSError, ValueError, TypeError) as exc:
        message = str(exc) if isinstance(exc, QuestError) else "Sidequest could not read its local files. Check access and try again."
        result = {"ok": False, "message": message}
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
