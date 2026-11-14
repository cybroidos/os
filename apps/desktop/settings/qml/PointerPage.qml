import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Mouse and touchpad (X11 libinput): applied at once with xinput, and kept
// where KDE applies them again at sign-in and when a device is plugged in:
// touchpads in touchpadxlibinputrc (a group per device), mice in kcminputrc
// [Mouse] (every mouse alike).
SettingsPage {
    id: page
    title: "Mouse & Touchpad"

    property var pads: []          // [{id, name, tap, natural, speed, dwt}]
    property var mice: []          // [{id, name}]
    property var mouse: ({ speed: 0, natural: false, left: false, flat: false, profiles: 2 })

    // libinput's acceleration profiles, as many as the device reports
    // (adaptive, flat and, on newer ones, custom).
    function profiles(props) { return (props.match(/libinput Accel Profile Enabled \(\d+\):\s*([^\n]*)/) || [])[1] || "" }
    function profileValue(flat) {
        const v = [flat ? 0 : 1, flat ? 1 : 0]
        while (v.length < mouse.profiles) v.push(0)
        return v.join(" ")
    }

    function prop(text, name) {
        const m = text.match(new RegExp("^\\s*" + name.replace(/ /g, "\\s") + " \\(\\d+\\):\\s*([^\\n]*)$", "m"))
        return m ? m[1].trim().split(",")[0].trim() : ""
    }
    function refresh() {
        System.run(["xinput", "list", "--short"], (o) => {
            const devs = []
            for (const l of o.split("\n")) {
                const m = l.match(/↳\s*(.*?)\s+id=(\d+)\s+\[slave\s+pointer/)
                if (m && !/XTEST|Virtual core/.test(m[1])) devs.push({ id: m[2], name: m[1] })
            }
            const p = [], ms = []
            let left = devs.length
            if (!left) { pads = []; mice = [] }
            for (const d of devs)
                System.run(["xinput", "list-props", d.id], (props) => {
                    if (props.indexOf("libinput Tapping Enabled (") >= 0)
                        p.push({ id: d.id, name: d.name, tap: prop(props, "libinput Tapping Enabled") === "1",
                                 natural: prop(props, "libinput Natural Scrolling Enabled") === "1",
                                 speed: parseFloat(prop(props, "libinput Accel Speed")) || 0,
                                 dwt: prop(props, "libinput Disable While Typing Enabled") === "1" })
                    else if (props.indexOf("libinput Accel Speed (") >= 0) {
                        ms.push({ id: d.id, name: d.name })
                        mouse = { speed: parseFloat(prop(props, "libinput Accel Speed")) || 0,
                                  natural: prop(props, "libinput Natural Scrolling Enabled") === "1",
                                  left: prop(props, "libinput Left Handed Enabled") === "1",
                                  flat: /^0,\s*1/.test(profiles(props)),
                                  profiles: profiles(props).split(",").length }
                    }
                    if (--left === 0) { pads = p; mice = ms }
                })
        })
    }
    // A touchpad: now (xinput) and kept (KDE's touchpad file).
    function setPad(pad, xprop, value, key, kept) {
        System.run(["xinput", "set-prop", pad.id, xprop].concat(String(value).split(" ")), () => {})
        System.run(["kwriteconfig6", "--file", "touchpadxlibinputrc", "--group", pad.name, "--key", key, String(kept)], () => refreshLater.restart())
    }
    // Every mouse: now and kept (KDE's [Mouse] group).
    function setMice(xprop, value, key, kept) {
        for (const m of mice) System.run(["xinput", "set-prop", m.id, xprop].concat(String(value).split(" ")), () => {})
        System.run(["kwriteconfig6", "--file", "kcminputrc", "--group", "Mouse", "--key", key, String(kept)], () => refreshLater.restart())
    }
    Component.onCompleted: refresh()
    Timer { id: refreshLater; interval: 400; onTriggered: page.refresh() }

    Repeater {
        model: page.pads
        ColumnLayout {
            id: pd
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Section { title: "Touchpad"; caption: pd.modelData.name }
            Card {
                SettingRow {
                    title: "Tap to click"
                    subtitle: "A light tap clicks; two fingers for a right click"
                    Toggle { checked: pd.modelData.tap; onToggled: (on) => page.setPad(pd.modelData, "libinput Tapping Enabled", on ? 1 : 0, "tapToClick", on) }
                }
                SettingRow {
                    title: "Natural scrolling"
                    subtitle: "The page moves with your fingers, as on a phone"
                    Toggle { checked: pd.modelData.natural; onToggled: (on) => page.setPad(pd.modelData, "libinput Natural Scrolling Enabled", on ? 1 : 0, "naturalScroll", on) }
                }
                SettingRow {
                    title: "Speed"
                    Slide {
                        from: -1; to: 1; stepSize: 0.1
                        value: pd.modelData.speed
                        onMoved: page.setPad(pd.modelData, "libinput Accel Speed", value.toFixed(2), "pointerAcceleration", value.toFixed(2))
                    }
                }
                SettingRow {
                    title: "Ignore while typing"
                    subtitle: "A palm on the touchpad doesn't move the pointer"
                    Toggle { checked: pd.modelData.dwt; onToggled: (on) => page.setPad(pd.modelData, "libinput Disable While Typing Enabled", on ? 1 : 0, "disableWhileTyping", on) }
                }
            }
        }
    }

    Section { visible: page.mice.length > 0; title: "Mouse"; caption: page.mice.map(m => m.name).join(" · ") }
    Card {
        visible: page.mice.length > 0
        SettingRow {
            title: "Speed"
            Slide {
                from: -1; to: 1; stepSize: 0.1
                value: page.mouse.speed
                onMoved: page.setMice("libinput Accel Speed", value.toFixed(2), "XLbInptPointerAcceleration", value.toFixed(2))
            }
        }
        SettingRow {
            title: "Natural scrolling"
            subtitle: "The wheel moves the page the other way"
            Toggle { checked: page.mouse.natural; onToggled: (on) => page.setMice("libinput Natural Scrolling Enabled", on ? 1 : 0, "XLbInptNaturalScroll", on) }
        }
        SettingRow {
            title: "Left-handed"
            subtitle: "The right button clicks, the left one opens menus"
            Toggle { checked: page.mouse.left; onToggled: (on) => page.setMice("libinput Left Handed Enabled", on ? 1 : 0, "XLbInptLeftHanded", on) }
        }
        SettingRow {
            title: "Precise pointing"
            subtitle: "The pointer moves as far as the mouse, however fast (for drawing and games)"
            Toggle { checked: page.mouse.flat; onToggled: (on) => page.setMice("libinput Accel Profile Enabled", page.profileValue(on), "XLbInptAccelProfileFlat", on) }
        }
    }

    SettingRow {
        visible: page.pads.length === 0 && page.mice.length === 0
        title: "No mouse or touchpad found"
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Buttons, scrolling speed and more"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_mouse"])
        }
    }
}
