import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// Bluetooth through BlueZ (bluetoothctl): on or off, this computer's name,
// your devices (connect, disconnect, forget, battery), and devices nearby to
// pair. A PIN or a confirmation is asked by KDE's Bluetooth agent (bluedevil).
SettingsPage {
    id: page
    title: "Bluetooth"

    property bool present: true
    property bool powered: false
    property string alias: ""
    property var mine: []          // {mac, name, icon, connected, battery}
    property var nearby: []        // {mac, name}
    property bool scanning: false
    property string busy: ""       // the device being changed
    property string error: ""
    property bool renaming: false

    function field(text, key) {
        const m = text.match(new RegExp("^\\s*" + key + ":\\s*(.*)$", "m"))
        return m ? m[1].trim() : ""
    }
    function devices(out) {
        const list = []
        for (const l of out.split("\n")) {
            const m = l.match(/^Device ([0-9A-F:]{17}) (.*)$/)
            if (m) list.push({ mac: m[1], name: m[2] })
        }
        return list
    }
    function refresh() {
        System.run(["bluetoothctl", "show"], (out, code) => {
            present = code === 0 && out.indexOf("Controller") >= 0
            powered = field(out, "Powered") === "yes"
            alias = field(out, "Alias")
            if (!present || !powered) { mine = []; return }
            System.run(["bluetoothctl", "devices", "Paired"], (o) => {
                const list = devices(o)
                const done = []
                if (!list.length) { mine = []; listNearby(); return }
                for (const d of list) {
                    System.run(["bluetoothctl", "info", d.mac], (info) => {
                        const b = info.match(/Battery Percentage:.*\((\d+)\)/)
                        done.push({ mac: d.mac, name: field(info, "Alias") || d.name, icon: field(info, "Icon"),
                                    connected: field(info, "Connected") === "yes", battery: b ? parseInt(b[1]) : -1 })
                        if (done.length === list.length) {
                            mine = done.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
                            listNearby()
                        }
                    })
                }
            })
        })
    }
    function listNearby() {
        System.run(["bluetoothctl", "devices"], (o) => {
            const known = mine.map(d => d.mac)
            // Devices without a name show only their address: left out.
            nearby = devices(o).filter(d => known.indexOf(d.mac) < 0 && d.name.replace(/-/g, ":") !== d.mac)
        })
    }
    function scan() {
        scanning = true
        System.run(["bluetoothctl", "--timeout", "12", "scan", "on"], () => { scanning = false; refresh() })
        later.start()
    }
    function act(mac, args, then) {
        busy = mac; error = ""
        System.run(["bluetoothctl"].concat(args), (out, code) => {
            if (then) then(out, code)
            else { busy = ""; if (code !== 0 || /Failed|not available/.test(out)) error = "That didn't work: " + out.trim().split("\n").pop() ; refresh() }
        })
    }
    function pair(d) {
        act(d.mac, ["pair", d.mac], (out, code) => {
            if (code !== 0 || /Failed/.test(out)) { busy = ""; error = "Couldn't pair with " + d.name + ". Put it in pairing mode and try again."; refresh(); return }
            System.run(["bluetoothctl", "trust", d.mac], () => act(d.mac, ["connect", d.mac]))
        })
    }
    function iconFor(i) {
        return /audio|headset|headphone/.test(i) ? "audio-headphones-symbolic"
             : /mouse/.test(i) ? "input-mouse-symbolic" : /keyboard/.test(i) ? "input-keyboard-symbolic"
             : /phone/.test(i) ? "phone-symbolic" : /computer/.test(i) ? "computer-symbolic"
             : /gaming|joystick/.test(i) ? "input-gaming-symbolic" : "bluetooth-symbolic"
    }
    Component.onCompleted: refresh()
    Timer { id: later; interval: 3000; repeat: true; running: page.scanning; onTriggered: page.listNearby() }
    Timer { interval: 5000; repeat: true; running: page.visible && !page.scanning && page.busy === ""; onTriggered: page.refresh() }

    Card {
        SettingRow {
            title: "Bluetooth"
            subtitle: !page.present ? "This computer has no Bluetooth (or it is switched off with a key or in the firmware)"
                    : page.powered ? "On · seen by others as “" + page.alias + "”" : "Off"
            icon: "bluetooth-symbolic"
            Toggle {
                enabled: page.present
                checked: page.present && page.powered
                onToggled: (on) => { page.powered = on; System.run(["bluetoothctl", "power", on ? "on" : "off"], () => page.refresh()) }
            }
        }
        SettingRow {
            visible: page.present && page.powered && !page.renaming
            title: "Name"
            subtitle: "How this computer appears to phones and other devices"
            clickable: true
            chevron: false
            onClicked: { page.renaming = true; nameField.text = page.alias; nameField.forceActiveFocus() }
            Label { text: page.alias; color: Theme.soft }
            Kirigami.Icon { implicitWidth: 14; implicitHeight: 14; source: "document-edit-symbolic"; isMask: true; color: Theme.faint }
        }
        SettingRow {
            visible: page.renaming
            title: "Name"
            Field { id: nameField; implicitWidth: 220; onAccepted: saveName.clicked() }
            Btn { text: "Cancel"; onClicked: page.renaming = false }
            Btn {
                id: saveName
                text: "Save"; primary: true
                enabled: nameField.text.trim() !== ""
                onClicked: System.run(["bluetoothctl", "system-alias", nameField.text.trim()], () => { page.renaming = false; page.refresh() })
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

    Section { visible: page.powered; title: "My devices" }
    Card {
        visible: page.powered
        Repeater {
            model: page.mine
            SettingRow {
                required property var modelData
                title: modelData.name
                subtitle: page.busy === modelData.mac ? "Working…"
                        : (modelData.connected ? "Connected" : "Not connected") + (modelData.battery >= 0 ? " · Battery " + modelData.battery + "%" : "")
                icon: page.iconFor(modelData.icon)
                iconColor: modelData.connected ? Theme.accent : Theme.soft
                Btn {
                    text: modelData.connected ? "Disconnect" : "Connect"
                    enabled: page.busy === ""
                    onClicked: page.act(modelData.mac, [modelData.connected ? "disconnect" : "connect", modelData.mac])
                }
                Btn {
                    text: "Forget"
                    danger: true
                    enabled: page.busy === ""
                    onClicked: page.act(modelData.mac, ["remove", modelData.mac])
                }
            }
        }
        SettingRow {
            visible: page.mine.length === 0
            title: "No devices yet"
            subtitle: "Devices you pair appear here"
        }
    }

    RowLayout {
        visible: page.powered
        Layout.fillWidth: true
        Section { Layout.fillWidth: true; title: "Nearby"; caption: "Put the device in pairing mode, then choose it" }
        Btn {
            Layout.topMargin: 14
            text: page.scanning ? "Looking…" : "Look for devices"
            enabled: !page.scanning
            onClicked: page.scan()
        }
    }
    Card {
        visible: page.powered && (page.scanning || page.nearby.length > 0)
        Repeater {
            model: page.nearby
            SettingRow {
                required property var modelData
                title: modelData.name
                subtitle: page.busy === modelData.mac ? "Pairing…" : ""
                icon: "bluetooth-symbolic"
                iconColor: Theme.soft
                clickable: page.busy === ""
                chevron: false
                onClicked: page.pair(modelData)
                Btn { text: "Pair"; primary: true; enabled: page.busy === ""; onClicked: page.pair(modelData) }
            }
        }
        SettingRow {
            visible: page.nearby.length === 0
            title: "Looking for devices…"
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Send a file to a device"
            clickable: true
            onClicked: System.launch(["bluedevil-sendfile"])
        }
        SettingRow {
            title: "Advanced Bluetooth settings"
            subtitle: "Receiving files, adapters"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_bluetooth"])
        }
    }
}
