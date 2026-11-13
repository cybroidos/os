import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Cybroid.Settings
import CybroidUi

// Date and time through systemd's timedated (timedatectl): set from the
// internet (systemd-timesyncd) or by hand, the time zone, and how the
// hardware clock is kept (local time when Windows shares the computer).
// Changing them asks for an administrator's password (polkit).
SettingsPage {
    id: page
    title: "Date & Time"

    property var info: ({})
    property var zones: []
    property bool picking: false
    property string error: ""
    property date now: new Date()

    function refresh() {
        System.run(["timedatectl", "show"], (o) => {
            const m = {}
            for (const l of o.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1) }
            info = m
        })
    }
    function set(args, then) {
        error = ""
        System.run(["timedatectl"].concat(args), (o, code) => {
            if (code !== 0) error = /authoriz|authentic|denied/i.test(o) ? "That needs an administrator's password." : o.trim()
            refresh()
            if (then) then(code)
        })
    }
    function place(z) {
        // "Africa/Kampala" → "Kampala, Africa"
        const p = z.split("/")
        return p.length > 1 ? p.slice(1).join(" / ").replace(/_/g, " ") + ", " + p[0] : z
    }
    Component.onCompleted: {
        refresh()
        System.run(["timedatectl", "list-timezones"], (o) => zones = o.split("\n").filter(z => z !== ""))
    }
    Timer { interval: 1000; running: page.visible; repeat: true; onTriggered: page.now = new Date() }
    Timer { interval: 5000; running: page.visible; repeat: true; onTriggered: page.refresh() }

    // The time now, large, as the desktop's clock shows it.
    Surface {
        Layout.fillWidth: true
        implicitHeight: 112
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(page.now, "h:mm:ss AP")
                font.family: Theme.hex ? Theme.mono : Theme.font
                font.pixelSize: 40
                font.weight: Theme.hex ? Font.Medium : Font.Light
                font.letterSpacing: Theme.hex ? 2 : 0
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(page.now, "dddd d MMMM yyyy") + " · " + page.place(page.info.Timezone || "")
                color: Theme.soft
                font.pixelSize: 13
            }
        }
    }

    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: Theme.bad
        wrapMode: Text.WordWrap
    }

    Section { title: "Time" }
    Card {
        SettingRow {
            title: "Set the time automatically"
            subtitle: page.info.NTP !== "yes" ? "Off: the time is set by hand"
                    : page.info.NTPSynchronized === "yes" ? "On, and in step with the internet's time servers"
                    : "On: waiting for the internet to check the time"
            icon: "clock-symbolic"
            Toggle {
                enabled: page.info.CanNTP === "yes"
                checked: page.info.NTP === "yes"
                onToggled: (on) => page.set(["set-ntp", on ? "true" : "false"])
            }
        }
        SettingRow {
            id: manual
            visible: page.info.NTP !== "yes"
            title: "Date and time"
            subtitle: "Year-month-day and 24-hour time"
            Field {
                id: dateField
                implicitWidth: 120
                text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                inputMask: "9999-99-99"
            }
            Field {
                id: timeField
                implicitWidth: 84
                text: Qt.formatTime(new Date(), "HH:mm")
                inputMask: "99:99"
            }
            Btn { text: "Set"; primary: true; onClicked: page.set(["set-time", dateField.text + " " + timeField.text + ":00"]) }
        }
    }

    Section { title: "Time zone" }
    Card {
        SettingRow {
            title: page.place(page.info.Timezone || "")
            subtitle: page.info.Timezone || ""
            icon: "globe-symbolic"
            clickable: true
            chevron: !page.picking
            onClicked: { page.picking = !page.picking; if (page.picking) zoneSearch.forceActiveFocus() }
        }
        Item {
            visible: page.picking
            width: parent ? parent.width : 400
            implicitHeight: 300
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                Field {
                    id: zoneSearch
                    Layout.fillWidth: true
                    placeholderText: "Search for a city or region"
                }
                ListView {
                    id: zl
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: page.zones.filter(z => zoneSearch.text === "" || z.toLowerCase().replace(/_/g, " ").indexOf(zoneSearch.text.toLowerCase()) >= 0)
                    C.ScrollBar.vertical: C.ScrollBar { }
                    delegate: Item {
                        required property string modelData
                        width: zl.width
                        height: 34
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.hex ? 0 : 6
                            color: modelData === page.info.Timezone ? Theme.selected : zm.containsMouse ? Theme.cardHover : "transparent"
                        }
                        Label { x: 10; height: parent.height; text: page.place(modelData) }
                        Label { anchors.right: parent.right; anchors.rightMargin: 10; height: parent.height; text: modelData; color: Theme.faint; font.pixelSize: 12 }
                        MouseArea {
                            id: zm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.set(["set-timezone", modelData], (code) => { if (code === 0) page.picking = false })
                        }
                    }
                }
            }
        }
    }

    Section {
        title: "Windows on this computer"
        caption: "Windows keeps the computer's clock in local time. If the time is off by a few hours after using Windows, turn this on."
    }
    Card {
        SettingRow {
            title: "Keep the hardware clock in local time"
            subtitle: page.info.LocalRTC === "yes" ? "On: as Windows does" : "Off: universal time (best without Windows)"
            icon: "computer-symbolic"
            Toggle {
                checked: page.info.LocalRTC === "yes"
                onToggled: (on) => page.set(["set-local-rtc", on ? "true" : "false"])
            }
        }
    }
}
