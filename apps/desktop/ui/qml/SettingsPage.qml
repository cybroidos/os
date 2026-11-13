import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts

// A page: its title, then its sections in one column (at most 680 wide,
// centred), scrolling when taller than the window.
Item {
    id: page
    property string title
    property string subtitle
    default property alias content: col.data
    signal shown()

    C.ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        C.ScrollBar.horizontal.policy: C.ScrollBar.AlwaysOff
        C.ScrollBar.vertical: C.ScrollBar {
            parent: scroll
            x: scroll.width - width - 2
            y: 2
            height: scroll.height - 4
            visible: scroll.contentHeight > scroll.height
            contentItem: Rectangle { implicitWidth: 5; radius: Theme.hex ? 0 : 3; color: Theme.faint; opacity: 0.6 }
        }
        Item {
            width: scroll.availableWidth
            implicitHeight: col.implicitHeight + 56
            ColumnLayout {
                id: col
                width: Math.min(680, parent.width - 64)
                x: (parent.width - width) / 2
                y: 28
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 10
                    Rectangle {
                        visible: Theme.hex
                        width: 4; height: 26
                        color: Theme.accent
                    }
                    ColumnLayout {
                        spacing: 2
                        Label {
                            text: Theme.hex ? page.title.toUpperCase() : page.title
                            font.family: Theme.hex ? Theme.mono : Theme.font
                            font.pixelSize: Theme.hex ? 20 : 26
                            font.weight: Theme.hex ? Font.Medium : Font.Bold
                            font.letterSpacing: Theme.hex ? 3 : -0.3
                        }
                        Label {
                            visible: page.subtitle !== ""
                            text: page.subtitle
                            color: Theme.soft
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
