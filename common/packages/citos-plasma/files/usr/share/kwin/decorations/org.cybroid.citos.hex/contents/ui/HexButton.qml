/*
 * A colour key on CIT-OS Hex's title bar: a 13 px square, its corners just
 * softened, in its colour while the window is in front and grey behind; its
 * mark shows when the pointer is over the keys.
 */
import QtQuick
import QtQuick.Shapes
import org.kde.kwin.decoration

DecorationButton {
    id: key
    property color tint
    property string glyph
    property bool light: false
    width: 13
    height: 13

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: !key.enabled ? (key.light ? "#dfe8f7" : "#1d2d55")
            : decoration.client.active || key.hovered ? key.tint : (key.light ? "#c9d5ea" : "#2a3d6e")
        opacity: key.pressed ? 0.7 : 1
    }
    Shape {
        anchors.fill: parent
        visible: key.hovered && key.enabled
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.4
            strokeColor: "#1a0b06"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: key.glyph === "close" ? "M4 4 L9 9 M9 4 L4 9"
                    : key.glyph === "minimize" ? "M3.5 6.5 L9.5 6.5"
                    : "M3.5 6.5 L9.5 6.5 M6.5 3.5 L6.5 9.5"
            }
        }
    }
}
