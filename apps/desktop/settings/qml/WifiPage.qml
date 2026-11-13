import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// Wi-Fi through NetworkManager (nmcli): on or off, the network in use, the
// ones around (strongest first), joining one (with its password when it has
// one) and forgetting a saved one.
SettingsPage {
    id: page
    title: "Wi-Fi"

    property bool hasWifi: true
    property bool radio: false
    property var networks: []      // {ssid, signal, secure, inUse, saved}
    property var saved: []
    property string joining: ""
    property string asking: ""     // the network whose password is asked for
    property string error: ""
    property bool scanning: false

    function split(line) {
        // nmcli -t escapes ':' inside fields as '\:'
        const out = []; let cur = ""
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (line[i] === ":") { out.push(cur); cur = ""; continue }
            cur += line[i]
        }
        out.push(cur)
        return out
    }
    function refresh() {
        System.run(["nmcli", "-t", "-f", "TYPE", "device"], (out) => { hasWifi = out.split("\n").indexOf("wifi") >= 0 })
        System.run(["nmcli", "-t", "-f", "WIFI", "radio"], (out) => { radio = out.trim() === "enabled" })
        System.run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], (out) => {
            saved = out.split("\n").map(split).filter(f => f[1] === "802-11-wireless").map(f => f[0])
            scan(false)
        })
    }
    function scan(rescan) {
        if (rescan) scanning = true
        System.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", rescan ? "yes" : "auto"], (out) => {
            scanning = false
            const best = {}
            for (const l of out.split("\n")) {
                const f = split(l)
                if (f.length < 4 || f[1] === "") continue
                const n = { ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--", inUse: f[0] === "*", saved: saved.indexOf(f[1]) >= 0 }
                const o = best[n.ssid]
                if (!o || n.inUse || (!o.inUse && n.signal > o.signal)) best[n.ssid] = n
            }
            networks = Object.values(best).sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
        })
    }
    function join(n, password) {
        error = ""
        if (n.secure && !n.saved && password === undefined) { asking = n.ssid; return }
        joining = n.ssid
        asking = ""
        const args = n.saved ? ["nmcli", "connection", "up", "id", n.ssid]
                             : ["nmcli", "device", "wifi", "connect", n.ssid].concat(password ? ["password", password] : [])
        System.run(args, (out, code) => {
            joining = ""
            if (code !== 0) {
                error = /secrets|password|802-1x|psk/i.test(out) ? "The password for " + n.ssid + " wasn't accepted." : "Couldn't join " + n.ssid + "."
                if (!n.saved) System.run(["nmcli", "connection", "delete", "id", n.ssid], () => {})
            }
            refresh()
        })
    }
    function forget(n) {
        System.run(["nmcli", "connection", "delete", "id", n.ssid], () => refresh())
    }
    function bars(s) { return s >= 75 ? "network-wireless-signal-excellent-symbolic" : s >= 50 ? "network-wireless-signal-good-symbolic" : s >= 25 ? "network-wireless-signal-ok-symbolic" : "network-wireless-signal-weak-symbolic" }

    Component.onCompleted: refresh()
    Timer { interval: 8000; running: page.radio && page.visible; repeat: true; onTriggered: page.scan(false) }

    Card {
        SettingRow {
            title: "Wi-Fi"
            subtitle: !page.hasWifi ? "This computer has no Wi-Fi" : page.radio ? "On" : "Off"
            icon: "network-wireless-symbolic"
            Toggle {
                enabled: page.hasWifi
                checked: page.hasWifi && page.radio
                onToggled: (on) => {
                    page.radio = on
                    System.run(["nmcli", "radio", "wifi", on ? "on" : "off"], () => { if (on) page.scan(true); else page.networks = [] })
                }
            }
        }
    }

    Section {
        visible: page.hasWifi && page.radio && page.networks.some(n => n.inUse)
        title: "Connected"
    }
    Card {
        visible: page.hasWifi && page.radio && page.networks.some(n => n.inUse)
        Repeater {
            model: page.networks.filter(n => n.inUse)
            SettingRow {
                required property var modelData
                title: modelData.ssid
                subtitle: "Connected" + (modelData.secure ? " · Secured" : " · Open network")
                icon: page.bars(modelData.signal)
                iconColor: Theme.ok
                Btn { text: "Forget"; onClicked: page.forget(modelData) }
            }
        }
    }

    RowLayout {
        visible: page.hasWifi && page.radio
        Layout.fillWidth: true
        Section { title: "Networks"; Layout.fillWidth: true }
        Btn {
            Layout.topMargin: 14
            text: page.scanning ? "Looking…" : "Look again"
            enabled: !page.scanning
            onClicked: page.scan(true)
        }
    }
    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: Theme.bad
        wrapMode: Text.WordWrap
    }
    Card {
        visible: page.hasWifi && page.radio
        Repeater {
            model: page.networks.filter(n => !n.inUse)
            Item {
                id: net
                required property var modelData
                width: parent ? parent.width : 400
                implicitHeight: r.implicitHeight + (ask.visible ? ask.implicitHeight + 12 : 0)
                SettingRow {
                    id: r
                    first: net.Positioner.index <= 0
                    title: net.modelData.ssid
                    subtitle: page.joining === net.modelData.ssid ? "Joining…" : net.modelData.saved ? "Saved" : ""
                    icon: page.bars(net.modelData.signal)
                    iconColor: Theme.soft
                    clickable: page.joining === ""
                    chevron: false
                    onClicked: page.join(net.modelData)
                    Kirigami.Icon {
                        visible: net.modelData.secure
                        implicitWidth: 14; implicitHeight: 14
                        source: "object-locked-symbolic"; isMask: true; color: Theme.faint
                    }
                    Btn {
                        visible: net.modelData.saved
                        text: "Forget"
                        onClicked: page.forget(net.modelData)
                    }
                }
                RowLayout {
                    id: ask
                    visible: page.asking === net.modelData.ssid
                    anchors.top: r.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 50
                    anchors.rightMargin: 14
                    spacing: 8
                    Field {
                        id: pw
                        Layout.fillWidth: true
                        placeholderText: "Password for " + net.modelData.ssid
                        echoMode: TextInput.Password
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onAccepted: page.join(net.modelData, text)
                    }
                    Btn { text: "Cancel"; onClicked: page.asking = "" }
                    Btn { text: "Join"; primary: true; enabled: pw.text.length >= 8; onClicked: page.join(net.modelData, pw.text) }
                }
            }
        }
        SettingRow {
            visible: page.networks.filter(n => !n.inUse).length === 0
            title: page.scanning ? "Looking for networks…" : "No other networks nearby"
            subtitle: ""
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Hidden network, VPN and advanced settings"
            subtitle: "Opens the full network settings"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_networkmanagement"])
        }
    }
}
