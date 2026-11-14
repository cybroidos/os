/*
 * CybroidOS Control Centre (cybroid-plasma): the two-toggles icon in the top
 * bar. What people change most, done here rather than handed to Settings, as
 * macOS's Control Centre does:
 *
 *   Connections   Wi-Fi (the networks in reach; join one, its password asked
 *                 in place), Bluetooth (the devices; connect or disconnect,
 *                 pair a new one), Airplane mode, Tower.
 *   Tiles         Do Not Disturb, Appearance (Dark or Light), Night Light,
 *                 the design (Horizon or Hex), a screenshot, Settings.
 *   Display       the brightness of each display that has one (laptops, and
 *                 monitors that take DDC), and of the keyboard's backlight.
 *   Sound         the volume and mute; the output (speakers, headphones,
 *                 HDMI) chosen in place.
 *   Now Playing   what is playing in any app, with its controls.
 *
 * Brightness, Night Light, sound and media use Plasma's own models (the same
 * as its tray applets), so they always agree with the rest of the desktop and
 * need no special rights. Wi-Fi, Bluetooth and Tower are read through nmcli,
 * bluetoothctl and tailscale as the panel opens. Anything the machine lacks
 * (Bluetooth, a backlight, a sound card, Wi-Fi) simply isn't shown.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.private.volume
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    // Colours follow the colour scheme (Horizon or Hex, Dark or Light).
    readonly property color ink: Kirigami.Theme.textColor
    readonly property color soft: Qt.alpha(Kirigami.Theme.textColor, 0.68)
    readonly property color accent: Kirigami.Theme.focusColor
    readonly property color tile: Qt.alpha(Kirigami.Theme.textColor, 0.07)
    readonly property color tileOn: Kirigami.Theme.focusColor
    readonly property color onAccent: Kirigami.ColorUtils.brightnessForColor(tileOn) === Kirigami.ColorUtils.Light ? "#06122e" : "#ffffff"

    // What the panel shows, filled by refresh().
    property string netKind: ""      // "Wired", "Wi-Fi" or "" when offline
    property string netAddress: ""
    property string towerState: ""   // "Connected", "Not joined", "Off"
    property string towerAddress: ""
    property bool dark: true
    property bool hex: false
    property bool wifiOn: false      // the Wi-Fi radio
    property bool wifiHw: false      // a Wi-Fi device exists
    property bool wwanHw: false      // a mobile broadband modem exists
    property string wifiName: ""     // the network joined, if any
    property var networks: []        // [{ssid, signal, secure, active}]
    property var saved: []           // Wi-Fi networks already saved
    property bool scanning: false
    property string btState: ""      // "" (no adapter), "on", "off"
    property var btDevices: []       // [{mac, name, connected, icon}]
    property bool btBusy: false
    property bool airplane: false
    property string page: "main"     // "main", "wifi", "bluetooth" or "sound"
    property string joining: ""      // the network asking for its password
    property string joinMessage: ""
    property string btMessage: ""

    Plasmoid.icon: "cybroid-control-centre-symbolic"
    toolTipMainText: "Control Centre"
    toolTipSubText: (netKind ? netKind + " · " + netAddress : "Offline") + (dnd.on ? " · Do Not Disturb" : "")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        Layout.minimumWidth: Math.round(height * 1.2)
        Layout.preferredWidth: Math.round(height * 1.2)
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.height * 0.82); height: width
            source: Plasmoid.icon
            active: button.containsMouse || root.expanded
            // Drawn in the bar's text colour, so it shows on a light bar too.
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }

    onExpandedChanged: {
        if (root.expanded) {
            refresh()
        } else {
            root.page = "main"
            root.joining = ""
            root.joinMessage = ""
            root.btMessage = ""
        }
    }

    // ---- Plasma's own models ---------------------------------------------
    ScreenBrightnessControl { id: screens; isSilent: root.expanded }
    KeyboardBrightnessControl { id: keyboard; isSilent: root.expanded }
    NightLightControl { id: nightLight }
    SinkModel { id: sinks }
    PulseObjectFilterModel {
        id: outputs
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: sinks
    }
    Mpris.Mpris2Model { id: players }
    readonly property var player: players.currentPlayer
    readonly property var sink: PreferredDevice.sink
    // PipeWire's stand-in output when there is no sound card.
    readonly property bool hasSound: !!sink && sink.name !== "auto_null"
    readonly property real volume: hasSound ? sink.volume / PulseAudio.NormalVolume : 0
    // A card's connectors (speakers, the headphone jack, line out) are its
    // ports. Those PipeWire knows are unplugged (availability 2) are left
    // out, so the jack shows only while headphones are in it.
    function usablePorts(dev) {
        const out = [];
        const ps = dev && dev.ports ? dev.ports : [];
        for (let i = 0; i < ps.length; i++)
            if (ps[i] && ps[i].availability !== 2) out.push({ index: i, port: ps[i] });
        return out;
    }
    function portName(dev) {
        const ps = dev && dev.ports ? dev.ports : [];
        const p = ps[dev ? dev.activePortIndex : -1];
        return p && p.description ? p.description : "";
    }
    function outputIcon(text) {
        return /headphone|headset/i.test(text) ? "audio-headphones-symbolic"
            : /hdmi|displayport/i.test(text) ? "video-display-symbolic" : "audio-speakers-symbolic";
    }
    readonly property var sinkPorts: hasSound ? usablePorts(sink) : []

    // Do Not Disturb: Plasma's own setting, so its notifications obey it.
    NotificationManager.Settings { id: notifSettings }
    QtObject {
        id: dnd
        readonly property bool on: notifSettings.notificationsInhibitedUntil !== undefined
            && notifSettings.notificationsInhibitedUntil > new Date()
        function toggle() {
            if (on) {
                notifSettings.notificationsInhibitedUntil = undefined
                notifSettings.revokeApplicationInhibitions()
            } else {
                // Until turned off: a date far ahead, as Plasma's own toggle does.
                const d = new Date(); d.setFullYear(d.getFullYear() + 1)
                notifSettings.notificationsInhibitedUntil = d
            }
            notifSettings.save()
        }
    }

    // ---- Shell commands ---------------------------------------------------
    // One at a time per command line; each answer goes to its handler.
    P5Support.DataSource {
        id: sh
        engine: "executable"
        // A Map, not an object: keys added and deleted every few seconds on
        // a plain object crash Qt 6.8's JavaScript engine (QV4::Object::
        // insertMember; Hex's plasmashell fell over every minute, 2026-11-14).
        property var handlers: new Map()
        function run(cmd, handler) {
            handlers.set(cmd, handler)
            connectSource(cmd)
        }
        onNewData: (source, data) => {
            const h = handlers.get(source)
            disconnectSource(source)
            handlers.delete(source)
            if (h) h(String(data["stdout"] || ""), Number(data["exit code"]))
        }
    }
    // A word for the shell, quoted.
    function q(v) { return "'" + String(v).replace(/'/g, "'\\''") + "'" }
    // nmcli -t output: fields split on ":", its "\:" kept as ":".
    function fields(line) {
        return line.replace(/\\:/g, "\u0001").split(":").map((x) => x.replace(/\u0001/g, ":"))
    }

    function refresh() {
        // The route to the internet names the interface and our address on it.
        sh.run("ip -o -4 route get 1.1.1.1", (out, code) => {
            const dev = (out.match(/ dev (\S+)/) || [])[1] || ""
            root.netAddress = (out.match(/ src (\S+)/) || [])[1] || ""
            root.netKind = code !== 0 || !dev ? "" : (/^(wl|wifi)/.test(dev) ? "Wi-Fi" : "Wired")
        })
        sh.run("nmcli -t -f TYPE device", (out) => {
            root.wifiHw = /^wifi$/m.test(out)
            root.wwanHw = /^gsm$/m.test(out)
        })
        sh.run("nmcli -t -f WIFI,WWAN radio", (out) => {
            const f = out.trim().split(":")
            root.wifiOn = f[0] === "enabled"
            root.airplane = f[0] === "disabled" && (f[1] === "disabled" || !root.wwanHw) && root.btState !== "on"
        })
        sh.run("nmcli -t -f ACTIVE,SSID dev wifi", (out) => {
            const m = out.match(/^yes:(.*)$/m)
            root.wifiName = m ? m[1].replace(/\\:/g, ":") : ""
        })
        refreshBluetooth()
        sh.run("tailscale status --json --peers=false", (out, code) => {
            if (code !== 0 && !out) { root.towerState = "Off"; root.towerAddress = ""; return }
            try {
                const s = JSON.parse(out)
                root.towerState = s.BackendState === "Running" ? "Connected" : "Not joined"
                root.towerAddress = (s.TailscaleIPs || [])[0] || ""
            } catch (e) { root.towerState = "Off" }
        })
        sh.run("kreadconfig6 --file kdeglobals --group General --key ColorScheme", (out) => {
            root.dark = !/Light/.test(out)
            root.hex = /Hex/.test(out)
        })
    }

    // ---- Design and appearance -------------------------------------------
    function setDesign(hex) {
        root.hex = hex
        root.expanded = false
        sh.run("cybroid-appearance " + (hex ? "hex" : "horizon"), () => {})
    }
    function setAppearance(dark) {
        root.dark = dark
        sh.run("cybroid-appearance " + (dark ? "dark" : "light"), () => {})
    }

    // ---- Night Light: warmer colours after sunset in Kampala --------------
    // On: KWin's Night Light at its schedule (the warm colours only show in
    // the evening). Off: Night Light switched off.
    function setNightLight(on) {
        // --notify: KWin's Night Light listens for the change (KConfigWatcher).
        sh.run("kwriteconfig6 --notify --file kwinrc --group NightColor --key Active " + (on ? "true" : "false"), () => {})
    }

    // ---- Wi-Fi ------------------------------------------------------------
    function scan() {
        sh.run("nmcli -t -f NAME,TYPE connection show", (out) => {
            root.saved = out.split("\n").filter((l) => /:802-11-wireless$/.test(l))
                .map((l) => l.replace(/:802-11-wireless$/, "").replace(/\\:/g, ":"))
        })
        root.scanning = true
        sh.run("nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes", (out) => {
            const seen = {}
            const list = []
            for (const line of out.split("\n")) {
                const f = fields(line)
                if (f.length < 4 || !f[1] || seen[f[1]]) continue
                seen[f[1]] = true
                list.push({ ssid: f[1], signal: Number(f[2]) || 0, secure: f[3].length > 0 && f[3] !== "--", active: f[0] === "*" })
            }
            list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            // Not while a password is being typed: a new list would rebuild
            // the rows and lose it.
            if (root.joining === "") root.networks = list
            root.scanning = false
        })
    }
    function setWifi(on) {
        root.wifiOn = on
        if (on) root.airplane = false
        sh.run("nmcli radio wifi " + (on ? "on" : "off"), () => { if (on) scanTimer.start() })
    }
    Timer { id: scanTimer; interval: 2500; onTriggered: root.scan() }
    // Join: a saved network or an open one at once; a new secured one asks
    // for its password here first. nmcli keeps the password with the
    // connection, so nothing else ever asks for it.
    function join(n, password) {
        if (password === undefined && n.secure && root.saved.indexOf(n.ssid) < 0) {
            root.joinMessage = ""
            root.joining = n.ssid
            return
        }
        root.joinMessage = "Joining " + n.ssid + "…"
        const cmd = password !== undefined
            ? "nmcli dev wifi connect " + q(n.ssid) + " password " + q(password)
            : root.saved.indexOf(n.ssid) >= 0
                ? "nmcli connection up id " + q(n.ssid)
                : "nmcli dev wifi connect " + q(n.ssid)
        sh.run("sh -c " + q(cmd + " 2>&1"), (out, code) => {
            if (code === 0) {
                root.joinMessage = ""
                root.joining = ""
                root.refresh()
                root.scan()
                return
            }
            // A wrong password: the saved profile goes (it would keep
            // asking), and the password is asked here again.
            const badPassword = /secrets were required|password|802-1x|4-way|authentication/i.test(out)
            if (badPassword) {
                sh.run("nmcli connection delete id " + q(n.ssid), () => root.scan())
                root.joinMessage = "Couldn't join " + n.ssid + ": check the password."
                root.joining = n.ssid
            } else {
                // Reached the network, but no address (or out of reach).
                root.joinMessage = /IP configuration|DHCP|timeout/i.test(out)
                    ? n.ssid + " accepted the password, but gave no network address. Try again in a moment."
                    : "Couldn't join " + n.ssid + "."
                root.joining = ""
                root.scan()
            }
        })
    }
    function forget(n) {
        sh.run("nmcli connection delete id " + q(n.ssid), () => { root.refresh(); root.scan() })
    }

    // ---- Bluetooth --------------------------------------------------------
    function refreshBluetooth() {
        sh.run("bluetoothctl show", (out, code) => {
            root.btState = code !== 0 || !/Controller/.test(out) ? "" : /Powered: yes/.test(out) ? "on" : "off"
        })
        sh.run("sh -c " + q("bluetoothctl devices Paired | while read -r _ mac name; do "
            + "i=$(bluetoothctl info \"$mac\"); "
            + "c=$(echo \"$i\" | sed -n 's/.*Connected: //p'); "
            + "k=$(echo \"$i\" | sed -n 's/.*Icon: //p'); "
            + "printf '%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$c\" \"$k\" \"$name\"; done"), (out) => {
            const list = []
            for (const line of out.split("\n")) {
                const f = line.split("\t")
                if (f.length < 4 || !f[0]) continue
                list.push({ mac: f[0], connected: f[1] === "yes", icon: f[2], name: f[3] })
            }
            list.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
            root.btDevices = list
        })
    }
    function setBluetooth(on) {
        root.btState = on ? "on" : "off"
        if (on) root.airplane = false
        sh.run("bluetoothctl power " + (on ? "on" : "off"), () => root.refreshBluetooth())
    }
    function toggleDevice(d) {
        root.btBusy = true
        root.btMessage = (d.connected ? "Disconnecting " : "Connecting ") + d.name + "…"
        sh.run("bluetoothctl " + (d.connected ? "disconnect " : "connect ") + d.mac, (out, code) => {
            root.btBusy = false
            root.btMessage = code === 0 ? "" : "Couldn't connect to " + d.name + ". Is it on and nearby?"
            root.refreshBluetooth()
        })
    }
    function btIcon(kind) {
        if (/audio|headset|headphone/.test(kind)) return "audio-headphones-symbolic"
        if (/keyboard/.test(kind)) return "input-keyboard-symbolic"
        if (/mouse/.test(kind)) return "input-mouse-symbolic"
        if (/phone/.test(kind)) return "smartphone-symbolic"
        if (/computer/.test(kind)) return "computer-symbolic"
        if (/gaming|joystick/.test(kind)) return "input-gaming-symbolic"
        return "bluetooth-symbolic"
    }

    // ---- Airplane mode: every radio off, and back on ----------------------
    function setAirplane(on) {
        root.airplane = on
        if (on) {
            root.wifiOn = false
            root.btState = root.btState === "" ? "" : "off"
            sh.run("sh -c " + q("nmcli radio all off; bluetoothctl power off >/dev/null 2>&1; true"), () => root.refresh())
        } else {
            root.wifiOn = true
            sh.run("sh -c " + q("nmcli radio all on; bluetoothctl power on >/dev/null 2>&1; true"), () => { root.refresh(); laterTimer.start() })
        }
    }

    // ---- Pieces --------------------------------------------------------------

    // A tile; big ones carry a title and a status line.
    component Tile: Rectangle {
        id: t
        property string icon
        property string title
        property string detail
        property bool on: false
        property bool big: false
        signal clicked()
        // Horizon: a rounded tile. Hex: a cut panel (top-left and bottom-right
        // corners cut), drawn by the shape below.
        radius: root.hex ? 0 : 16
        readonly property color fill: area.pressed ? Qt.alpha(root.ink, 0.17) : area.containsMouse ? Qt.alpha(root.ink, 0.12) : root.tile
        color: root.hex ? "transparent" : fill
        implicitHeight: big ? 60 : 72
        Behavior on color { ColorAnimation { duration: 120 } }
        Shape {
            visible: root.hex
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1
                strokeColor: t.on ? Qt.alpha(root.accent, 0.7) : Qt.alpha(root.ink, 0.16)
                fillColor: t.fill
                startX: 12; startY: 0.5
                PathLine { x: t.width - 0.5; y: 0.5 }
                PathLine { x: t.width - 0.5; y: t.height - 12 }
                PathLine { x: t.width - 12; y: t.height - 0.5 }
                PathLine { x: 0.5; y: t.height - 0.5 }
                PathLine { x: 0.5; y: 12 }
                PathLine { x: 12; y: 0.5 }
            }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.clicked() }
        RowLayout {
            visible: t.big
            anchors.fill: parent; anchors.margins: 12
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: root.hex ? 3 : 16
                color: t.on ? root.tileOn : Qt.alpha(root.ink, 0.12)
                Kirigami.Icon { anchors.centerIn: parent; width: 17; height: 17; source: t.icon; color: t.on ? root.onAccent : root.ink; isMask: true }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                QQC2.Label { text: t.title; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                QQC2.Label { text: t.detail; color: root.soft; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true; visible: text.length > 0 }
            }
        }
        ColumnLayout {
            visible: !t.big
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: root.hex ? 3 : 16
                color: t.on ? root.tileOn : Qt.alpha(root.ink, 0.12)
                Kirigami.Icon { anchors.centerIn: parent; width: 17; height: 17; source: t.icon; color: t.on ? root.onAccent : root.ink; isMask: true }
            }
            QQC2.Label { Layout.alignment: Qt.AlignHCenter; text: t.title; color: root.ink; font.pixelSize: 12 }
        }
    }

    // A row in the connections block: the round icon turns it on or off; the
    // rest of the row opens more.
    component Toggle: Item {
        id: tg
        property string icon
        property string title
        property string detail
        property bool on: false
        property bool more: false
        signal toggled()
        signal opened()
        implicitHeight: 44
        Rectangle {
            anchors.fill: parent
            radius: root.hex ? 0 : 10
            color: rowArea.containsMouse ? Qt.alpha(root.ink, 0.07) : "transparent"
        }
        MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tg.opened() }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: root.hex ? 3 : 15
                color: tg.on ? root.tileOn : Qt.alpha(root.ink, 0.12)
                Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; source: tg.icon; color: tg.on ? root.onAccent : root.ink; isMask: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                QQC2.Label { text: tg.title; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                QQC2.Label { text: tg.detail; color: root.soft; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true; visible: text.length > 0 }
            }
            Kirigami.Icon { visible: tg.more; Layout.preferredWidth: 14; Layout.preferredHeight: 14; source: "go-next-symbolic"; color: root.soft; isMask: true }
        }
    }

    // A panel behind a group of controls: rounded (Horizon) or cut (Hex).
    component Panel: Rectangle {
        id: pn
        radius: root.hex ? 0 : 16
        color: root.hex ? "transparent" : root.tile
        Shape {
            visible: root.hex
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1; strokeColor: Qt.alpha(root.ink, 0.16); fillColor: root.tile
                startX: 12; startY: 0.5
                PathLine { x: pn.width - 0.5; y: 0.5 }
                PathLine { x: pn.width - 0.5; y: pn.height - 12 }
                PathLine { x: pn.width - 12; y: pn.height - 0.5 }
                PathLine { x: 0.5; y: pn.height - 0.5 }
                PathLine { x: 0.5; y: 12 }
                PathLine { x: 12; y: 0.5 }
            }
        }
    }

    // A slider line: an icon (a tap does iconClicked), the slider, a value.
    component SliderRow: RowLayout {
        id: sr
        property string icon
        property real from: 0
        property real to: 1
        property real value: 0
        property string valueText
        signal moved(real v)
        signal iconClicked()
        spacing: 8
        Kirigami.Icon {
            Layout.preferredWidth: 18; Layout.preferredHeight: 18
            source: sr.icon; color: root.ink; isMask: true
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sr.iconClicked() }
        }
        QQC2.Slider {
            Layout.fillWidth: true
            from: sr.from; to: sr.to
            value: sr.value
            onMoved: sr.moved(value)
        }
        QQC2.Label { visible: sr.valueText.length > 0; text: sr.valueText; color: root.soft; font.pixelSize: 11; Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight }
    }

    // A page's header: back, title, and whatever goes at the right.
    component PageHeader: RowLayout {
        id: ph
        property string title
        default property alias trailing: tail.data
        Layout.fillWidth: true
        spacing: 8
        QQC2.ToolButton {
            icon.name: "go-previous-symbolic"
            onClicked: { root.page = "main"; root.joining = ""; root.joinMessage = ""; root.btMessage = "" }
            QQC2.ToolTip.text: "Back"; QQC2.ToolTip.visible: hovered
        }
        QQC2.Label { text: ph.title; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 15; Layout.fillWidth: true }
        RowLayout { id: tail; spacing: 8 }
    }

    // ---- The panel ----------------------------------------------------------
    fullRepresentation: Item {
        Layout.preferredWidth: 380
        Layout.minimumWidth: 380
        Layout.maximumWidth: 380
        Layout.preferredHeight: (root.page === "wifi" ? wifiPage.implicitHeight
            : root.page === "bluetooth" ? btPage.implicitHeight
            : root.page === "sound" ? soundPage.implicitHeight : mainPage.implicitHeight) + 24
        Layout.minimumHeight: Layout.preferredHeight
        Keys.onEscapePressed: root.page !== "main" ? root.page = "main" : root.expanded = false

        // ---- Main ----
        ColumnLayout {
            id: mainPage
            visible: root.page === "main"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Panel {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    implicitHeight: conn.implicitHeight + 12
                    ColumnLayout {
                        id: conn
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                        spacing: 0
                        Toggle {
                            Layout.fillWidth: true
                            visible: root.wifiHw
                            icon: root.wifiOn ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"
                            title: "Wi-Fi"
                            detail: !root.wifiOn ? "Off" : root.wifiName || "Not connected"
                            on: root.wifiOn
                            more: true
                            onToggled: root.setWifi(!root.wifiOn)
                            onOpened: { root.page = "wifi"; root.scan() }
                        }
                        Toggle {
                            Layout.fillWidth: true
                            visible: !root.wifiHw || root.netKind === "Wired"
                            icon: root.netKind === "Wired" ? "network-wired-symbolic" : "network-offline-symbolic"
                            title: root.netKind === "Wired" ? "Wired" : "Offline"
                            detail: root.netKind === "Wired" ? root.netAddress : "No network"
                            on: root.netKind === "Wired"
                        }
                        Toggle {
                            Layout.fillWidth: true
                            visible: root.btState !== ""
                            icon: "network-bluetooth-symbolic"
                            title: "Bluetooth"
                            detail: root.btState !== "on" ? "Off"
                                : root.btDevices.filter((d) => d.connected).map((d) => d.name).join(", ") || "On"
                            on: root.btState === "on"
                            more: true
                            onToggled: root.setBluetooth(root.btState !== "on")
                            onOpened: { root.page = "bluetooth"; root.refreshBluetooth() }
                        }
                        Toggle {
                            Layout.fillWidth: true
                            visible: root.wifiHw || root.btState !== "" || root.wwanHw
                            icon: "network-flightmode-on-symbolic"
                            title: "Airplane mode"
                            detail: root.airplane ? "On" : "Off"
                            on: root.airplane
                            onToggled: root.setAirplane(!root.airplane)
                            onOpened: root.setAirplane(!root.airplane)
                        }
                        Toggle {
                            Layout.fillWidth: true
                            icon: "network-vpn-symbolic"
                            title: "Tower"
                            detail: root.towerState === "Connected" ? root.towerAddress : root.towerState
                            on: root.towerState === "Connected"
                            onOpened: Qt.openUrlExternally("https://tower.cybroid.com")
                            onToggled: Qt.openUrlExternally("https://tower.cybroid.com")
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 10
                    Tile {
                        Layout.fillWidth: true; big: true
                        icon: dnd.on ? "notifications-disabled-symbolic" : "notifications-symbolic"
                        title: "Do Not Disturb"
                        detail: dnd.on ? "On" : "Off"
                        on: dnd.on
                        onClicked: dnd.toggle()
                    }
                    Tile {
                        Layout.fillWidth: true; big: true
                        icon: root.dark ? "weather-clear-night-symbolic" : "weather-clear-symbolic"
                        title: "Appearance"
                        detail: root.dark ? "Dark" : "Light"
                        on: true
                        onClicked: root.setAppearance(!root.dark)
                    }
                    Tile {
                        Layout.fillWidth: true; big: true
                        visible: nightLight.available
                        icon: "redshift-status-on"
                        title: "Night Light"
                        detail: !nightLight.enabled ? "Off" : nightLight.running && nightLight.currentTemperature < 6500 ? "On now" : "At sunset"
                        on: nightLight.enabled
                        onClicked: root.setNightLight(!nightLight.enabled)
                    }
                }
            }

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: root.hex ? "view-grid-symbolic" : "preferences-desktop-theme-global-symbolic"
                    title: root.hex ? "Hex" : "Horizon"
                    on: root.hex
                    onClicked: root.setDesign(!root.hex)
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: "camera-photo-symbolic"
                    title: "Screenshot"
                    // The panel closes first, so it isn't in the picture.
                    onClicked: { root.expanded = false; shotTimer.start() }
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: "configure-symbolic"
                    title: "Settings"
                    onClicked: { root.expanded = false; sh.run("cybroid-settings", () => {}) }
                }
            }

            // Display: every screen that has a brightness (laptops, DDC
            // monitors), and the keyboard's backlight.
            Panel {
                visible: displayRepeater.count > 0 || keyboard.isBrightnessAvailable
                Layout.fillWidth: true
                implicitHeight: displayCol.implicitHeight + 24
                ColumnLayout {
                    id: displayCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 4
                    QQC2.Label { text: "Display"; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 13 }
                    Repeater {
                        id: displayRepeater
                        model: screens.isBrightnessAvailable ? screens.displays : null
                        delegate: ColumnLayout {
                            required property string displayName
                            required property string label
                            required property int brightness
                            required property int maxBrightness
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label { visible: displayRepeater.count > 1; text: label; color: root.soft; font.pixelSize: 11 }
                            SliderRow {
                                Layout.fillWidth: true
                                icon: "brightness-high-symbolic"
                                to: maxBrightness
                                value: brightness
                                valueText: Math.round(100 * brightness / Math.max(1, maxBrightness)) + "%"
                                onMoved: (v) => screens.setBrightness(displayName, Math.max(1, Math.round(v)))
                            }
                        }
                    }
                    SliderRow {
                        visible: keyboard.isBrightnessAvailable
                        Layout.fillWidth: true
                        icon: "input-keyboard-brightness"
                        to: keyboard.brightnessMax
                        value: keyboard.brightness
                        onMoved: (v) => keyboard.brightness = Math.round(v)
                    }
                }
            }

            // Sound: where there is an output. The arrow chooses it.
            Panel {
                visible: root.hasSound
                Layout.fillWidth: true
                implicitHeight: soundCol.implicitHeight + 24
                ColumnLayout {
                    id: soundCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.Label { text: "Sound"; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 13 }
                        QQC2.Label {
                            // "Headphones" once they're plugged in, else the card.
                            text: root.hasSound ? (root.portName(root.sink) || root.sink.description || "") : ""
                            color: root.soft; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                        }
                        QQC2.ToolButton {
                            visible: outputs.count > 1 || root.sinkPorts.length > 1
                            icon.name: "go-next-symbolic"
                            implicitWidth: 26; implicitHeight: 26
                            onClicked: root.page = "sound"
                            QQC2.ToolTip.text: "Output"; QQC2.ToolTip.visible: hovered
                        }
                    }
                    SliderRow {
                        Layout.fillWidth: true
                        icon: !root.hasSound || root.sink.muted || root.volume === 0 ? "audio-volume-muted"
                            : root.volume < 0.4 ? "audio-volume-low" : root.volume < 0.75 ? "audio-volume-medium" : "audio-volume-high"
                        value: Math.min(1, root.volume)
                        valueText: Math.round(Math.min(1, root.volume) * 100) + "%"
                        onMoved: (v) => { root.sink.volume = Math.round(v * PulseAudio.NormalVolume); root.sink.muted = v === 0 }
                        onIconClicked: root.sink.muted = !root.sink.muted
                    }
                }
            }

            // Now Playing: any app's music or video, with its controls.
            Panel {
                visible: !!root.player && (root.player.track || "").length > 0
                Layout.fillWidth: true
                implicitHeight: 72
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 52; Layout.preferredHeight: 52
                        radius: root.hex ? 2 : 10
                        color: Qt.alpha(root.ink, 0.1)
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: root.player ? (root.player.artUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent; width: 24; height: 24
                            visible: !root.player || !root.player.artUrl
                            source: "media-optical-audio"; color: root.soft; isMask: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        QQC2.Label { text: root.player ? root.player.track : ""; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                        QQC2.Label { text: root.player ? (root.player.artist || root.player.identity) : ""; color: root.soft; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    QQC2.ToolButton {
                        icon.name: "media-skip-backward"; enabled: !!root.player && root.player.canGoPrevious
                        onClicked: root.player.Previous()
                    }
                    QQC2.ToolButton {
                        readonly property bool playing: !!root.player && root.player.playbackStatus === Mpris.PlaybackStatus.Playing
                        icon.name: playing ? "media-playback-pause" : "media-playback-start"
                        onClicked: playing ? root.player.Pause() : root.player.Play()
                    }
                    QQC2.ToolButton {
                        icon.name: "media-skip-forward"; enabled: !!root.player && root.player.canGoNext
                        onClicked: root.player.Next()
                    }
                }
            }
        }

        // ---- Wi-Fi: the networks in reach ----
        ColumnLayout {
            id: wifiPage
            visible: root.page === "wifi"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            PageHeader {
                title: "Wi-Fi"
                QQC2.BusyIndicator { running: root.scanning; visible: running; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                QQC2.Switch { checked: root.wifiOn; onToggled: root.setWifi(checked) }
            }

            Panel {
                Layout.fillWidth: true
                implicitHeight: Math.min(330, list.contentHeight) + 12
                visible: root.wifiOn && root.networks.length > 0
                ListView {
                    id: list
                    anchors.fill: parent; anchors.margins: 6
                    clip: true
                    model: root.networks
                    boundsBehavior: Flickable.StopAtBounds
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }
                    delegate: ColumnLayout {
                        id: net
                        required property var modelData
                        width: ListView.view.width
                        spacing: 4
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            Rectangle {
                                anchors.fill: parent; radius: root.hex ? 0 : 10
                                color: netArea.containsMouse ? Qt.alpha(root.ink, 0.07) : "transparent"
                            }
                            MouseArea {
                                id: netArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (!net.modelData.active) root.join(net.modelData)
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4
                                spacing: 10
                                Kirigami.Icon {
                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                    source: net.modelData.signal > 70 ? "network-wireless-signal-excellent-symbolic"
                                        : net.modelData.signal > 45 ? "network-wireless-signal-good-symbolic"
                                        : net.modelData.signal > 25 ? "network-wireless-signal-ok-symbolic" : "network-wireless-signal-weak-symbolic"
                                    color: net.modelData.active ? root.accent : root.ink; isMask: true
                                }
                                QQC2.Label {
                                    text: net.modelData.ssid
                                    color: root.ink; font.pixelSize: 13
                                    font.weight: net.modelData.active ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                QQC2.Label { visible: net.modelData.active; text: "Connected"; color: root.soft; font.pixelSize: 12 }
                                Kirigami.Icon {
                                    visible: net.modelData.secure
                                    Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                    source: "object-locked-symbolic"; color: root.soft; isMask: true
                                }
                                QQC2.ToolButton {
                                    visible: root.saved.indexOf(net.modelData.ssid) >= 0
                                    icon.name: "edit-delete-remove"
                                    implicitWidth: 26; implicitHeight: 26
                                    onClicked: root.forget(net.modelData)
                                    QQC2.ToolTip.text: "Forget this network"; QQC2.ToolTip.visible: hovered
                                }
                            }
                        }
                        // The password, where this network asks for one.
                        RowLayout {
                            visible: root.joining === net.modelData.ssid
                            Layout.fillWidth: true; Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.bottomMargin: 6
                            spacing: 8
                            QQC2.TextField {
                                id: pw
                                Layout.fillWidth: true
                                placeholderText: "Password"
                                echoMode: showPw.checked ? TextInput.Normal : TextInput.Password
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                                onAccepted: if (text.length >= 8) root.join(net.modelData, text)
                            }
                            QQC2.ToolButton {
                                id: showPw
                                checkable: true
                                icon.name: checked ? "view-hidden" : "view-visible"
                                QQC2.ToolTip.text: checked ? "Hide the password" : "Show the password"; QQC2.ToolTip.visible: hovered
                            }
                            QQC2.Button { text: "Join"; enabled: pw.text.length >= 8; onClicked: root.join(net.modelData, pw.text) }
                        }
                    }
                }
            }

            QQC2.Label {
                visible: root.joinMessage.length > 0 || (root.wifiOn && !root.scanning && root.networks.length === 0) || !root.wifiOn
                text: root.joinMessage || (!root.wifiOn ? "Wi-Fi is off." : "No networks in reach.")
                color: root.soft; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
            }

            QQC2.Button {
                Layout.alignment: Qt.AlignRight
                flat: true
                text: "Wi-Fi Settings…"
                onClicked: { root.expanded = false; sh.run("cybroid-settings wifi", () => {}) }
            }
        }

        // ---- Bluetooth: the devices ----
        ColumnLayout {
            id: btPage
            visible: root.page === "bluetooth"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            PageHeader {
                title: "Bluetooth"
                QQC2.BusyIndicator { running: root.btBusy; visible: running; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                QQC2.Switch { checked: root.btState === "on"; onToggled: root.setBluetooth(checked) }
            }

            Panel {
                Layout.fillWidth: true
                visible: root.btState === "on" && root.btDevices.length > 0
                implicitHeight: btList.implicitHeight + 12
                ColumnLayout {
                    id: btList
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 0
                    Repeater {
                        model: root.btDevices
                        delegate: Item {
                            id: dev
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 40
                            Rectangle {
                                anchors.fill: parent; radius: root.hex ? 0 : 10
                                color: devArea.containsMouse ? Qt.alpha(root.ink, 0.07) : "transparent"
                            }
                            MouseArea {
                                id: devArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: !root.btBusy
                                onClicked: root.toggleDevice(dev.modelData)
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: root.hex ? 3 : 14
                                    color: dev.modelData.connected ? root.tileOn : Qt.alpha(root.ink, 0.12)
                                    Kirigami.Icon {
                                        anchors.centerIn: parent; width: 15; height: 15
                                        source: root.btIcon(dev.modelData.icon)
                                        color: dev.modelData.connected ? root.onAccent : root.ink; isMask: true
                                    }
                                }
                                QQC2.Label { text: dev.modelData.name; color: root.ink; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                QQC2.Label { text: dev.modelData.connected ? "Connected" : "Not connected"; color: root.soft; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }

            QQC2.Label {
                visible: root.btMessage.length > 0 || root.btState !== "on" || root.btDevices.length === 0
                text: root.btMessage || (root.btState !== "on" ? "Bluetooth is off." : "No devices yet: pair one below.")
                color: root.soft; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                QQC2.Button {
                    flat: true
                    enabled: root.btState === "on"
                    icon.name: "list-add"
                    text: "Pair a new device…"
                    onClicked: { root.expanded = false; sh.run("bluedevil-wizard", () => {}) }
                }
                Item { Layout.fillWidth: true }
                QQC2.Button {
                    flat: true
                    text: "Settings…"
                    onClicked: { root.expanded = false; sh.run("systemsettings kcm_bluetooth", () => {}) }
                }
            }
        }

        // ---- Sound: the output ----
        ColumnLayout {
            id: soundPage
            visible: root.page === "sound"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            PageHeader { title: "Sound output" }

            Panel {
                Layout.fillWidth: true
                implicitHeight: outList.implicitHeight + 12
                ColumnLayout {
                    id: outList
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 0
                    Repeater {
                        model: outputs
                        delegate: ColumnLayout {
                            id: outGroup
                            required property var model
                            readonly property var dev: model.PulseObject
                            readonly property var ports: root.usablePorts(dev)
                            Layout.fillWidth: true
                            spacing: 0
                        Item {
                            id: out
                            readonly property var model: outGroup.model
                            readonly property bool chosen: !!model.PulseObject && model.PulseObject.default
                            Layout.fillWidth: true
                            implicitHeight: 40
                            Rectangle {
                                anchors.fill: parent; radius: root.hex ? 0 : 10
                                color: outArea.containsMouse ? Qt.alpha(root.ink, 0.07) : "transparent"
                            }
                            MouseArea {
                                id: outArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: out.model.PulseObject.default = true
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 10
                                Kirigami.Icon {
                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                    source: root.outputIcon((out.model.Description || "") + " " + root.portName(outGroup.dev))
                                    color: out.chosen ? root.accent : root.ink; isMask: true
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    QQC2.Label {
                                        text: out.model.Description || out.model.Name || "Output"
                                        color: root.ink; font.pixelSize: 13
                                        font.weight: out.chosen ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    // The connector in use, when the card has only one to show.
                                    QQC2.Label {
                                        visible: outGroup.ports.length === 1 && text !== ""
                                        text: root.portName(outGroup.dev)
                                        color: root.soft; font.pixelSize: 11
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                }
                                Kirigami.Icon {
                                    visible: out.chosen && outGroup.ports.length < 2
                                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                    source: "checkmark-symbolic"; color: root.accent; isMask: true
                                }
                            }
                        }
                        // Speakers, Headphones…: each plugged-in connector of this card.
                        Repeater {
                            model: outGroup.ports.length > 1 ? outGroup.ports : []
                            delegate: Item {
                                id: portRow
                                required property var modelData
                                readonly property bool chosen: out.chosen && outGroup.dev.activePortIndex === modelData.index
                                Layout.fillWidth: true
                                implicitHeight: 34
                                Rectangle {
                                    anchors.fill: parent; anchors.leftMargin: 28
                                    radius: root.hex ? 0 : 8
                                    color: portArea.containsMouse ? Qt.alpha(root.ink, 0.07) : "transparent"
                                }
                                MouseArea {
                                    id: portArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { outGroup.dev.activePortIndex = portRow.modelData.index; outGroup.dev.default = true }
                                }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 36; anchors.rightMargin: 8
                                    spacing: 10
                                    Kirigami.Icon {
                                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                        source: root.outputIcon(portRow.modelData.port.description || "")
                                        color: portRow.chosen ? root.accent : root.soft; isMask: true
                                    }
                                    QQC2.Label {
                                        text: portRow.modelData.port.description || portRow.modelData.port.name
                                        color: root.ink; font.pixelSize: 12
                                        font.weight: portRow.chosen ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Kirigami.Icon {
                                        visible: portRow.chosen
                                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                        source: "checkmark-symbolic"; color: root.accent; isMask: true
                                    }
                                }
                            }
                        }
                        }
                    }
                }
            }

            QQC2.Button {
                Layout.alignment: Qt.AlignRight
                flat: true
                text: "Sound Settings…"
                onClicked: { root.expanded = false; sh.run("cybroid-settings sound", () => {}) }
            }
        }
    }

    // Again a few seconds on, once the radios have reconnected.
    Timer { id: laterTimer; interval: 6000; onTriggered: root.refresh() }

    // Spectacle's region selection, after the panel has closed.
    Timer {
        id: shotTimer
        interval: 450
        onTriggered: sh.run("spectacle --region", () => {})
    }
}
