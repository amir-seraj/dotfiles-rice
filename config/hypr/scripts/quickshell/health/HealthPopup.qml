import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var notifModel: null
    property real layoutWidth: 560
    property real layoutHeight: 620
    width: layoutWidth
    height: layoutHeight
    implicitWidth: layoutWidth
    implicitHeight: layoutHeight

    property var healthData: ({ movement: {}, focus: {}, spine: {}, privacy: {} })
    property string errorMsg: ""
    readonly property var movement: healthData.movement || ({})
    readonly property var focusStats: healthData.focus || ({})

    color: "#12051c"
    radius: 20
    border.width: 1
    border.color: "#4b2b61"
    clip: true

    function refresh() {
        healthProc.running = false;
        healthProc.running = true;
    }

    function movementAction(action) {
        moveProc.command = ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/movetimer/move_timer.py", action];
        moveProc.running = false;
        moveProc.running = true;
    }

    Component.onCompleted: refresh()
    Timer { interval: 5000; repeat: true; running: true; onTriggered: refresh() }

    Process {
        id: healthProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/cockpit/hermes_cockpit_status.py", "health", "--print-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.healthData = JSON.parse(this.text); root.errorMsg = ""; }
                catch(e) { root.errorMsg = "health parse: " + e; }
            }
        }
    }

    Process {
        id: moveProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/movetimer/move_timer.py", "status"]
        onExited: root.refresh()
    }

    Process {
        id: focusModeProc
        running: false
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/health/focus_mode.sh"]
        onExited: root.refresh()
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 28
        text: "󰋑"
        color: "#a6e3a1"
        font.family: "Iosevka Nerd Font"
        font.pixelSize: 34
        font.bold: true
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 78
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.top: parent.top
        anchors.topMargin: 27
        text: "Health / focus / spine"
        color: "#f5e9ff"
        font.family: "JetBrains Mono"
        font.pixelSize: 18
        font.bold: true
        elide: Text.ElideRight
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 78
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.top: parent.top
        anchors.topMargin: 56
        text: "Privacy-safe aggregate status. No health note bodies are read or shown."
        color: "#a9a0b7"
        font.family: "JetBrains Mono"
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 112
        anchors.margins: 28
        spacing: 14

        HealthCard {
            title: "Movement"
            accent: movement.move_due ? "#f38ba8" : "#a6e3a1"
            primary: movement.move_due ? "Stand up now" : ((movement.remaining_seconds || 0) + "s to next reset")
            secondary: "today " + (movement.cycles_today || 0) + " • streak " + (movement.current_streak_days || 0) + "d • best " + (movement.best_streak_days || 0) + "d"
        }

        HealthCard {
            title: "Focus"
            accent: "#89b4fa"
            primary: (focusStats.minutes_today || 0) + " minutes tracked today"
            secondary: "apps counted " + (focusStats.tracked_apps_count || 0) + " • session " + (focusStats.session_active ? "active" : "idle")
        }

        HealthCard {
            title: "Spine guard"
            accent: "#cba6f7"
            primary: "Done returns to work/focus mode"
            secondary: "gentle movement cycles only • no raw health notes"
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        spacing: 12

        HealthButton { label: "Focus mode"; accentColor: "#89b4fa"; onClicked: { focusModeProc.running = false; focusModeProc.running = true; } }
        HealthButton { label: "Done"; accentColor: "#a6e3a1"; onClicked: root.movementAction("done") }
        HealthButton { label: "Snooze"; accentColor: "#fab387"; onClicked: root.movementAction("snooze") }
        HealthButton { label: "Refresh"; accentColor: "#cba6f7"; onClicked: root.refresh() }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        horizontalAlignment: Text.AlignHCenter
        text: root.errorMsg
        color: "#f38ba8"
        font.family: "JetBrains Mono"
        font.pixelSize: 10
        visible: root.errorMsg !== ""
    }

    component HealthCard: Rectangle {
        property string title: ""
        property string primary: ""
        property string secondary: ""
        property color accent: "#a6e3a1"
        width: parent ? parent.width : 500
        height: 118
        radius: 16
        color: "#1a1022"
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.32)

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 18
            text: title
            color: accent
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.bold: true
        }
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 44
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            text: primary
            color: "#f5e9ff"
            font.family: "JetBrains Mono"
            font.pixelSize: 17
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 75
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            text: secondary
            color: "#a9a0b7"
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    component HealthButton: Rectangle {
        id: btn
        property string label: ""
        property color accentColor: "#cba6f7"
        signal clicked()
        width: 112
        height: 42
        radius: 13
        color: mouse.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22) : "#201229"
        border.width: 1
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, mouse.containsMouse ? 0.8 : 0.36)
        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.accentColor
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.bold: true
        }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }
}
