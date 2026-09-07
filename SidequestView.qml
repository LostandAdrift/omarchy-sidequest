pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"
import "Model.js" as Model

FocusScope {
    id: root
    property var library: Model.emptyLibrary()
    property bool busy: false
    property bool ready: false
    property bool active: true
    property bool demo: false
    property bool reducedMotion: false
    property string status: ""
    property bool error: false
    property string selectedId: ""
    property string mode: "all"
    property string draftNote: ""
    property string draftMood: "any"
    property var drafts: ({})
    property var savedDraftSets: ({
            live: {},
            demo: {}
        })
    property bool previousDemo: false
    property bool rolling: false
    property bool helpOpen: false
    property real now: Date.now()
    readonly property bool compact: width < 860
    readonly property bool shortView: height < 650
    readonly property var filtered: Model.filter(library.games || [], search.text, mode)
    readonly property var game: Model.byId(library.games || [], selectedId)
    readonly property bool dirty: game !== null && (draftNote !== String(game.note || "") || draftMood !== String(game.mood || "any"))
    readonly property int visibleCount: (library.games || []).filter(function (g) {
        return !g.hidden;
    }).length
    readonly property bool editing: noteInput.activeFocus || search.activeFocus
    signal closeRequested
    signal refreshRequested
    signal demoRequested
    signal saveRequested(string appid, string note, string mood)
    signal favoriteRequested(string appid)
    signal hideRequested(string appid)
    signal rollRequested(var ids)
    signal launchRequested(string appid)

    function focusBody() {
        keyFocus.forceActiveFocus();
    }
    function rememberDraft() {
        if (!selectedId)
            return;
        var next = Object.assign({}, drafts);
        if (dirty || !game)
            next[selectedId] = {
                note: draftNote,
                mood: draftMood
            };
        else
            delete next[selectedId];
        drafts = next;
    }
    function selectGame(id) {
        if (id === selectedId)
            return;
        rememberDraft();
        selectedId = id;
        var current = Model.byId(library.games || [], id), draft = drafts[id];
        draftNote = draft ? draft.note : (current ? String(current.note || "") : "");
        draftMood = draft ? draft.mood : (current ? String(current.mood || "any") : "any");
        noteInput.text = draftNote;
    }
    function reconcile() {
        var present = filtered.some(function (g) {
            return g.id === root.selectedId;
        });
        if (!present)
            selectGame(filtered.length ? filtered[0].id : "");
    }
    function moveSelection(delta) {
        if (!filtered.length)
            return;
        var index = filtered.findIndex(function (g) {
            return g.id === root.selectedId;
        });
        index = Math.max(0, Math.min(filtered.length - 1, index + delta));
        selectGame(filtered[index].id);
        gamesList.positionViewAtIndex(index, ListView.Contain);
    }
    function save() {
        if (game && dirty && !busy)
            saveRequested(game.id, draftNote, draftMood);
    }
    function acceptSaved(id, note, mood) {
        var next = Object.assign({}, drafts);
        if (next[id] && next[id].note === note && next[id].mood === mood)
            delete next[id];
        drafts = next;
    }
    function requestRoll() {
        if (busy || rolling || mode === "hidden" || !filtered.length)
            return;
        rolling = true;
        rollTimer.restart();
        rollRequested(filtered.map(function (g) {
            return g.id;
        }));
    }
    function showPick(id) {
        if (!id)
            return;
        selectGame(id);
        var index = filtered.findIndex(function (g) {
            return g.id === id;
        });
        if (index >= 0)
            gamesList.positionViewAtIndex(index, ListView.Contain);
    }
    function resetView() {
        rememberDraft();
        var sets = Object.assign({}, savedDraftSets);
        sets[previousDemo ? "demo" : "live"] = drafts;
        savedDraftSets = sets;
        previousDemo = demo;
        drafts = sets[demo ? "demo" : "live"] || {};
        selectedId = "";
        draftNote = "";
        draftMood = "any";
        search.text = "";
        mode = "all";
        reconcile();
    }
    onFilteredChanged: reconcile()
    onDemoChanged: resetView()
    onActiveChanged: if (!active) {
        rollTimer.stop();
        rolling = false;
        helpOpen = false;
    }
    Component.onCompleted: reconcile()
    Timer {
        id: rollTimer
        interval: root.reducedMotion ? 1 : 460
        onTriggered: root.rolling = false
    }

    Item {
        id: keyFocus
        focus: true
    }
    onHelpOpenChanged: if (helpOpen)
        Qt.callLater(function () {
            helpBack.forceActiveFocus();
        })
    else
        focusBody()
    Keys.onPressed: function (event) {
        if (helpOpen) {
            if (event.key === Qt.Key_Escape)
                helpOpen = false;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            if (helpOpen)
                helpOpen = false;
            else if (noteInput.activeFocus)
                root.focusBody();
            else if (search.text) {
                search.text = "";
                root.focusBody();
            } else
                closeRequested();
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
            save();
        } else if (!editing && event.key === Qt.Key_Slash) {
            search.forceActiveFocus();
        } else if (!editing && event.key === Qt.Key_R) {
            requestRoll();
        } else if (!editing && event.key === Qt.Key_N && game) {
            noteInput.forceActiveFocus();
        } else if (!editing && event.key === Qt.Key_Down) {
            moveSelection(1);
        } else if (!editing && event.key === Qt.Key_Up) {
            moveSelection(-1);
        } else if (!editing && event.key === Qt.Key_F && game && !busy) {
            favoriteRequested(game.id);
        } else if (!editing && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && game && !busy) {
            launchRequested(game.id);
        } else if (!editing && event.key === Qt.Key_Question) {
            helpOpen = !helpOpen;
        } else {
            event.accepted = false;
            return;
        }
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Model.ink
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 18 : 26
        spacing: root.shortView ? 10 : 16
        enabled: !root.helpOpen
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 36
                Rectangle {
                    x: 14
                    y: 2
                    width: 5
                    height: 26
                    color: Model.accent
                }
                Rectangle {
                    x: 4
                    y: 22
                    width: 25
                    height: 4
                    color: Model.mint
                }
                Rectangle {
                    x: 14
                    y: 26
                    width: 5
                    height: 9
                    color: Model.gold
                }
                Rectangle {
                    x: 11
                    y: 0
                    width: 11
                    height: 3
                    color: Model.accent
                }
            }
            ColumnLayout {
                spacing: 2
                Text {
                    text: "SIDEQUEST"
                    font.family: "monospace"
                    font.pixelSize: root.compact ? 23 : 27
                    font.bold: true
                    font.letterSpacing: 3
                    color: Model.text
                }
                Text {
                    text: root.compact ? "YOUR NEXT MOVE, REMEMBERED." : "YOUR NEXT MOVE, REMEMBERED.  /  OMARCHY"
                    font.family: "monospace"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Model.muted
                }
            }
            Item {
                Layout.fillWidth: true
            }
            QuestButton {
                text: root.demo ? "Exit demo" : "Demo"
                compact: true
                tint: root.demo ? Model.gold : Model.muted
                onClicked: root.demoRequested()
            }
            QuestButton {
                text: "?"
                compact: true
                Accessible.name: "Keyboard shortcuts and help"
                onClicked: root.helpOpen = !root.helpOpen
            }
            QuestButton {
                text: "×"
                compact: true
                Accessible.name: "Close Sidequest"
                onClicked: root.closeRequested()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Model.line
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.compact ? 14 : 22
            ColumnLayout {
                Layout.preferredWidth: root.compact ? 208 : 292
                Layout.maximumWidth: root.compact ? 208 : 292
                Layout.fillWidth: false
                Layout.minimumWidth: 180
                Layout.fillHeight: true
                spacing: root.shortView ? 8 : 12
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "QUEST LOG"
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                        color: Model.accent
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: String(root.visibleCount).padStart(2, "0") + " INSTALLED"
                        font.family: "monospace"
                        font.pixelSize: 9
                        color: Model.muted
                    }
                }
                TextField {
                    id: search
                    objectName: "gameSearch"
                    Layout.fillWidth: true
                    implicitHeight: 39
                    placeholderText: "Find a game  /"
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Model.text
                    placeholderTextColor: Model.muted
                    selectionColor: Model.accent
                    selectedTextColor: Model.ink
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle {
                        color: Model.panel
                        border.color: search.activeFocus ? Model.accent : Model.line
                        radius: 4
                    }
                    Accessible.name: "Search installed games"
                    Keys.onDownPressed: function (event) {
                        root.moveSelection(1);
                        root.focusBody();
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: root.focusBody()
                    Keys.onEscapePressed: function (event) {
                        if (text)
                            text = "";
                        else
                            root.focusBody();
                        event.accepted = true;
                    }
                }
                ComboBox {
                    id: filterBox
                    objectName: "poolFilter"
                    Layout.fillWidth: true
                    implicitHeight: 34
                    model: ["All quests", "Favourites", "With a note", "Quick session", "Deep dive", "Party time", "Hidden games"]
                    property var modes: ["all", "favorites", "notes", "quick", "deep", "party", "hidden"]
                    currentIndex: modes.indexOf(root.mode)
                    onActivated: function (index) {
                        root.mode = modes[index];
                    }
                    font.family: "monospace"
                    font.pixelSize: 11
                    contentItem: Text {
                        text: filterBox.displayText
                        color: Model.muted
                        font: filterBox.font
                        leftPadding: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: Model.panel
                        border.color: filterBox.activeFocus ? Model.accent : Model.line
                        radius: 4
                    }
                    Accessible.name: "Quest pool"
                }
                ListView {
                    id: gamesList
                    objectName: "gameList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.filtered
                    spacing: 7
                    clip: true
                    reuseItems: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    delegate: ItemDelegate {
                        id: row
                        required property var modelData
                        width: gamesList.width
                        height: root.compact ? 66 : 76
                        focusPolicy: Qt.NoFocus
                        onClicked: {
                            root.selectGame(modelData.id);
                            root.focusBody();
                        }
                        Accessible.name: modelData.name + (modelData.note ? ", quest note saved" : "")
                        background: Rectangle {
                            color: root.selectedId === row.modelData.id ? "#29283d" : (row.hovered ? Model.panel : "transparent")
                            radius: 4
                            border.color: root.selectedId === row.modelData.id ? Model.accent : "transparent"
                        }
                        contentItem: RowLayout {
                            spacing: 10
                            QuestArt {
                                Layout.preferredWidth: root.compact ? 35 : 44
                                Layout.preferredHeight: root.compact ? 48 : 58
                                miniature: true
                                gameId: row.modelData.id
                                title: row.modelData.name
                                cover: row.modelData.cover || ""
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    textFormat: Text.PlainText
                                    color: root.selectedId === row.modelData.id ? Model.text : "#c8c9d5"
                                    font.pixelSize: root.compact ? 12 : 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (row.modelData.favorite ? "★  " : "") + (row.modelData.note ? "QUEST SAVED" : row.modelData.mood !== "any" ? ({
                                                quick: "QUICK SESSION",
                                                deep: "DEEP DIVE",
                                                party: "PARTY TIME"
                                            })[row.modelData.mood] : "START A CHAPTER")
                                    font.family: "monospace"
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    color: row.modelData.note ? Model.mint : Model.muted
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        visible: root.filtered.length === 0
                        text: root.error ? "Your quest log needs attention.\nSee the message below." : !root.ready ? "Opening your quest log…" : (root.library.games.length ? "No quests in this pool.\nTry another filter." : "Your adventure starts here.\nInstall a game in Steam,\nthen refresh.\n\nOr explore the demo.")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Model.muted
                        font.pixelSize: 12
                        lineHeight: 1.5
                    }
                }
                QuestButton {
                    objectName: "rollButton"
                    Layout.fillWidth: true
                    text: root.rolling ? "◇  FATE IS THINKING…" : "◇  ROLL A QUEST"
                    primary: true
                    tint: Model.accent
                    enabled: !root.busy && !root.rolling && root.filtered.length > 0 && root.mode !== "hidden"
                    onClicked: root.requestRoll()
                }
                Text {
                    visible: !root.shortView
                    Layout.fillWidth: true
                    text: "A shuffle bag. No repeats until\nevery quest gets its turn."
                    font.pixelSize: 10
                    color: Model.muted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.3
                }
            }
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Model.line
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 260
                spacing: root.shortView ? 8 : 12
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.shortView ? Math.max(88, root.height * .23 - 35) : Math.max(140, Math.min(260, root.height * .32))
                    clip: true
                    QuestArt {
                        anchors.fill: parent
                        gameId: root.game ? root.game.id : "700001"
                        title: root.game ? root.game.name : ""
                        cover: root.game ? root.game.cover || "" : ""
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Model.line
                        radius: 4
                    }
                    Rectangle {
                        x: 14
                        y: 10
                        width: heroLabel.implicitWidth + 18
                        height: 20
                        color: "#df10131d"
                        radius: 3
                        visible: !root.shortView
                        Text {
                            id: heroLabel
                            anchors.centerIn: parent
                            text: root.demo ? "DEMO / FICTIONAL GAMES" : root.game ? "CONTINUE YOUR ADVENTURE" : "A NEW ADVENTURE"
                            font.family: "monospace"
                            font.pixelSize: 8
                            font.letterSpacing: 1
                            color: Model.mint
                        }
                    }
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: root.shortView ? 12 : 18
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: root.game ? root.game.name : "The next chapter is yours."
                            textFormat: Text.PlainText
                            font.pixelSize: root.compact ? 24 : 32
                            font.weight: Font.Bold
                            color: Model.text
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.game ? Model.lastPlayed(root.game.lastPlayed, root.now) + "   ·   " + Model.sizeLabel(root.game.bytes) : "Your games. Your notes. Entirely local."
                            font.family: "monospace"
                            font.pixelSize: 9
                            color: Model.muted
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Model.accent
                        opacity: root.rolling ? .18 : 0
                        Behavior on opacity {
                            enabled: !root.reducedMotion && root.active
                            NumberAnimation {
                                duration: 180
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    QuestButton {
                        objectName: "playButton"
                        text: root.compact ? "▶  PLAY" : "▶  CONTINUE IN STEAM"
                        primary: true
                        tint: Model.mint
                        Layout.fillWidth: true
                        implicitHeight: root.shortView ? 34 : 40
                        enabled: root.game !== null && !root.busy
                        onClicked: root.launchRequested(root.game.id)
                    }
                    QuestButton {
                        text: root.game && root.game.favorite ? "★" : "☆"
                        tint: Model.gold
                        enabled: root.game !== null && !root.busy
                        implicitWidth: 40
                        Accessible.name: root.game && root.game.favorite ? "Remove favourite" : "Add favourite"
                        onClicked: root.favoriteRequested(root.game.id)
                    }
                    QuestButton {
                        text: root.game && root.game.hidden ? "Unhide" : "Hide"
                        tint: Model.muted
                        enabled: root.game !== null && !root.busy
                        implicitWidth: root.compact ? 62 : 68
                        onClicked: root.hideRequested(root.game.id)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "NEXT TIME, REMEMBER…"
                        font.family: "monospace"
                        font.pixelSize: root.compact ? 9 : 11
                        font.bold: true
                        font.letterSpacing: 1
                        color: Model.accent
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.dirty ? "UNSAVED" : "LOCAL NOTE"
                        font.family: "monospace"
                        font.pixelSize: 8
                        color: root.dirty ? Model.gold : Model.muted
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 54
                    color: Model.panel
                    border.color: noteInput.activeFocus ? Model.accent : Model.line
                    radius: 4
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        contentWidth: availableWidth
                        TextArea {
                            id: noteInput
                            objectName: "questNote"
                            placeholderText: "Where did you leave off?\nA boss strategy, a quest clue, one thing to try…"
                            placeholderTextColor: "#858ba4"
                            color: Model.text
                            enabled: root.game !== null
                            wrapMode: TextEdit.Wrap
                            font.pixelSize: root.compact ? 12 : 14
                            textFormat: TextEdit.PlainText
                            selectByMouse: true
                            selectionColor: Model.accent
                            selectedTextColor: Model.ink
                            background: null
                            padding: 0
                            onTextChanged: {
                                if (text.length > 600)
                                    text = Model.limitText(text, 600);
                                root.draftNote = text;
                            }
                            Accessible.name: "Next-session quest note"
                            Keys.onPressed: function (event) {
                                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                                    root.save();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.focusBody();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ComboBox {
                        id: moodBox
                        objectName: "sessionTag"
                        Layout.fillWidth: true
                        implicitHeight: 36
                        enabled: root.game !== null
                        model: ["Any session", "Quick session", "Deep dive", "Party time"]
                        property var moods: ["any", "quick", "deep", "party"]
                        currentIndex: moods.indexOf(root.draftMood)
                        onActivated: function (index) {
                            root.draftMood = moods[index];
                        }
                        font.family: "monospace"
                        font.pixelSize: 10
                        contentItem: Text {
                            text: moodBox.displayText
                            color: Model.muted
                            font: moodBox.font
                            leftPadding: 10
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: Model.panel
                            border.color: moodBox.activeFocus ? Model.accent : Model.line
                            radius: 4
                        }
                        Accessible.name: "Your session tag"
                    }
                    Text {
                        text: Model.characterCount(root.draftNote) + "/600"
                        font.family: "monospace"
                        font.pixelSize: 9
                        color: Model.muted
                    }
                    QuestButton {
                        objectName: "saveButton"
                        text: "SAVE QUEST"
                        compact: root.compact
                        tint: Model.accent
                        enabled: root.game !== null && root.dirty && !root.busy
                        onClicked: root.save()
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Model.line
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: root.status || (root.demo ? "DEMO · Original fictional games. Nothing will launch." : root.busy ? "Reading local library…" : root.library.warnings.length ? root.library.warnings.join(" ") : root.library.toolsHidden + " runtime packages tucked away. No cloud. No accounts.")
                textFormat: Text.PlainText
                font.pixelSize: 11
                color: root.error ? "#f1a7ab" : Model.muted
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            QuestButton {
                text: "↻"
                compact: true
                enabled: !root.busy
                Accessible.name: "Refresh local library"
                onClicked: root.refreshRequested()
            }
            Text {
                visible: !root.compact
                text: "/ SEARCH   R ROLL   N NOTE   ↵ PLAY"
                font.family: "monospace"
                font.pixelSize: 8
                color: Model.muted
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.helpOpen
        color: "#ec10131d"
        z: 20
        MouseArea {
            anchors.fill: parent
            onClicked: root.helpOpen = false
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 530)
            height: Math.min(parent.height - 40, 480)
            color: Model.panel
            border.color: Model.accent
            radius: 5
            MouseArea {
                anchors.fill: parent
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14
                Text {
                    text: "HOW TO SIDEQUEST"
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: 19
                    color: Model.accent
                }
                Text {
                    Layout.fillWidth: true
                    text: "Remember the clue. Skip the indecision. Play."
                    font.pixelSize: 13
                    color: Model.text
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    text: "/     Search your installed games\n↑ ↓   Choose a quest\nR     Draw from the current pool\nN     Write your next-session note\nF     Toggle favourite\nEnter Request launch from Steam\nCtrl+S Save your note and session tag\nEsc   Leave the editor / close the panel"
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Model.muted
                    lineHeight: 1.55
                }
                Text {
                    Layout.fillWidth: true
                    text: "Session tags are yours to choose. Notes stay on this machine. Sidequest remembers your plans; your game's save files stay with the game.\n\nHidden games can be restored from the Hidden games filter. A roll selects a game; Play launches it."
                    font.pixelSize: 12
                    color: Model.muted
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                }
                Item {
                    Layout.fillHeight: true
                }
                QuestButton {
                    id: helpBack
                    text: "BACK TO THE QUEST"
                    Layout.fillWidth: true
                    onClicked: {
                        root.helpOpen = false;
                        root.focusBody();
                    }
                }
            }
        }
    }
}
