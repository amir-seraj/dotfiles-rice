import QtQuick
import QtQuick.Layouts
import "../"

Rectangle {
    id: root

    property string title: "X Operator"
    property string subtitle: ""
    property string icon: "󰣇"
    property color accentColor: theme.mauve
    property bool showDivider: true
    default property alias actions: actionRow.data

    signal closeRequested()
    signal refreshRequested()

    implicitHeight: scaler.s(72)
    color: "transparent"

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width : 900
        currentHeight: root.height > 0 ? root.height : 700
    }

    MatugenColors { id: theme }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: scaler.s(18)
        anchors.rightMargin: scaler.s(18)
        spacing: scaler.s(12)

        Rectangle {
            Layout.preferredWidth: scaler.s(44)
            Layout.preferredHeight: scaler.s(44)
            radius: scaler.s(14)
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.44)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.accentColor
                font.family: "Iosevka Nerd Font"
                font.pixelSize: scaler.s(20)
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: scaler.s(2)

            Text {
                Layout.fillWidth: true
                text: root.title
                color: theme.text
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: scaler.s(18)
                font.weight: Font.Black
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: theme.subtext0
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: scaler.s(11)
                font.bold: true
            }
        }

        RowLayout {
            id: actionRow
            spacing: scaler.s(8)
        }
    }

    Rectangle {
        visible: root.showDivider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.06)
    }
}
