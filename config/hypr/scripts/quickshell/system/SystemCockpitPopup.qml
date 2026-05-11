import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 900
    property real layoutHeight: 700

    property var payload: ({ metrics: {}, privacy: { sanitized: true }, safe_summary: "Loading..." })
    property string errorMsg: ""

    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight
    radius: 22
    color: "#100719"
    border.width: 1
    border.color: "#89b4fa"
    clip: true

    function safe(obj, key, fallback) {
        try { return obj && obj[key] !== undefined && obj[key] !== null ? obj[key] : fallback; }
        catch(e) { return fallback; }
    }

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
    }

    Component.onCompleted: refresh()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: refresh() }

    Process {
        id: statusProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/cockpit/hermes_cockpit_status.py", "system", "--print-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.payload = JSON.parse(this.text || "{}");
                    root.errorMsg = "";
                } catch(e) {
                    root.errorMsg = "system parse failed";
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰍛"; color: "#89b4fa"; font.pixelSize: 28; Layout.preferredWidth: 40 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "SYSTEM COCKPIT"; color: "#f5e9ff"; font.family: "JetBrains Mono"; font.pixelSize: 22; font.bold: true }
                Text { text: "Sanitized resources and service health. No IP addresses, process args, paths, or active window titles."; color: "#a99ab8"; font.family: "JetBrains Mono"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            Rectangle {
                width: 86; height: 34; radius: 12; color: "#172033"; border.width: 1; border.color: "#89b4fa"
                Text { anchors.centerIn: parent; text: "refresh"; color: "#89b4fa"; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 12
            columnSpacing: 12

            MetricCard { title: "CPU"; value: root.safe(root.safe(root.payload, "metrics", {}), "cpu_percent", "--") + "%"; detail: "aggregate utilization"; accentColor: "#89b4fa" }
            MetricCard { title: "MEMORY"; value: root.safe(root.safe(root.payload, "metrics", {}), "memory_percent", "--") + "%"; detail: "used memory"; accentColor: "#a6e3a1" }
            MetricCard { title: "HOME DISK"; value: root.safe(root.safe(root.payload, "metrics", {}), "home_disk_percent", "--") + "%"; detail: "coarse usage only"; accentColor: "#f9e2af" }
            MetricCard { title: "LOAD"; value: root.safe(root.safe(root.safe(root.payload, "metrics", {}), "load", {}), "one", "--"); detail: "1m average"; accentColor: "#cba6f7" }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            radius: 16
            color: "#1a1024"
            border.width: 1
            border.color: "#34203f"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                Text { text: "PRIVACY GUARD"; color: "#89b4fa"; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
                Text { text: root.safe(root.payload, "safe_summary", "Sanitized output only."); color: "#f5e9ff"; font.family: "JetBrains Mono"; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Text { text: "raw_content_included=" + root.safe(root.safe(root.payload, "privacy", {}), "raw_content_included", false) + " · redaction=" + root.safe(root.safe(root.payload, "privacy", {}), "redaction", "fail-closed"); color: "#a99ab8"; font.family: "JetBrains Mono"; font.pixelSize: 11; Layout.fillWidth: true }
            }
        }

        Text { text: root.errorMsg; visible: root.errorMsg !== ""; color: "#f38ba8"; font.family: "JetBrains Mono"; font.pixelSize: 11; Layout.fillWidth: true }
    }

    component MetricCard: Rectangle {
        property string title: ""
        property string value: ""
        property string detail: ""
        property color accentColor: "#89b4fa"
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        radius: 16
        color: "#1a1024"
        border.width: 1
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.42)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6
            Text { text: title; color: accentColor; font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true }
            Text { text: value; color: "#f5e9ff"; font.family: "JetBrains Mono"; font.pixelSize: 28; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: detail; color: "#a99ab8"; font.family: "JetBrains Mono"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
}
