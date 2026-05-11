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
    readonly property color accent: "#cba6f7"

    function value(path, fallbackValue) {
        var cur = root.statusData;
        for (var i = 0; i < path.length; i++) {
            if (cur === undefined || cur === null || cur[path[i]] === undefined || cur[path[i]] === null)
                return fallbackValue;
            cur = cur[path[i]];
        }
        return cur;
    }

    function refresh() { statusProc.running = false; statusProc.running = true; }

    Component.onCompleted: refresh()
    Timer { interval: 15000; running: true; repeat: true; onTriggered: root.refresh() }

    Process {
        id: statusProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/cockpit/hermes_cockpit_status.py", "agents", "--print-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.statusData = JSON.parse(this.text); root.errorMsg = ""; }
                catch(e) { root.errorMsg = "status parse failed"; }
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
            Text { text: "󰚩"; color: root.accent; font.family: "Iosevka Nerd Font"; font.pixelSize: 34 }
            Column {
                width: parent.width - 70
                spacing: 4
                Text { text: "Agent HUD"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 21; font.bold: true }
                Text { text: "Agent/project/status/counts only — no prompts, transcripts, arguments, or client text."; color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
            }
        }

        Grid {
            width: parent.width
            columns: 3
            spacing: 12
            Repeater {
                model: [
                    { label: "Matching agent processes", value: root.value(["counts", "matching_processes"], 0) },
                    { label: "Known safe commands", value: root.value(["counts", "safe_command_kinds"], 0) },
                    { label: "Active", value: root.value(["active"], false) ? "yes" : "no" }
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
            height: 164
            radius: 16
            color: root.card
            border.width: 1
            border.color: "#313244"
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 9
                Text { text: "Safe status"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true }
                Text { text: "Process scan uses command names only. Full command lines, session files, prompts, transcript text, and raw client text are never emitted."; color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap }
                Text { text: "Project status: " + root.value(["project", "status"], "unknown") + "  |  project count: " + root.value(["project", "known_count"], 0); color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                Text { text: "Cache health: " + root.value(["cache", "status"], "unknown"); color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 12 }
            }
        }

        Text { visible: root.errorMsg.length > 0; text: root.errorMsg; color: "#f38ba8"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
        Text { text: root.value(["safe_summary"], "Sanitized status cache."); color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
        Text { text: "Updated: " + root.value(["updated_at"], "never") + "  |  privacy: " + (root.value(["privacy", "sanitized"], false) ? "sanitized" : "unknown"); color: "#6c7086"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
    }
}
