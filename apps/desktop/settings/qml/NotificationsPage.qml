import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Notifications: Do Not Disturb (for a while, or until turned off), quiet
// while presenting, sounds, where popups appear and how long they stay. In
// Plasma's own settings (plasmanotifyrc), written with --notify so the
// running desktop follows at once; each app's notifications in KDE's page.
SettingsPage {
    id: page
    title: "Notifications"

    property var cfg: ({})
    readonly property var keys: [
        ["DoNotDisturb", "Until", ""], ["DoNotDisturb", "WhenScreensMirrored", "true"], ["DoNotDisturb", "WhenScreenSharing", "true"],
        ["DoNotDisturb", "NotificationSoundsMuted", "false"], ["Notifications", "CriticalInDndMode", "true"],
        ["Notifications", "PopupPosition", "0"], ["Notifications", "PopupTimeout", "5000"], ["Notifications", "LowPriorityPopups", "true"]]
    // Plasma's popup places: 0 near the clock (the top right here).
    readonly property var places: [[0, "Top right, by the clock"], [1, "Top left"], [2, "Top centre"], [6, "Bottom right"], [4, "Bottom left"], [5, "Bottom centre"]]
    readonly property var stays: [[3000, "3 seconds"], [5000, "5 seconds"], [8000, "8 seconds"], [15000, "15 seconds"]]

    function read() {
        for (const k of keys)
            System.run(["kreadconfig6", "--file", "plasmanotifyrc", "--group", k[0], "--key", k[1]], (o) => {
                const c = Object.assign({}, cfg); c[k[1]] = o.trim() !== "" ? o.trim() : k[2]; cfg = c
            })
    }
    function set(group, key, value) {
        const c = Object.assign({}, cfg); c[key] = String(value); cfg = c
        System.run(["kwriteconfig6", "--notify", "--file", "plasmanotifyrc", "--group", group, "--key", key, String(value)], () => {})
    }
    // KConfig keeps a date and time as year,month,day,hour,minute,second.
    function stamp(d) { return [d.getFullYear(), d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds()].join(",") }
    function until() {
        const p = (cfg.Until || "").split(",").map(Number)
        return p.length === 6 ? new Date(p[0], p[1] - 1, p[2], p[3], p[4], p[5]) : null
    }
    readonly property bool dnd: { const u = until(); return !!u && u > new Date() }
    function quiet(minutes) {
        let d
        if (minutes === -1) { d = new Date(); d.setDate(d.getDate() + 1); d.setHours(8, 0, 0, 0) }    // until tomorrow morning
        else if (minutes === 0) d = new Date(2100, 0, 1)                                                // until turned off
        else d = new Date(Date.now() + minutes * 60000)
        set("DoNotDisturb", "Until", stamp(d))
    }
    function loud() {
        const c = Object.assign({}, cfg); c.Until = ""; cfg = c
        System.run(["kwriteconfig6", "--notify", "--file", "plasmanotifyrc", "--group", "DoNotDisturb", "--key", "Until", "--delete"], () => {})
    }
    Component.onCompleted: read()
    Timer { interval: 30000; repeat: true; running: page.visible; onTriggered: page.read() }

    Card {
        SettingRow {
            title: "Do Not Disturb"
            subtitle: !page.dnd ? "Off: notifications show as they come"
                    : page.until().getFullYear() >= 2100 ? "On until you turn it off"
                    : "On until " + Qt.formatDateTime(page.until(), page.until().getDate() === new Date().getDate() ? "h:mm AP" : "dddd h:mm AP")
            icon: "notifications-disabled-symbolic"
            Toggle { checked: page.dnd; onToggled: (on) => on ? page.quiet(0) : page.loud() }
        }
        SettingRow {
            visible: !page.dnd
            title: "Quiet for a while"
            Btn { text: "1 hour"; onClicked: page.quiet(60) }
            Btn { text: "Until tomorrow"; onClicked: page.quiet(-1) }
        }
        SettingRow {
            title: "Let urgent ones through"
            subtitle: "Critical notifications (a low battery) show even in Do Not Disturb"
            Toggle { checked: page.cfg.CriticalInDndMode !== "false"; onToggled: (on) => page.set("Notifications", "CriticalInDndMode", on) }
        }
    }

    Section { title: "Quiet automatically" }
    Card {
        SettingRow {
            title: "While sharing the screen"
            subtitle: "In a video call or a recording"
            Toggle { checked: page.cfg.WhenScreenSharing !== "false"; onToggled: (on) => page.set("DoNotDisturb", "WhenScreenSharing", on) }
        }
        SettingRow {
            title: "While mirroring to a projector"
            Toggle { checked: page.cfg.WhenScreensMirrored !== "false"; onToggled: (on) => page.set("DoNotDisturb", "WhenScreensMirrored", on) }
        }
    }

    Section { title: "How they appear" }
    Card {
        SettingRow {
            title: "Sounds"
            Toggle { checked: page.cfg.NotificationSoundsMuted !== "true"; onToggled: (on) => page.set("DoNotDisturb", "NotificationSoundsMuted", !on) }
        }
        SettingRow {
            title: "Where they appear"
            Choice {
                options: page.places.map(p => p[1])
                current: page.places.findIndex(p => String(p[0]) === page.cfg.PopupPosition)
                onPicked: (i) => page.set("Notifications", "PopupPosition", page.places[i][0])
            }
        }
        SettingRow {
            title: "How long they stay"
            Choice {
                options: page.stays.map(s => s[1])
                current: page.stays.findIndex(s => String(s[0]) === page.cfg.PopupTimeout)
                onPicked: (i) => page.set("Notifications", "PopupTimeout", page.stays[i][0])
            }
        }
        SettingRow {
            title: "Show less important ones too"
            subtitle: "Updates finished, files downloaded and the like"
            Toggle { checked: page.cfg.LowPriorityPopups !== "false"; onToggled: (on) => page.set("Notifications", "LowPriorityPopups", on) }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Each app's notifications"
            subtitle: "Which apps may notify you, and how"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_notifications"])
        }
    }
}
