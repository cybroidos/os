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
 */
import QtQuick
import QtQuick.Effects
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

    readonly property real memShare: memTotal ? Math.min(1, memUsed / memTotal) : 0
    readonly property real diskShare: diskSize ? Math.min(1, (diskSize - diskFree) / diskSize) : 0

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    // Machine facts every 15 s; the weather every 20 minutes.
    Timer {
        interval: 15000; running: root.card === "system"; repeat: true; triggeredOnStart: true
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
        sh.run("tailscale status --json --peers=false", (out) => {
            try {
                const s = JSON.parse(out)
                root.tower = s.BackendState === "Running" ? "On Tower" : "Not on Tower"
            } catch (e) { root.tower = "" }
        })
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

    fullRepresentation: Item {
        Layout.preferredWidth: view.implicitWidth
        Layout.preferredHeight: view.implicitHeight
        Layout.minimumWidth: 220

        Loader {
            id: view
            anchors.left: parent.left
            sourceComponent: root.card === "system" ? (root.look === "gauges" ? systemGauges : systemCard) : todayCard
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
