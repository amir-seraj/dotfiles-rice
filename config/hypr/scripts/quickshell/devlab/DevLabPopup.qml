import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 960
    property real layoutHeight: 720

    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight
    radius: 20
    color: "#11111b"
    border.width: 1
    border.color: "#45475a"
    clip: true

    property var statusData: ({ git: {}, github: {}, privacy: {} })
    property string errorMsg: ""
    readonly property color fg: "#cdd6f4"
    readonly property color muted: "#a6adc8"
    readonly property color card: "#181825"
    readonly property color accent: "#a6e3a1"

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
    Timer { interval: 20000; running: true; repeat: true; onTriggered: root.refresh() }

    Process {
        id: statusProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/cockpit/hermes_cockpit_status.py", "devlab", "--print-json"]
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
            Text { text: "󰙨"; color: root.accent; font.family: "Iosevka Nerd Font"; font.pixelSize: 34 }
            Column {
                width: parent.width - 70
                spacing: 4
                Text { text: "Dev Lab"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 21; font.bold: true }
                Text { text: "Git/GitHub aggregate status — counts only, no filenames, patch text, branch names, issue titles, or repository remotes."; color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
            }
        }

        Grid {
            width: parent.width
            columns: 4
            spacing: 12
            Repeater {
                model: [
                    { label: "Changed files", value: root.value(["git", "changed_files"], 0) },
                    { label: "Staged", value: root.value(["git", "staged_files"], 0) },
                    { label: "Untracked", value: root.value(["git", "untracked_files"], 0) },
                    { label: "Dirty", value: root.value(["git", "dirty"], false) ? "yes" : "no" },
                    { label: "Ahead", value: root.value(["git", "ahead"], 0) },
                    { label: "Behind", value: root.value(["git", "behind"], 0) },
                    { label: "Open PRs", value: root.value(["github", "open_prs"], "—") },
                    { label: "Open issues", value: root.value(["github", "open_issues"], "—") }
                ]
                delegate: Rectangle {
                    width: (parent.width - 36) / 4
                    height: 92
                    radius: 14
                    color: root.card
                    border.width: 1
                    border.color: "#313244"
                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Text { text: modelData.value; color: root.accent; font.family: "JetBrains Mono"; font.pixelSize: 24; font.bold: true }
                        Text { text: modelData.label; color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 10; width: parent.width; wrapMode: Text.WordWrap }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 126
            radius: 16
            color: root.card
            border.width: 1
            border.color: "#313244"
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 9
                Text { text: "Repository status"; color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true }
                Text { text: "Repo present: " + (root.value(["git", "present"], false) ? "yes" : "no") + "  |  upstream: " + (root.value(["git", "upstream_present"], false) ? "yes" : "no") + "  |  GitHub CLI: " + root.value(["github", "status"], "unknown"); color: root.fg; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                Text { text: root.value(["safe_summary"], "Sanitized status cache."); color: root.muted; font.family: "JetBrains Mono"; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
            }
        }

        Text { visible: root.errorMsg.length > 0; text: root.errorMsg; color: "#f38ba8"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
        Text { text: "Updated: " + root.value(["updated_at"], "never") + "  |  privacy: " + (root.value(["privacy", "sanitized"], false) ? "sanitized" : "unknown"); color: "#6c7086"; font.family: "JetBrains Mono"; font.pixelSize: 10 }
    }
}
