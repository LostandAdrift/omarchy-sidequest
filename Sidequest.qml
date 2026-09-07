pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "Model.js" as Model
import "runtime" as Local

Ui.Panel {
    id: root
    moduleName: "io.github.lostandadrift.sidequest"
    ipcTarget: moduleName
    manageIpc: false
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    property bool demo: false
    property var demoLibrary: Model.demoLibrary()
    property var demoBag: []
    property string demoStatus: ""
    readonly property bool reducedMotion: setting("reducedMotion", false) === true
    readonly property bool hasScreen: button.QsWindow.window !== null && button.QsWindow.window.screen !== null
    readonly property bool coordinator: hasScreen && button.QsWindow.window.screen === Quickshell.screens[0]
    readonly property var lockService: root.bar && root.bar.shell && typeof root.bar.shell.serviceFor === "function" ? root.bar.shell.serviceFor("omarchy.lock") : null
    readonly property bool locked: lockService !== null && lockService.locked === true
    onLockedChanged: if (locked)
        close()
    onHasScreenChanged: if (!hasScreen)
        close()
    onOpenedChanged: if (opened) {
        view.now = Date.now();
        if (!demo)
            Local.Library.request({
                action: "scan"
            });
    }

    function instances() {
        return bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root];
    }
    function activeInstance() {
        var all = instances();
        for (var i = 0; i < all.length; i++)
            if (all[i].opened)
                return all[i];
        return root;
    }
    function state() {
        return {
            opened: opened,
            demo: demo,
            ready: Local.Library.ready,
            busy: Local.Library.busy,
            running: Local.Library.running,
            error: Local.Library.error,
            requests: Local.Library.requests,
            games: view.library.games.length,
            selected: view.selectedId,
            dirty: view.dirty,
            rolling: view.rolling,
            locked: locked,
            screen: hasScreen ? button.QsWindow.window.screen.name : "",
            scanMs: view.library.scanMs,
            panel: {
                x: panel.cardOrigin.x,
                y: panel.cardOrigin.y,
                width: panel.contentWidth,
                height: panel.contentHeight
            }
        };
    }
    function toggleDemo() {
        demo = !demo;
        demoStatus = "";
        if (opened && !demo)
            Local.Library.request({
                action: "scan"
            });
    }
    function act(payload) {
        if (locked || !opened)
            return;
        if (!demo) {
            Local.Library.request(payload);
            return;
        }
        var copy = JSON.parse(JSON.stringify(demoLibrary)), g = Model.byId(copy.games, payload.id);
        if (payload.action === "save" && g) {
            g.note = payload.note;
            g.mood = payload.mood;
            demoStatus = "Demo quest saved. Your real journal is untouched.";
        } else if (payload.action === "favorite" && g)
            g.favorite = !g.favorite;
        else if (payload.action === "hide" && g)
            g.hidden = !g.hidden;
        else if (payload.action === "launch") {
            demoStatus = "Demo only. No game was launched.";
            return;
        } else if (payload.action === "roll") {
            var pool = payload.ids.filter(function (id) {
                return root.demoBag.indexOf(id) < 0;
            });
            if (!pool.length) {
                demoBag = [];
                pool = payload.ids;
            }
            if (pool.length) {
                var picked = pool[Math.floor(Math.random() * pool.length)];
                demoBag = demoBag.concat([picked]);
                view.showPick(picked);
                demoStatus = "Demo quest drawn. The adventure is imaginary.";
            }
            return;
        }
        demoLibrary = copy;
    }
    Connections {
        target: Local.Library
        function onFinished(request, response) {
            if (root.demo || !response.ok)
                return;
            if (request.action === "save")
                view.acceptSaved(request.id, request.note, request.mood);
            if (response.picked)
                view.showPick(response.picked);
        }
    }
    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        tooltipText: "Sidequest — your next move, remembered"
        onPressed: function (b) {
            root.toggle();
        }
        iconComponent: Component {
            Canvas {
                id: glyph
                onPaint: {
                    var c = getContext("2d"), s = width / 24;
                    c.reset();
                    c.scale(s, s);
                    c.strokeStyle = button.foreground;
                    c.lineWidth = 1.7;
                    c.lineCap = "square";
                    c.lineJoin = "miter";
                    c.beginPath();
                    c.moveTo(12, 2);
                    c.lineTo(15, 6);
                    c.lineTo(14, 15);
                    c.lineTo(10, 15);
                    c.lineTo(9, 6);
                    c.closePath();
                    c.stroke();
                    c.beginPath();
                    c.moveTo(5, 15);
                    c.lineTo(19, 15);
                    c.moveTo(12, 16);
                    c.lineTo(12, 22);
                    c.moveTo(9, 22);
                    c.lineTo(15, 22);
                    c.stroke();
                }
                Connections {
                    target: button
                    function onForegroundChanged() {
                        glyph.requestPaint();
                    }
                }
            }
        }
    }
    Ui.KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: view
        padding: 0
        centerOnBar: true
        contentWidth: panel.fittedContentWidth(1080)
        contentHeight: panel.fittedContentHeight(760)
        SidequestView {
            id: view
            anchors.fill: parent
            library: root.demo ? root.demoLibrary : Local.Library.library
            ready: root.demo || Local.Library.ready
            busy: !root.demo && Local.Library.busy
            error: !root.demo && Local.Library.error
            status: root.demo ? root.demoStatus : Local.Library.status
            demo: root.demo
            active: root.opened && !root.locked
            reducedMotion: root.reducedMotion
            onCloseRequested: root.close()
            onDemoRequested: root.toggleDemo()
            onRefreshRequested: if (!root.demo)
                Local.Library.request({
                    action: "scan"
                })
            else
                root.demoStatus = "Demo library ready."
            onSaveRequested: function (id, note, mood) {
                root.act({
                    action: "save",
                    id: id,
                    note: note,
                    mood: mood
                });
            }
            onFavoriteRequested: function (id) {
                root.act({
                    action: "favorite",
                    id: id
                });
            }
            onHideRequested: function (id) {
                root.act({
                    action: "hide",
                    id: id
                });
            }
            onLaunchRequested: function (id) {
                root.act({
                    action: "launch",
                    id: id
                });
            }
            onRollRequested: function (ids) {
                root.act({
                    action: "roll",
                    ids: ids
                });
            }
        }
    }
    IpcHandler {
        target: "sidequest"
        enabled: root.coordinator
        function state(): string {
            return JSON.stringify(root.activeInstance().state());
        }
        function allStates(): string {
            return JSON.stringify(root.instances().map(function (item) {
                return item.state();
            }));
        }
        function demo(): void {
            root.activeInstance().toggleDemo();
        }
        function roll(): void {
            var item = root.activeInstance();
            if (item.opened)
                item.act({
                    action: "roll",
                    ids: Model.filter(item.demo ? item.demoLibrary.games : Local.Library.library.games, "", "all").map(function (g) {
                        return g.id;
                    })
                });
        }
    }
}
