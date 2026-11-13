import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import Cybroid.Settings
import CybroidUi

// CybroidOS Settings: the account at the top of the sidebar, the settings
// people use in groups below it, each page drawn in Horizon or Hex. Pages
// not yet our own open KDE's page for that setting.
Window {
    id: win
    width: 1040
    height: 720
    minimumWidth: 760
    minimumHeight: 520
    visible: true
    title: "Settings"
    color: Theme.bg

    // id, name, icon, page (ours) or kcm (KDE's)
    readonly property var groups: [
        [
            { id: "wifi", name: "Wi-Fi", icon: "network-wireless-symbolic", page: "WifiPage.qml" },
            { id: "bluetooth", name: "Bluetooth", icon: "bluetooth-symbolic", kcm: "kcm_bluetooth" },
            { id: "network", name: "Network", icon: "network-wired-symbolic", kcm: "kcm_networkmanagement" }
        ], [
            { id: "appearance", name: "Appearance", icon: "color-management-symbolic", page: "AppearancePage.qml" },
            { id: "display", name: "Displays", icon: "video-display-symbolic", kcm: "kcm_kscreen" },
            { id: "sound", name: "Sound", icon: "audio-volume-high-symbolic", page: "SoundPage.qml" },
            { id: "notifications", name: "Notifications", icon: "notifications-symbolic", kcm: "kcm_notifications" },
            { id: "power", name: "Battery & Power", icon: "battery-full-symbolic", kcm: "kcm_powerdevilprofilesconfig" }
        ], [
            { id: "keyboard", name: "Keyboard", icon: "input-keyboard-symbolic", kcm: "kcm_keyboard" },
            { id: "touchpad", name: "Mouse & Touchpad", icon: "input-touchpad-symbolic", kcm: "kcm_touchpad" },
            { id: "printers", name: "Printers", icon: "printer-symbolic", kcm: "kcm_printer_manager" }
        ], [
            { id: "users", name: "Users", icon: "system-users-symbolic", kcm: "kcm_users" },
            { id: "region", name: "Language & Region", icon: "preferences-desktop-locale-symbolic", kcm: "kcm_regionandlang" },
            { id: "datetime", name: "Date & Time", icon: "clock-symbolic", page: "DateTimePage.qml" },
            { id: "apps", name: "Default Apps", icon: "applications-all-symbolic", kcm: "kcm_componentchooser" },
            { id: "about", name: "About", icon: "help-about-symbolic", page: "AboutPage.qml" }
        ]
    ]
    property string current: System.startPage
    Connections {
        target: System
        function onStartPageChanged() {
            if (win.find(System.startPage)) win.current = System.startPage
            win.raise()
            win.requestActivate()
        }
    }

    function find(id) {
        for (const g of groups) for (const e of g) if (e.id === id) return e
        return null
    }
    function open(e) {
        if (e.page) { current = e.id; return }
        System.launch(["systemsettings", e.kcm])
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // The sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 264
            color: Theme.side
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                contentHeight: side.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: side
                    width: parent.width
                    spacing: 2

                    Field {
                        id: search
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        placeholderText: "Search"
                        leftPadding: 34
                        Kirigami.Icon {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            source: "search-symbolic"; isMask: true; color: Theme.faint
                        }
                    }

                    // The Cybroid Account (coming): one account for this
                    // computer, a phone and the school's services.
                    Item {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        implicitHeight: 64
                        visible: search.text === ""
                        Surface {
                            anchors.fill: parent
                            fill: acct.containsMouse ? Theme.cardHover : Theme.card
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            Rectangle {
                                implicitWidth: 40; implicitHeight: 40
                                radius: Theme.hex ? 0 : 20
                                color: Theme.selected
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    source: "user-symbolic"; isMask: true; color: Theme.accent
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { Layout.fillWidth: true; text: "Cybroid Account"; font.weight: Font.DemiBold; font.pixelSize: 14 }
                                Label { Layout.fillWidth: true; text: "Sign in: coming soon"; color: Theme.soft; font.pixelSize: 12 }
                            }
                        }
                        MouseArea { id: acct; anchors.fill: parent; hoverEnabled: true }
                    }

                    Repeater {
                        model: win.groups
                        ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 2
                            readonly property var shown: modelData.filter(e => search.text === "" || e.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
                            visible: shown.length > 0
                            Item { implicitHeight: index > 0 && search.text === "" ? 10 : 0 }
                            Repeater {
                                model: parent.shown
                                Item {
                                    required property var modelData
                                    readonly property bool on: win.current === modelData.id
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    Surface {
                                        anchors.fill: parent
                                        radius: Theme.hex ? 0 : 8
                                        cut: 6
                                        strokeWidth: Theme.hex && parent.on ? 1 : 0
                                        stroke: Theme.accent
                                        fill: parent.on ? Theme.selected : (ma.containsMouse ? Theme.cardHover : "transparent")
                                    }
                                    Rectangle {
                                        visible: Theme.hex && parent.on
                                        width: 3; height: parent.height - 12
                                        x: 0; anchors.verticalCenter: parent.verticalCenter
                                        color: Theme.accent
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 10
                                        spacing: 10
                                        Item {
                                            implicitWidth: 26; implicitHeight: 26
                                            Rectangle {
                                                visible: !Theme.hex
                                                anchors.fill: parent
                                                radius: 7
                                                color: Theme.accent
                                            }
                                            Kirigami.Icon {
                                                anchors.centerIn: parent
                                                width: Theme.hex ? 20 : 16; height: width
                                                source: modelData.icon
                                                isMask: true
                                                color: Theme.hex ? (parent.parent.parent.on ? Theme.accent : Theme.soft) : "#ffffff"
                                            }
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.pixelSize: 14
                                            font.weight: parent.parent.on ? Font.DemiBold : Font.Normal
                                        }
                                        // Opens KDE's page, in a window of its own.
                                        Kirigami.Icon {
                                            visible: !modelData.page
                                            implicitWidth: 14; implicitHeight: 14
                                            source: "window-new-symbolic"; isMask: true; color: Theme.faint
                                        }
                                    }
                                    MouseArea {
                                        id: ma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.open(modelData)
                                    }
                                }
                            }
                        }
                    }
                    Item { implicitHeight: 10 }
                    Btn {
                        Layout.fillWidth: true
                        text: "More settings"
                        onClicked: System.launch(["systemsettings"])
                    }
                }
            }
        }

        // The page
        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property var entry: win.find(win.current) || win.find("wifi")
            source: entry && entry.page ? Qt.resolvedUrl("CybroidUi/" + entry.page) : ""
        }
    }
}
