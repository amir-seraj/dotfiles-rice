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

    property string ritualText: "Boot ritual not run yet."
    property bool running: false

    MatugenColors { id: theme }
    Scaler { id: scaler; currentWidth: root.width > 0 ? root.width : 760 }

    Process {
        id: ritualProc
        command: [Qt.resolvedUrl("../../boot-ritual.sh").toString().replace("file://", ""), "--dry-run"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.ritualText = this.text.trim().length > 0 ? this.text.trim() : "Boot ritual produced no output.";
                root.running = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0) root.ritualText += "\n\nERR: " + this.text.trim()
        }
    }

    function runDry() {
        if (root.running) return;
        root.running = true;
        root.ritualText = "Running dry-run boot ritual…";
        ritualProc.running = true;
    }

    Component.onCompleted: runDry()

    Rectangle {
        anchors.fill: parent
        radius: scaler.s(24)
        color: "#100719"
        border.width: 1
        border.color: "#cba6f7"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: scaler.s(24)
            spacing: scaler.s(16)

            RowLayout {
                Layout.fillWidth: true
                spacing: scaler.s(16)

                Components.XMascot {
                    Layout.preferredWidth: scaler.s(96)
                    Layout.preferredHeight: scaler.s(112)
                    mood: "focus"
                    caption: "BOOT"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Boot Ritual"
                        color: theme.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: scaler.s(30)
                        font.bold: true
                    }
                    Text {
                        text: "Dry-run local checklist. No sync, commit, push, reports, or messages."
                        color: theme.subtext0
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font.pixelSize: scaler.s(13)
                    }
                }

                Button {
                    text: root.running ? "Running" : "Run dry-run"
                    enabled: !root.running
                    onClicked: root.runDry()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: scaler.s(16)
                color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.78)
                border.width: 1
                border.color: Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.7)

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: scaler.s(16)
                    clip: true
                    TextArea {
                        text: root.ritualText
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        color: theme.text
                        selectedTextColor: theme.crust
                        selectionColor: theme.mauve
                        font.family: "JetBrains Mono"
                        font.pixelSize: scaler.s(12)
                        background: Rectangle { color: "transparent" }
                    }
                }
            }
        }
    }
}
