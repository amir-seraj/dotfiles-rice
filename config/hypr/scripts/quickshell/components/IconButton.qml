import QtQuick
import QtQuick.Layouts
import "../"

Rectangle {
    id: root

    property string icon: "󰅖"
    property string tooltip: ""
    property color accentColor: theme.text
    property color idleColor: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.06)
    property color hoverColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
    property bool enabled: true
    property bool checked: false

    signal clicked()

    implicitWidth: scaler.s(38)
    implicitHeight: scaler.s(38)
    radius: scaler.s(12)
    color: !root.enabled ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.46)
          : root.checked ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
          : hoverArea.containsMouse ? root.hoverColor : root.idleColor
    border.width: 1
    border.color: root.checked || hoverArea.containsMouse
                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.52)
                  : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.06)
    opacity: root.enabled ? 1.0 : 0.45

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width * 24 : 900
        currentHeight: root.height > 0 ? root.height * 18 : 700
    }

    MatugenColors { id: theme }

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.accentColor
        font.family: "Iosevka Nerd Font"
        font.pixelSize: scaler.s(16)
        font.bold: true
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
