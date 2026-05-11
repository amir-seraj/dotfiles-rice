import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 900
    property real layoutHeight: 700

    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight
    radius: 20
    color: "#11111b"
    border.width: 1
    border.color: "#45475a"
    clip: true

    property var statusData: ({ counts: {}, privacy: {} })
    property string errorMsg: ""
    readonly property color fg: "#cdd6f4"
    readonly property color muted: "#a6adc8"
    readonly property color card: "#181825"
    readonly property color accent: "#89b4fa"

    function value(path, fallbackValue) {
        var cur = root.statusData;
        for (var i = 0; i < path.length; i++) {
            if (cur === undefined || cur === null || cur[path[i]] === undefined || cur[path[i]] === null)
                return fallbackValue;
            cur = cur[path[i]];
        }
        return cur;
    }

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
    }

    Component.onCompleted: refresh()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }

    Process {
        id: statusProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/cockpit/hermes_cockpit_status.py", "obsidian", "--print-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.statusData = JSON.parse(this.text);
                    root.errorMsg = "";
                } catch(e) {
                    root.errorMsg = "status parse failed";
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Row {
            width: parent.width
            spacing: 14
            Text { text: "󰠮"; color: root.accent; font.family: "Iosevka Nerd Font"; font.pixelSize: 34 }
            Column {
                width: parent.width - 70
                spacing: 4
                Text { text: "Obsidian cockpit"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 21; font.bold: true }
                Text { text: "Counts and safe links only — no note names or bodies."; color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
            }
        }

        Grid {
            width: parent.width
            columns: 3
            spacing: 12
            Repeater {
                model: [
                    { label: "Vault roots checked", value: root.value(["counts", "candidate_roots_checked"], 0) },
                    { label: "Markdown notes seen", value: root.value(["counts", "markdown_notes_seen"], 0) },
                    { label: "Recent note bodies", value: root.value(["counts", "recent_note_bodies_included"], 0) }
                ]
                delegate: Rectangle {
                    width: (parent.width - 24) / 3
                    height: 105
                    radius: 14
                    color: root.card
                    border.width: 1
                    border.color: "#313244"
                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        Text { text: modelData.value; color: root.accent; font.family: "JetBrains Mono"; font.pixelSize: 28; font.bold: true }
                        Text { text: modelData.label; color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 146
            radius: 16
            color: root.card
            border.width: 1
            border.color: "#313244"
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                Text { text: "Safe actions"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true }
                Text { text: "Open Obsidian app; cache contains aggregate metadata only."; color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap }
                Rectangle {
                    width: 178; height: 34; radius: 10; color: openHover.containsMouse ? "#313244" : "#1e1e2e"; border.width: 1; border.color: root.accent
                    Text { anchors.centerIn: parent; text: "Open Obsidian"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
                    MouseArea { id: openHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", "obsidian://open"]) }
                }
            }
        }

        Text { visible: root.errorMsg.length > 0; text: root.errorMsg; color: "#f38ba8"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
        Text { text: root.value(["safe_summary"], "Sanitized status cache."); color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
        Text { text: "Updated: " + root.value(["updated_at"], "never") + "  |  privacy: " + (root.value(["privacy", "sanitized"], false) ? "sanitized" : "unknown"); color: "#6c7086"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
    }
}
