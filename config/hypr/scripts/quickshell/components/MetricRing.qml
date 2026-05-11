import QtQuick
import "../"

Item {
    id: root

    property real value: 0
    property real minimumValue: 0
    property real maximumValue: 100
    property string label: ""
    property string sublabel: ""
    property color accentColor: theme.mauve
    property color trackColor: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.10)
    property int lineWidth: scaler.s(8)
    readonly property real progress: Math.max(0, Math.min(1, (root.value - root.minimumValue) / Math.max(1, root.maximumValue - root.minimumValue)))

    implicitWidth: scaler.s(128)
    implicitHeight: scaler.s(128)

    Scaler {
        id: scaler
        currentWidth: root.width > 0 ? root.width * 7 : 900
        currentHeight: root.height > 0 ? root.height * 7 : 700
    }

    MatugenColors { id: theme }

    onProgressChanged: ringCanvas.requestPaint()
    onAccentColorChanged: ringCanvas.requestPaint()
    onTrackColorChanged: ringCanvas.requestPaint()
    onLineWidthChanged: ringCanvas.requestPaint()
    onWidthChanged: ringCanvas.requestPaint()
    onHeightChanged: ringCanvas.requestPaint()

    Canvas {
        id: ringCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            let ctx = getContext("2d");
            let size = Math.min(width, height);
            let radius = Math.max(1, size / 2 - root.lineWidth / 2 - 1);
            let cx = width / 2;
            let cy = height / 2;
            ctx.reset();
            ctx.lineCap = "round";
            ctx.lineWidth = root.lineWidth;
            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2, false);
            ctx.stroke();
            ctx.strokeStyle = root.accentColor;
            ctx.beginPath();
            ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * root.progress, false);
            ctx.stroke();
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.sublabel.length > 0 ? -scaler.s(8) : 0
        text: root.label.length > 0 ? root.label : Math.round(root.progress * 100) + "%"
        color: theme.text
        font.family: "JetBrains Mono"
        font.pixelSize: scaler.s(21)
        font.weight: Font.Black
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: scaler.s(18)
        visible: root.sublabel.length > 0
        text: root.sublabel
        color: theme.subtext0
        font.family: "JetBrains Mono"
        font.pixelSize: scaler.s(10)
        font.bold: true
    }
}
