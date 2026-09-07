import QtQuick
import QtTest
import ".."
import "../Model.js" as Model

TestCase {
    id: tests
    name: "SidequestView"
    when: windowShown
    visible: true
    width: 1080
    height: 760
    property var subject
    Component {
        id: factory
        SidequestView {
            width: 1080
            height: 760
            library: Model.demoLibrary()
            ready: true
            demo: true
            reducedMotion: true
        }
    }
    SignalSpy {
        id: launchSpy
        signalName: "launchRequested"
    }
    SignalSpy {
        id: rollSpy
        signalName: "rollRequested"
    }
    SignalSpy {
        id: saveSpy
        signalName: "saveRequested"
    }
    SignalSpy {
        id: closeSpy
        signalName: "closeRequested"
    }
    SignalSpy {
        id: favoriteSpy
        signalName: "favoriteRequested"
    }
    function init() {
        failOnWarning(/.*/);
        subject = createTemporaryObject(factory, tests);
        verify(subject !== null);
        launchSpy.target = subject;
        rollSpy.target = subject;
        saveSpy.target = subject;
        closeSpy.target = subject;
        favoriteSpy.target = subject;
        launchSpy.clear();
        rollSpy.clear();
        saveSpy.clear();
        closeSpy.clear();
        favoriteSpy.clear();
        wait(50);
        subject.forceActiveFocus();
    }
    function test_initial_selection_and_navigation() {
        verify(subject.game !== null);
        compare(subject.selectedId, subject.filtered[0].id);
        var first = subject.selectedId;
        keyClick(Qt.Key_Down);
        verify(subject.selectedId !== first);
        keyClick(Qt.Key_Up);
        compare(subject.selectedId, first);
    }
    function test_play_is_explicit() {
        compare(launchSpy.count, 0);
        keyClick(Qt.Key_Return);
        compare(launchSpy.count, 1);
        compare(launchSpy.signalArguments[0][0], subject.selectedId);
    }
    function test_roll_never_launches() {
        keyClick(Qt.Key_R);
        compare(rollSpy.count, 1);
        compare(launchSpy.count, 0);
        compare(rollSpy.signalArguments[0][0].length, 8);
    }
    function test_busy_blocks_actions() {
        subject.busy = true;
        keyClick(Qt.Key_R);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_F);
        compare(rollSpy.count, 0);
        compare(launchSpy.count, 0);
        compare(favoriteSpy.count, 0);
    }
    function test_search_typing_does_not_trigger_shortcuts() {
        keyClick(Qt.Key_Slash);
        var input = findChild(subject, "gameSearch");
        verify(input.activeFocus);
        keyClick(Qt.Key_R);
        keyClick(Qt.Key_F);
        keyClick(Qt.Key_N);
        compare(rollSpy.count, 0);
        compare(favoriteSpy.count, 0);
        compare(input.text, "rfn");
        keyClick(Qt.Key_Return);
        compare(launchSpy.count, 0);
    }
    function test_note_editing_and_save_shortcut() {
        keyClick(Qt.Key_N);
        var note = findChild(subject, "questNote");
        verify(note.activeFocus);
        note.text = "Bring a potion. <b>Plain text</b>";
        compare(subject.draftNote, note.text);
        verify(subject.dirty);
        keyClick(Qt.Key_Return);
        compare(launchSpy.count, 0);
        keyClick(Qt.Key_S, Qt.ControlModifier);
        compare(saveSpy.count, 1);
        compare(saveSpy.signalArguments[0][0], subject.selectedId);
    }
    function test_unsaved_draft_survives_game_switch_and_refresh() {
        var id = subject.selectedId;
        var note = findChild(subject, "questNote");
        note.text = "My unfinished thought";
        subject.moveSelection(1);
        subject.selectGame(id);
        compare(note.text, "My unfinished thought");
        subject.library = Model.demoLibrary();
        compare(note.text, "My unfinished thought");
        verify(subject.dirty);
    }
    function test_save_ack_clears_dirty_only_for_matching_content() {
        var note = findChild(subject, "questNote"), id = subject.selectedId;
        note.text = "Save this";
        var copy = Model.demoLibrary();
        Model.byId(copy.games, id).note = "Save this";
        subject.library = copy;
        subject.acceptSaved(id, "Save this", subject.draftMood);
        verify(!subject.dirty);
        note.text = "A newer thought";
        subject.acceptSaved(id, "Save this", subject.draftMood);
        verify(subject.dirty);
    }
    function test_filter_preserves_drafts() {
        var id = subject.selectedId;
        findChild(subject, "questNote").text = "Do not lose me";
        subject.mode = "party";
        subject.mode = "all";
        subject.selectGame(id);
        compare(subject.draftNote, "Do not lose me");
    }
    function test_hidden_pool_cannot_roll() {
        var copy = Model.demoLibrary();
        copy.games[0].hidden = true;
        subject.library = copy;
        subject.mode = "hidden";
        compare(subject.filtered.length, 1);
        verify(!findChild(subject, "rollButton").enabled);
        keyClick(Qt.Key_R);
        compare(rollSpy.count, 0);
    }
    function test_escape_leaves_editor_before_closing() {
        keyClick(Qt.Key_N);
        keyClick(Qt.Key_Escape);
        compare(closeSpy.count, 0);
        keyClick(Qt.Key_Escape);
        compare(closeSpy.count, 1);
    }
    function test_empty_and_error_have_no_actions() {
        subject.demo = false;
        subject.library = Model.emptyLibrary();
        subject.ready = true;
        wait(20);
        compare(subject.game, null);
        verify(!findChild(subject, "playButton").enabled);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_R);
        compare(launchSpy.count, 0);
        compare(rollSpy.count, 0);
        subject.error = true;
        subject.status = "Library unavailable";
        wait(20);
    }
    function test_short_compact_keeps_primary_actions_inside_view() {
        subject.width = 640;
        subject.height = 480;
        wait(80);
        for (var name of ["playButton", "saveButton", "rollButton", "questNote"]) {
            var item = findChild(subject, name), p = item.mapToItem(subject, 0, 0);
            verify(p.x >= 0 && p.y >= 0, name + " begins inside");
            verify(p.x + item.width <= subject.width + 1, name + " fits width: " + p.x + " + " + item.width);
            verify(p.y + item.height <= subject.height + 1, name + " fits height: " + p.y + " + " + item.height);
        }
    }
    function test_note_limit_and_multiline() {
        var note = findChild(subject, "questNote");
        note.text = "x".repeat(700);
        compare(note.text.length, 600);
        note.text = "line one\nline two";
        compare(subject.draftNote, note.text);
    }
    function test_closed_view_stops_roll_animation() {
        subject.reducedMotion = false;
        subject.requestRoll();
        verify(subject.rolling);
        subject.active = false;
        compare(subject.rolling, false);
    }
    function test_help_escape_does_not_close_panel() {
        subject.helpOpen = true;
        keyClick(Qt.Key_Escape);
        compare(subject.helpOpen, false);
        compare(closeSpy.count, 0);
    }
    function test_help_blocks_game_shortcuts() {
        subject.helpOpen = true;
        wait(10);
        keyClick(Qt.Key_R);
        keyClick(Qt.Key_N);
        keyClick(Qt.Key_F);
        compare(rollSpy.count, 0);
        compare(favoriteSpy.count, 0);
        compare(launchSpy.count, 0);
    }
    function test_demo_switch_preserves_separate_draft_sets() {
        var id = subject.selectedId;
        findChild(subject, "questNote").text = "Demo draft";
        subject.demo = false;
        subject.selectGame(id);
        findChild(subject, "questNote").text = "Live draft";
        subject.demo = true;
        subject.selectGame(id);
        compare(subject.draftNote, "Demo draft");
        subject.demo = false;
        subject.selectGame(id);
        compare(subject.draftNote, "Live draft");
    }
    function test_note_markup_is_literal() {
        var note = findChild(subject, "questNote");
        note.text = "<b>Remember this</b>";
        compare(note.textFormat, TextEdit.PlainText);
        compare(subject.draftNote, "<b>Remember this</b>");
    }
    function test_uninstalled_game_keeps_unsaved_draft_until_reinstalled() {
        var id = subject.selectedId;
        findChild(subject, "questNote").text = "My remaining clue";
        var copy = Model.demoLibrary();
        copy.games = copy.games.filter(function (g) {
            return g.id !== id;
        });
        subject.library = copy;
        subject.library = Model.demoLibrary();
        subject.selectGame(id);
        compare(subject.draftNote, "My remaining clue");
    }
    function test_emoji_limit_does_not_split_surrogate_pairs() {
        var note = findChild(subject, "questNote");
        note.text = "x".repeat(599) + "🎮🎮";
        compare(Model.characterCount(note.text), 600);
        verify(note.text.endsWith("🎮"));
    }
    function test_selected_game_stays_visible_after_save_refresh() {
        var id = subject.filtered[6].id, list = findChild(subject, "gameList");
        subject.showPick(id);
        wait(30);
        verify(list.contentY > 0);
        subject.library = Model.demoLibrary();
        wait(30);
        compare(subject.selectedId, id);
        verify(list.contentY > 0, "Model replacement must preserve the selected row's visibility");
    }
}
