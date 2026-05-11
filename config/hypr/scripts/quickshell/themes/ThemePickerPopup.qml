import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../components" as Components

Item {
    id: root

    property var notifModel: null
    property real layoutWidth: 860
    property real layoutHeight: 660

    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight

    property string selectedTheme: "noir-purple"
    property string selectedAura: selectedTheme
    property string statusText: "Choose an aura/theme. Apply writes local state only."
    property var choices: [
        { key: "noir-purple", label: "Noir Purple", mood: "idle", accent: "#cba6f7", note: "glass operator default" },
        { key: "matrix-green", label: "Matrix Green", mood: "agent_running", accent: "#a6e3a1", note: "code rain / agent active" },
        { key: "sentinel-olive", label: "Sentinel Olive", mood: "focus", accent: "#a6b37d", note: "watch floor / focus" },
        { key: "private-red", label: "Private Red", mood: "privacy", accent: "#f38ba8", note: "privacy lock-safe" },
        { key: "ocean-cyan", label: "Ocean Cyan", mood: "music", accent: "#94e2d5", note: "cool media / flow" }
    ]

    MatugenColors { id: theme }
    Scaler { id: scaler; currentWidth: root.width > 0 ? root.width : 820 }

    Process {
        id: auraProc
        command: [Qt.resolvedUrl("../../aura.sh").toString().replace("file://", ""), "--aura", root.selectedAura, "--theme", root.selectedTheme]
        running: false
        stdout: StdioCollector { onStreamFinished: root.statusText = this.text.trim() }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim().length > 0) root.statusText = this.text.trim() }
    }

    Rectangle {
        anchors.fill: parent
        radius: scaler.s(24)
        color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.95)
        border.width: 1
        border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: scaler.s(24)
            spacing: scaler.s(16)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Aura / Theme Engine"
                    color: theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: scaler.s(28)
                    font.bold: true
                }
                Button {
                    text: "Apply local"
                    onClicked: {
                        root.statusText = "Applying " + root.selectedTheme + "…";
                        auraProc.running = true;
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 5
                rowSpacing: scaler.s(12)
                columnSpacing: scaler.s(12)

                Repeater {
                    model: root.choices
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: scaler.s(230)
                        radius: scaler.s(18)
                        color: root.selectedTheme === modelData.key ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.98) : Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.72)
                        border.width: root.selectedTheme === modelData.key ? 2 : 1
                        border.color: modelData.accent

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.selectedTheme = modelData.key;
                                root.selectedAura = modelData.key;
                                root.statusText = "Selected " + modelData.label;
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: scaler.s(12)
                            spacing: scaler.s(8)

                            Components.XMascot {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: scaler.s(92)
                                Layout.preferredHeight: scaler.s(112)
                                mood: modelData.mood
                                caption: modelData.key === "private-red" ? "PRIVATE" : "X"
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: theme.text
                                horizontalAlignment: Text.AlignHCenter
                                font.family: "JetBrains Mono"
                                font.bold: true
                                font.pixelSize: scaler.s(14)
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.note
                                color: theme.subtext0
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: scaler.s(11)
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: scaler.s(54)
                radius: scaler.s(14)
                color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.65)
                border.width: 1
                border.color: Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.65)
                Text {
                    anchors.centerIn: parent
                    width: parent.width - scaler.s(24)
                    text: root.statusText
                    color: theme.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.family: "JetBrains Mono"
                    font.pixelSize: scaler.s(12)
                }
            }
        }
    }
}
