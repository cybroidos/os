import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// Keyboard: layouts (KDE's kxkbrc, the keyboard daemon told to reload),
// key repeat and Num Lock (kcminputrc, applied now with xset), and a place
// to try them; shortcuts in KDE's page.
SettingsPage {
    id: page
    title: "Keyboard"

    property var all: []           // [{code, name}] from XKB's list
    property var layouts: []       // [{code, variant}]
    property int delay: 600
    property int rate: 25
    property string numlock: "2"   // 0 on, 1 off, 2 as it was

    function name(code, variant) {
        const l = all.find(a => a.code === code)
        return (l ? l.name : code) + (variant ? " (" + variant + ")" : "")
    }
    function read() {
        System.run(["sh", "-c", "sed -n '/^! layout/,/^$/p' /usr/share/X11/xkb/rules/evdev.lst"], (o) => {
            all = o.split("\n").slice(1).map(l => l.trim()).filter(l => l !== "")
                   .map(l => { const i = l.search(/\s/); return { code: l.slice(0, i), name: l.slice(i).trim() } })
                   .sort((a, b) => a.name.localeCompare(b.name))
        })
        System.run(["kreadconfig6", "--file", "kxkbrc", "--group", "Layout", "--key", "LayoutList"], (o) => {
            const codes = o.trim()
            System.run(["kreadconfig6", "--file", "kxkbrc", "--group", "Layout", "--key", "VariantList"], (v) => {
                const vs = v.trim().split(",")
                if (codes === "") {
                    // Not set in KDE yet: the system's layout (Debian's installer setting).
                    System.run(["sh", "-c", ". /etc/default/keyboard 2>/dev/null; echo \"$XKBLAYOUT|$XKBVARIANT\""], (d) => {
                        const p = d.trim().split("|")
                        layouts = p[0].split(",").filter(c => c).map((c, i) => ({ code: c, variant: (p[1] || "").split(",")[i] || "" }))
                    })
                } else layouts = codes.split(",").map((c, i) => ({ code: c, variant: vs[i] || "" }))
            })
        })
        System.run(["kreadconfig6", "--file", "kcminputrc", "--group", "Keyboard", "--key", "RepeatDelay"], (o) => delay = parseInt(o) || 600)
        System.run(["kreadconfig6", "--file", "kcminputrc", "--group", "Keyboard", "--key", "RepeatRate"], (o) => rate = Math.round(parseFloat(o)) || 25)
        System.run(["kreadconfig6", "--file", "kcminputrc", "--group", "Keyboard", "--key", "NumLock"], (o) => numlock = o.trim() || "2")
    }
    function saveLayouts(list) {
        layouts = list
        const w = (k, v) => System.run(["kwriteconfig6", "--file", "kxkbrc", "--group", "Layout", "--key", k, v], () => {})
        w("Use", "true")
        w("LayoutList", list.map(l => l.code).join(","))
        System.run(["kwriteconfig6", "--file", "kxkbrc", "--group", "Layout", "--key", "VariantList", list.map(l => l.variant).join(",")], () =>
            System.run(["dbus-send", "--session", "--type=signal", "/Layouts", "org.kde.keyboard.reloadConfig"], () => {}))
    }
    function saveRepeat() {
        System.run(["kwriteconfig6", "--file", "kcminputrc", "--group", "Keyboard", "--key", "RepeatDelay", String(delay)], () => {})
        System.run(["kwriteconfig6", "--file", "kcminputrc", "--group", "Keyboard", "--key", "RepeatRate", String(rate)], () => {})
        System.run(["kwriteconfig6", "--file", "kcminputrc", "--group", "Keyboard", "--key", "KeyRepeat", "repeat"], () => {})
        System.run(["xset", "r", "rate", String(delay), String(rate)], () => {})
    }
    Component.onCompleted: read()
    Timer { id: repeatLater; interval: 400; onTriggered: page.saveRepeat() }

    Section { title: "Layouts"; caption: "The first is used when you sign in. Switch between them with Meta+Space." }
    Card {
        Repeater {
            model: page.layouts
            SettingRow {
                required property var modelData
                required property int index
                title: page.name(modelData.code, modelData.variant)
                subtitle: index === 0 ? "Used first" : ""
                icon: "input-keyboard-symbolic"
                iconColor: index === 0 ? Theme.accent : Theme.soft
                Btn {
                    visible: index > 0
                    text: "Use first"
                    onClicked: { const l = page.layouts.slice(); const m = l.splice(index, 1)[0]; l.unshift(m); page.saveLayouts(l) }
                }
                Btn {
                    visible: page.layouts.length > 1
                    text: "Remove"
                    danger: true
                    onClicked: { const l = page.layouts.slice(); l.splice(index, 1); page.saveLayouts(l) }
                }
            }
        }
        SettingRow {
            title: "Add a layout"
            Choice {
                implicitWidth: 260
                placeholder: "Choose a language or layout"
                options: page.all.map(a => a.name)
                current: -1
                onPicked: (i) => {
                    const a = page.all[i]
                    if (!page.layouts.some(l => l.code === a.code && !l.variant)) page.saveLayouts(page.layouts.concat([{ code: a.code, variant: "" }]))
                }
            }
        }
    }

    Section { title: "Typing" }
    Card {
        SettingRow {
            title: "Repeat after"
            subtitle: "How long a key is held before it repeats"
            Slide { id: d; from: 200; to: 1000; stepSize: 50; value: page.delay; onMoved: { page.delay = value; repeatLater.restart() } }
            Label { text: page.delay + " ms"; color: Theme.soft; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
        }
        SettingRow {
            title: "Repeat speed"
            Slide { from: 10; to: 50; stepSize: 1; value: page.rate; onMoved: { page.rate = value; repeatLater.restart() } }
            Label { text: page.rate + " a second"; color: Theme.soft; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
        }
        SettingRow {
            title: "Try it"
            Field { implicitWidth: 280; placeholderText: "Hold a key down here" }
        }
        SettingRow {
            title: "Num Lock when the computer starts"
            Segmented {
                options: ["On", "Off", "As it was"]
                current: parseInt(page.numlock)
                onPicked: (i) => { page.numlock = String(i); System.run(["kwriteconfig6", "--file", "kcminputrc", "--group", "Keyboard", "--key", "NumLock", String(i)], () => {}) }
            }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Keyboard shortcuts"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_keys"])
        }
        SettingRow {
            title: "Layout variants and special keys"
            subtitle: "Compose key, Caps Lock behaviour and more"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_keyboard"])
        }
    }
}
