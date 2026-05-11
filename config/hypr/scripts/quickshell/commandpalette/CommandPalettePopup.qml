import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../components"

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 900
    property real layoutHeight: 720

    property var allItems: []
    property string query: ""
    property string errorMsg: ""

    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight
    radius: 22
    color: "#100719"
    border.width: 1
    border.color: "#6f4ca2"
    clip: true
    focus: true

    function safe(value, fallback) {
        return value === undefined || value === null || value === "" ? fallback : value;
    }

    function refresh() {
        paletteProc.running = false;
        paletteProc.running = true;
    }

    function filter() {
        var q = root.query.toLowerCase();
        paletteModel.clear();
        for (var i = 0; i < root.allItems.length && paletteModel.count < 80; i++) {
            var row = root.allItems[i];
            var hay = (row.label + " " + row.kind + " " + row.subtitle + " " + (row.keywords || []).join(" ")).toLowerCase();
            if (q === "" || hay.indexOf(q) >= 0) {
                paletteModel.append({
                    itemId: row.id || "item",
                    kind: row.kind || "command",
                    label: row.label || "Unnamed",
                    subtitle: row.subtitle || "",
                    commandJson: JSON.stringify(row.command || [])
                });
            }
        }
        list.currentIndex = paletteModel.count > 0 ? 0 : -1;
    }

    function launchCurrent() {
        if (list.currentIndex < 0 || list.currentIndex >= paletteModel.count)
            return;
        var row = paletteModel.get(list.currentIndex);
        try {
            var argv = JSON.parse(row.commandJson);
            if (argv.length === 0)
                return;
            Quickshell.execDetached(argv);
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        } catch(e) {
            root.errorMsg = "launch parse failed";
        }
    }

    Component.onCompleted: refresh()

    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        event.accepted = true;
    }
    Keys.onReturnPressed: { launchCurrent(); event.accepted = true; }
    Keys.onEnterPressed: { launchCurrent(); event.accepted = true; }
    Keys.onUpPressed: { list.currentIndex = Math.max(0, list.currentIndex - 1); event.accepted = true; }
    Keys.onDownPressed: { list.currentIndex = Math.min(paletteModel.count - 1, list.currentIndex + 1); event.accepted = true; }

    ListModel { id: paletteModel }

    Process {
        id: paletteProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/commandpalette/command_palette.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var payload = JSON.parse(this.text || "{}");
                    root.allItems = payload.items || [];
                    root.errorMsg = "";
                    root.filter();
                } catch(e) {
                    root.errorMsg = "palette parse failed";
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text { text: "󰘳"; color: "#cba6f7"; font.pixelSize: 28 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "COMMAND PALETTE"; color: "#f5e9ff"; font.family: "JetBrains Mono"; font.pixelSize: 22; font.bold: true }
                Text { text: "Apps · safe rice scripts · project terminals. Secrets, args history, IPs, and file contents are never indexed."; color: "#a99ab8"; font.family: "JetBrains Mono"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            Rectangle {
                width: 86; height: 34; radius: 12; color: "#21132d"; border.width: 1; border.color: "#6f4ca2"
                Text { anchors.centerIn: parent; text: "refresh"; color: "#cba6f7"; font.family: "JetBrains Mono"; font.pixelSize: 11; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 16
            color: "#1a1024"
            border.width: 1
            border.color: search.activeFocus ? "#cba6f7" : "#34203f"
            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                color: "#f5e9ff"
                selectionColor: "#6f4ca2"
                font.family: "JetBrains Mono"
                font.pixelSize: 18
                text: root.query
                onTextChanged: { root.query = text; root.filter(); }
                Keys.forwardTo: [root]
            }
            Text { anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter; visible: search.text.length === 0; text: "search commands..."; color: "#6f6178"; font.family: "JetBrains Mono"; font.pixelSize: 16 }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: paletteModel
            clip: true
            spacing: 8
            delegate: Rectangle {
                required property int index
                required property string kind
                required property string label
                required property string subtitle
                width: list.width
                height: 58
                radius: 14
                color: ListView.isCurrentItem ? "#2a1840" : "#1a1024"
                border.width: 1
                border.color: ListView.isCurrentItem ? "#cba6f7" : "#34203f"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    Text { text: kind === "app" ? "󰀻" : kind === "project" ? "󰈙" : kind === "terminal" ? "" : "󰘳"; color: "#cba6f7"; font.pixelSize: 18; Layout.preferredWidth: 26 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: label; color: "#f5e9ff"; font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: kind + (subtitle ? " · " + subtitle : ""); color: "#a99ab8"; font.family: "JetBrains Mono"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { list.currentIndex = index; root.launchCurrent(); } }
            }
        }

        Text { text: root.errorMsg; visible: root.errorMsg !== ""; color: "#f38ba8"; font.family: "JetBrains Mono"; font.pixelSize: 11; Layout.fillWidth: true }
    }
}
