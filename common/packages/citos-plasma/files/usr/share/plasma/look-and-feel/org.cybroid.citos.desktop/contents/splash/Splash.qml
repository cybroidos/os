// CIT-OS Horizon's splash while Plasma starts (citos-plasma): the wallpaper
// (it carries the logo) and a thin cyan progress line.
import QtQuick

Rectangle {
    id: root
    color: "#0b1638"
    property int stage

    Image {
        anchors.fill: parent
        source: "file:///usr/share/backgrounds/citos/citos-1920x1080.png"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        width: 220
        height: 4
        radius: 2
        color: "#33ffffff"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.16

        Rectangle {
            width: parent.width * Math.min(1, root.stage / 6)
            height: parent.height
            radius: 2
            color: "#1ccbff"
            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        }
    }
}
