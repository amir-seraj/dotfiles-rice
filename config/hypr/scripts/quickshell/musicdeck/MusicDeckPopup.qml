import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 820
    property real layoutHeight: 660

    property var payload: ({ playback: { available: false, status: "stopped", player: "unknown", track: "REDACTED", artist: "REDACTED" }, privacy: { sanitized: true }, safe_summary: "Loading..." })
    property string errorMsg: ""

    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight
    radius: 24
    color: "#100719"
    border.width: 1
    border.color: "#89dceb"
    clip: true

    function safe(obj, key, fallback) {
        try { return obj && obj[key] !== undefined && obj[key] !== null ? obj[key] : fallback; }
        catch(e) { return fallback; }
    }

    function playback() { return root.safe(root.payload, "playback", {}); }

    function refresh() {
        musicProc.running = false;
        musicProc.running = true;
    }

    function playerctl(action) {
        Quickshell.execDetached(["playerctl", action]);
        refreshTimer.restart();
    }

    Component.onCompleted: refresh()
    Timer { id: refreshTimer; interval: 800; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 15000; repeat: true; running: true; onTriggered: root.refresh() }

    Process {
        id: musicProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/cockpit/hermes_cockpit_status.py", "music", "--print-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.payload = JSON.parse(this.text || "{}");
                    root.errorMsg = "";
                } catch(e) {
                    root.errorMsg = "music parse failed";
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#100719" }
            GradientStop { position: 1.0; color: "#10232c" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰝚"; color: "#89dceb"; font.pixelSize: 32; Layout.preferredWidth: 44 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "MUSIC DECK"; color: "#f5e9ff"; font.family: "JetBrains Mono"; font.pixelSize: 23; font.bold: true }
                Text { text: "Playback controls with redacted title, artist, album, artwork URLs, and file paths."; color: "#a99ab8"; font.family: "JetBrains Mono"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            Rectangle {
                width: 86; height: 34; radius: 12; color: "#10232c"; border.width: 1; border.color: "#89dceb"
                Text { anchors.centerIn: parent; text: "refresh"; color: "#89dceb"; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 22
            color: "#1a1024"
            border.width: 1
            border.color: "#245463"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8
                Text { text: root.safe(root.playback(), "status", "stopped").toUpperCase(); color: "#89dceb"; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
                Text { text: "TRACK REDACTED"; color: "#f5e9ff"; font.family: "JetBrains Mono"; font.pixelSize: 28; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: "artist: REDACTED · player: " + root.safe(root.playback(), "player", "unknown"); color: "#a99ab8"; font.family: "JetBrains Mono"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: root.safe(root.payload, "safe_summary", "Music metadata redacted."); color: "#c9f3ff"; font.family: "JetBrains Mono"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            DeckButton { label: "󰒮"; action: "previous" }
            DeckButton { label: root.safe(root.playback(), "status", "stopped") === "Playing" ? "󰏤" : "󰐊"; action: "play-pause"; wide: true }
            DeckButton { label: "󰒭"; action: "next" }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            radius: 16
            color: "#1a1024"
            border.width: 1
            border.color: "#34203f"
            Text {
                anchors.fill: parent
                anchors.margins: 16
                text: "privacy.sanitized=" + root.safe(root.safe(root.payload, "privacy", {}), "sanitized", true) + " · raw_content_included=" + root.safe(root.safe(root.payload, "privacy", {}), "raw_content_included", false) + " · title/artist always shown as REDACTED"
                color: "#a99ab8"
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Text { text: root.errorMsg; visible: root.errorMsg !== ""; color: "#f38ba8"; font.family: "JetBrains Mono"; font.pixelSize: 11; Layout.fillWidth: true }
    }

    component DeckButton: Rectangle {
        property string label: ""
        property string action: "play-pause"
        property bool wide: false
        Layout.preferredWidth: wide ? 92 : 64
        Layout.preferredHeight: 52
        radius: 18
        color: "#14313b"
        border.width: 1
        border.color: "#89dceb"
        Text { anchors.centerIn: parent; text: label; color: "#f5e9ff"; font.pixelSize: 22 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playerctl(action) }
    }
}
