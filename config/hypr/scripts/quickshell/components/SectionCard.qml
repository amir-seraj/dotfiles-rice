import QtQuick
import QtQuick.Layouts
import "../"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property color accentColor: theme.mauve
    property int padding: scaler.s(14)
    property bool elevated: false
    default property alias content: bodyColumn.data

    implicitWidth: scaler.s(260)
    implicitHeight: Math.max(bodyColumn.implicitHeight + root.padding * 2, scaler.s(104))
    radius: scaler.s(16)
    color: root.elevated ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.92)
                         : Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.58)
    border.width: 1
    border.color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.07)
    clip: true

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width * 4 : 900
        currentHeight: root.height > 0 ? root.height * 7 : 700
    }

    MatugenColors { id: theme }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: scaler.s(3)
        color: root.accentColor
        opacity: 0.70
    }

    ColumnLayout {
        id: bodyColumn
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: scaler.s(9)

        RowLayout {
            Layout.fillWidth: true
            visible: root.title.length > 0 || root.subtitle.length > 0 || root.icon.length > 0
            spacing: scaler.s(8)

            Text {
                visible: root.icon.length > 0
                text: root.icon
                color: root.accentColor
                font.family: "Iosevka Nerd Font"
                font.pixelSize: scaler.s(16)
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: scaler.s(1)

                Text {
                    Layout.fillWidth: true
                    visible: root.title.length > 0
                    text: root.title
                    color: theme.text
                    elide: Text.ElideRight
                    font.family: "JetBrains Mono"
                    font.pixelSize: scaler.s(13)
                    font.weight: Font.Black
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    color: theme.subtext0
                    elide: Text.ElideRight
                    font.family: "JetBrains Mono"
                    font.pixelSize: scaler.s(10)
                    font.bold: true
                }
            }
        }
    }
}
