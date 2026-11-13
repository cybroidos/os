import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import CybroidUi

// One setting: a title, an optional line under it, and its control at the
// right. Clickable rows (a page or a choice) light up under the pointer.
Item {
    id: row
    property string title
    property string subtitle
    property string icon
    property color iconColor: Theme.accent
    property bool clickable: false
    property bool chevron: clickable
    property bool selected: false
    property bool first: Positioner.index <= 0
    default property alias trailing: tail.data
    signal clicked()
    width: parent ? parent.width : 400
    implicitHeight: Math.max(subtitle !== "" ? 60 : 50, lay.implicitHeight + 16)
    visible: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.hex ? 1 : 0
        radius: Theme.hex ? 0 : Theme.radius - 1
        color: row.selected ? Theme.selected : (row.clickable && hover.hovered ? Theme.cardHover : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.duration } }
    }
    Rectangle {
        visible: !row.first
        x: lay.x; width: parent.width - x
        height: 1
        color: Theme.line
    }
    HoverHandler { id: hover; enabled: row.clickable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: row.clickable; onTapped: row.clicked() }

    RowLayout {
        id: lay
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 12
        Kirigami.Icon {
            visible: row.icon !== ""
            source: row.icon
            implicitWidth: 22; implicitHeight: 22
            isMask: true
            color: row.iconColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { Layout.fillWidth: true; text: row.title; font.pixelSize: 14 }
            Label {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                text: row.subtitle
                color: Theme.soft
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            }
        }
        RowLayout { id: tail; spacing: 10 }
        Kirigami.Icon {
            visible: row.chevron
            source: "go-next-symbolic"
            implicitWidth: 16; implicitHeight: 16
            isMask: true
            color: Theme.faint
        }
    }
}
