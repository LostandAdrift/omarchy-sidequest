import QtQuick
import "../Model.js" as Model

Item {
    id: root
    property string gameId: "700001"
    property string title: "Starfall"
    property string cover: ""
    property bool miniature: false
    readonly property var artColors: Model.colors(gameId)
    clip: true
    Rectangle {
        anchors.fill: parent
        color: root.artColors[0]
    }
    Canvas {
        id: art
        anchors.fill: parent
        onPaint: {
            var c = getContext("2d"), w = width, h = height, seed = Model.hash(root.gameId), p = root.artColors;
            c.reset();
            c.fillStyle = p[0];
            c.fillRect(0, 0, w, h);
            function rand() {
                seed = (seed * 1664525 + 1013904223) >>> 0;
                return seed / 4294967296;
            }
            var unit = root.miniature ? 2 : 3;
            for (var i = 0; i < 55; i++) {
                var x = Math.floor(rand() * w / unit) * unit, y = Math.floor(rand() * h * .7 / unit) * unit;
                c.fillStyle = i % 5 === 0 ? p[2] : p[1];
                c.globalAlpha = .35 + rand() * .5;
                c.fillRect(x, y, unit, unit);
            }
            c.globalAlpha = 1;
            var moonX = w * .72, moonY = h * .3, r = Math.min(w, h) * .18;
            c.fillStyle = p[2];
            c.beginPath();
            c.arc(moonX, moonY, r, 0, Math.PI * 2);
            c.fill();
            c.fillStyle = p[0];
            c.beginPath();
            c.arc(moonX + r * .38, moonY - r * .2, r * .9, 0, Math.PI * 2);
            c.fill();
            for (var layer = 0; layer < 3; layer++) {
                c.fillStyle = [p[1], Qt.darker(p[1], 1.6).toString(), "#111622"][layer];
                c.beginPath();
                c.moveTo(0, h);
                for (var t = 0; t <= 10; t++) {
                    var xx = t * w / 10, yy = h * (.52 + layer * .13) - rand() * h * .17;
                    c.lineTo(xx, yy);
                }
                c.lineTo(w, h);
                c.closePath();
                c.fill();
            }
            // A tiny, original save-point sword on the foreground ridge.
            var sx = Math.floor(w * .28), sy = Math.floor(h * .78), u = Math.max(2, Math.floor(Math.min(w, h) / 42));
            c.fillStyle = p[2];
            c.fillRect(sx - u, sy - 10 * u, 2 * u, 10 * u);
            c.fillStyle = Model.gold;
            c.fillRect(sx - 4 * u, sy - 3 * u, 8 * u, u);
            c.fillRect(sx - u, sy - 2 * u, 2 * u, 4 * u);
            c.fillStyle = "#0c111a";
            c.fillRect(sx - 5 * u, sy + 2 * u, 10 * u, 2 * u);
        }
        Connections {
            target: root
            function onGameIdChanged() {
                art.requestPaint();
            }
            function onMiniatureChanged() {
                art.requestPaint();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    Image {
        id: coverImage
        anchors.fill: parent
        source: root.cover
        sourceSize.width: root.miniature ? 120 : 600
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#0010131d"
            }
            GradientStop {
                position: .6
                color: "#1010131d"
            }
            GradientStop {
                position: 1
                color: "#e610131d"
            }
        }
        visible: !root.miniature
    }
    Text {
        visible: root.miniature && !coverImage.visible
        anchors.centerIn: parent
        text: Model.initials(root.title)
        textFormat: Text.PlainText
        font.family: "monospace"
        font.pixelSize: 15
        font.bold: true
        color: Model.text
    }
}
