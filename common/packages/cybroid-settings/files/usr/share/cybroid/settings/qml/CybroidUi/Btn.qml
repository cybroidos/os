import QtQuick
import CybroidUi

// A button: primary (filled with the accent) or plain.
Item {
    id: b
    property string text
    property bool primary: false
    property bool danger: false
    signal clicked()
    implicitWidth: Math.max(84, lbl.implicitWidth + 32)
    implicitHeight: 34
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onReturnPressed: b.clicked()
    Keys.onSpacePressed: b.clicked()
    Surface {
        anchors.fill: parent
        radius: Theme.hex ? 0 : 9
        cut: 7
        fill: b.primary ? (area.pressed ? Qt.darker(Theme.accent, 1.15) : area.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                        : (area.pressed ? Theme.selected : area.containsMouse ? Theme.cardHover : (Theme.hex ? "transparent" : Theme.card))
        stroke: b.primary ? Theme.accent : (b.activeFocus ? Theme.accent : (Theme.hex ? Theme.edge : Theme.line))
        strokeWidth: 1
    }
    Label {
        id: lbl
        anchors.centerIn: parent
        text: Theme.hex ? b.text.toUpperCase() : b.text
        font.family: Theme.labelFont
        font.pixelSize: Theme.hex ? 12 : 14
        font.weight: Font.Medium
        font.letterSpacing: Theme.hex ? 1.2 : 0
        color: b.primary ? Theme.onAccent : (b.danger ? Theme.bad : Theme.ink)
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
