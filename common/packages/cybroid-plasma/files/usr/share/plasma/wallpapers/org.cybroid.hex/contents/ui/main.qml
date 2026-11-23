/*
 * CybroidOS Hex's wallpaper (org.cybroid.hex): Hex's interface over its own
 * ground or over a picture the person chose, so choosing a wallpaper in Hex
 * never takes the dial and the readouts' leaders away (HexScene.qml).
 * cybroid-appearance switches to it in Hex and back to Plasma's Image
 * wallpaper in Horizon; Settings > Appearance and Plasma's own "Configure
 * Desktop and Wallpaper" choose its picture.
 */
import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root
    HexScene {
        anchors.fill: parent
        image: root.configuration.Image || ""
        light: root.configuration.Light === true || root.configuration.Light === "true"
        dim: (root.configuration.Dim || 60) / 100
    }
}
