import QtQuick
import QtQuick.Layouts
import "../"

Rectangle {
    id: root

    property string label: "Action"
    property string icon: ""
    property color accentColor: theme.mauve
    property bool enabled: true
    property bool checked: false
    property bool compact: false

    signal clicked()

    implicitWidth: Math.max(labelText.implicitWidth + iconText.implicitWidth + scaler.s(root.icon.length > 0 ? 42 : 28), scaler.s(root.compact ? 76 : 104))
    implicitHeight: scaler.s(root.compact ? 32 : 40)
    radius: height / 2
    color: !root.enabled ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.50)
          : root.checked ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
          : hoverArea.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
          : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.82)
    border.width: 1
    border.color: root.checked || hoverArea.containsMouse
                  ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55)
                  : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.07)
    opacity: root.enabled ? 1.0 : 0.45

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width * 10 : 900
        currentHeight: root.height > 0 ? root.height * 18 : 700
    }

    MatugenColors { id: theme }

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.centerIn: parent
        spacing: scaler.s(7)

        Text {
            id: iconText
            visible: root.icon.length > 0
            text: root.icon
            color: root.accentColor
            font.family: "Iosevka Nerd Font"
            font.pixelSize: scaler.s(root.compact ? 12 : 14)
            font.bold: true
        }

        Text {
            id: labelText
            text: root.label
            color: root.checked ? root.accentColor : theme.text
            font.family: "JetBrains Mono"
            font.pixelSize: scaler.s(root.compact ? 10 : 12)
            font.bold: true
        }
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
