import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// Updates: CybroidOS's and Debian's (deb.cybroid.com), and the person's
// Flatpak apps. Whether the computer is up to date (apt's lists, refreshed
// daily by apt's own timer), what's waiting, installing them now (the
// cybroid-update helper through pkexec: an administrator's password) and
// whether they install by themselves (unattended-upgrades).
SettingsPage {
    id: page
    title: "Updates"

    property string version: ""
    property var waiting: []       // package names
    property real checked: 0       // when the lists were last fetched (ms)
    property bool auto: true
    property bool restart: false
    property string state: ""      // "", working, done, failed
    property string progress: ""
    property string failure: ""
    property bool systemPart: false    // the helper is running (its log is read)

    function refresh() {
        const rel = System.readText("/etc/os-release")
        version = ((rel.match(/^VERSION="?([^"\n]*)/m) || [])[1]) || ""
        System.run(["sh", "-c", "apt list --upgradable 2>/dev/null | sed -n 's|/.*||p'"], (o) => waiting = o.split("\n").filter(n => n && n !== "Listing..."))
        System.run(["stat", "-c", "%Y", "/var/lib/apt/periodic/update-success-stamp", "/var/lib/apt/lists"], (o) => {
            checked = Math.max(...o.trim().split("\n").map(Number).filter(n => n > 0)) * 1000
        })
        auto = /Unattended-Upgrade\s+"1"/.test(System.readText("/etc/apt/apt.conf.d/20auto-upgrades"))
        restart = System.exists("/run/reboot-required")
    }
    function ago(ms) {
        if (!ms) return "never"
        const m = Math.round((Date.now() - ms) / 60000)
        return m < 2 ? "just now" : m < 60 ? m + " minutes ago" : m < 1440 ? Math.round(m / 60) + " hours ago" : Math.round(m / 1440) + " days ago"
    }
    function updateNow() {
        state = "working"; progress = "Asking for permission…"; failure = ""; systemPart = true
        System.run(["pkexec", "/usr/libexec/cybroid/cybroid-update", "now"], (o, code) => {
            systemPart = false
            // pkexec: 126 when the password prompt was dismissed (nothing to
            // say), 127 when it couldn't ask at all.
            if (code === 126) { state = ""; progress = ""; return }
            if (code === 127) { state = "failed"; progress = ""; failure = "Couldn't ask for an administrator's password"; return }
            if (code !== 0) { state = "failed"; refresh(); return }
            progress = "Updating apps…"
            System.run(["flatpak", "update", "-y", "--noninteractive"], () => { state = "done"; refresh() })
        })
    }
    Component.onCompleted: refresh()
    // While it works, the helper's last line.
    Timer {
        interval: 700; repeat: true
        running: page.state === "working" && page.systemPart
        onTriggered: {
            const lines = System.readText("/var/log/cybroid-update.log").trim().split("\n")
            const l = lines[lines.length - 1] || ""
            if (/^== /.test(l)) page.progress = l.slice(3) + "…"
            else if (/^(Unpacking|Setting up|Get:\d+)/.test(l)) page.progress = l.replace(/^Get:\d+ \S+ \S+ \S+ /, "Downloading ").replace(/ \(.*$/, "").slice(0, 70)
        }
    }

    // The state, large.
    Surface {
        Layout.fillWidth: true
        implicitHeight: 104
        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16
            Kirigami.Icon {
                id: stateIcon
                implicitWidth: 44; implicitHeight: 44
                source: page.state === "working" ? "view-refresh-symbolic" : page.state === "failed" ? "dialog-error-symbolic" : page.waiting.length ? "system-software-update-symbolic" : "checkmark-symbolic"
                isMask: true
                color: page.state === "failed" ? Theme.bad : page.waiting.length || page.state === "working" ? Theme.accent : Theme.ok
                RotationAnimator on rotation { running: page.state === "working"; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
                // Upright again when the work stops (the animator leaves its angle).
                Connections { target: page; function onStateChanged() { if (page.state !== "working") stateIcon.rotation = 0 } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Label {
                    Layout.fillWidth: true
                    text: page.state === "working" ? "Updating" : page.state === "failed" ? "The update didn't finish"
                        : page.waiting.length ? page.waiting.length + (page.waiting.length === 1 ? " update" : " updates") + " to install"
                        : "CybroidOS is up to date"
                    font.pixelSize: 18; font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    text: page.state === "working" ? page.progress
                        : page.state === "failed" ? (page.failure || "Check the connection and try again; details in /var/log/cybroid-update.log")
                        : "Version " + page.version + " · checked " + page.ago(page.checked)
                    color: page.state === "failed" ? Theme.bad : Theme.soft
                }
            }
            Btn {
                text: page.waiting.length ? "Update now" : "Check now"
                primary: page.waiting.length > 0
                enabled: page.state !== "working"
                onClicked: page.updateNow()
            }
        }
    }

    Surface {
        visible: page.restart
        Layout.fillWidth: true
        implicitHeight: 60
        stroke: Theme.accent
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            Label { Layout.fillWidth: true; text: "Restart to finish the update"; font.weight: Font.DemiBold }
            Btn {
                text: "Restart"; primary: true
                onClicked: System.launch(["qdbus6", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptReboot"])
            }
        }
    }

    Section { visible: page.waiting.length > 0; title: "Waiting" }
    Card {
        visible: page.waiting.length > 0
        SettingRow {
            title: page.waiting.slice(0, 6).join(", ") + (page.waiting.length > 6 ? " and " + (page.waiting.length - 6) + " more" : "")
            subtitle: page.waiting.some(n => /^cybroid-/.test(n)) ? "Includes CybroidOS itself" : "Security and app updates from Debian"
            icon: "package-x-generic-symbolic"
            iconColor: Theme.soft
        }
    }

    Section { title: "Automatic updates" }
    Card {
        SettingRow {
            title: "Install updates by themselves"
            subtitle: "CybroidOS and security updates, once a day in the background"
            icon: "system-software-update-symbolic"
            Toggle {
                checked: page.auto
                onToggled: (on) => System.run(["pkexec", "/usr/libexec/cybroid/cybroid-update", "auto", on ? "on" : "off"], () => page.refresh())
            }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Get more apps"
            subtitle: "App Centre"
            clickable: true
            onClicked: System.launch(["plasma-discover"])
        }
    }
}
