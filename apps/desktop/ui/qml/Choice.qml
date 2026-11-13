import QtQuick
import QtQuick.Controls.Basic as C
import org.kde.kirigami as Kirigami

// A choice from a list: shows the chosen one, and the list opens under it.
Item {
    id: ch
    property var options: []        // the names shown
    property int current: -1
    property string placeholder: "Choose"
    signal picked(int index)
    implicitWidth: Math.max(150, Math.min(320, lbl.implicitWidth + 46))
    implicitHeight: 34
    opacity: enabled ? 1 : 0.45

    Surface {
        anchors.fill: parent
        radius: Theme.hex ? 0 : 9
        cut: 7
        fill: area.containsMouse ? Theme.cardHover : (Theme.hex ? "transparent" : Theme.card)
        stroke: pop.visible ? Theme.accent : (Theme.hex ? Theme.edge : Theme.line)
        strokeWidth: 1
    }
    Label {
        id: lbl
        x: 12
        width: parent.width - 40
        height: parent.height
        text: ch.current >= 0 && ch.current < ch.options.length ? ch.options[ch.current] : ch.placeholder
        color: ch.current >= 0 ? Theme.ink : Theme.faint
        font.pixelSize: 13
    }
    Kirigami.Icon {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14
        source: "go-down-symbolic"; isMask: true; color: Theme.soft
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pop.open()
    }
    C.Popup {
        id: pop
        y: ch.height + 4
        width: Math.max(ch.width, 200)
        height: Math.min(list.contentHeight + 12, 320)
        padding: 6
        background: Surface { fill: Theme.card; stroke: Theme.hex ? Theme.accent : Theme.line }
        contentItem: ListView {
            id: list
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ch.options
            currentIndex: ch.current
            C.ScrollBar.vertical: C.ScrollBar { }
            delegate: Item {
                required property var modelData
                required property int index
                width: list.width
                height: 32
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.hex ? 0 : 6
                    color: index === ch.current ? Theme.selected : (m.containsMouse ? Theme.cardHover : "transparent")
                }
                Label { x: 10; width: parent.width - 20; height: parent.height; text: modelData; font.pixelSize: 13 }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { pop.close(); if (index !== ch.current) ch.picked(index) }
                }
            }
        }
    }
}
