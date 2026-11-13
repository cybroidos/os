import QtQuick
import QtQuick.Layouts

// A group's heading above its card; Hex writes it in spaced mono capitals.
ColumnLayout {
    property string title
    property string caption
    spacing: 2
    Layout.fillWidth: true
    Layout.topMargin: 14
    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: Theme.hex ? title.toUpperCase() : title
        font.family: Theme.labelFont
        font.pixelSize: Theme.hex ? 11 : 13
        font.weight: Theme.hex ? Font.Medium : Font.DemiBold
        font.letterSpacing: Theme.hex ? 1.6 : 0
        color: Theme.hex ? Theme.accent : Theme.soft
        visible: title !== ""
    }
    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: caption
        color: Theme.soft
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        visible: caption !== ""
    }
}
