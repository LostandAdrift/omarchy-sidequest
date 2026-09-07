import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("sidequest", Path(__file__).parents[1] / "scripts/sidequest.py")
sq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sq)


def manifest(appid="123", name="Moonlight Courier", flags="4", install="Moonlight", extra=""):
    return f'"AppState" {{ "appid" "{appid}" "name" "{name}" "StateFlags" "{flags}" "installdir" "{install}" "SizeOnDisk" "5000000000" "LastPlayed" "1700000000" {extra} }}'


class ParserTests(unittest.TestCase):
    def test_comments_quoted_braces_and_escaped_names(self):
        parsed = sq.parse_vdf('// first\n"AppState" { "name" "{A \\"Quest\\"}" // note\n "path" "C:\\\\Steam" }'.replace('\\\\"', '\\"'))
        self.assertEqual(parsed["appstate"]["path"], "C:\\Steam")
        self.assertIn("Quest", parsed["appstate"]["name"])

    def test_unquoted_keys_and_case_insensitivity(self):
        self.assertEqual(sq.parse_vdf('APPSTATE { NAME "Quest" }'), {"appstate": {"name": "Quest"}})

    def test_invalid_structures_rejected(self):
        for raw in ['"a" {', '"a" "unfinished', '}', '"a" }', '"a"', '{ "a" "b" }']:
            with self.subTest(raw=raw), self.assertRaises(sq.QuestError):
                sq.parse_vdf(raw)

    def test_depth_and_size_bounds(self):
        with self.assertRaises(sq.QuestError):
            sq.parse_vdf('"a" {' * 30 + '}' * 30)
        with self.assertRaises(sq.QuestError):
            sq.parse_vdf("a" * (sq.MAX_VDF + 1))

    def test_unknown_escape_is_preserved(self):
        self.assertEqual(sq.parse_vdf(r'"path" "C:\games"')["path"], r'C:\games')


class LibraryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "Steam"
        (self.root / "steamapps/common/Moonlight").mkdir(parents=True)

    def add(self, appid="123", **kwargs):
        path = self.root / f"steamapps/appmanifest_{appid}.acf"
        path.write_text(manifest(appid, **kwargs))
        return path

    def scan(self):
        return sq.scan_library([self.root])

    def test_indexes_only_whitelisted_metadata(self):
        self.add(extra='"LastOwner" "PRIVATE" "Password" "NEVER" "LaunchOptions" "SECRET"')
        result = self.scan()
        self.assertEqual(len(result["games"]), 1)
        self.assertEqual(result["games"][0]["name"], "Moonlight Courier")
        self.assertNotIn("PRIVATE", json.dumps(result)); self.assertNotIn("SECRET", json.dumps(result))
        self.assertEqual(set(result["games"][0]), {"id", "name", "bytes", "lastPlayed", "cover", "launcher"})

    def test_runtime_packages_filtered_but_games_named_protonic_survive(self):
        for i, name in enumerate(["Proton Experimental", "Steam Linux Runtime 4.0", "Steamworks Common Redistributables", "Protonic Knight"]):
            self.add(str(i + 1), name=name)
        result = self.scan()
        self.assertEqual([g["name"] for g in result["games"]], ["Protonic Knight"])
        self.assertEqual(result["toolsHidden"], 3)

    def test_missing_and_incomplete_install_not_launchable(self):
        self.add("1", flags="2"); self.add("2", install="Missing")
        self.assertEqual(self.scan()["games"], [])
        self.assertEqual(self.scan()["notReady"], 2)

    def test_install_directory_traversal_rejected(self):
        self.add(install="../outside")
        self.assertEqual(self.scan()["games"], [])

    def test_malformed_manifest_does_not_hide_good_game(self):
        self.add()
        (self.root / "steamapps/appmanifest_456.acf").write_text('"broken')
        result = self.scan()
        self.assertEqual(len(result["games"]), 1)
        self.assertTrue(result["warnings"])

    def test_filename_and_id_must_match(self):
        self.add().write_text(manifest("456"))
        self.assertEqual(self.scan()["games"], [])

    def test_secondary_libraries_and_offline_disks(self):
        other = Path(self.temp.name) / "Other disk"
        (other / "steamapps/common/Moonlight").mkdir(parents=True)
        (other / "steamapps/appmanifest_456.acf").write_text(manifest("456"))
        (self.root / "steamapps/libraryfolders.vdf").write_text(f'"libraryfolders" {{ "0" {{ "path" "{self.root}" }} "1" {{ "path" "{other}" }} "2" {{ "path" "{other}/offline" }} }}')
        self.add()
        result = self.scan()
        self.assertEqual(len(result["games"]), 2)
        self.assertEqual(result["libraries"], 3)
        self.assertIn("offline", " ".join(result["warnings"]))

    def test_legacy_library_list(self):
        (self.root / "steamapps/libraryfolders.vdf").write_text(f'"LibraryFolders" {{ "1" "{self.root}" }}')
        self.add(); self.assertEqual(self.scan()["libraries"], 1)

    def test_duplicate_root_and_app_are_deduplicated(self):
        self.add(); self.assertEqual(len(sq.scan_library([self.root, self.root])["games"]), 1)

    def test_legacy_and_current_local_cover_paths(self):
        self.add()
        cache = self.root / "appcache/librarycache"
        cache.mkdir(parents=True)
        legacy = cache / "123_library_600x900.jpg"; legacy.write_bytes(b"fixture")
        self.assertEqual(self.scan()["games"][0]["cover"], legacy.as_uri())
        legacy.unlink()
        current = cache / "123" / ("a" * 40) / "library_capsule.jpg"
        current.parent.mkdir(parents=True); current.write_bytes(b"fixture")
        self.assertEqual(self.scan()["games"][0]["cover"], current.as_uri())

    def test_cover_symlink_cannot_leave_cache(self):
        self.add()
        cache = self.root / "appcache/librarycache"; cache.mkdir(parents=True)
        secret = Path(self.temp.name) / "secret.jpg"; secret.write_bytes(b"secret")
        (cache / "123_library_600x900.jpg").symlink_to(secret)
        self.assertEqual(self.scan()["games"][0]["cover"], "")

    def test_negative_bad_numbers_are_normalized(self):
        self.add().write_text(manifest().replace('"5000000000"', '"NaN"').replace('"1700000000"', '"-400"'))
        game = self.scan()["games"][0]
        self.assertEqual(game["bytes"], 0); self.assertEqual(game["lastPlayed"], 0)

    def test_unreadable_artwork_does_not_hide_game(self):
        self.add(); (self.root / "appcache/librarycache/123").mkdir(parents=True)
        with patch.object(Path, "iterdir", side_effect=PermissionError("fixture")):
            result = self.scan()
        self.assertEqual(len(result["games"]), 1)
        self.assertEqual(result["games"][0]["cover"], "")

    def test_no_steam_is_a_valid_empty_library(self):
        self.assertEqual(sq.scan_library([])["games"], [])


class JournalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.journal = sq.Journal(Path(self.temp.name) / "private")
        self.games = [{"id": str(i), "name": f"Quest {i}", "bytes": 1, "lastPlayed": 0, "cover": "", "launcher": "steam"} for i in range(1, 5)]
        self.scanner = lambda: {"games": self.games, "libraries": 1, "warnings": [], "scanMs": 1}

    def call(self, **request):
        return sq.handle(request, self.journal, self.scanner, lambda game: None)

    def test_notes_favourites_and_tags_survive_independent_actions(self):
        self.call(action="save", id="1", note="Try the parry.\nBring a potion.", mood="deep")
        self.call(action="favorite", id="1")
        result = self.call(action="scan")["library"]["games"][0]
        self.assertEqual(result["note"], "Try the parry.\nBring a potion.")
        self.assertTrue(result["favorite"]); self.assertEqual(result["mood"], "deep")

    def test_hide_is_reversible_and_preserves_note(self):
        self.call(action="save", id="1", note="Boss clue", mood="any")
        self.call(action="hide", id="1")
        self.assertTrue(self.journal.read()["entries"]["1"]["hidden"])
        self.call(action="hide", id="1")
        entry = self.journal.read()["entries"]["1"]
        self.assertFalse(entry["hidden"]); self.assertEqual(entry["note"], "Boss clue")

    def test_overlong_note_and_invalid_tag_rejected(self):
        for req in [{"note": "x" * 601, "mood": "any"}, {"note": "x", "mood": "unknown"}]:
            with self.assertRaises(sq.QuestError):
                self.call(action="save", id="1", **req)

    def test_control_sequences_removed_without_interpreting_markup(self):
        self.call(action="save", id="1", note="<b>boss</b>\x00\x1b[31m", mood="any")
        self.assertEqual(self.journal.read()["entries"]["1"]["note"], "<b>boss</b>[31m")

    def test_journal_permissions(self):
        self.call(action="favorite", id="1")
        self.assertEqual(stat.S_IMODE(self.journal.directory.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.journal.path.stat().st_mode), 0o600)

    def test_corrupt_journal_never_overwritten(self):
        self.journal.directory.mkdir(); self.journal.path.write_text("broken")
        with self.assertRaises(sq.QuestError):
            self.call(action="favorite", id="1")
        self.assertEqual(self.journal.path.read_text(), "broken")

    def test_replace_failure_preserves_previous_state(self):
        self.call(action="save", id="1", note="old", mood="any")
        previous = self.journal.path.read_bytes()
        with patch.object(sq.os, "replace", side_effect=OSError("disk")), self.assertRaises(OSError):
            self.call(action="save", id="1", note="new", mood="any")
        self.assertEqual(self.journal.path.read_bytes(), previous)
        self.assertEqual(list(self.journal.directory.glob(".journal-*")), [])

    def test_symlink_journal_rejected(self):
        self.journal.directory.mkdir(); destination = Path(self.temp.name) / "other"
        destination.write_text(json.dumps(sq.default_state())); self.journal.path.symlink_to(destination)
        with self.assertRaises(OSError):
            self.call(action="favorite", id="1")
        self.assertEqual(json.loads(destination.read_text()), sq.default_state())

    def test_concurrent_request_gets_bounded_busy_error(self):
        with self.journal.locked(), self.assertRaisesRegex(sq.QuestError, "busy"):
            self.call(action="scan")

    def test_removed_game_cannot_be_launched_or_mutated(self):
        for action in ("launch", "save", "hide", "favorite"):
            with self.subTest(action=action), self.assertRaises(sq.QuestError):
                self.call(action=action, id="99999")

    def test_launch_is_only_explicit_and_known_id(self):
        calls = []
        sq.handle({"action": "roll", "ids": ["1"]}, self.journal, self.scanner, calls.append)
        self.assertEqual(calls, [])
        sq.handle({"action": "launch", "id": "1"}, self.journal, self.scanner, calls.append)
        self.assertEqual(calls[0]["id"], "1")

    def test_failed_state_write_prevents_launch(self):
        calls = []
        with patch.object(self.journal, "write", side_effect=OSError("disk")), self.assertRaises(OSError):
            sq.handle({"action": "launch", "id": "1"}, self.journal, self.scanner, calls.append)
        self.assertEqual(calls, [])

    def test_exact_steam_launch_argument_array(self):
        with patch.object(sq.subprocess, "Popen") as proc:
            sq.launch_game(self.games[0])
        self.assertEqual(proc.call_args.args[0], ["steam", "steam://rungameid/1"])
        self.assertNotIn("shell", proc.call_args.kwargs)
        self.assertTrue(proc.call_args.kwargs["start_new_session"])

    def test_flatpak_launch_and_command_injection_rejection(self):
        with patch.object(sq.subprocess, "Popen") as proc:
            sq.launch_game(dict(self.games[0], launcher="flatpak"))
        self.assertEqual(proc.call_args.args[0], ["flatpak", "run", "com.valvesoftware.Steam", "steam://rungameid/1"])
        with patch.object(sq.subprocess, "Popen") as proc, self.assertRaises(sq.QuestError):
            sq.launch_game({"id": "1;touch /tmp/pwn"})
        proc.assert_not_called()

    def test_real_process_launch_handoff_to_isolated_steam_stub(self):
        # Exercise the real Popen path without launching Steam or a real game.
        folder = Path(self.temp.name) / "bin"; folder.mkdir()
        receipt = Path(self.temp.name) / "receipt.json"
        stub = folder / "steam"
        stub.write_text(f'#!{os.sys.executable}\nimport json,sys\nfrom pathlib import Path\nPath({str(receipt)!r}).write_text(json.dumps(sys.argv[1:]))\n')
        stub.chmod(0o700)
        children = []
        actual_popen = sq.subprocess.Popen
        def launch_stub(*args, **kwargs):
            child = actual_popen(*args, **kwargs); children.append(child); return child
        with patch.dict(os.environ, {"PATH": str(folder)}), patch.object(sq.subprocess, "Popen", side_effect=launch_stub):
            sq.handle({"action": "launch", "id": "1"}, self.journal, self.scanner, sq.launch_game)
        deadline = time.monotonic() + 3
        while not receipt.exists() and time.monotonic() < deadline:
            time.sleep(.01)
        self.assertEqual(json.loads(receipt.read_text()), ["steam://rungameid/1"])
        for child in children:
            child.wait(timeout=3)

    def test_unknown_action_rejected(self):
        with self.assertRaises(sq.QuestError):
            self.call(action="shell")


class ShuffleTests(unittest.TestCase):
    def setUp(self):
        self.games = [{"id": str(i)} for i in range(1, 5)]
        self.state = sq.default_state()

    def roll(self, ids=None):
        return sq.roll(self.games, self.state, ids or [g["id"] for g in self.games], lambda pool: pool[0])

    def test_every_game_once_before_repeat(self):
        self.assertEqual(len({self.roll() for _ in range(4)}), 4)
        self.assertEqual(len({self.roll() for _ in range(4)}), 4)

    def test_cycle_boundary_never_immediately_repeats(self):
        self.state["bag"] = ["1", "2", "3", "4"]; self.state["lastRoll"] = "1"
        self.assertNotEqual(self.roll(), "1")

    def test_single_game_pool_is_supported(self):
        self.assertEqual([self.roll(["1"]) for _ in range(3)], ["1", "1", "1"])

    def test_hidden_and_uninstalled_ids_never_drawn(self):
        self.state["entries"]["1"] = {"hidden": True}
        self.assertEqual(self.roll(["1", "2", "999"]), "2")
        with self.assertRaises(sq.QuestError):
            self.roll(["1", "999"])

    def test_filter_change_only_resets_its_pool(self):
        self.state["bag"] = ["1", "2", "3"]
        self.roll(["1", "2"])
        self.assertIn("3", self.state["bag"])

    def test_duplicate_ids_do_not_weight_draw(self):
        choices = []
        sq.roll(self.games, self.state, ["1", "1", "2"], lambda pool: choices.append(pool) or pool[0])
        self.assertEqual(choices, [["1", "2"]])


if __name__ == "__main__":
    unittest.main()
