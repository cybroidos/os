import QtQuick
import QtQuick.Layouts
import CybroidUi

// A choice of a few: the chosen one stands out and slides when it changes.
Item {
    id: seg
    property var options: []
    property int current: 0
    signal picked(int index)
    implicitWidth: rowl.implicitWidth + 6
    implicitHeight: 34
    Surface {
        anchors.fill: parent
        radius: Theme.hex ? 0 : 10
        cut: 7
        fill: Theme.hex ? "transparent" : Theme.track
        stroke: Theme.hex ? Theme.edge : "transparent"
        strokeWidth: Theme.hex ? 1 : 0
    }
    Surface {
        visible: seg.current >= 0 && rep.count > 0
        readonly property Item at: rep.count > seg.current && seg.current >= 0 ? rep.itemAt(seg.current) : null
        x: at ? at.x + 3 : 3
        y: 3
        width: at ? at.width : 0
        height: seg.height - 6
        radius: Theme.hex ? 0 : 8
        cut: 5
        fill: Theme.hex ? Theme.accent : (Theme.light ? "#ffffff" : Theme.card)
        stroke: "transparent"
        strokeWidth: 0
        Behavior on x { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.duration; easing.type: Easing.OutCubic } }
    }
    RowLayout {
        id: rowl
        x: 3; y: 3
        height: seg.height - 6
        spacing: 0
        Repeater {
            id: rep
            model: seg.options
            Item {
                Layout.fillHeight: true
                implicitWidth: Math.max(64, l.implicitWidth + 28)
                Label {
                    id: l
                    anchors.centerIn: parent
                    text: Theme.hex ? String(modelData).toUpperCase() : modelData
                    font.family: Theme.labelFont
                    font.pixelSize: Theme.hex ? 11 : 13
                    font.letterSpacing: Theme.hex ? 1.2 : 0
                    font.weight: index === seg.current ? Font.DemiBold : Font.Normal
                    color: index === seg.current && Theme.hex ? Theme.onAccent : (index === seg.current ? Theme.ink : Theme.soft)
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (index !== seg.current) seg.picked(index) }
            }
        }
    }
}
