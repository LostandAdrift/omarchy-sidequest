pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Model.js" as Model

QtObject {
    id: root
    property var library: Model.emptyLibrary()
    property bool ready: false
    property bool busy: false
    property bool error: false
    property string status: ""
    property int requests: 0
    property var pending: null
    property string output: ""
    property bool outputDone: false
    property bool exited: false
    property bool timedOut: false
    property int exitCode: -1
    readonly property bool running: worker.running
    signal finished(var request, var response)

    function request(payload) {
        if (busy)
            return false;
        pending = payload;
        busy = true;
        error = false;
        status = "";
        output = "";
        outputDone = false;
        exited = false;
        timedOut = false;
        exitCode = -1;
        requests++;
        var script = decodeURIComponent(Qt.resolvedUrl("../scripts/sidequest.py").toString().replace("file://", ""));
        worker.command = ["python3", "-u", script];
        worker.running = true;
        deadline.restart();
        return true;
    }
    function settle() {
        if (!busy || worker.running || (!timedOut && (!exited || !outputDone)))
            return;
        deadline.stop();
        killDeadline.stop();
        var payload = pending, response = null;
        try {
            if (output.length <= 8 * 1024 * 1024)
                response = JSON.parse(output);
        } catch (e) {}
        if (timedOut || !response || typeof response.ok !== "boolean")
            response = {
                ok: false,
                message: timedOut ? "The local library took too long to respond. Try refreshing." : "The local helper could not respond. Try refreshing."
            };
        if (response.ok && exitCode === 0 && response.library && Array.isArray(response.library.games)) {
            library = response.library;
            ready = true;
            error = false;
        } else {
            response.ok = false;
            error = true;
        }
        status = response.message || (error ? "The local library could not be opened." : "");
        busy = false;
        pending = null;
        output = "";
        finished(payload, response);
    }
    property Process worker: Process {
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify(root.pending));
            stdinEnabled = false;
        }
        onExited: function (code, status) {
            root.exitCode = code;
            root.exited = true;
            stdinEnabled = true;
            Qt.callLater(root.settle);
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.output = text;
                root.outputDone = true;
                Qt.callLater(root.settle);
            }
        }
        stderr: StdioCollector {}
    }
    property Timer deadline: Timer {
        interval: 10000
        onTriggered: {
            root.timedOut = true;
            if (worker.running) {
                worker.signal(15);
                killDeadline.start();
            } else
                root.settle();
        }
    }
    property Timer killDeadline: Timer {
        interval: 1000
        onTriggered: {
            if (worker.running)
                worker.signal(9);
            else
                root.settle();
        }
    }
}
