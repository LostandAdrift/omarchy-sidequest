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
    property string output: "/tmp/sidequest-preview.png"
    SidequestView {
        id: view
        anchors.fill: parent
        library: Model.demoLibrary()
        ready: true
        demo: true
        now: 1788825600000
    }
    Timer {
        interval: 900
        running: true
        onTriggered: {
            if (!view.grabToImage(function (result) {
                if (!result.saveToFile(window.output))
                    Qt.exit(1);
                else
                    Qt.quit();
            }))
                Qt.exit(1);
        }
    }
    Component.onCompleted: {
        var args = Qt.application.arguments;
        for (var i = 0; i < args.length; i++) {
            if (args[i] === "--output")
                output = args[++i];
            else if (args[i] === "--compact") {
                width = 720;
                height = 600;
            } else if (args[i] === "--small") {
                width = 640;
                height = 480;
            } else if (args[i] === "--empty") {
                view.demo = false;
                view.library = Model.emptyLibrary();
            } else if (args[i] === "--help-view")
                view.helpOpen = true;
            else if (args[i] === "--error") {
                view.error = true;
                view.status = "A Steam library is offline or unmounted. Your quest notes are safe.";
            } else if (args[i] === "--game")
                view.showPick(args[++i]);
        }
    }
}
