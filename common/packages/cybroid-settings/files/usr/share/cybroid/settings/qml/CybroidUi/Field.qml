import QtQuick
import QtQuick.Controls.Basic as C
import CybroidUi

// A text field with a clear focus ring in the accent colour.
C.TextField {
    id: f
    implicitWidth: 240
    implicitHeight: 36
    leftPadding: 12; rightPadding: 12
    color: Theme.ink
    placeholderTextColor: Theme.faint
    selectionColor: Theme.selected
    selectedTextColor: Theme.ink
    font.family: Theme.font
    font.pixelSize: 14
    background: Surface {
        radius: Theme.hex ? 0 : 9
        cut: 7
        fill: Theme.hex ? Theme.bg : (Theme.light ? "#ffffff" : Qt.rgba(0, 0, 0, 0.18))
        stroke: f.activeFocus ? Theme.accent : (Theme.hex ? Theme.edge : Theme.line)
        strokeWidth: f.activeFocus ? 2 : 1
    }
}
