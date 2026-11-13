import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Displays through KScreen (kscreen-doctor): each screen's resolution,
// refresh rate, scale and rotation; with more than one, which is the main
// one, side by side or the same picture on both, and switching one off. A
// change that can leave the screen unreadable is undone after 15 seconds
// unless kept.
SettingsPage {
    id: page
    title: "Displays"

    property var outputs: []
    property string error: ""
    property var undo: []          // kscreen-doctor arguments that restore the last change
    property int countdown: 0

    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    readonly property var rotations: [["normal", 1, "Normal"], ["left", 2, "Turned left"], ["inverted", 4, "Upside down"], ["right", 8, "Turned right"]]

    function refresh() {
        System.run(["kscreen-doctor", "-j"], (out) => {
            try {
                const j = JSON.parse(out.slice(out.indexOf("{")))
                outputs = j.outputs.filter(o => o.connected).sort((a, b) => (a.priority || 99) - (b.priority || 99))
            } catch (e) { }
        })
    }
    function apply(args, revert) {
        error = ""
        System.run(["kscreen-doctor"].concat(args), (out, code) => {
            if (code !== 0) error = "Couldn't change the display: " + out.trim().split("\n").pop()
            else if (revert) { undo = revert; countdown = 15 }
            refresh()
        })
    }
    function keep() { undo = []; countdown = 0 }
    function revertNow() { const u = undo; keep(); if (u.length) apply(u, null) }
    function label(o) {
        return /^(eDP|LVDS|DSI)/.test(o.name) ? "Built-in display" : (o.name.replace(/-\d+$/, "").replace("HDMI-A", "HDMI").replace("DisplayPort", "DisplayPort") + " display")
    }
    // The sizes a screen offers (largest first) and the rates for one size.
    function sizes(o) {
        const seen = {}, out = []
        for (const m of o.modes) {
            const k = m.size.width + "×" + m.size.height
            if (!seen[k]) { seen[k] = true; out.push({ key: k, w: m.size.width, h: m.size.height }) }
        }
        return out.sort((a, b) => b.w * b.h - a.w * a.h)
    }
    function current(o) { return o.modes.find(m => m.id === o.currentModeId) || o.modes[0] }
    function rates(o, w, h) {
        return o.modes.filter(m => m.size.width === w && m.size.height === h).sort((a, b) => b.refreshRate - a.refreshRate)
    }
    function bestMode(o, w, h) { return rates(o, w, h)[0] }

    Component.onCompleted: refresh()
    Timer {
        interval: 1000
        repeat: true
        running: page.countdown > 0
        onTriggered: { page.countdown--; if (page.countdown <= 0) page.revertNow() }
    }

    // Keep or undo the last change.
    Surface {
        visible: page.countdown > 0
        Layout.fillWidth: true
        implicitHeight: 64
        stroke: Theme.accent
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            Label { Layout.fillWidth: true; text: "Keep these display settings? Going back in " + page.countdown + " s"; font.weight: Font.DemiBold }
            Btn { text: "Go back"; onClicked: page.revertNow() }
            Btn { text: "Keep"; primary: true; onClicked: page.keep() }
        }
    }
    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: Theme.bad
        wrapMode: Text.WordWrap
    }

    // Two or more screens: how they work together.
    Section { visible: page.outputs.length > 1; title: "Screens together" }
    Card {
        visible: page.outputs.length > 1
        SettingRow {
            id: arrRow
            title: "Arrangement"
            subtitle: "One wide desktop across both, or the same picture on each (for a projector)"
            readonly property var main: page.outputs[0]
            readonly property var other: page.outputs[1]
            readonly property bool mirrored: !!main && !!other && main.pos.x === other.pos.x && main.pos.y === other.pos.y
            Segmented {
                options: ["Extend", "Mirror"]
                current: arrRow.mirrored ? 1 : 0
                onPicked: (i) => {
                    const a = page.outputs[0], b = page.outputs[1]
                    const before = ["output." + b.name + ".position." + b.pos.x + "," + b.pos.y]
                    if (i === 1) page.apply(["output." + b.name + ".position." + a.pos.x + "," + a.pos.y], before)
                    else page.apply(["output." + b.name + ".position." + (a.pos.x + Math.round(page.current(a).size.width / a.scale)) + "," + a.pos.y], before)
                }
            }
        }
    }

    Repeater {
        model: page.outputs
        ColumnLayout {
            id: od
            required property var modelData
            required property int index
            readonly property var o: modelData
            readonly property var cur: page.current(o)
            Layout.fillWidth: true
            spacing: 8
            Section {
                title: page.label(od.o) + (page.outputs.length > 1 && od.index === 0 ? " · main" : "")
                caption: od.o.enabled ? od.cur.size.width + " × " + od.cur.size.height + " at " + Math.round(od.cur.refreshRate) + " Hz" : "Switched off"
            }
            Card {
                SettingRow {
                    visible: page.outputs.length > 1
                    title: "Use this display"
                    Toggle {
                        checked: od.o.enabled
                        onToggled: (on) => page.apply(["output." + od.o.name + "." + (on ? "enable" : "disable")], ["output." + od.o.name + "." + (on ? "disable" : "enable")])
                    }
                }
                SettingRow {
                    visible: page.outputs.length > 1 && od.index > 0 && od.o.enabled
                    title: "Main display"
                    subtitle: "The top bar, the dock and new windows start here"
                    Btn { text: "Make main"; onClicked: page.apply(["output." + od.o.name + ".priority.1"], null) }
                }
                SettingRow {
                    visible: od.o.enabled
                    id: resRow
                    title: "Resolution"
                    readonly property var list: page.sizes(od.o)
                    Choice {
                        options: resRow.list.map((s, i) => s.key + (i === 0 ? " (best)" : ""))
                        current: resRow.list.findIndex(s => s.w === od.cur.size.width && s.h === od.cur.size.height)
                        onPicked: (i) => {
                            const s = resRow.list[i]
                            page.apply(["output." + od.o.name + ".mode." + page.bestMode(od.o, s.w, s.h).id], ["output." + od.o.name + ".mode." + od.cur.id])
                        }
                    }
                }
                SettingRow {
                    visible: od.o.enabled && page.rates(od.o, od.cur.size.width, od.cur.size.height).length > 1
                    id: rateRow
                    title: "Refresh rate"
                    subtitle: "Higher is smoother"
                    readonly property var list: page.rates(od.o, od.cur.size.width, od.cur.size.height)
                    Choice {
                        options: rateRow.list.map(m => (Math.round(m.refreshRate * 100) / 100) + " Hz")
                        current: rateRow.list.findIndex(m => m.id === od.cur.id)
                        onPicked: (i) => page.apply(["output." + od.o.name + ".mode." + rateRow.list[i].id], ["output." + od.o.name + ".mode." + od.cur.id])
                    }
                }
                SettingRow {
                    visible: od.o.enabled
                    title: "Scale"
                    subtitle: "Makes text and everything else larger"
                    Segmented {
                        options: page.scales.map(s => Math.round(s * 100) + "%")
                        current: page.scales.findIndex(s => Math.abs(s - od.o.scale) < 0.01)
                        onPicked: (i) => page.apply(["output." + od.o.name + ".scale." + page.scales[i]], ["output." + od.o.name + ".scale." + od.o.scale])
                    }
                }
                SettingRow {
                    visible: od.o.enabled
                    title: "Rotation"
                    Choice {
                        options: page.rotations.map(r => r[2])
                        current: page.rotations.findIndex(r => r[1] === od.o.rotation)
                        onPicked: (i) => {
                            const was = page.rotations.find(r => r[1] === od.o.rotation) || page.rotations[0]
                            page.apply(["output." + od.o.name + ".rotation." + page.rotations[i][0]], ["output." + od.o.name + ".rotation." + was[0]])
                        }
                    }
                }
            }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Night Light"
            subtitle: "Warmer colours at night: in Appearance"
            clickable: true
            onClicked: System.launch(["cybroid-settings", "appearance"])
        }
        SettingRow {
            title: "Arrange screens by dragging, and more"
            subtitle: "Opens the full display settings"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_kscreen"])
        }
    }
}
