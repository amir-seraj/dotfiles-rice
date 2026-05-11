import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 1180
    property real layoutHeight: 760
    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight

    property var statePayload: ({ mode: "normal", privacy: false, activeWorkspace: 1, aura: "calm", theme: "noir-purple" })
    property var systemPayload: ({ resources: { cpu_percent: 0, mem_percent: 0, disk_root_percent: 0 }, services: {}, alerts: [] })
    property var healthPayload: ({ move_timer: { label: "--:--", mode: "focus", cycles: 0 }, focus: { today_seconds: 0 }, alerts: [] })
    property var agentsPayload: ({ active: [], recent: [], ingestor: {}, alerts: [] })
    property var obsidianPayload: ({ today_note: {}, cockpit: {}, alerts: [] })
    property var musicPayload: ({ status: "Offline", track_label: "Hidden", privacy: { redacted: true } })
    property var sentinelPayload: ({ enabled: false, mode: "off", alerts: [] })
    property var ritualPayload: ({ active: false, mode: "off", steps: [] })
    property string errorMsg: ""
    property int activeTab: 0

    readonly property color bg: "#100719"
    readonly property color card: "#1a1024"
    readonly property color card2: "#21132d"
    readonly property color textColor: "#f5e9ff"
    readonly property color muted: "#a99ab8"
    readonly property color accent: statePayload.privacy ? "#f38ba8" : "#cba6f7"

    color: bg
    radius: 24
    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
    clip: true

    function safe(obj, key, fallback) {
        try { return obj && obj[key] !== undefined && obj[key] !== null ? obj[key] : fallback; }
        catch(e) { return fallback; }
    }

    function readJson(path, assignName) {
        reader.command = ["bash", "-lc", "test -f " + path + " && cat " + path + " || printf '{}'" ];
        reader.assignName = assignName;
        reader.running = false;
        reader.running = true;
    }

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
        readJson((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr-rice/state.json", "state");
    }

    function loadCache() {
        var home = Quickshell.env("HOME");
        readJson(home + "/.cache/hermes-cockpit/system.json", "system");
        readJson(home + "/.cache/hermes-cockpit/health.json", "health");
        readJson(home + "/.cache/hermes-cockpit/agents.json", "agents");
        readJson(home + "/.cache/hermes-cockpit/obsidian.json", "obsidian");
        readJson(home + "/.cache/hermes-cockpit/music.json", "music");
        readJson(home + "/.cache/hermes-cockpit/sentinel.json", "sentinel");
        readJson(home + "/.cache/hermes-cockpit/ritual.json", "ritual");
    }

    Component.onCompleted: refresh()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: refresh() }

    Process {
        id: statusProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/cockpit/hermes_cockpit_status.py", "all"]
        stdout: StdioCollector { onStreamFinished: { root.errorMsg = ""; root.loadCache(); } }
    }

    Process {
        id: reader
        property string assignName: ""
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(this.text || "{}");
                    if (reader.assignName === "state") root.statePayload = obj;
                    else if (reader.assignName === "system") root.systemPayload = obj;
                    else if (reader.assignName === "health") root.healthPayload = obj;
                    else if (reader.assignName === "agents") root.agentsPayload = obj;
                    else if (reader.assignName === "obsidian") root.obsidianPayload = obj;
                    else if (reader.assignName === "music") root.musicPayload = obj;
                    else if (reader.assignName === "sentinel") root.sentinelPayload = obj;
                    else if (reader.assignName === "ritual") root.ritualPayload = obj;
                } catch(e) { root.errorMsg = "cache parse: " + e; }
            }
        }
    }

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 4; color: accent; opacity: 0.9 }

    Text {
        x: 34; y: 26
        text: "X COMMAND DECK"
        color: textColor
        font.family: "JetBrains Mono"
        font.pixelSize: 26
        font.weight: Font.Black
    }

    Text {
        x: 36; y: 62
        text: "mode=" + safe(statePayload, "mode", "normal") + "  privacy=" + safe(statePayload, "privacy", false) + "  ws=" + safe(statePayload, "activeWorkspace", 1) + "  aura=" + safe(statePayload, "aura", "calm")
        color: muted
        font.family: "JetBrains Mono"
        font.pixelSize: 12
        font.bold: true
    }

    Rectangle {
        x: parent.width - 200; y: 28; width: 160; height: 34; radius: 12
        color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
        Text { anchors.centerIn: parent; text: statePayload.privacy ? "󰌾 PRIVATE" : "󰗹 OPERATOR"; color: accent; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
    }

    Row {
        x: 34; y: 108; spacing: 10
        Repeater {
            model: ["Overview", "Work", "Health", "Agents", "System", "Music", "Ritual"]
            delegate: Rectangle {
                width: 120; height: 34; radius: 12
                color: root.activeTab === index ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20) : "#1b1024"
                border.width: 1
                border.color: root.activeTab === index ? root.accent : "#34203f"
                Text { anchors.centerIn: parent; text: modelData; color: root.activeTab === index ? root.accent : root.muted; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = index }
            }
        }
    }

    Grid {
        x: 34; y: 166
        columns: 3
        spacing: 16

        MetricCard { title: "SYSTEM"; value: Math.round(root.safe(root.safe(root.systemPayload, "resources", {}), "cpu_percent", 0)) + "% cpu"; detail: "ram " + Math.round(root.safe(root.safe(root.systemPayload, "resources", {}), "mem_percent", 0)) + "%  disk " + Math.round(root.safe(root.safe(root.systemPayload, "resources", {}), "disk_root_percent", 0)) + "%"; accentColor: "#89b4fa" }
        MetricCard { title: "SPINE"; value: root.safe(root.safe(root.healthPayload, "move_timer", {}), "label", "--:--"); detail: root.safe(root.safe(root.healthPayload, "move_timer", {}), "mode", "focus") + "  cycles " + root.safe(root.safe(root.healthPayload, "move_timer", {}), "cycles", 0); accentColor: "#a6e3a1" }
        MetricCard { title: "AGENTS"; value: root.safe(root.safe(root.agentsPayload, "active", []), "length", 0) + " active"; detail: root.safe(root.safe(root.agentsPayload, "recent", []), "length", 0) + " recent sessions"; accentColor: "#cba6f7" }
        MetricCard { title: "OBSIDIAN"; value: root.safe(root.safe(root.obsidianPayload, "cockpit", {}), "projects", 0) + " projects"; detail: "daily exists: " + root.safe(root.safe(root.obsidianPayload, "today_note", {}), "exists", false); accentColor: "#f9e2af" }
        MetricCard { title: "MUSIC"; value: root.safe(root.musicPayload, "status", "Offline"); detail: root.safe(root.musicPayload, "track_label", "Hidden"); accentColor: "#89dceb" }
        MetricCard { title: "SENTINEL"; value: root.safe(root.sentinelPayload, "mode", "off"); detail: "enabled: " + root.safe(root.sentinelPayload, "enabled", false); accentColor: "#94e2d5" }
    }

    Rectangle {
        x: 34; y: 584; width: parent.width - 68; height: 104; radius: 18
        color: card
        border.width: 1
        border.color: "#34203f"
        Text {
            anchors.fill: parent
            anchors.margins: 20
            text: "Actions wired next: Work Mode · Privacy Mode · Capture Note · Work Report · Open Project · AI Handoff\nFoundation online: sanitized cockpit cache + Quickshell command deck route. No raw private text is rendered here."
            color: textColor
            wrapMode: Text.WordWrap
            font.family: "JetBrains Mono"
            font.pixelSize: 14
            lineHeight: 1.2
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        text: errorMsg
        visible: errorMsg !== ""
        color: "#f38ba8"
        font.family: "JetBrains Mono"
        font.pixelSize: 10
    }

    component MetricCard: Rectangle {
        property string title: ""
        property string value: ""
        property string detail: ""
        property color accentColor: "#cba6f7"
        width: 354; height: 126; radius: 18
        color: root.card
        border.width: 1
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
        Rectangle { x: 18; y: 18; width: 10; height: parent.height - 36; radius: 5; color: accentColor; opacity: 0.75 }
        Text { x: 42; y: 20; text: title; color: accentColor; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
        Text { x: 42; y: 48; width: parent.width - 62; text: value; color: root.textColor; elide: Text.ElideRight; font.family: "JetBrains Mono"; font.pixelSize: 24; font.weight: Font.Black }
        Text { x: 42; y: 86; width: parent.width - 62; text: detail; color: root.muted; elide: Text.ElideRight; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
    }
}
