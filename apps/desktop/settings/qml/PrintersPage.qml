import QtQuick
import QtQuick.Layouts
import Cybroid.Ui

// Printers and scanners (CUPS): the printers this computer knows (network
// ones appear by themselves through cups-browsed and IPP Everywhere), which
// one prints first, their queues, a test page, adding and removing; scanning.
SettingsPage {
    id: page
    title: "Printers"

    property var printers: []      // {name, state, info}
    property string def: ""
    property string error: ""

    function refresh() {
        System.run(["lpstat", "-d"], (o) => def = (o.match(/destination:\s*(\S+)/) || [])[1] || "")
        System.run(["lpstat", "-p"], (o) => {
            const list = []
            for (const l of o.split("\n")) {
                const m = l.match(/^printer (\S+) (?:is )?(idle|now printing|disabled)/)
                if (m) list.push({ name: m[1], state: m[2] })
            }
            printers = list
        })
    }
    function act(args) {
        error = ""
        System.run(args, (out, code) => { if (code !== 0) error = out.trim().split("\n").pop(); refresh() })
    }
    Component.onCompleted: refresh()
    Timer { interval: 5000; repeat: true; running: page.visible; onTriggered: page.refresh() }

    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: Theme.bad
        wrapMode: Text.WordWrap
    }

    Section { title: "Printers"; caption: "Printers on your network appear here by themselves" }
    Card {
        Repeater {
            model: page.printers
            SettingRow {
                required property var modelData
                title: modelData.name.replace(/_/g, " ")
                subtitle: (modelData.name === page.def ? "Prints first · " : "") +
                          (modelData.state === "idle" ? "Ready" : modelData.state === "now printing" ? "Printing" : "Paused")
                icon: "printer-symbolic"
                iconColor: modelData.name === page.def ? Theme.accent : Theme.soft
                Btn { text: "Queue"; onClicked: System.launch(["kde-print-queue", modelData.name]) }
                Btn {
                    visible: modelData.name !== page.def
                    text: "Print first"
                    onClicked: page.act(["lpoptions", "-d", modelData.name])
                }
                Btn {
                    text: "Test page"
                    onClicked: page.act(["lp", "-d", modelData.name, "-t", "Test page", "/usr/share/cups/data/testprint"])
                }
            }
        }
        SettingRow {
            visible: page.printers.length === 0
            title: "No printers yet"
            subtitle: "Turn the printer on and connect it to the same network, or plug it in with USB"
        }
        SettingRow {
            title: "Add a printer"
            clickable: true
            onClicked: System.launch(["kde-add-printer", "--add-printer"])
        }
    }

    Section { title: "Scanners" }
    Card {
        SettingRow {
            title: "Scan a document"
            subtitle: "Scanners on the network and USB scanners"
            icon: "scanner-symbolic"
            clickable: true
            onClicked: System.launch(["skanlite"])
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Printer options, sharing and removing"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_printer_manager"])
        }
    }
}
