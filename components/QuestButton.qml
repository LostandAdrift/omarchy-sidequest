import QtQuick
import QtQuick.Controls.Basic
import "../Model.js" as Model

Button {
    id: root
    property bool primary: false
    property bool compact: false
    property color tint: Model.accent
    implicitHeight: compact ? 32 : 40
    implicitWidth: Math.max(compact ? 34 : 70, metrics.width + 30)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    leftPadding: 12
    rightPadding: 12
    contentItem: Text {
        id: label
        text: root.text
        textFormat: Text.PlainText
        color: root.enabled ? (root.primary ? Model.ink : root.tint) : Model.muted
        font.family: "monospace"
        font.pixelSize: root.compact ? 11 : 12
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        color: root.primary ? (root.down ? Qt.darker(root.tint, 1.2) : root.tint) : (root.hovered || root.down ? "#2a2e42" : "transparent")
        border.color: root.activeFocus ? Model.mint : (root.primary ? root.tint : Model.line)
        border.width: root.activeFocus ? 2 : 1
        radius: 4
        opacity: root.enabled ? 1 : 0.45
    }
    Accessible.name: text
    TextMetrics {
        id: metrics
        font: label.font
        text: root.text
    }
}
