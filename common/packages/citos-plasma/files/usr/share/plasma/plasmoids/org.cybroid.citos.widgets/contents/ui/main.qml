/*
 * CIT-OS Widgets (citos-plasma): the cards from the CIT-OS design on the
 * desktop, as macOS keeps its widgets. Each copy shows one card (setting
 * "card"): "today" (the day, the time, the date and Kampala's weather from
 * Open-Meteo) or "system" (this computer: memory, disk, Tower). A first
 * sign-in puts Today at the left and System at the right, both as cards of
 * one size.
 *
 * Three looks (setting "look"), all in the colour scheme's colours so they
 * suit CIT-OS Horizon and Horizon Light:
 *   card    a raised card: lit from above, a light edge, a soft shadow
 *   open    no card: large type straight on the wallpaper, with a shadow
 *           that keeps it legible (macOS's lock-screen clock)
 *   gauges  a compact card; System shows memory and disk as rings
 *   hud     Hex, the HUD design: a column of three readouts on the wallpaper,
 *           each beside the end of one of the dial's leaders. Today is the
 *           left column (time, processor, memory), System the right one
 *           (network, Tower, traffic). citos-appearance sizes and places
 *           them; the readouts sit at fixed shares of the column's height,
 *           which match the wallpaper's leaders (render-brand.py, HEX_*).
 */
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property string card: Plasmoid.configuration.card || "today"
    readonly property string look: Plasmoid.configuration.look || "card"

    readonly property bool dark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    // On the wallpaper ("open") text is white in both appearances, as on a
    // Mac's lock screen; on a card it follows the scheme.
    readonly property color ink: look === "open" ? "#ffffff" : Kirigami.Theme.textColor
    readonly property color soft: Qt.alpha(ink, 0.75)
    readonly property color faint: Qt.alpha(ink, 0.55)
    readonly property color accent: look === "open" ? "#ffffff" : Kirigami.Theme.focusColor
    readonly property color cardColor: Qt.alpha(Kirigami.Theme.backgroundColor, dark ? 0.82 : 0.74)

    property date now: new Date()
    property string weather: ""
    property string host: ""
    property string cpus: ""
    property real memUsed: 0
    property real memTotal: 0
    property real diskFree: 0
    property real diskSize: 0
    property string tower: ""
    // HUD readouts: CPU use (from /proc/stat between readings), load, uptime.
    property real cpuShare: 0
    property var cpuLast: null
    property string load: ""
    property string uptime: ""
    // Hex's readouts: recent CPU use, the network (address, gateway, ping,
    // bytes through the interface) and Tower's devices.
    property var cpuHist: []
    property string netDev: ""
    property string netIp: ""
    property string netGw: ""
    property string netPing: ""
    property real rxTotal: 0
    property real txTotal: 0
    property var netLast: null
    property var netHist: []
    property var towerPeers: []
    readonly property bool hud: look === "hud"

    readonly property real memShare: memTotal ? Math.min(1, memUsed / memTotal) : 0
    readonly property real diskShare: diskSize ? Math.min(1, (diskSize - diskFree) / diskSize) : 0

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    // Machine facts every 15 s; the weather every 20 minutes.
    Timer {
        interval: root.hud ? 3000 : 15000; running: root.card === "system" || root.hud; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 20 * 60000; running: root.card === "today"; repeat: true; triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }

    P5Support.DataSource {
        id: sh
        engine: "executable"
        property var handlers: ({})
        function run(cmd, handler) { handlers[cmd] = handler; connectSource(cmd) }
        onNewData: (source, data) => {
            const h = handlers[source]
            disconnectSource(source)
            delete handlers[source]
            if (h) h(String(data["stdout"] || ""), Number(data["exit code"]))
        }
    }

    function refresh() {
        sh.run("sh -c 'hostname; nproc; grep -E \"^(MemTotal|MemAvailable):\" /proc/meminfo; df -B1 --output=avail,size / | tail -1'", (out) => {
            const l = out.trim().split("\n")
            root.host = l[0] || ""
            root.cpus = l[1] || ""
            const kb = (re) => Number(((out.match(re) || [])[1]) || 0)
            root.memTotal = kb(/MemTotal:\s+(\d+)/) / 1048576
            root.memUsed = root.memTotal - kb(/MemAvailable:\s+(\d+)/) / 1048576
            const d = (l[l.length - 1] || "").trim().split(/\s+/)
            if (d.length === 2) {
                root.diskFree = Number(d[0]) / 1e9
                root.diskSize = Number(d[1]) / 1e9
            }
        })
        sh.run("sh -c 'head -1 /proc/stat; cat /proc/loadavg; cut -d. -f1 /proc/uptime'", (out) => {
            const l = out.trim().split("\n")
            const t = (l[0] || "").trim().split(/\s+/).slice(1).map(Number)
            if (t.length >= 4) {
                const idle = t[3] + (t[4] || 0), total = t.reduce((a, b) => a + b, 0)
                if (root.cpuLast) {
                    const dt = total - root.cpuLast.total, di = idle - root.cpuLast.idle
                    root.cpuShare = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0
                }
                root.cpuLast = { total: total, idle: idle }
                root.cpuHist = root.cpuHist.concat([root.cpuShare]).slice(-48)
            }
            root.load = ((l[1] || "").split(" ").slice(0, 3)).join("  ")
            const up = Math.floor(Number(l[2] || 0))
            const d = Math.floor(up / 86400), h = Math.floor(up % 86400 / 3600), m = Math.floor(up % 3600 / 60)
            root.uptime = (d ? d + "d " : "") + String(h).padStart(2, "0") + "h " + String(m).padStart(2, "0") + "m"
        })
        sh.run(root.hud ? "tailscale status --json" : "tailscale status --json --peers=false", (out) => {
            try {
                const s = JSON.parse(out)
                root.tower = s.BackendState === "Running" ? "On Tower" : "Not on Tower"
                const peers = []
                for (const k in (s.Peer || {})) {
                    const p = s.Peer[k]
                    peers.push({ name: String(p.HostName || p.DNSName || "").split(".")[0].toLowerCase(), online: !!p.Online })
                }
                peers.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name))
                root.towerPeers = peers
            } catch (e) { root.tower = ""; root.towerPeers = [] }
        })
        if (root.hud && root.card === "system") refreshNet()
    }

    // The way out: the interface, this computer's address and the gateway,
    // a ping to the gateway, and the bytes through the interface.
    function refreshNet() {
        sh.run("sh -c 'ip -4 -o route get 1.1.1.1 2>/dev/null; echo; cat /proc/net/dev'", (out) => {
            const r = (out.split("\n")[0] || "")
            const m = (re) => ((r.match(re) || [])[1]) || ""
            root.netDev = m(/ dev (\S+)/)
            root.netIp = m(/ src (\S+)/)
            root.netGw = m(/ via (\S+)/)
            const line = out.split("\n").find((l) => root.netDev && l.trim().startsWith(root.netDev + ":"))
            if (line) {
                const f = line.split(":")[1].trim().split(/\s+/).map(Number)
                const rx = f[0], tx = f[8], t = Date.now()
                if (root.netLast && t > root.netLast.t) {
                    const rate = ((rx - root.netLast.rx) + (tx - root.netLast.tx)) / ((t - root.netLast.t) / 1000)
                    root.netHist = root.netHist.concat([Math.max(0, rate)]).slice(-48)
                }
                root.netLast = { rx: rx, tx: tx, t: t }
                root.rxTotal = rx
                root.txTotal = tx
            }
            if (root.netGw)
                sh.run("ping -n -c1 -W1 " + root.netGw, (p) => {
                    const ms = (p.match(/time=([\d.]+)/) || [])[1]
                    root.netPing = ms ? Math.round(Number(ms)) + "ms" : "--"
                })
            else root.netPing = "--"
        })
    }

    function bytes(v) {
        if (v >= 1e9) return (v / 1e9).toFixed(1) + " GB"
        if (v >= 1e6) return Math.round(v / 1e6) + " MB"
        return Math.round(v / 1e3) + " KB"
    }

    function fetchWeather() {
        const x = new XMLHttpRequest()
        x.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=0.3476&longitude=32.5825&current=temperature_2m,weather_code&timezone=auto")
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return
            try {
                const c = JSON.parse(x.responseText).current
                root.weather = "Kampala " + Math.round(c.temperature_2m) + "°, " + describe(c.weather_code)
            } catch (e) { /* offline: leave it out */ }
        }
        x.send()
    }

    // WMO weather codes, as Open-Meteo reports them.
    function describe(c) {
        if (c === 0) return "clear"
        if (c <= 2) return "partly cloudy"
        if (c === 3) return "cloudy"
        if (c <= 48) return "fog"
        if (c <= 55) return "drizzle"
        if (c <= 63) return "light rain"
        if (c <= 67) return "rain"
        if (c <= 77) return "snow"
        if (c <= 81) return "showers"
        if (c <= 82) return "heavy showers"
        return "thunderstorms"
    }

    function gb(v) { return v >= 100 ? Math.round(v) + " GB" : v.toFixed(1) + " GB" }

    // A raised surface: lit from above, a light edge, a soft shadow. With
    // "open" it draws nothing and only the text carries a shadow.
    // Cards are one fixed size, as macOS's widgets are, so Today and This
    // computer match side by side (300 x 176); content sits in the middle.
    readonly property int cardWidth: 300
    readonly property int cardHeight: 176

    component Surface: Item {
        id: surf
        default property alias content: inner.data
        property int pad: 18
        implicitWidth: root.look === "card" ? root.cardWidth : inner.implicitWidth + 2 * pad
        implicitHeight: root.look === "card" ? root.cardHeight : inner.implicitHeight + 2 * pad
        Rectangle {
            visible: root.look !== "open"
            anchors.fill: parent
            radius: root.look === "gauges" ? 20 : 24
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.tint(root.cardColor, Qt.alpha("#ffffff", root.dark ? 0.07 : 0.35)) }
                GradientStop { position: 1.0; color: root.cardColor }
            }
            border.color: root.dark ? Qt.alpha("#ffffff", 0.10) : Qt.alpha("#ffffff", 0.7)
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha("#000000", root.dark ? 0.55 : 0.22)
                shadowBlur: 1.0
                shadowVerticalOffset: 8
                autoPaddingEnabled: true
            }
        }
        Item {
            id: textLayer
            anchors.fill: parent
            layer.enabled: root.look === "open"
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha("#000000", 0.45)
                shadowBlur: 0.6
                shadowVerticalOffset: 2
                autoPaddingEnabled: true
            }
            ColumnLayout {
                id: inner
                anchors { left: parent.left; right: parent.right; margins: surf.pad }
                anchors.verticalCenter: root.look === "card" ? parent.verticalCenter : undefined
                anchors.top: root.look === "card" ? undefined : parent.top
                anchors.topMargin: surf.pad
                spacing: 6
            }
        }
    }

    // A ring gauge: share 0..1, a label in the middle and one under it.
    component Ring: Item {
        property real share: 0
        property string centre
        property string caption
        implicitWidth: 92
        implicitHeight: 92 + 22
        Canvas {
            id: c
            width: 92; height: 92
            property real s: parent.share
            property color track: Qt.alpha(root.ink, 0.12)
            property color fill: parent.share > 0.85 ? "#f0a63c" : root.accent
            onSChanged: requestPaint()
            onTrackChanged: requestPaint()
            onFillChanged: requestPaint()
            onPaint: {
                const g = getContext("2d")
                g.reset()
                g.lineWidth = 9
                g.lineCap = "round"
                g.strokeStyle = track
                g.beginPath(); g.arc(46, 46, 38, 0, Math.PI * 2); g.stroke()
                if (s > 0) {
                    g.strokeStyle = fill
                    g.beginPath(); g.arc(46, 46, 38, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * s); g.stroke()
                }
            }
        }
        QQC2.Label {
            anchors.centerIn: c
            text: parent.centre
            color: root.ink; font.pixelSize: 18; font.weight: Font.DemiBold
        }
        QQC2.Label {
            anchors.top: c.bottom; anchors.topMargin: 4
            anchors.horizontalCenter: c.horizontalCenter
            text: parent.caption
            color: root.soft; font.pixelSize: 12
        }
    }


    // ---- Hex, the HUD look (look "hud"): Hangar's HUD on the desktop. ----
    // Hangar's HUD shapes in CIT's colours: deep navy, cyan, blue.
    readonly property color hudAcc: "#1ccbff"
    readonly property color hudBlue: "#3a7cff"
    readonly property color hudLine: "#2a3d6e"
    readonly property color hudFg: "#e8eefc"
    readonly property color hudMuted: "#8fa3c8"
    readonly property color hudDim: "#4a5b85"
    readonly property string mono: "JetBrains Mono"

    // A column's heading: PANEL at the left, its name at the right, over a
    // rule lit at its outer end.
    component HudHeading: Item {
        property string name
        id: hh
        property bool atRight: false
        implicitHeight: 22
        QQC2.Label { text: hh.atRight ? hh.name : "PANEL"; color: root.hudMuted; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2 }
        QQC2.Label { anchors.right: hh.right; text: hh.atRight ? "PANEL" : hh.name; color: root.hudMuted; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2 }
        Rectangle { anchors.bottom: hh.bottom; width: hh.width; height: 1; color: root.hudLine }
        Rectangle { anchors.bottom: hh.bottom; anchors.bottomMargin: -0.5; x: hh.atRight ? hh.width - 40 : 0; width: 40; height: 2; color: root.hudAcc }
    }

    // A readout: a label, a value at the right, and what is drawn under them.
    component HudReadout: Column {
        id: ro
        property string label
        property string value
        property color valueColor: root.hudFg
        spacing: 8
        Item {
            width: ro.width; height: 16
            QQC2.Label { text: ro.label; color: "#c4d0ea"; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1.8 }
            QQC2.Label { anchors.right: parent.right; text: ro.value; color: ro.valueColor; font.family: root.mono; font.pixelSize: 12 }
        }
    }

    // A line of recent values (0..1 of the highest), over a hairline.
    component Spark: Canvas {
        property var values: []
        property real ceiling: 1
        implicitHeight: 34
        onValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = "#2a4686"; c.lineWidth = 1
            c.beginPath(); c.moveTo(0, height - 0.5); c.lineTo(width, height - 0.5); c.stroke()
            const v = values || [], n = 48
            if (v.length < 2) return
            const hi = Math.max(ceiling, ...v)
            c.strokeStyle = "#1ccbff"; c.lineWidth = 1.5
            c.beginPath()
            for (let i = 0; i < v.length; i++) {
                const x = width * (n - v.length + i) / (n - 1)
                const y = height - 3 - (height - 6) * (v[i] / hi)
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
            }
            c.stroke()
        }
    }

    // A hexagon, Hangar's mark for a device.
    component Hex: Shape {
        id: hx
        property real r: 7
        property color fill: "transparent"
        property color edge: "#8fb4ee"
        width: 2 * r; height: 2 * r
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: sp
            strokeWidth: 1.5; strokeColor: hx.edge; fillColor: hx.fill
            readonly property real k: hx.r - 1
            readonly property real c: hx.r
            startX: sp.c; startY: sp.c - sp.k
            PathLine { x: sp.c + sp.k * 0.866; y: sp.c - sp.k / 2 }
            PathLine { x: sp.c + sp.k * 0.866; y: sp.c + sp.k / 2 }
            PathLine { x: sp.c; y: sp.c + sp.k }
            PathLine { x: sp.c - sp.k * 0.866; y: sp.c + sp.k / 2 }
            PathLine { x: sp.c - sp.k * 0.866; y: sp.c - sp.k / 2 }
            PathLine { x: sp.c; y: sp.c - sp.k }
        }
    }

    // Where the three readouts sit: level with the wallpaper's leaders, which
    // end at 242, 530 and 818 in units of the picture's height (render-
    // brand.py, HEX_CY and HEX_ELBOW). Worked out from the screen, as the
    // wallpaper is drawn (one picture per screen shape, scaled to cover it),
    // and from where the column is: the desktop snaps widgets to a grid, so
    // the column is never exactly where citos-appearance put it.
    function hudRowY(item, i) {
        void root.now  // re-placed each second: cheap, and follows moves
        const W = Screen.width, H = Screen.height
        if (!W || !H) return 0
        const Hp = W / H < 1.7 ? 1200 : 1080
        const s = Math.max(W / 1920, H / Hp)
        const U = s * Hp / 1080, oy = (H - Hp * s) / 2
        const at = item.mapToGlobal(0, 0).y - Screen.virtualY
        return oy + [242, 530, 818][i] * U - at
    }

    fullRepresentation: Item {
        Layout.preferredWidth: view.implicitWidth
        Layout.preferredHeight: view.implicitHeight
        Layout.minimumWidth: 220

        Loader {
            id: view
            anchors.left: parent.left
            width: root.hud ? parent.width : implicitWidth
            height: root.hud ? parent.height : implicitHeight
            sourceComponent: root.hud
                ? (root.card === "system" ? systemHud : todayHud)
                : root.card === "system" ? (root.look === "gauges" ? systemGauges : systemCard) : todayCard
        }

        // Hex, left: the time, the processor, memory.
        Component {
            id: todayHud
            Item {
                id: col
                HudHeading { width: col.width; name: "SYSTEM" }
                Column {
                    width: col.width
                    y: root.hudRowY(col, 0) - height / 2
                    spacing: 6
                    Row {
                        spacing: 6
                        QQC2.Label { id: hhmm; text: Qt.formatTime(root.now, "HH:mm"); color: root.hudFg; font.family: root.mono; font.pixelSize: 60; font.weight: Font.Medium; font.letterSpacing: 2 }
                        QQC2.Label { anchors.baseline: hhmm.baseline; text: Qt.formatTime(root.now, "ss"); color: root.hudAcc; font.family: root.mono; font.pixelSize: 26; font.weight: Font.Light }
                    }
                    QQC2.Label {
                        width: col.width; elide: Text.ElideRight
                        text: (Qt.formatDate(root.now, "ddd d MMM") + (root.weather ? " · " + root.weather.replace(/,.*/, "") : "")).toUpperCase()
                        color: root.hudMuted; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1.8
                    }
                }
                HudReadout {
                    width: col.width
                    y: root.hudRowY(col, 1) - height / 2
                    label: "CPU"
                    value: Math.round(root.cpuShare * 100) + "%"
                    valueColor: "#8fe6ff"
                    Spark { width: col.width; values: root.cpuHist; ceiling: 0.25 }
                }
                HudReadout {
                    width: col.width
                    y: root.hudRowY(col, 2) - height / 2
                    label: "MEMORY"
                    value: root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1) + " GiB"
                    valueColor: root.hudMuted
                    Grid {
                        id: dots
                        columns: 24; spacing: 4
                        readonly property real cell: (col.width - 23 * spacing) / 24
                        Repeater {
                            model: 48
                            Rectangle {
                                required property int index
                                width: dots.cell; height: 6
                                color: index < Math.round(root.memShare * 48) ? (root.memShare > 0.85 ? "#ff6b5a" : root.hudAcc) : "#1b2f63"
                            }
                        }
                    }
                }
            }
        }

        // Hex, right: the network, Tower, traffic.
        Component {
            id: systemHud
            Item {
                id: col
                HudHeading { width: col.width; name: "NETWORK"; atRight: true }
                Row {
                    width: col.width
                    y: root.hudRowY(col, 0) - height / 2
                    Repeater {
                        model: [
                            { k: "STATE", v: root.netIp ? "ONLINE" : "OFFLINE", c: root.netIp ? "#3ee0a0" : "#ff6b5a", w: 0.25 },
                            { k: "IPv4", v: root.netIp || "--", c: root.hudFg, w: 0.56 },
                            { k: "PING", v: root.netPing || "--", c: root.hudFg, w: 0.19, end: true }
                        ]
                        Column {
                            required property var modelData
                            width: col.width * modelData.w
                            spacing: 4
                            QQC2.Label { width: parent.width; horizontalAlignment: modelData.end ? Text.AlignRight : Text.AlignLeft; text: modelData.k; color: root.hudMuted; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1.6 }
                            QQC2.Label { width: parent.width; horizontalAlignment: modelData.end ? Text.AlignRight : Text.AlignLeft; elide: Text.ElideRight; text: modelData.v; color: modelData.c; font.family: root.mono; font.pixelSize: 13 }
                        }
                    }
                }
                HudReadout {
                    id: tw
                    width: col.width
                    y: root.hudRowY(col, 1) - height / 2
                    label: "TOWER"
                    value: root.tower === "On Tower"
                        ? root.towerPeers.filter((p) => p.online).length + " DEVICES ONLINE"
                        : "NOT LINKED"
                    valueColor: root.tower === "On Tower" ? root.hudMuted : root.hudDim
                    // This computer in the middle, up to four of Tower's
                    // devices round it (online ones first).
                    Item {
                        id: map
                        width: col.width; height: 110
                        readonly property var slots: [[0.22, 0.22], [0.78, 0.18], [0.2, 0.8], [0.78, 0.84]]
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: "#16264a"; strokeWidth: 1; fillColor: "transparent"
                                PathAngleArc { centerX: map.width / 2; centerY: map.height / 2; radiusX: map.width * 0.45; radiusY: map.height * 0.46; sweepAngle: 360 }
                            }
                            ShapePath {
                                strokeColor: "#16264a"; strokeWidth: 1; fillColor: "transparent"
                                PathAngleArc { centerX: map.width / 2; centerY: map.height / 2; radiusX: map.width * 0.24; radiusY: map.height * 0.46; sweepAngle: 360 }
                            }
                        }
                        Repeater {
                            model: Math.min(4, root.towerPeers.length)
                            Item {
                                required property int index
                                readonly property var peer: root.towerPeers[index]
                                readonly property real px: map.width * map.slots[index][0]
                                readonly property real py: map.height * map.slots[index][1]
                                anchors.fill: parent
                                Shape {
                                    anchors.fill: parent
                                    ShapePath {
                                        strokeColor: peer.online ? (index === 0 ? root.hudAcc : "#3d5fa8") : "#1d2d55"
                                        strokeWidth: 1.2; fillColor: "transparent"
                                        strokeStyle: index === 0 && peer.online ? ShapePath.DashLine : ShapePath.SolidLine
                                        dashPattern: [3, 4]
                                        startX: map.width / 2; startY: map.height / 2
                                        PathLine { x: px; y: py }
                                    }
                                }
                                Hex { x: px - r; y: py - r; fill: "#050b1e"; edge: peer.online ? "#8fb4ee" : "#2a3d6e" }
                                QQC2.Label {
                                    x: index % 2 === 0 ? px + 12 : px - 12 - width
                                    y: py - height / 2
                                    text: peer.name
                                    color: peer.online ? root.hudMuted : root.hudDim
                                    font.family: root.mono; font.pixelSize: 9
                                }
                            }
                        }
                        Hex { x: map.width / 2 - r; y: map.height / 2 - r; r: 11; fill: root.hudAcc; edge: root.hudAcc }
                    }
                }
                HudReadout {
                    width: col.width
                    y: root.hudRowY(col, 2) - height / 2
                    label: "TRAFFIC"
                    value: "\u2191 " + root.bytes(root.txTotal) + "   \u2193 " + root.bytes(root.rxTotal)
                    valueColor: "#8fe6ff"
                    Spark { width: col.width; implicitHeight: 28; values: root.netHist; ceiling: 1e5 }
                }
            }
        }

        Component {
            id: todayCard
            Surface {
                width: root.look === "open" ? 360 : root.cardWidth
                QQC2.Label { text: Qt.formatDate(root.now, "dddd"); color: root.accent; font.pixelSize: root.look === "open" ? 20 : 14; font.weight: Font.DemiBold }
                QQC2.Label {
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: root.ink
                    font.pixelSize: root.look === "open" ? 104 : root.look === "gauges" ? 44 : 56
                    font.weight: root.look === "open" ? Font.Light : Font.DemiBold
                    Layout.topMargin: -6; Layout.bottomMargin: -6
                }
                QQC2.Label {
                    text: Qt.formatDate(root.now, "d MMMM") + (root.weather ? " · " + root.weather : "")
                    color: root.soft; font.pixelSize: root.look === "open" ? 16 : 13; wrapMode: Text.Wrap; Layout.fillWidth: true
                }
            }
        }

        Component {
            id: systemCard
            Surface {
                width: root.look === "open" ? 320 : root.cardWidth
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: "This computer"; color: root.ink; font.pixelSize: root.look === "open" ? 18 : 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    QQC2.Label { text: root.host; color: root.soft; font.pixelSize: 12 }
                }
                QQC2.Label {
                    text: (root.cpus ? root.cpus + (root.cpus === "1" ? " CPU" : " CPUs") : "") + (root.memTotal ? " · " + root.memTotal.toFixed(1) + " GB memory" : "") + (root.tower ? " · " + root.tower : "")
                    color: root.soft; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
                }
                Repeater {
                    model: [
                        { name: "Memory", share: root.memShare, detail: root.memUsed.toFixed(1) + " of " + root.memTotal.toFixed(1) + " GB" },
                        { name: "Disk", share: root.diskShare, detail: root.gb(root.diskFree) + " free of " + root.gb(root.diskSize) }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; Layout.topMargin: 6
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            QQC2.Label { text: modelData.name; color: root.ink; font.pixelSize: 12; font.weight: Font.Medium; Layout.fillWidth: true }
                            QQC2.Label { text: modelData.detail; color: root.faint; font.pixelSize: 12 }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6; radius: 3; color: Qt.alpha(root.ink, 0.14)
                            Rectangle {
                                width: parent.width * modelData.share
                                height: parent.height; radius: 3
                                color: modelData.share > 0.85 ? "#f0a63c" : root.accent
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: systemGauges
            Surface {
                RowLayout {
                    spacing: 18
                    Ring { share: root.memShare; centre: Math.round(root.memShare * 100) + "%"; caption: "Memory" }
                    Ring { share: root.diskShare; centre: Math.round(root.diskShare * 100) + "%"; caption: "Disk" }
                }
                QQC2.Label {
                    text: root.host + (root.tower ? " · " + root.tower : "")
                    color: root.faint; font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
