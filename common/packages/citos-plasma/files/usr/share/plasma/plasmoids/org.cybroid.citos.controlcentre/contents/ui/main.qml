/*
 * CIT-OS Control Centre (citos-plasma): the two-toggles icon in the top bar
 * opens the settings people change most, as macOS's Control Centre does:
 * network, Tower (CIT's private network), Do Not Disturb and Appearance
 * (Light or Dark) as big tiles, a screenshot and Settings as small ones,
 * and the sound level. Everything
 * is read from the machine as it opens (ip, tailscale, wpctl), so a tile
 * never claims a state the system doesn't have; the sound slider hides when
 * there's no output (most VMs).
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
    property bool dark: true         // CIT-OS Horizon, or Horizon Light
    property bool hex: false         // the HUD design (CIT-OS Hex)

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
        sh.run("wpctl get-volume @DEFAULT_AUDIO_SINK@", (out, code) => {
            const m = out.match(/Volume:\s*([\d.]+)/)
            root.volume = code === 0 && m ? Number(m[1]) : -1
            root.muted = /MUTED/.test(out)
        })
    }

    // Light or Dark: the two CIT-OS global themes (colours, window title
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

    fullRepresentation: Item {
        Layout.preferredWidth: 372
        Layout.preferredHeight: col.implicitHeight + 24
        Layout.minimumWidth: 372
        Layout.maximumWidth: 372

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; big: true
                    icon: root.netKind === "Wi-Fi" ? "network-wireless-symbolic" : root.netKind ? "network-wired-symbolic" : "network-offline-symbolic"
                    title: root.netKind || "Offline"
                    detail: root.netAddress
                    on: root.netKind.length > 0
                    onClicked: sh.run("systemsettings kcm_networkmanagement || systemsettings", () => {})
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; big: true
                    icon: "network-vpn-symbolic"
                    title: "Tower"
                    detail: root.towerState === "Connected" ? root.towerAddress : root.towerState
                    on: root.towerState === "Connected"
                    onClicked: Qt.openUrlExternally("https://tower.cybroid.com")
                }
            }

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; big: true
                    icon: dnd.on ? "notifications-disabled-symbolic" : "notifications-symbolic"
                    title: "Do Not Disturb"
                    detail: dnd.on ? "On" : "Off"
                    on: dnd.on
                    onClicked: dnd.toggle()
                }
                Tile {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; big: true
                    icon: root.dark ? "weather-clear-night-symbolic" : "weather-clear-symbolic"
                    title: "Appearance"
                    detail: root.dark ? "Dark" : "Light"
                    on: true
                    onClicked: root.setAppearance(!root.dark)
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

            // Sound: hidden when the machine has no output.
            Rectangle {
                visible: root.volume >= 0
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 16
                color: root.tile
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    QQC2.Label { text: "Sound"; color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 8
                        Kirigami.Icon {
                            Layout.preferredWidth: 18; Layout.preferredHeight: 18
                            source: root.muted || root.volume === 0 ? "audio-volume-muted" : root.volume < 0.4 ? "audio-volume-low" : "audio-volume-high"
                            color: root.ink; isMask: true
                            MouseArea { anchors.fill: parent; onClicked: sh.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", () => root.refresh()) }
                        }
                        QQC2.Slider {
                            Layout.fillWidth: true
                            from: 0; to: 1; stepSize: 0.02
                            value: Math.min(1, Math.max(0, root.volume))
                            onMoved: sh.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + value.toFixed(2), () => {})
                        }
                    }
                }
            }
        }
    }
}
