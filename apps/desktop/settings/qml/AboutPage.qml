import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// This computer: its name (hostnamectl; others see it on the network and in
// KDE Connect), CybroidOS's version, and the hardware.
SettingsPage {
    id: page
    title: "About"

    property var os: ({})
    property string host: ""
    property string cpu: ""
    property string gpu: ""
    property string memory: ""
    property string disk: ""
    property string plasma: ""
    property string kernel: ""
    property string editions: ""   // "Security", "Developer + Network": installed editions
    property bool renaming: false
    property string error: ""

    function gib(kb) { return (kb / 1048576).toFixed(kb > 8 * 1048576 ? 0 : 1) + " GB" }
    function refresh() {
        const rel = System.readText("/etc/os-release")
        const m = {}
        for (const l of rel.split("\n")) { const i = l.indexOf("="); if (i > 0) m[l.slice(0, i)] = l.slice(i + 1).replace(/^"|"$/g, "") }
        os = m
        System.run(["hostnamectl", "hostname"], (o) => host = o.trim())
        const ci = System.readText("/proc/cpuinfo")
        const model = (ci.match(/model name\s*:\s*(.*)/) || [])[1] || ""
        const n = (ci.match(/^processor\s*:/gm) || []).length
        cpu = model.replace(/\(R\)|\(TM\)|CPU |@.*$/g, "").replace(/\s+/g, " ").trim() + (n ? " · " + n + " threads" : "")
        const mi = System.readText("/proc/meminfo")
        memory = gib(parseInt((mi.match(/MemTotal:\s*(\d+)/) || [0, 0])[1]))
        System.run(["df", "-k", "--output=size,avail", "/"], (o) => {
            const f = o.trim().split("\n").pop().trim().split(/\s+/)
            if (f.length === 2) disk = gib(parseInt(f[1])) + " free of " + gib(parseInt(f[0]))
        })
        // Graphics: each display controller lspci knows, by its short name
        // ("Intel Iris Xe Graphics", "AMD Radeon 780M").
        System.run(["lspci", "-mm"], (o) => {
            const names = []
            for (const l of o.split("\n")) {
                const f = (l.match(/"[^"]*"/g) || []).map(x => x.slice(1, -1))
                if (f.length < 3 || !/VGA|3D|Display/.test(f[0])) continue
                const vendor = /NVIDIA/i.test(f[1]) ? "NVIDIA" : /\bIntel\b/i.test(f[1]) ? "Intel" : /\bAMD\b|\bATI\b|Advanced Micro Devices/.test(f[1]) ? "AMD" : f[1].replace(/,? (Inc|Corporation|Corp|Ltd)\.?$/, "")  // whole words: "Intel Corporation" contains "ati"
                const dev = (f[2].match(/\[([^\]]+)\]/) || [null, f[2]])[1]
                names.push(vendor + " " + dev)
            }
            gpu = names.filter(n => !/Device [0-9a-f]{4}$/.test(n)).join(" + ")
        })
        System.run(["plasmashell", "--version"], (o) => plasma = ((o.match(/plasmashell\s+(\S+)/) || [])[1] || ""))
        System.run(["uname", "-r"], (o) => kernel = o.trim())
        // Editions (cybroid-edition-*): each leaves its name in /usr/share/cybroid/editions.
        System.run(["sh", "-c", "for f in /usr/share/cybroid/editions/*; do [ -f \"$f\" ] && head -n 1 \"$f\"; done; true"],
                   (o) => editions = o.trim().split("\n").filter(s => s).join(" + "))
    }
    Component.onCompleted: refresh()

    // CybroidOS, large, with its mark.
    Surface {
        Layout.fillWidth: true
        implicitHeight: 128
        RowLayout {
            anchors.centerIn: parent
            spacing: 18
            Kirigami.Icon {
                implicitWidth: 64; implicitHeight: 64
                source: "cybroid-mark"
            }
            ColumnLayout {
                spacing: 2
                Label {
                    text: Theme.hex ? "CYBROIDOS" : "CybroidOS"
                    font.family: Theme.hex ? Theme.mono : Theme.font
                    font.pixelSize: 26
                    font.weight: Theme.hex ? Font.Medium : Font.Bold
                    font.letterSpacing: Theme.hex ? 4 : -0.3
                }
                Label {
                    text: (page.editions ? page.editions + (page.editions.indexOf("+") >= 0 ? " editions" : " edition") + " · " : "") + "Version " + (page.os.VERSION_ID || "")
                    color: Theme.soft; font.pixelSize: 13
                }
            }
        }
    }

    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: Theme.bad
        wrapMode: Text.WordWrap
    }

    Section { title: "Editions" }
    Card {
        SettingRow {
            icon: "system-software-install-symbolic"
            title: page.editions ? page.editions : "No editions yet"
            subtitle: "Tools for your work: Developer, Security, Network, Engineering, Classroom"
            Btn { text: "Add an edition"; onClicked: System.launch(["cybroid-settings", "welcome", "editions"]) }
        }
    }

    Section { title: "This computer" }
    Card {
        SettingRow {
            title: "Name"
            subtitle: "How it appears on the network and to your other devices"
            visible: !page.renaming
            clickable: true
            chevron: false
            onClicked: { page.renaming = true; nameField.text = page.host; nameField.forceActiveFocus(); nameField.selectAll() }
            Label { text: page.host; color: Theme.soft; font.family: Theme.hex ? Theme.mono : Theme.font }
            Kirigami.Icon { implicitWidth: 14; implicitHeight: 14; source: "document-edit-symbolic"; isMask: true; color: Theme.faint }
        }
        SettingRow {
            title: "Name"
            visible: page.renaming
            Field {
                id: nameField
                implicitWidth: 220
                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9][A-Za-z0-9-]{0,62}/ }
                onAccepted: save.clicked()
            }
            Btn { text: "Cancel"; onClicked: page.renaming = false }
            Btn {
                id: save
                text: "Save"
                primary: true
                enabled: nameField.acceptableInput && nameField.text !== page.host
                onClicked: {
                    page.error = ""
                    System.run(["hostnamectl", "set-hostname", nameField.text], (o, code) => {
                        if (code !== 0) page.error = "Couldn't rename the computer: " + o.trim()
                        else page.renaming = false
                        page.refresh()
                    })
                }
            }
        }
        SettingRow { title: "Processor"; Label { text: page.cpu; color: Theme.soft } }
        SettingRow { title: "Memory"; Label { text: page.memory; color: Theme.soft } }
        SettingRow { visible: page.gpu !== ""; title: "Graphics"; Label { text: page.gpu; color: Theme.soft; Layout.maximumWidth: 360 } }
        SettingRow { title: "Storage"; Label { text: page.disk; color: Theme.soft } }
    }

    Section { title: "Software" }
    Card {
        SettingRow { title: "CybroidOS"; Label { text: page.os.VERSION || ""; color: Theme.soft } }
        SettingRow {
            title: "Updates"
            subtitle: "CybroidOS and security updates install by themselves"
            clickable: true
            onClicked: System.launch(["cybroid-settings", "updates"])
        }
        SettingRow { visible: page.plasma !== ""; title: "Desktop"; Label { text: "KDE Plasma " + page.plasma; color: Theme.soft } }
        SettingRow { visible: page.kernel !== ""; title: "Kernel"; Label { text: "Linux " + page.kernel; color: Theme.soft } }
        SettingRow {
            title: "All the details"
            subtitle: "Hardware, drivers and more, to copy into a help request"
            clickable: true
            onClicked: System.launch(["kinfocenter"])
        }
    }
}
