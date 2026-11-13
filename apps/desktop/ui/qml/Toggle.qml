import QtQuick
import QtQuick.Shapes

// An on/off switch. Horizon: a pill with a round knob. Hex: a cut-corner
// track with a hexagonal knob that turns the accent colour when on.
Item {
    id: t
    property bool checked: false
    property bool busy: false
    signal toggled(bool on)
    implicitWidth: Theme.hex ? 46 : 44
    implicitHeight: Theme.hex ? 22 : 26
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onSpacePressed: { t.toggled(!t.checked) }

    Surface {
        anchors.fill: parent
        radius: height / 2
        cut: 6
        fill: t.checked ? Theme.accent : (Theme.hex ? "transparent" : Theme.track)
        stroke: t.checked ? Theme.accent : (Theme.hex ? Theme.edge : "transparent")
        strokeWidth: Theme.hex ? 1 : 0
    }
    Item {
        id: knob
        width: t.height - (Theme.hex ? 8 : 4)
        height: width
        y: (t.height - height) / 2
        x: t.checked ? t.width - width - (Theme.hex ? 4 : 2) : (Theme.hex ? 4 : 2)
        Behavior on x { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
        Rectangle {
            visible: !Theme.hex
            anchors.fill: parent
            radius: width / 2
            color: "#ffffff"
            border.color: Qt.rgba(0, 0, 0, 0.08)
        }
        Shape {
            visible: Theme.hex
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: t.checked ? Theme.onAccent : Theme.soft
                strokeColor: "transparent"
                readonly property real w: knob.width
                startX: w * 0.25; startY: 0
                PathLine { x: knob.width * 0.75; y: 0 }
                PathLine { x: knob.width; y: knob.height / 2 }
                PathLine { x: knob.width * 0.75; y: knob.height }
                PathLine { x: knob.width * 0.25; y: knob.height }
                PathLine { x: 0; y: knob.height / 2 }
                PathLine { x: knob.width * 0.25; y: 0 }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: t.toggled(!t.checked)
    }
}
