/*
 * CIT-OS Today (citos-plasma): the date and time at the right of the top bar.
 * A click opens what macOS keeps behind its clock: notifications (newest
 * first, each closable, Clear for all) and the widgets from the CIT-OS
 * design: Today (the day, the time, the date and Kampala's weather), This
 * computer (memory, disk, Tower) and the month. Weather is Open-Meteo's
 * (free, no key); without a connection the line simply leaves it out.
 *
 * In Hex (the colour scheme's name, read as it opens) the cards are Hex's
 * panels: the top-left and bottom-right corners cut, a hairline lit at the
 * cut, mono figures and a square mark on today.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager
import QtQuick.Shapes

PlasmoidItem {
    id: root

    // Colours follow the colour scheme (CIT-OS Horizon or Horizon Light).
    readonly property color ink: Kirigami.Theme.textColor
    readonly property color soft: Qt.alpha(Kirigami.Theme.textColor, 0.72)
    readonly property color faint: Qt.alpha(Kirigami.Theme.textColor, 0.5)
    readonly property color accent: Kirigami.Theme.focusColor
    readonly property color onAccent: Kirigami.ColorUtils.brightnessForColor(accent) === Kirigami.ColorUtils.Light ? "#06122e" : "#ffffff"
    readonly property color card: Qt.alpha(Kirigami.Theme.textColor, 0.06)

    property bool hex: false

    property date now: new Date()
    property string weather: ""
    property var weatherAt: null
    property string host: ""
    property string cpus: ""
    property real memUsed: 0
    property real memTotal: 0
    property string disk: ""
    property string tower: ""

    Plasmoid.icon: "preferences-system-time"
    toolTipMainText: Qt.formatDate(now, "dddd d MMMM yyyy")
    toolTipSubText: notifs.count > 0 ? notifs.count + (notifs.count === 1 ? " notification" : " notifications") : ""
    Plasmoid.status: notifs.unreadNotificationsCount > 0 ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        Layout.minimumWidth: label.implicitWidth + 16
        Layout.preferredWidth: label.implicitWidth + 16
        onClicked: root.expanded = !root.expanded
        Rectangle {
            anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3
            radius: 6
            color: root.expanded ? Qt.alpha(root.ink, 0.16) : button.containsMouse ? Qt.alpha(root.ink, 0.08) : "transparent"
        }
        RowLayout {
            id: label
            anchors.centerIn: parent
            spacing: 6
            QQC2.Label {
                text: Qt.formatDate(root.now, "ddd d MMM") + "   " + Qt.formatTime(root.now, "HH:mm")
                color: root.ink
                font.pixelSize: Math.max(12, Math.round(button.height * 0.46))
                font.weight: Font.Medium
            }
            // A dot while there are unread notifications.
            Rectangle {
                visible: notifs.unreadNotificationsCount > 0
                width: 6; height: 6; radius: 3; color: root.accent
            }
        }
    }

    onExpandedChanged: {
        if (!root.expanded) {
            notifs.lastRead = new Date()
            return
        }
        refresh()
    }

    // Every notification Plasma keeps, newest first; jobs (copies) stay in their own popups.
    NotificationManager.Notifications {
        id: notifs
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupDisabled
    }

    function clearAll() {
        for (let i = notifs.count - 1; i >= 0; i--) notifs.close(notifs.index(i, 0))
        notifs.clear(NotificationManager.Notifications.ClearExpired)
    }

    function ago(d) {
        const s = Math.max(0, (root.now - d) / 1000)
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + " min"
        if (s < 86400) return Qt.formatTime(d, "HH:mm")
        return Qt.formatDate(d, "d MMM")
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
        sh.run("kreadconfig6 --file kdeglobals --group General --key ColorScheme", (out) => { root.hex = /Hex/.test(out) })
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
                root.tower = s.BackendState === "Running" ? "on Tower · " + ((s.TailscaleIPs || [])[0] || "") : "not on Tower"
            } catch (e) { root.tower = "" }
        })
        // The weather at most every 20 minutes.
        if (!root.weatherAt || (new Date() - root.weatherAt) > 20 * 60000) fetchWeather()
    }

    function fetchWeather() {
        const x = new XMLHttpRequest()
        x.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=0.3476&longitude=32.5825&current=temperature_2m,weather_code&timezone=auto")
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return
            try {
                const c = JSON.parse(x.responseText).current
                root.weather = "Kampala " + Math.round(c.temperature_2m) + "°, " + describe(c.weather_code)
                root.weatherAt = new Date()
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

    component Card: Item {
        id: cardItem
        default property alias content: inner.data
        implicitHeight: inner.implicitHeight + 28
        // Horizon: a rounded card.
        Rectangle {
            anchors.fill: parent
            visible: !root.hex
            radius: 18
            color: root.card
            border.color: Qt.alpha(root.ink, 0.07)
        }
        // Hex: a panel with two corners cut, its hairline lit at the cut.
        Shape {
            anchors.fill: parent
            visible: root.hex
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1
                strokeColor: Qt.alpha(root.ink, 0.16)
                fillColor: root.card
                readonly property real c: 12
                startX: c; startY: 0.5
                PathLine { x: cardItem.width - 0.5; y: 0.5 }
                PathLine { x: cardItem.width - 0.5; y: cardItem.height - 12 }
                PathLine { x: cardItem.width - 12; y: cardItem.height - 0.5 }
                PathLine { x: 0.5; y: cardItem.height - 0.5 }
                PathLine { x: 0.5; y: 12 }
                PathLine { x: 12; y: 0.5 }
            }
            ShapePath {
                strokeWidth: 1.5
                strokeColor: root.accent
                fillColor: "transparent"
                startX: 0.75; startY: 30
                PathLine { x: 0.75; y: 12 }
                PathLine { x: 12; y: 0.75 }
                PathLine { x: 44; y: 0.75 }
            }
        }
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 6
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 380
        Layout.minimumWidth: 380
        Layout.maximumWidth: 380
        Layout.preferredHeight: Math.min(720, body.implicitHeight + 32)
        Layout.minimumHeight: 320

        QQC2.ScrollView {
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: availableWidth
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 12

                // Notifications
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Label { text: "Notifications"; color: root.ink; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    QQC2.ToolButton {
                        visible: notifs.count > 0
                        text: "Clear"
                        onClicked: root.clearAll()
                    }
                }
                QQC2.Label {
                    visible: notifs.count === 0
                    text: "No notifications"
                    color: root.faint
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 6; Layout.bottomMargin: 6
                }
                Repeater {
                    model: notifs
                    delegate: Rectangle {
                        id: n
                        required property int index
                        required property var model
                        Layout.fillWidth: true
                        implicitHeight: ncol.implicitHeight + 24
                        radius: root.hex ? 0 : 16
                        color: nArea.containsMouse ? Qt.alpha(root.ink, 0.11) : root.card
                        // Hex: lit from its left edge, like Hex's list rows.
                        Rectangle { visible: root.hex; width: 2; height: parent.height; color: root.accent }
                        MouseArea {
                            id: nArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (n.model.hasDefaultAction) notifs.invokeDefaultAction(notifs.index(n.index, 0))
                            }
                        }
                        RowLayout {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 10
                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                source: n.model.applicationIconName || n.model.iconName || "preferences-desktop-notification"
                            }
                            ColumnLayout {
                                id: ncol
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    QQC2.Label { text: n.model.applicationName || ""; color: root.soft; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                    QQC2.Label { text: n.model.created ? root.ago(n.model.created) : ""; color: root.faint; font.pixelSize: 12; visible: !closeBtn.visible }
                                    QQC2.ToolButton {
                                        id: closeBtn
                                        visible: nArea.containsMouse || hovered
                                        icon.name: "window-close"
                                        implicitWidth: 22; implicitHeight: 22
                                        onClicked: notifs.close(notifs.index(n.index, 0))
                                    }
                                }
                                QQC2.Label { text: n.model.summary || ""; color: root.ink; font.pixelSize: 13; font.weight: Font.DemiBold; wrapMode: Text.Wrap; Layout.fillWidth: true; visible: text.length > 0 }
                                QQC2.Label { text: n.model.body || ""; textFormat: Text.StyledText; color: root.soft; font.pixelSize: 13; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; Layout.fillWidth: true; visible: text.length > 0 }
                            }
                        }
                    }
                }

                // Today
                Card {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    QQC2.Label { text: Qt.formatDate(root.now, "dddd"); color: root.accent; font.pixelSize: 13; font.weight: Font.DemiBold }
                    QQC2.Label { text: Qt.formatTime(root.now, "HH:mm"); color: root.ink; font.pixelSize: root.hex ? 38 : 44; font.weight: root.hex ? Font.Medium : Font.DemiBold; font.family: root.hex ? "JetBrains Mono" : Kirigami.Theme.defaultFont.family; Layout.topMargin: root.hex ? -6 : -4; Layout.bottomMargin: root.hex ? -8 : -4 }
                    QQC2.Label {
                        text: Qt.formatDate(root.now, "d MMMM") + (root.weather ? " · " + root.weather : "")
                        color: root.soft; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                }

                // This computer
                Card {
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.Label { text: "This computer"; color: root.ink; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        QQC2.Label { text: root.host; color: root.soft; font.pixelSize: 12 }
                    }
                    QQC2.Label {
                        text: (root.cpus ? root.cpus + (root.cpus === "1" ? " CPU" : " CPUs") : "") + (root.memTotal ? " · " + root.memTotal.toFixed(1) + " GB" : "") + (root.tower ? " · " + root.tower : "")
                        color: root.soft; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.topMargin: 4
                        implicitHeight: 6; radius: 3; color: Qt.alpha(root.ink, 0.12)
                        Rectangle {
                            width: parent.width * (root.memTotal ? Math.min(1, root.memUsed / root.memTotal) : 0)
                            height: parent.height; radius: 3
                            color: root.memTotal && root.memUsed / root.memTotal > 0.85 ? "#f0a63c" : root.accent
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.Label { text: "Memory " + root.memUsed.toFixed(1) + " of " + root.memTotal.toFixed(1) + " GB"; color: root.faint; font.pixelSize: 12; Layout.fillWidth: true }
                        QQC2.Label { text: root.disk ? "Disk " + root.disk : ""; color: root.faint; font.pixelSize: 12 }
                    }
                }

                // The month
                Card {
                    Layout.fillWidth: true
                    QQC2.Label { text: Qt.formatDate(root.now, "MMMM yyyy"); color: root.ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                    QQC2.DayOfWeekRow {
                        Layout.fillWidth: true
                        locale: Qt.locale("en_GB")
                        delegate: QQC2.Label {
                            required property string shortName
                            text: shortName.slice(0, 2)
                            color: root.faint; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    QQC2.MonthGrid {
                        Layout.fillWidth: true
                        month: root.now.getMonth()
                        year: root.now.getFullYear()
                        locale: Qt.locale("en_GB")
                        // MonthGrid's own delegate pattern: a Label per day (it
                        // sizes the cells), today on an accent disc.
                        delegate: QQC2.Label {
                            required property int day
                            required property int month
                            required property bool today
                            text: day
                            topPadding: 6; bottomPadding: 6
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            font.weight: today ? Font.Bold : Font.Normal
                            color: today ? root.onAccent : month === root.now.getMonth() ? root.ink : Qt.alpha(root.ink, 0.3)
                            background: Rectangle {
                                anchors.centerIn: parent
                                width: 26; height: 26; radius: root.hex ? 3 : 13
                                color: today ? root.accent : "transparent"
                            }
                        }
                    }
                }
            }
        }
    }
}
