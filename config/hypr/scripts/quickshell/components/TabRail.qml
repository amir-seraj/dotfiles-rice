import QtQuick
import QtQuick.Layouts
import "../"

Rectangle {
    id: root

    property var tabs: []
    property string currentTab: tabs.length > 0 ? (tabs[0].id || tabs[0].key || "") : ""
    property color accentColor: theme.mauve
    property bool compact: false

    signal tabSelected(string tabId)

    implicitWidth: scaler.s(root.compact ? 54 : 178)
    implicitHeight: tabColumn.implicitHeight + scaler.s(16)
    radius: scaler.s(16)
    color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.58)
    border.width: 1
    border.color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.06)

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width * 7 : 900
        currentHeight: root.height > 0 ? root.height * 8 : 700
    }

    MatugenColors { id: theme }

    ColumnLayout {
        id: tabColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: scaler.s(8)
        spacing: scaler.s(5)

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: tabItem

                readonly property string tabId: modelData.id || modelData.key || ""
                readonly property bool active: root.currentTab === tabItem.tabId

                Layout.fillWidth: true
                Layout.preferredHeight: scaler.s(root.compact ? 38 : 36)
                radius: scaler.s(11)
                color: tabItem.active ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
                      : hoverArea.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.06)
                      : "transparent"
                border.width: tabItem.active ? 1 : 0
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.40)

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: scaler.s(10)
                    anchors.rightMargin: scaler.s(10)
                    spacing: scaler.s(8)

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: modelData.icon || ""
                        color: tabItem.active ? root.accentColor : theme.subtext0
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: scaler.s(14)
                        font.bold: true
                        visible: text.length > 0
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: !root.compact
                        text: modelData.label || modelData.title || tabItem.tabId
                        color: tabItem.active ? theme.text : theme.subtext0
                        elide: Text.ElideRight
                        font.family: "JetBrains Mono"
                        font.pixelSize: scaler.s(11)
                        font.bold: tabItem.active
                    }

                    Rectangle {
                        visible: !root.compact && modelData.badge !== undefined && modelData.badge >= 0
                        Layout.preferredWidth: badgeLabel.implicitWidth + scaler.s(10)
                        Layout.preferredHeight: scaler.s(18)
                        radius: scaler.s(9)
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)

                        Text {
                            id: badgeLabel
                            anchors.centerIn: parent
                            text: modelData.badge !== undefined ? modelData.badge : ""
                            color: root.accentColor
                            font.family: "JetBrains Mono"
                            font.pixelSize: scaler.s(9)
                            font.bold: true
                        }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentTab = tabItem.tabId;
                        root.tabSelected(tabItem.tabId);
                    }
                }
            }
        }
    }
}
