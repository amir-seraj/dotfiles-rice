import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."
import "../"

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 900
    property real layoutHeight: 640
    property string title: "X Operator"
    property string subtitle: "Shared popup scaffold"
    property string icon: "󰣇"
    property color accentColor: theme.mauve
    property bool headerVisible: true
    property bool scrollable: true
    property int contentPadding: scaler.s(18)
    property alias headerActions: header.actions
    default property alias content: contentColumn.data

    signal closeRequested()
    signal refreshRequested()

    width: root.layoutWidth
    height: root.layoutHeight
    implicitWidth: root.layoutWidth
    implicitHeight: root.layoutHeight
    radius: scaler.s(20)
    color: theme.base
    border.width: 1
    border.color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.08)
    clip: true

    Scaler {
        id: scaler
        currentWidth: root.layoutWidth
        currentHeight: root.layoutHeight
    }

    MatugenColors { id: theme }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: scaler.s(1)
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
        radius: root.radius
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: scaler.s(3)
        color: root.accentColor
        opacity: 0.78
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PopupHeader {
            id: header
            visible: root.headerVisible
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerVisible ? scaler.s(76) : 0
            title: root.title
            subtitle: root.subtitle
            icon: root.icon
            accentColor: root.accentColor
            onCloseRequested: root.closeRequested()
            onRefreshRequested: root.refreshRequested()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: flickable
                anchors.fill: parent
                anchors.margins: root.contentPadding
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                interactive: root.scrollable && contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: root.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

                ColumnLayout {
                    id: contentColumn
                    width: flickable.width
                    spacing: scaler.s(12)
                }
            }
        }
    }
}
