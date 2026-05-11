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

    property var timerData: ({ label: "45:00", mode: "focus", due: false, progress: 0, cycles: 0, daily_cycles_today: 0, current_streak_days: 0, best_streak_days: 0, interval_minutes: 45, break_minutes: 5, phase_label: "Focus posture", overdue_label: "00:00", snoozes: 0 })
    property string errorMsg: ""
    readonly property bool isDue: timerData.due === true
    readonly property bool isBreak: timerData.mode === "break"
    readonly property bool isPaused: timerData.mode === "paused"
    readonly property color accent: isDue ? "#f38ba8" : (isBreak ? "#a6e3a1" : "#cba6f7")

    color: "#14051f"
    radius: 20
    border.width: 1
    border.color: "#7a4a8a"
    clip: true

    function runAction(action) {
        actionProc.command = ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/movetimer/move_timer.py"].concat(action.split(" "));
        actionProc.running = false;
        actionProc.running = true;
    }

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
    }

    Component.onCompleted: refresh()

    Timer { interval: 1000; running: true; repeat: true; onTriggered: refresh() }

    Process {
        id: statusProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/movetimer/move_timer.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.timerData = JSON.parse(this.text); root.errorMsg = ""; }
                catch(e) { root.errorMsg = "timer parse: " + e; }
            }
        }
    }

    Process {
        id: actionProc
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/movetimer/move_timer.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.timerData = JSON.parse(this.text); root.errorMsg = ""; }
                catch(e) { root.errorMsg = "action parse: " + e; }
            }
        }
    }

    Text {
        id: icon
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 28
        text: root.isDue ? "󰐃" : (root.isBreak ? "󰝊" : "󰔟")
        color: root.accent
        font.family: "Iosevka Nerd Font"
        font.pixelSize: 34
        font.bold: true
    }

    Text {
        anchors.left: icon.right
        anchors.leftMargin: 16
        anchors.right: cycleBadge.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 26
        text: "L4/L5 movement timer"
        color: "#f5e9ff"
        font.family: "JetBrains Mono"
        font.pixelSize: 18
        font.bold: true
        elide: Text.ElideRight
    }

    Text {
        anchors.left: icon.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.top: parent.top
        anchors.topMargin: 54
        text: root.isDue ? "Stand up. Decompress. Walk. Your disk is not a Git repo." : (root.timerData.phase_label || "Focus posture")
        color: root.isDue ? "#f38ba8" : "#a9a0b7"
        font.family: "JetBrains Mono"
        font.pixelSize: 12
        font.bold: true
        wrapMode: Text.WordWrap
    }

    Rectangle {
        id: cycleBadge
        width: 88
        height: 36
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 26
        radius: 11
        color: "#241230"
        border.width: 1
        border.color: "#3a2248"
        Text {
            anchors.centerIn: parent
            text: (root.timerData.interval_minutes || 45) + "/" + (root.timerData.break_minutes || 5)
            color: root.accent
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        id: ring
        width: 190
        height: 190
        radius: 95
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 130
        color: "#1b0b29"
        border.width: 9
        border.color: root.accent
        opacity: root.isDue ? 1.0 : 0.82

        SequentialAnimation on scale {
            running: root.isDue
            loops: Animation.Infinite
            NumberAnimation { to: 1.05; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -13
            text: root.isDue ? "MOVE" : (root.timerData.label || "45:00")
            color: root.isDue ? "#f38ba8" : "#f5e9ff"
            font.family: "JetBrains Mono"
            font.pixelSize: root.isDue ? 31 : 34
            font.bold: true
        }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 28
            text: root.isDue ? ("over " + (root.timerData.overdue_label || "00:00")) : (root.isPaused ? "paused" : (root.isBreak ? "break left" : "until standup"))
            color: "#a9a0b7"
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: ring.bottom
        anchors.topMargin: 26
        anchors.margins: 28
        height: 78
        radius: 16
        color: "#1a1022"
        border.width: 1
        border.color: "#30203b"

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 7

            Text {
                width: parent.width
                text: root.isDue ? "Do this: stand up, walk 2-5 min, hip hinge, gentle McGill-style reset. No hero stretching." : "Every 45 minutes: move your body before the L4/L5 tax collector arrives. Break target: 5 minutes."
                color: "#cfc3dc"
                wrapMode: Text.WordWrap
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                lineHeight: 1.18
            }

            Text {
                width: parent.width
                text: "today " + (root.timerData.daily_cycles_today || 0) + "  •  streak " + (root.timerData.current_streak_days || 0) + "d  •  best " + (root.timerData.best_streak_days || 0) + "d  •  total " + (root.timerData.cycles || 0)
                color: root.accent
                elide: Text.ElideRight
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.bold: true
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        spacing: 12

        MoveButton { label: root.isPaused ? "Resume" : "Pause"; accentColor: "#cba6f7"; onClicked: root.runAction(root.isPaused ? "resume" : "pause") }
        MoveButton { label: "Done"; accentColor: "#a6e3a1"; onClicked: root.runAction("done") }
        MoveButton { label: "+5"; accentColor: "#89b4fa"; onClicked: root.runAction("snooze") }
        MoveButton { label: "Reset"; accentColor: "#fab387"; onClicked: root.runAction("reset") }
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

    component MoveButton: Rectangle {
        id: btn
        property string label: ""
        property color accentColor: "#cba6f7"
        signal clicked()
        width: 102
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
            font.pixelSize: 13
            font.bold: true
        }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }
}
