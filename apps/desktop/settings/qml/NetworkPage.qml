import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Network (NetworkManager, nmcli): wired connections, Tower (Hangar's private
// network, Tailscale), VPNs, and a hotspot sharing this computer's connection.
SettingsPage {
    id: page
    title: "Network"

    property var wired: []         // {dev, state, con, ip, speed}
    property var vpns: []          // {name, type, active}
    property string tower: ""      // Running, NeedsLogin, Stopped, "" (not installed)
    property string towerName: ""
    property string towerIp: ""
    property int towerPeers: 0
    property string towerCode: ""   // waiting for Hangar to approve this code
    property string towerUrl: ""
    property bool towerKey: false   // the join key field is open
    property bool hotspot: false
    property bool canHotspot: false
    property string hsName: ""
    property string hsPass: ""
    property string busy: ""
    property string error: ""

    function split(line) {
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
        System.run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], (o) => {
            const list = []
            const devs = o.split("\n").map(split).filter(f => f.length >= 4)
            canHotspot = devs.some(f => f[1] === "wifi")
            for (const f of devs.filter(f => f[1] === "ethernet")) {
                const d = { dev: f[0], state: f[2], con: f[3], ip: "", speed: "" }
                list.push(d)
                System.run(["nmcli", "-g", "IP4.ADDRESS", "device", "show", f[0]], (ip) => { d.ip = ip.trim().split("\n")[0].replace(/\/\d+$/, ""); wired = list.slice() })
                System.run(["cat", "/sys/class/net/" + f[0] + "/speed"], (sp, c) => { const n = parseInt(sp); d.speed = c === 0 && n > 0 ? (n >= 1000 ? n / 1000 + " Gb/s" : n + " Mb/s") : ""; wired = list.slice() })
            }
            wired = list
        })
        System.run(["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"], (o) => {
            const rows = o.split("\n").map(split).filter(f => f.length >= 3)
            vpns = rows.filter(f => f[1] === "vpn" || f[1] === "wireguard").map(f => ({ name: f[0], type: f[1], active: f[2] === "yes" }))
            const hs = rows.find(f => f[0] === "Hotspot")
            hotspot = !!hs && hs[2] === "yes"
            if (hotspot) {
                System.run(["nmcli", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.psk", "connection", "show", "Hotspot"], (h) => {
                    const p = h.trim().split("\n"); hsName = p[0] || ""; hsPass = p[1] || ""
                })
            }
        })
        System.run(["tailscale", "status", "--json"], (o, code) => {
            if (code === 127) { tower = ""; return }
            try {
                const j = JSON.parse(o)
                tower = j.BackendState || ""
                towerName = (j.Self && j.Self.DNSName || "").split(".")[0]
                towerIp = (j.TailscaleIPs || [])[0] || ""
                towerPeers = Object.values(j.Peer || {}).filter(p => p.Online).length
                if (tower === "Running") { towerCode = ""; towerUrl = ""; towerKey = false }
                // Waiting for approval (also after Settings was closed and opened again).
                else if (j.AuthURL) { towerUrl = j.AuthURL; towerCode = j.AuthURL.split("/").pop() }
            } catch (e) { tower = "Stopped" }
        })
    }
    // The key from Hangar's join command (…--authkey KEY / --auth-key=KEY), or a bare key.
    function keyOf(t) {
        t = t.trim()
        const m = t.match(/--auth-?key[= ]['"]?([A-Za-z0-9_-]+)/)
        return m ? m[1] : t.split(/\s+/).pop().replace(/['"]/g, "")
    }
    // Tower, through cybroid-tower (pkexec: an administrator, once).
    function towerDo(args) {
        busy = "tower"; error = ""
        // On and off as this computer's Tower operator first (no password).
        const cmd = args[0] === "on" || args[0] === "off"
            ? ["sh", "-c", "/usr/libexec/cybroid/cybroid-tower \"$1\" 2>/dev/null || pkexec /usr/libexec/cybroid/cybroid-tower \"$1\"", "sh", args[0]]
            : ["pkexec", "/usr/libexec/cybroid/cybroid-tower"].concat(args)
        System.run(cmd, (out, code) => {
            busy = ""
            if (code === 126) { refresh(); return }            // the password prompt was dismissed
            const c = (out.match(/^CODE (\S+)/m) || [])[1], u = (out.match(/^URL (\S+)/m) || [])[1]
            if (c) { towerCode = c; towerUrl = u || "" }
            else if (code !== 0) error = "Tower: " + (out.trim().split("\n").pop() || "couldn't connect")
            refresh()
        })
    }
    function run(what, args) {
        busy = what; error = ""
        System.run(args, (out, code) => { busy = ""; if (code !== 0) error = out.trim().split("\n").pop(); refresh() })
    }
    Component.onCompleted: refresh()
    Timer { interval: 5000; repeat: true; running: page.visible && page.busy === ""; onTriggered: page.refresh() }

    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: Theme.bad
        wrapMode: Text.WordWrap
    }

    Section { title: "Wired" }
    Card {
        Repeater {
            model: page.wired
            SettingRow {
                required property var modelData
                title: modelData.con !== "" && modelData.con !== "--" ? modelData.con : "Ethernet (" + modelData.dev + ")"
                subtitle: modelData.state === "connected" ? "Connected" + (modelData.ip ? " · " + modelData.ip : "") + (modelData.speed ? " · " + modelData.speed : "")
                        : modelData.state === "unavailable" ? "Cable unplugged" : modelData.state
                icon: "network-wired-symbolic"
                iconColor: modelData.state === "connected" ? Theme.ok : Theme.soft
                Btn {
                    visible: modelData.state === "connected" || modelData.state === "disconnected"
                    text: modelData.state === "connected" ? "Disconnect" : "Connect"
                    enabled: page.busy === ""
                    onClicked: page.run(modelData.dev, ["nmcli", "device", modelData.state === "connected" ? "disconnect" : "connect", modelData.dev])
                }
            }
        }
        SettingRow { visible: page.wired.length === 0; title: "No wired network port" }
    }

    Section { title: "Tower and VPN"; caption: "Tower is your school's private network: reach your devices and Hangar from anywhere" }
    Card {
        SettingRow {
            title: "Tower"
            subtitle: page.busy === "tower" ? "Working…"
                    : page.tower === "" ? "Tower's client isn't installed"
                    : page.tower === "Running" ? "Connected as " + page.towerName + (page.towerIp ? " · " + page.towerIp : "") + " · " + page.towerPeers + (page.towerPeers === 1 ? " device online" : " devices online")
                    : page.towerCode !== "" ? "Waiting for approval in Hangar"
                    : page.tower === "Stopped" ? "Linked, switched off"
                    : "Not linked: approve this computer in Hangar, or paste a join command from it"
            icon: "network-vpn-symbolic"
            iconColor: page.tower === "Running" ? Theme.ok : Theme.soft
            // Linked: on and off. Not linked: Link.
            Toggle {
                visible: page.tower === "Running" || page.tower === "Stopped"
                checked: page.tower === "Running"
                enabled: page.busy === ""
                onToggled: (on) => page.towerDo([on ? "on" : "off"])
            }
            Btn {
                visible: page.tower !== "" && page.tower !== "Running" && page.tower !== "Stopped" && page.towerCode === ""
                text: "Link"
                primary: true
                enabled: page.busy === ""
                onClicked: page.towerDo(["link"])
            }
        }
        // Approving: the code Hangar asks for (Tower → Approve a device).
        SettingRow {
            visible: page.towerCode !== "" && page.tower !== "Running"
            title: page.towerCode
            subtitle: "In Hangar: Network → Add a device, paste this code and press Approve. This page updates by itself."
            icon: "dialog-password-symbolic"
            iconColor: Theme.accent
            TextEdit { id: clip; visible: false; text: page.towerCode }
            Btn { text: "Copy"; onClicked: { clip.selectAll(); clip.copy() } }
        }
        // Or a one-time join key, made in Hangar (Tower → Join key).
        SettingRow {
            visible: page.tower !== "" && page.tower !== "Running" && page.tower !== "Stopped"
            title: "Have a join command?"
            subtitle: "Hangar's Network → Add a device → Make a join command: paste it (or its key) here"
            icon: "network-connect-symbolic"
            iconColor: Theme.soft
            Field {
                id: joinKey
                visible: page.towerKey
                implicitWidth: 220
                placeholderText: "Paste the command or key"
                echoMode: TextInput.Password
                onAccepted: if (text.trim()) { page.towerDo(["link", page.keyOf(text)]); text = "" }
            }
            Btn {
                text: page.towerKey ? "Join" : "Paste"
                enabled: page.busy === "" && (!page.towerKey || joinKey.text.trim() !== "")
                onClicked: {
                    if (!page.towerKey) { page.towerKey = true; joinKey.forceActiveFocus(); return }
                    page.towerDo(["link", page.keyOf(joinKey.text)]); joinKey.text = ""
                }
            }
        }
        SettingRow {
            visible: page.tower === "Running" || page.tower === "Stopped"
            title: "Leave Tower"
            subtitle: "This computer is removed from your private network until linked again"
            clickable: true
            chevron: false
            onClicked: page.towerDo(["unlink"])
        }
        Repeater {
            model: page.vpns
            SettingRow {
                required property var modelData
                title: modelData.name
                subtitle: page.busy === modelData.name ? "Working…" : modelData.active ? "Connected" : (modelData.type === "wireguard" ? "WireGuard" : "VPN")
                icon: "network-vpn-symbolic"
                iconColor: modelData.active ? Theme.ok : Theme.soft
                Toggle {
                    checked: modelData.active
                    enabled: page.busy === ""
                    onToggled: (on) => page.run(modelData.name, ["nmcli", "connection", on ? "up" : "down", "id", modelData.name])
                }
            }
        }
        SettingRow {
            title: "Add a VPN"
            subtitle: "From a file your school or provider gave you, or by hand"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_networkmanagement"])
        }
    }

    Section { visible: page.canHotspot; title: "Hotspot"; caption: "Share this computer's connection with phones and other computers over Wi-Fi" }
    Card {
        visible: page.canHotspot
        SettingRow {
            title: "Hotspot"
            subtitle: page.busy === "hotspot" ? "Working…" : page.hotspot ? "On · “" + page.hsName + "”" : "Off (Wi-Fi is used for the hotspot while it is on)"
            icon: "network-wireless-hotspot-symbolic"
            Toggle {
                checked: page.hotspot
                enabled: page.busy === ""
                onToggled: (on) => {
                    if (!on) { page.run("hotspot", ["nmcli", "connection", "down", "id", "Hotspot"]); return }
                    // A fresh 12-letter password from the kernel's random source
                    // (no 0/o or 1/l, easy to read out and type on a phone).
                    page.busy = "hotspot"
                    System.run(["sh", "-c", "hostname -s; tr -dc 'a-km-np-z2-9' </dev/urandom | head -c 12"], (o) => {
                        const p = o.trim().split("\n")
                        page.run("hotspot", ["nmcli", "device", "wifi", "hotspot", "ssid", p[0] + " hotspot", "password", p[1]])
                    })
                }
            }
        }
        SettingRow {
            visible: page.hotspot
            title: "Password"
            Label { text: page.hsPass; color: Theme.soft; font.family: Theme.mono }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Proxy, DNS and advanced settings"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_networkmanagement"])
        }
    }
}
