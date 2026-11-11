/*
 * CIT-OS Widgets (citos-plasma): the cards from the CIT-OS design, on the
 * desktop as macOS keeps its widgets: Today (the day, a large clock, the date
 * and Kampala's weather from Open-Meteo), This computer (memory, disk,
 * Tower) and the month. Frosted cards in the colour scheme's colours, so
 * they suit CIT-OS Horizon and Horizon Light; the wallpaper shows around them.
 */
import QtQuick
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

    readonly property color ink: Kirigami.Theme.textColor
    readonly property color soft: Qt.alpha(Kirigami.Theme.textColor, 0.72)
    readonly property color faint: Qt.alpha(Kirigami.Theme.textColor, 0.5)
    readonly property color accent: Kirigami.Theme.focusColor
    readonly property color onAccent: Kirigami.ColorUtils.brightnessForColor(accent) === Kirigami.ColorUtils.Light ? "#06122e" : "#ffffff"
    readonly property color cardColor: Qt.alpha(Kirigami.Theme.backgroundColor, 0.78)

    property date now: new Date()
    property string weather: ""
    property string host: ""
    property string cpus: ""
    property real memUsed: 0
    property real memTotal: 0
    property string disk: ""
    property string tower: ""

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    // Machine facts every 30 s; the weather every 20 minutes.
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 20 * 60000; running: true; repeat: true; triggeredOnStart: true
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
        sh.run("sh -c 'hostname; nproc; grep -E \"^(MemTotal|MemAvailable):\" /proc/meminfo; df -h --output=avail,size / | tail -1'", (out) => {
            const l = out.trim().split("\n")
            root.host = l[0] || ""
            root.cpus = l[1] || ""
            const kb = (re) => Number(((out.match(re) || [])[1]) || 0)
            root.memTotal = kb(/MemTotal:\s+(\d+)/) / 1048576
            root.memUsed = root.memTotal - kb(/MemAvailable:\s+(\d+)/) / 1048576
            const d = (l[l.length - 1] || "").trim().split(/\s+/)
            const gb = (v) => v.replace(/([0-9.]+)([KMGT])$/, "$1 $2B")
            root.disk = d.length === 2 ? gb(d[0]) + " free of " + gb(d[1]) : ""
        })
        sh.run("tailscale status --json --peers=false", (out) => {
            try {
                const s = JSON.parse(out)
                root.tower = s.BackendState === "Running" ? "On Tower · " + ((s.TailscaleIPs || [])[0] || "") : "Not on Tower"
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

    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 36
        radius: 22
        color: root.cardColor
        border.color: Qt.alpha(root.ink, 0.08)
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 6
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 300
        Layout.preferredHeight: col.implicitHeight
        Layout.minimumWidth: 260

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 14

            Card {
                QQC2.Label { text: Qt.formatDate(root.now, "dddd"); color: root.accent; font.pixelSize: 14; font.weight: Font.DemiBold }
                QQC2.Label { text: Qt.formatTime(root.now, "HH:mm"); color: root.ink; font.pixelSize: 56; font.weight: Font.DemiBold; Layout.topMargin: -6; Layout.bottomMargin: -6 }
                QQC2.Label {
                    text: Qt.formatDate(root.now, "d MMMM") + (root.weather ? " · " + root.weather : "")
                    color: root.soft; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true
                }
            }

            Card {
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: "This computer"; color: root.ink; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    QQC2.Label { text: root.host; color: root.soft; font.pixelSize: 12 }
                }
                QQC2.Label {
                    text: (root.cpus ? root.cpus + (root.cpus === "1" ? " CPU" : " CPUs") : "") + (root.memTotal ? " · " + root.memTotal.toFixed(1) + " GB" : "")
                    color: root.soft; font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.topMargin: 4
                    implicitHeight: 6; radius: 3; color: Qt.alpha(root.ink, 0.12)
                    Rectangle {
                        width: parent.width * (root.memTotal ? Math.min(1, root.memUsed / root.memTotal) : 0)
                        height: parent.height; radius: 3
                        color: root.memTotal && root.memUsed / root.memTotal > 0.85 ? "#f0a63c" : root.accent
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
                QQC2.Label { text: "Memory " + root.memUsed.toFixed(1) + " of " + root.memTotal.toFixed(1) + " GB"; color: root.faint; font.pixelSize: 12 }
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: root.disk ? "Disk " + root.disk : ""; color: root.faint; font.pixelSize: 12; Layout.fillWidth: true }
                    QQC2.Label { text: root.tower; color: root.faint; font.pixelSize: 12 }
                }
            }

            Card {
                QQC2.Label { text: Qt.formatDate(root.now, "MMMM").toUpperCase(); color: root.accent; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1 }
                QQC2.DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: Qt.locale("en_GB")
                    delegate: QQC2.Label {
                        required property string shortName
                        text: shortName.slice(0, 1)
                        color: root.faint; font.pixelSize: 11; font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                QQC2.MonthGrid {
                    Layout.fillWidth: true
                    month: root.now.getMonth()
                    year: root.now.getFullYear()
                    locale: Qt.locale("en_GB")
                    delegate: QQC2.Label {
                        required property int day
                        required property int month
                        required property bool today
                        text: day
                        topPadding: 4; bottomPadding: 4
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        font.weight: today ? Font.Bold : Font.Normal
                        color: today ? root.onAccent : month === root.now.getMonth() ? root.ink : "transparent"
                        background: Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: today ? root.accent : "transparent"
                        }
                    }
                }
            }
        }
    }
}
