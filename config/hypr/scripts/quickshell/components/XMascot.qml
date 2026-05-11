import QtQuick
import "../"

Item {
    id: root

    property string mood: "idle"
    property color accentColor: moodColor()
    property bool animated: true
    property string caption: moodLabel()

    implicitWidth: scaler.s(118)
    implicitHeight: scaler.s(138)

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width * 8 : 900
        currentHeight: root.height > 0 ? root.height * 6 : 700
    }

    MatugenColors { id: theme }

    function moodColor() {
        if (root.mood === "privacy") return theme.red;
        if (root.mood === "focus") return theme.mauve;
        if (root.mood === "move_due") return theme.peach;
        if (root.mood === "agent_running") return theme.green;
        if (root.mood === "music") return theme.sapphire;
        return theme.blue;
    }

    function moodLabel() {
        if (root.mood === "privacy") return "PRIVATE";
        if (root.mood === "focus") return "FOCUS";
        if (root.mood === "move_due") return "MOVE";
        if (root.mood === "agent_running") return "AGENT";
        if (root.mood === "music") return "VIBING";
        return "ONLINE";
    }

    Rectangle {
        id: halo
        anchors.centerIn: face
        width: face.width + scaler.s(18)
        height: face.height + scaler.s(18)
        radius: width / 2
        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)

        SequentialAnimation on scale {
            running: root.animated && (root.mood === "move_due" || root.mood === "agent_running")
            loops: Animation.Infinite
            NumberAnimation { to: 1.06; duration: 760; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.00; duration: 760; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        id: face
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: scaler.s(8)
        width: scaler.s(86)
        height: scaler.s(86)
        radius: scaler.s(28)
        color: Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.92)
        border.width: 2
        border.color: root.accentColor

        Text {
            id: leftEye
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -scaler.s(9)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -scaler.s(17)
            text: root.mood === "privacy" ? "–" : "•"
            color: root.accentColor
            font.family: "JetBrains Mono"
            font.pixelSize: scaler.s(root.mood === "privacy" ? 28 : 31)
            font.weight: Font.Black
        }

        Text {
            anchors.verticalCenter: leftEye.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: scaler.s(17)
            text: root.mood === "privacy" ? "–" : "•"
            color: root.accentColor
            font.family: "JetBrains Mono"
            font.pixelSize: leftEye.font.pixelSize
            font.weight: Font.Black
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: scaler.s(13)
            text: root.mood === "move_due" ? "!" : "X"
            color: theme.text
            font.family: "JetBrains Mono"
            font.pixelSize: scaler.s(20)
            font.weight: Font.Black
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: face.bottom
        anchors.topMargin: scaler.s(12)
        width: Math.max(captionText.implicitWidth + scaler.s(18), scaler.s(74))
        height: scaler.s(26)
        radius: scaler.s(13)
        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14)
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.36)

        Text {
            id: captionText
            anchors.centerIn: parent
            text: root.caption
            color: root.accentColor
            font.family: "JetBrains Mono"
            font.pixelSize: scaler.s(10)
            font.bold: true
        }
    }
}
