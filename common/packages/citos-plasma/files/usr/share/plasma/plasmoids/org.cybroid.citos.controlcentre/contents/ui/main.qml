/*
 * CybroidOS Control Centre (citos-plasma): the two-toggles icon in the top bar
 * opens the settings people change most, as macOS's Control Centre does. A
 * block for connections (Wi-Fi, Bluetooth, Tower: each row's icon turns it
 * on or off, the row opens more), Do Not Disturb and Appearance beside it,
 * the design (Horizon or Hex), a screenshot and Settings, and sliders for
 * the display's brightness and the sound. Wi-Fi opens the networks in reach:
 * a tap joins one, asking for its password where it has one.
 *
 * Everything is read from the machine as it opens (ip, nmcli, bluetoothctl,
 * brightnessctl, wpctl, tailscale), so nothing claims a state the system
 * doesn't have: Bluetooth, brightness and sound hide where there is none
 * (most VMs, desktops without a backlight). The tray keeps only what isn't
 * here (USB drives while one is plugged in, the battery).
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

PlasmoidItem {
    id: root

    // Colours follow the colour scheme (CIT-OS Horizon or Horizon Light).
    readonly property color ink: Kirigami.Theme.textColor
    readonly property color soft: Qt.alpha(Kirigami.Theme.textColor, 0.68)
    readonly property color accent: Kirigami.Theme.focusColor
    readonly property color tile: Qt.alpha(Kirigami.Theme.textColor, 0.07)
    readonly property color tileOn: Kirigami.Theme.focusColor
    readonly property color onAccent: Kirigami.ColorUtils.brightnessForColor(tileOn) === Kirigami.ColorUtils.Light ? "#06122e" : "#ffffff"

    // What the tiles show, filled by refresh().
    property string netKind: ""      // "Wired", "Wi-Fi" or "" when offline
    property string netAddress: ""
    property string towerState: ""   // "Connected", "Not joined", "Off"
    property string towerAddress: ""
    property real volume: -1         // 0..1.5, -1 = no sound output
    property bool muted: false
    property bool dark: true         // Horizon or Hex in Dark, or Light
    property bool hex: false         // the HUD design (Hex)
    property bool wifiOn: false      // the Wi-Fi radio
    property bool wifiHw: false      // a Wi-Fi device exists
    property string wifiName: ""     // the network joined, if any
    property var networks: []        // [{ssid, signal, secure, active}]
    property bool scanning: false
    property string btState: ""      // "" (no adapter), "on", "off"
    property real brightness: -1     // 0..1, -1 = no backlight
    property string page: "main"     // "main" or "wifi"
    property string joining: ""      // the network asking for its password
    property string joinMessage: ""

    Plasmoid.icon: "citos-control-centre-symbolic"
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

    onExpandedChanged: if (root.expanded) refresh()

    // Shell commands, one at a time per source; each answer goes to its handler.
    P5Support.DataSource {
        id: sh
        engine: "executable"
        property var handlers: ({})
        function run(cmd, handler) {
            handlers[cmd] = handler
            connectSource(cmd)
        }
        onNewData: (source, data) => {
            const h = handlers[source]
            disconnectSource(source)
            delete handlers[source]
            if (h) h(String(data["stdout"] || ""), Number(data["exit code"]))
        }
    }

    function refresh() {
        // The route to the internet names the interface and our address on it.
        sh.run("ip -o -4 route get 1.1.1.1", (out, code) => {
            const dev = (out.match(/ dev (\S+)/) || [])[1] || ""
            root.netAddress = (out.match(/ src (\S+)/) || [])[1] || ""
            root.netKind = code !== 0 || !dev ? "" : (/^(wl|wifi)/.test(dev) ? "Wi-Fi" : "Wired")
        })
        sh.run("nmcli -t -f TYPE,STATE device", (out) => {
            root.wifiHw = /^wifi:/m.test(out)
        })
        sh.run("nmcli radio wifi", (out) => { root.wifiOn = /enabled/.test(out) })
        sh.run("nmcli -t -f ACTIVE,SSID dev wifi", (out) => {
            const m = out.match(/^yes:(.*)$/m)
            root.wifiName = m ? m[1].replace(/\\:/g, ":") : ""
        })
        sh.run("bluetoothctl show", (out, code) => {
            root.btState = code !== 0 || !/Controller/.test(out) ? "" : /Powered: yes/.test(out) ? "on" : "off"
        })
        sh.run("brightnessctl -m -c backlight", (out, code) => {
            const f = out.trim().split(",")
            root.brightness = code === 0 && f.length >= 4 ? Number(f[3].replace("%", "")) / 100 : -1
        })
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
        // PipeWire's stand-in output ("auto_null", when there is no sound card)
        // counts as no sound: the slider would move nothing.
        sh.run("sh -c \"wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q auto_null && exit 1; wpctl get-volume @DEFAULT_AUDIO_SINK@\"", (out, code) => {
            const m = out.match(/Volume:\s*([\d.]+)/)
            root.volume = code === 0 && m ? Number(m[1]) : -1
            root.muted = /MUTED/.test(out)
        })
    }

    // Light or Dark: the two global themes of the design (colours, window title
    // bars, top bar and popups, icons); the layout stays as it is.
    // The design: Horizon (clean, for everyone) or Hex (the HUD).
    function setDesign(hex) {
        root.hex = hex
        root.expanded = false
        sh.run("citos-appearance " + (hex ? "hex" : "horizon"), () => {})
    }

    function setAppearance(dark) {
        root.dark = dark
        sh.run("citos-appearance " + (dark ? "dark" : "light"), () => {})
    }

    // A word for the shell, quoted.
    function q(v) { return "'" + String(v).replace(/'/g, "'\\''") + "'" }

    // Wi-Fi: the networks in reach, strongest first, one line each.
    function scan() {
        root.scanning = true
        sh.run("nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes", (out) => {
            const seen = {}
            const list = []
            for (const line of out.split("\n")) {
                // nmcli -t escapes ":" in values as "\:".
                const f = line.replace(/\\:/g, "\u0001").split(":").map((x) => x.replace(/\u0001/g, ":"))
                if (f.length < 4 || !f[1] || seen[f[1]]) continue
                seen[f[1]] = true
                list.push({ ssid: f[1], signal: Number(f[2]) || 0, secure: f[3].length > 0 && f[3] !== "--", active: f[0] === "*" })
            }
            list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            root.networks = list
            root.scanning = false
        })
    }
    function setWifi(on) {
        root.wifiOn = on
        sh.run("nmcli radio wifi " + (on ? "on" : "off"), () => { if (on) scanTimer.start() })
    }
    Timer { id: scanTimer; interval: 2500; onTriggered: root.scan() }
    // Join: a saved or open network at once; a new secured one asks first.
    function join(n, password) {
        root.joinMessage = "Joining " + n.ssid + "…"
        const cmd = password !== undefined
            ? "nmcli dev wifi connect " + q(n.ssid) + " password " + q(password)
            : "sh -c " + q("nmcli connection up id " + q(n.ssid) + " 2>/dev/null || nmcli dev wifi connect " + q(n.ssid))
        sh.run(cmd, (out, code) => {
            if (code === 0) {
                root.joinMessage = ""
                root.joining = ""
                root.refresh()
                root.scan()
            } else if (n.secure && password === undefined) {
                root.joinMessage = ""
                root.joining = n.ssid
            } else {
                root.joinMessage = "Couldn't join " + n.ssid + (password !== undefined ? ": check the password." : ".")
                root.joining = n.secure ? n.ssid : ""
            }
        })
    }
    function setBluetooth(on) {
        root.btState = on ? "on" : "off"
        sh.run("bluetoothctl power " + (on ? "on" : "off"), () => {})
    }
    function setBrightness(v) {
        sh.run("brightnessctl -q -c backlight set " + Math.max(1, Math.round(v * 100)) + "%", () => {})
    }

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

    // A rounded tile; big ones carry a title and a status line.
    component Tile: Rectangle {
        id: t
        property string icon
        property string title
        property string detail
        property bool on: false
        property bool big: false
        signal clicked()
        // Horizon: a rounded tile. Hex: Hangar's cut panel (top-left and
        // bottom-right corners cut), drawn by the shape below.
        radius: root.hex ? 0 : 16
        readonly property color fill: area.pressed ? Qt.alpha(root.ink, 0.17) : area.containsMouse ? Qt.alpha(root.ink, 0.12) : base
        color: root.hex ? "transparent" : fill
        readonly property color base: root.tile
        implicitHeight: big ? 64 : 76
        Behavior on color { ColorAnimation { duration: 120 } }
        Shape {
            visible: root.hex
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                readonly property real c: 12
                strokeWidth: 1
                strokeColor: t.on ? Qt.alpha(root.accent, 0.7) : Qt.alpha(root.ink, 0.16)
                fillColor: t.fill
                startX: c; startY: 0.5
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
                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: root.hex ? 3 : 17
                color: t.on ? root.tileOn : Qt.alpha(root.ink, 0.12)
                Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: t.icon; color: t.on ? root.onAccent : root.ink; isMask: true }
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
                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: root.hex ? 3 : 17
                color: t.on ? root.tileOn : Qt.alpha(root.ink, 0.12)
                Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: t.icon; color: t.on ? root.onAccent : root.ink; isMask: true }
            }
            QQC2.Label { Layout.alignment: Qt.AlignHCenter; text: t.title; color: root.ink; font.pixelSize: 12 }
        }
    }

    // A row in the connections block: the icon (on or off by a tap) and
    // the row (opens more).
    component Toggle: Item {
        id: tg
        property string icon
        property string title
        property string detail
        property bool on: false
        property bool more: false
        signal toggled()
        signal opened()
        implicitHeight: 46
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
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: root.hex ? 3 : 16
                color: tg.on ? root.tileOn : Qt.alpha(root.ink, 0.12)
                Kirigami.Icon { anchors.centerIn: parent; width: 17; height: 17; source: tg.icon; color: tg.on ? root.onAccent : root.ink; isMask: true }
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

    // A slider in its panel: a name, an icon and the slider.
    component SliderPanel: Panel {
        id: sp
        property string title
        property string icon
        property real value: 0
        signal moved(real v)
        signal iconClicked()
        implicitHeight: 64
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 4
            QQC2.Label { text: sp.title; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 13 }
            RowLayout {
                spacing: 8
                Kirigami.Icon {
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                    source: sp.icon; color: root.ink; isMask: true
                    MouseArea { anchors.fill: parent; onClicked: sp.iconClicked() }
                }
                QQC2.Slider {
                    Layout.fillWidth: true
                    from: 0; to: 1; stepSize: 0.02
                    value: sp.value
                    onMoved: sp.moved(value)
                }
            }
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 380
        Layout.minimumWidth: 380
        Layout.maximumWidth: 380
        Layout.preferredHeight: (root.page === "wifi" ? wifiPage.implicitHeight : col.implicitHeight) + 24
        Layout.minimumHeight: Layout.preferredHeight
        Keys.onEscapePressed: root.page === "wifi" ? root.page = "main" : root.expanded = false

        Connections {
            target: root
            function onExpandedChanged() { if (!root.expanded) { root.page = "main"; root.joining = ""; root.joinMessage = "" } }
        }

        // ---- The main page --------------------------------------------
        ColumnLayout {
            id: col
            visible: root.page === "main"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                // Connections: Wi-Fi (or the wired link), Bluetooth, Tower.
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
                            icon: root.netKind ? "network-wired-symbolic" : "network-offline-symbolic"
                            title: root.netKind === "Wired" || !root.wifiHw ? (root.netKind ? "Wired" : "Offline") : ""
                            detail: root.netAddress
                            on: root.netKind === "Wired"
                            onOpened: { root.expanded = false; sh.run("systemsettings kcm_networkmanagement", () => {}) }
                        }
                        Toggle {
                            Layout.fillWidth: true
                            visible: root.btState !== ""
                            icon: "network-bluetooth-symbolic"
                            title: "Bluetooth"
                            detail: root.btState === "on" ? "On" : "Off"
                            on: root.btState === "on"
                            more: true
                            onToggled: root.setBluetooth(root.btState !== "on")
                            onOpened: { root.expanded = false; sh.run("systemsettings kcm_bluetooth", () => {}) }
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
                    onClicked: { root.expanded = false; sh.run("sleep 0.4; spectacle -r", () => {}) }
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: "configure-symbolic"
                    title: "Settings"
                    onClicked: { root.expanded = false; sh.run("systemsettings", () => {}) }
                }
            }

            // Display: where there is a backlight (laptops).
            SliderPanel {
                visible: root.brightness >= 0
                Layout.fillWidth: true
                title: "Display"
                icon: "brightness-high-symbolic"
                value: Math.max(0, root.brightness)
                onMoved: (v) => root.setBrightness(v)
            }
            // Sound: where there is an output.
            SliderPanel {
                visible: root.volume >= 0
                Layout.fillWidth: true
                title: "Sound"
                icon: root.muted || root.volume === 0 ? "audio-volume-muted" : root.volume < 0.4 ? "audio-volume-low" : "audio-volume-high"
                value: Math.min(1, Math.max(0, root.volume))
                onMoved: (v) => sh.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2), () => {})
                onIconClicked: sh.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", () => root.refresh())
            }
        }

        // ---- Wi-Fi: the networks in reach ------------------------------
        ColumnLayout {
            id: wifiPage
            visible: root.page === "wifi"
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                QQC2.ToolButton {
                    icon.name: "go-previous-symbolic"
                    onClicked: { root.page = "main"; root.joining = ""; root.joinMessage = "" }
                    QQC2.ToolTip.text: "Back"; QQC2.ToolTip.visible: hovered
                }
                QQC2.Label { text: "Wi-Fi"; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 15; Layout.fillWidth: true }
                QQC2.BusyIndicator { running: root.scanning; visible: running; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                QQC2.Switch { checked: root.wifiOn; onToggled: root.setWifi(checked) }
            }

            Panel {
                Layout.fillWidth: true
                implicitHeight: Math.min(330, list.contentHeight) + 12
                visible: root.wifiOn
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
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
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
                                echoMode: TextInput.Password
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                                onAccepted: root.join(net.modelData, text)
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
                text: "Network Settings…"
                onClicked: { root.expanded = false; sh.run("systemsettings kcm_networkmanagement", () => {}) }
            }
        }
    }
}
