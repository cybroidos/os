import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Battery and power: the battery (upower), the power mode (power-profiles-
// daemon), and when the screen dims, turns off and the computer sleeps, the
// lid and the power button: KDE's power manager (PowerDevil) settings in
// powerdevilrc, which it is told to read again.
SettingsPage {
    id: page
    title: "Battery & Power"

    property var bat: null          // {percent, state, time, health}
    property var profiles: []
    property string profile: ""
    property var cfg: ({})          // "AC/Display/DimDisplayIdleTimeoutSec": value

    // Minutes offered for dimming, the screen and sleep; 0 = never.
    readonly property var times: [[60, "1 minute"], [120, "2 minutes"], [300, "5 minutes"], [600, "10 minutes"], [900, "15 minutes"], [1800, "30 minutes"], [3600, "1 hour"], [0, "Never"]]
    // PowerDevil's actions: 0 nothing, 1 sleep, 2 hibernate, 8 shut down, 16 ask, 32 lock, 64 turn off the screen.
    readonly property var lidActions: [[1, "Sleep"], [64, "Turn off the screen"], [32, "Lock the screen"], [0, "Do nothing"], [8, "Shut down"]]
    readonly property var buttonActions: [[16, "Ask what to do"], [1, "Sleep"], [8, "Shut down"], [32, "Lock the screen"], [0, "Do nothing"]]
    readonly property var keys: [
        ["Display", "DimDisplayWhenIdle"], ["Display", "DimDisplayIdleTimeoutSec"],
        ["Display", "TurnOffDisplayWhenIdle"], ["Display", "TurnOffDisplayIdleTimeoutSec"],
        ["SuspendAndShutdown", "AutoSuspendAction"], ["SuspendAndShutdown", "AutoSuspendIdleTimeoutSec"],
        ["SuspendAndShutdown", "LidAction"], ["SuspendAndShutdown", "PowerButtonAction"]]
    // PowerDevil's own defaults, for keys never written.
    readonly property var defaults: ({ "DimDisplayWhenIdle": "true", "DimDisplayIdleTimeoutSec": "300", "TurnOffDisplayWhenIdle": "true",
                                       "TurnOffDisplayIdleTimeoutSec": "600", "AutoSuspendAction": "1", "AutoSuspendIdleTimeoutSec": "900",
                                       "LidAction": "1", "PowerButtonAction": "16" })

    function read() {
        for (const mode of ["AC", "Battery"]) for (const k of keys) {
            const key = mode + "/" + k[0] + "/" + k[1]
            System.run(["kreadconfig6", "--file", "powerdevilrc", "--group", mode, "--group", k[0], "--key", k[1]], (o) => {
                const c = Object.assign({}, cfg)
                c[key] = o.trim() !== "" ? o.trim() : (mode === "Battery" && k[1] === "AutoSuspendIdleTimeoutSec" ? "600" : defaults[k[1]])
                cfg = c
            })
        }
    }
    function get(mode, group, key) { return cfg[mode + "/" + group + "/" + key] || "" }
    function set(mode, group, key, value) {
        const c = Object.assign({}, cfg); c[mode + "/" + group + "/" + key] = String(value); cfg = c
        // Lid and power button apply on mains and on battery alike.
        const modes = (key === "LidAction" || key === "PowerButtonAction") ? ["AC", "Battery", "LowBattery"] : [mode]
        let left = modes.length
        for (const m of modes)
            System.run(["kwriteconfig6", "--file", "powerdevilrc", "--group", m, "--group", group, "--key", key, String(value)], () => {
                if (--left === 0) System.run(["qdbus6", "org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement",
                                              "org.kde.Solid.PowerManagement.reparseConfiguration"], () => {})
            })
    }
    // A timeout: 0 means its "when idle" switch is off.
    function timeIndex(mode, group, whenKey, secKey) {
        if (whenKey && get(mode, group, whenKey) === "false") return times.length - 1
        if (!whenKey && get(mode, group, "AutoSuspendAction") === "0") return times.length - 1
        const s = parseInt(get(mode, group, secKey)) || 0
        let best = 0
        for (let i = 0; i < times.length - 1; i++) if (Math.abs(times[i][0] - s) < Math.abs(times[best][0] - s)) best = i
        return best
    }
    function setTime(mode, group, whenKey, secKey, i) {
        const t = times[i][0]
        if (whenKey) set(mode, group, whenKey, t > 0 ? "true" : "false")
        else set(mode, group, "AutoSuspendAction", t > 0 ? 1 : 0)
        if (t > 0) set(mode, group, secKey, t)
    }
    function refresh() {
        System.run(["sh", "-c", "upower -e | grep -m1 battery_ | xargs -r upower -i"], (o) => {
            if (o.indexOf("percentage") < 0) { bat = null; return }
            const f = (k) => ((o.match(new RegExp("^\\s*" + k + ":\\s*(.*)$", "m")) || [])[1] || "").trim()
            const full = parseFloat(f("energy-full")), design = parseFloat(f("energy-full-design"))
            bat = { percent: parseInt(f("percentage")), state: f("state"),
                    time: f("time to empty") || f("time to full"),
                    health: full > 0 && design > 0 ? Math.min(100, Math.round(full / design * 100)) : -1 }
        })
        System.run(["powerprofilesctl", "list"], (o) => {
            profiles = (o.match(/^[ *]+([a-z-]+):$/gm) || []).map(l => l.replace(/[ *:]/g, ""))
                       .sort((a, b) => ["power-saver", "balanced", "performance"].indexOf(a) - ["power-saver", "balanced", "performance"].indexOf(b))
        })
        System.run(["powerprofilesctl", "get"], (o) => profile = o.trim())
    }
    Component.onCompleted: { refresh(); read() }
    Timer { interval: 10000; repeat: true; running: page.visible; onTriggered: page.refresh() }

    component Timeouts: Card {
        id: to
        property string mode: "AC"
        SettingRow {
            title: "Dim the screen after"
            Choice {
                options: page.times.map(t => t[1])
                current: page.timeIndex(to.mode, "Display", "DimDisplayWhenIdle", "DimDisplayIdleTimeoutSec")
                onPicked: (i) => page.setTime(to.mode, "Display", "DimDisplayWhenIdle", "DimDisplayIdleTimeoutSec", i)
            }
        }
        SettingRow {
            title: "Turn off the screen after"
            Choice {
                options: page.times.map(t => t[1])
                current: page.timeIndex(to.mode, "Display", "TurnOffDisplayWhenIdle", "TurnOffDisplayIdleTimeoutSec")
                onPicked: (i) => page.setTime(to.mode, "Display", "TurnOffDisplayWhenIdle", "TurnOffDisplayIdleTimeoutSec", i)
            }
        }
        SettingRow {
            title: "Sleep after"
            Choice {
                options: page.times.map(t => t[1])
                current: page.timeIndex(to.mode, "SuspendAndShutdown", "", "AutoSuspendIdleTimeoutSec")
                onPicked: (i) => page.setTime(to.mode, "SuspendAndShutdown", "", "AutoSuspendIdleTimeoutSec", i)
            }
        }
    }

    // The battery, large.
    Surface {
        visible: page.bat !== null
        Layout.fillWidth: true
        implicitHeight: 96
        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18
            Label {
                text: page.bat ? page.bat.percent + "%" : ""
                font.family: Theme.hex ? Theme.mono : Theme.font
                font.pixelSize: 36
                font.weight: Theme.hex ? Font.Medium : Font.Light
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Label {
                    text: !page.bat ? "" : page.bat.state === "charging" ? "Charging" + (page.bat.time ? " · full in " + page.bat.time : "")
                        : page.bat.state === "fully-charged" ? "Fully charged" : page.bat.state === "discharging" ? "On battery" + (page.bat.time ? " · " + page.bat.time + " left" : "")
                        : "Plugged in, not charging"
                    color: Theme.soft
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    Surface { anchors.fill: parent; radius: 4; cut: 0; fill: Theme.track; strokeWidth: 0 }
                    Surface {
                        width: parent.width * (page.bat ? page.bat.percent / 100 : 0); height: parent.height
                        radius: 4; cut: 0; strokeWidth: 0
                        fill: page.bat && page.bat.percent <= 15 ? Theme.bad : page.bat && page.bat.state === "charging" ? Theme.ok : Theme.accent
                    }
                }
            }
        }
    }

    Section { visible: page.profiles.length > 1; title: "Power mode" }
    Card {
        visible: page.profiles.length > 1
        SettingRow {
            title: page.profile === "power-saver" ? "Battery saver" : page.profile === "performance" ? "Performance" : "Balanced"
            subtitle: page.profile === "power-saver" ? "Longer battery life, a little slower"
                    : page.profile === "performance" ? "Fastest, with more heat, fan and battery use" : "Speed when it's needed, saving power when it isn't"
            icon: "speedometer"
            Segmented {
                options: page.profiles.map(p => p === "power-saver" ? "Saver" : p === "performance" ? "Performance" : "Balanced")
                current: page.profiles.indexOf(page.profile)
                onPicked: (i) => { const p = page.profiles[i]; page.profile = p; System.run(["powerprofilesctl", "set", p], () => page.refresh()) }
            }
        }
    }

    Section { title: page.bat ? "When plugged in" : "Screen and sleep" }
    Timeouts { mode: "AC" }

    Section { visible: page.bat !== null; title: "On battery" }
    Timeouts { visible: page.bat !== null; mode: "Battery" }

    Section { title: "Buttons" }
    Card {
        SettingRow {
            visible: page.bat !== null
            title: "When the lid is closed"
            Choice {
                options: page.lidActions.map(a => a[1])
                current: page.lidActions.findIndex(a => String(a[0]) === page.get("AC", "SuspendAndShutdown", "LidAction"))
                onPicked: (i) => page.set("AC", "SuspendAndShutdown", "LidAction", page.lidActions[i][0])
            }
        }
        SettingRow {
            title: "When the power button is pressed"
            Choice {
                options: page.buttonActions.map(a => a[1])
                current: page.buttonActions.findIndex(a => String(a[0]) === page.get("AC", "SuspendAndShutdown", "PowerButtonAction"))
                onPicked: (i) => page.set("AC", "SuspendAndShutdown", "PowerButtonAction", page.buttonActions[i][0])
            }
        }
    }

    Section { visible: page.bat !== null && page.bat.health >= 0; title: "Battery health" }
    Card {
        visible: page.bat !== null && page.bat.health >= 0
        SettingRow {
            title: "Capacity"
            subtitle: "How much the battery holds now, compared with when it was new"
            Label { text: page.bat ? page.bat.health + "%" : ""; color: page.bat && page.bat.health < 70 ? Theme.warn : Theme.soft }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Low battery, charge limits and more"
            subtitle: "Opens the full power settings"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_powerdevilprofilesconfig"])
        }
    }
}
