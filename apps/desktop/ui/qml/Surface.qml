import QtQuick
import QtQuick.Shapes

// A frame: rounded for Horizon, cut at the top-left and bottom-right corners
// for Hex (as Hex's windows and controls are).
Item {
    id: s
    property color fill: Theme.card
    property color stroke: Theme.edge
    property real strokeWidth: 1
    property real radius: Theme.radius
    property real cut: Theme.cut

    Rectangle {
        visible: !Theme.hex
        anchors.fill: parent
        radius: s.radius
        color: s.fill
        border.color: s.stroke
        border.width: s.strokeWidth
        Behavior on color { ColorAnimation { duration: Theme.duration } }
    }
    Shape {
        visible: Theme.hex
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: sp
            fillColor: s.fill
            strokeColor: s.strokeWidth > 0 ? s.stroke : "transparent"
            strokeWidth: s.strokeWidth
            joinStyle: ShapePath.MiterJoin
            readonly property real h: s.strokeWidth / 2
            readonly property real c: Math.min(s.cut, s.width / 3, s.height / 3)
            startX: sp.h + sp.c; startY: sp.h
            PathLine { x: s.width - sp.h; y: sp.h }
            PathLine { x: s.width - sp.h; y: s.height - sp.h - sp.c }
            PathLine { x: s.width - sp.h - sp.c; y: s.height - sp.h }
            PathLine { x: sp.h; y: s.height - sp.h }
            PathLine { x: sp.h; y: sp.h + sp.c }
            PathLine { x: sp.h + sp.c; y: sp.h }
        }
    }
}
