import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Shapes

// A slider: a thin track filled in the accent colour, a round handle
// (Horizon) or a hexagon (Hex).
C.Slider {
    id: s
    implicitWidth: 220
    implicitHeight: 28
    background: Item {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth
        height: 4
        Surface { anchors.fill: parent; radius: 2; cut: 0; fill: Theme.track; strokeWidth: 0 }
        Surface {
            width: s.visualPosition * parent.width
            height: parent.height
            radius: 2; cut: 0; fill: Theme.accent; strokeWidth: 0
        }
    }
    handle: Item {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: Theme.hex ? 18 : 20
        height: Theme.hex ? 16 : 20
        Rectangle {
            visible: !Theme.hex
            anchors.fill: parent
            radius: width / 2
            color: "#ffffff"
            border.color: s.pressed ? Theme.accent : Qt.rgba(0, 0, 0, 0.14)
            border.width: s.pressed ? 2 : 1
        }
        Shape {
            visible: Theme.hex
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.bg
                strokeColor: Theme.accent
                strokeWidth: s.pressed ? 2.5 : 1.5
                startX: 4.5; startY: 1
                PathLine { x: 14; y: 1 }
                PathLine { x: 17; y: 8 }
                PathLine { x: 14; y: 15 }
                PathLine { x: 4.5; y: 15 }
                PathLine { x: 1; y: 8 }
                PathLine { x: 4.5; y: 1 }
            }
        }
    }
}
