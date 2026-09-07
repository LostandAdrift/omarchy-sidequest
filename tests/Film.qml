import QtQuick
import QtQuick.Window
import ".."
import "../Model.js" as Model

Window {
    id: window
    width: 1080
    height: 760
    visible: true
    color: Model.ink
    property string output: "/tmp/sidequest-film"
    property int frame: 0
    property bool capturing: false
    function findNamed(item, name) {
        if (item.objectName === name)
            return item;
        for (var child of item.children || []) {
            var found = findNamed(child, name);
            if (found)
                return found;
        }
        return null;
    }
    SidequestView {
        id: view
        anchors.fill: parent
        library: Model.demoLibrary()
        ready: true
        demo: true
        now: 1788825600000
        onSaveRequested: function (id, note, mood) {
            var copy = JSON.parse(JSON.stringify(library)), game = Model.byId(copy.games, id);
            game.note = note;
            game.mood = mood;
            library = copy;
            status = "Quest saved. Future you says thanks.";
        }
        onRollRequested: function (ids) {
            showPick(ids.indexOf("700006") >= 0 ? "700006" : ids[0]);
            status = "Quest drawn. Play when you're ready.";
        }
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (window.capturing)
                return;
            if (window.frame >= 200) {
                Qt.quit();
                return;
            }
            if (window.frame === 0)
                view.showPick("700001");
            if (window.frame === 45)
                view.showPick("700002");
            if (window.frame >= 60 && window.frame <= 100) {
                var note = "The second swing is a feint. Parry, then dash behind the boss.";
                window.findNamed(view, "questNote").text = note.slice(0, Math.floor((window.frame - 59) / 41 * note.length));
            }
            if (window.frame === 110)
                view.save();
            if (window.frame === 135) {
                view.mode = "quick";
                view.status = "";
            }
            if (window.frame === 155)
                view.requestRoll();
            window.capturing = true;
            var filename = window.output + "/frame-" + String(window.frame).padStart(4, "0") + ".png";
            if (!view.grabToImage(function (result) {
                if (!result.saveToFile(filename)) {
                    Qt.exit(1);
                    return;
                }
                window.frame++;
                window.capturing = false;
            }))
                Qt.exit(1);
        }
    }
    Component.onCompleted: {
        var args = Qt.application.arguments;
        for (var i = 0; i < args.length; i++)
            if (args[i] === "--output")
                output = args[++i];
    }
}
