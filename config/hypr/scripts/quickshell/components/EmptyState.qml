import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: root

    property string icon: "󰇘"
    property string title: "Nothing here"
    property string message: "No safe summary is available yet."
    property string actionLabel: ""
    property color accentColor: theme.mauve

    signal actionRequested()

    implicitWidth: scaler.s(280)
    implicitHeight: scaler.s(root.actionLabel.length > 0 ? 220 : 170)

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width * 3 : 900
        currentHeight: root.height > 0 ? root.height * 4 : 700
    }

    MatugenColors { id: theme }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, scaler.s(360))
        spacing: scaler.s(10)

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: scaler.s(58)
            Layout.preferredHeight: scaler.s(58)
            radius: scaler.s(19)
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.42)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.accentColor
                font.family: "Iosevka Nerd Font"
                font.pixelSize: scaler.s(24)
                font.bold: true
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: theme.text
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: "JetBrains Mono"
            font.pixelSize: scaler.s(15)
            font.weight: Font.Black
        }

        Text {
            Layout.fillWidth: true
            text: root.message
            color: theme.subtext0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.18
            font.family: "JetBrains Mono"
            font.pixelSize: scaler.s(11)
            font.bold: true
        }

        PillButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.actionLabel.length > 0
            label: root.actionLabel
            accentColor: root.accentColor
            onClicked: root.actionRequested()
        }
    }
}
