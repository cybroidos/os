import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// The design (Horizon or Hex) and Dark or Light, applied by
// cybroid-appearance as Control Centre does; Night Light (KWin).
SettingsPage {
    id: page
    title: "Appearance"

    property string busy: ""        // what is being applied
    property bool nightLight: false

    function apply(arg) {
        busy = arg
        System.run(["cybroid-appearance", arg], () => busy = "")
    }
    Component.onCompleted: System.run(["kreadconfig6", "--file", "kwinrc", "--group", "NightColor", "--key", "Active"], (o) => nightLight = o.trim() === "true")

    component DesignCard: Item {
        id: dc
        property string name
        property string design
        property string blurb
        readonly property bool on: System.design === design
        Layout.fillWidth: true
        implicitHeight: 236
        Surface {
            anchors.fill: parent
            fill: Theme.card
            stroke: dc.on ? Theme.accent : (ma.containsMouse ? Theme.faint : Theme.edge)
            strokeWidth: dc.on ? 2 : 1
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                // A real screenshot of the desktop in this design, in the
                // appearance in use (Dark or Light).
                Image {
                    anchors.fill: parent
                    source: "file:///usr/share/cybroid/settings/previews/" + dc.design + (System.light ? "-light" : "-dark") + ".jpg"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { text: dc.name; font.weight: Font.DemiBold; font.pixelSize: 14 }
                    Label { Layout.fillWidth: true; text: dc.blurb; color: Theme.soft; font.pixelSize: 12 }
                }
                Kirigami.Icon {
                    visible: dc.on || page.busy === dc.design
                    implicitWidth: 20; implicitHeight: 20
                    source: page.busy === dc.design ? "view-refresh-symbolic" : "checkmark-symbolic"
                    isMask: true; color: Theme.accent
                    RotationAnimator on rotation { running: page.busy === dc.design; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                }
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !dc.on && page.busy === ""
            onClicked: page.apply(dc.design)
        }
    }

    Section { title: "Design" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        DesignCard { name: "Horizon"; design: "horizon"; blurb: "Calm and rounded" }
        DesignCard { name: "Hex"; design: "hex"; blurb: "A heads-up display, with live readouts" }
    }

    Section { title: "Look" }
    Card {
        SettingRow {
            title: "Dark or Light"
            subtitle: page.busy === "dark" || page.busy === "light" ? "Changing…" : ""
            icon: "weather-clear-night-symbolic"
            Segmented {
                options: ["Light", "Dark"]
                current: System.light ? 0 : 1
                enabled: page.busy === ""
                onPicked: (i) => page.apply(i === 0 ? "light" : "dark")
            }
        }
        SettingRow {
            title: "Night Light"
            subtitle: "Warmer colours from sunset to sunrise, easier on the eyes at night"
            icon: "redshift-status-on"
            Toggle {
                checked: page.nightLight
                onToggled: (on) => {
                    page.nightLight = on
                    System.run(["kwriteconfig6", "--notify", "--file", "kwinrc", "--group", "NightColor", "--key", "Active", on ? "true" : "false"], () => {})
                }
            }
        }
    }

    // The desktop's picture, for the design in use (cybroid-appearance
    // wallpaper): in Hex it goes behind Hex's frame, dial and leaders, so the
    // readouts stay in place; never through KDE's wallpaper page, whose plain
    // picture would replace Hex's drawing.
    FileDialog {
        id: wallPicker
        title: "Choose a picture for the desktop"
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp)"]
        currentFolder: "file://" + System.folder("pictures")
        onAccepted: {
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
            page.busy = "wallpaper"
            System.run(["cybroid-appearance", "wallpaper", path], () => page.busy = "")
        }
    }
    Section { title: "Desktop picture" }
    Card {
        SettingRow {
            title: "Your own picture"
            subtitle: System.design === "hex" ? "It goes behind Hex's dial and readouts, toned to Hex's colours" : "Any photo or picture, filling the screen"
            icon: "preferences-desktop-wallpaper-symbolic"
            Btn { text: page.busy === "wallpaper" ? "Setting…" : "Choose…"; enabled: page.busy === ""; onClicked: wallPicker.open() }
        }
        SettingRow {
            title: "CybroidOS's own"
            subtitle: System.design === "hex" ? "Hex's own ground" : "The CybroidOS wallpaper"
            icon: "edit-undo-symbolic"
            Btn { text: "Use it"; enabled: page.busy === ""; onClicked: { page.busy = "wallpaper"; System.run(["cybroid-appearance", "wallpaper", "default"], () => page.busy = "") } }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Fonts and text size"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_fonts"])
        }
    }
}
