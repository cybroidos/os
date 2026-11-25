import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// CybroidOS's welcome (cybroid-settings welcome): shown once, at a new
// account's first sign-in (/usr/libexec/cybroid/welcome-start). Six steps,
// each skippable: hello; the look (Settings' own Appearance page); a picture
// for the account; Wi-Fi (Settings' own Wi-Fi page); editions (one ISO for
// everyone: each edition is a package, installed here from deb.cybroid.com
// by cybroid-editions); and where things are.
// Closing it at any point, or finishing, leaves ~/.config/cybroid/welcome-done
// so it doesn't come back; Settings has every choice made here.
Window {
    id: win
    width: 900
    height: 680
    minimumWidth: 720
    minimumHeight: 560
    visible: true
    title: "Welcome to CybroidOS"
    color: Theme.bg

    readonly property var steps: ["Welcome", "Look", "Picture", "Wi-Fi", "Editions", "Ready"]
    property int step: 0
    property string userName: ""
    property string fullName: ""
    property string userPath: ""     // the account in AccountsService
    property string picture: ""      // its picture, once one is set

    // A second start (cybroid-settings welcome) only brings this window forward.
    function showPage(p) { }

    function done() {
        const dir = System.folder("config") + "/cybroid"
        System.makeDir(dir)
        System.run(["touch", dir + "/welcome-done"], () => Qt.quit())
    }
    onClosing: (close) => { close.accepted = false; if (editionState !== "busy") done() }

    function bus(args, then) {
        System.run(["busctl", "--system", "--json=short"].concat(args), (o, code) => {
            if (code !== 0) return
            try { then(JSON.parse(o)) } catch (e) { }
        })
    }
    function readAccount() {
        System.run(["id", "-un"], (o) => {
            win.userName = o.trim()
            bus(["call", "org.freedesktop.Accounts", "/org/freedesktop/Accounts", "org.freedesktop.Accounts", "FindUserByName", "s", win.userName], (j) => {
                win.userPath = j.data[0]
                bus(["call", "org.freedesktop.Accounts", win.userPath, "org.freedesktop.DBus.Properties", "GetAll", "s", "org.freedesktop.Accounts.User"], (p) => {
                    const v = p.data[0]
                    win.fullName = v.RealName ? v.RealName.data : ""
                    const icon = v.IconFile ? v.IconFile.data : ""
                    win.picture = icon && System.exists(icon) ? icon : ""
                })
            })
        })
    }
    Component.onCompleted: {
        readAccount()
        if (welcomeStep === "editions") step = steps.indexOf("Editions")
    }
    readonly property string firstName: (fullName || userName).split(" ")[0]

    FileDialog {
        id: picker
        title: "Choose a picture"
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp)"]
        currentFolder: "file://" + System.folder("pictures")
        onAccepted: {
            if (!win.userPath) return
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
            win.bus(["call", "org.freedesktop.Accounts", win.userPath, "org.freedesktop.Accounts.User", "SetIconFile", "s", path], () => pictureLater.start())
        }
    }
    Timer { id: pictureLater; interval: 400; onTriggered: win.readAccount() }

    // Editions: chosen here, installed by cybroid-editions (pkexec), which
    // writes its progress to a log this reads every second.
    readonly property var editionList: [
        ["developer", "utilities-terminal-symbolic", "Developer", "Visual Studio Code, Docker, Git and GitHub CLI, Python, Java, Node.js, Go, Rust, PHP, Postman and DBeaver."],
        ["security", "security-high-symbolic", "Security", "Kali's tools (Burp Suite, Metasploit) with Nmap, Wireshark, Hydra, hashcat and forensics tools."],
        ["network", "network-wired-symbolic", "Network", "Wireshark, PuTTY, WinBox, iperf3, a TFTP server, Ansible and practice routers."],
        ["engineering", "applications-engineering-symbolic", "Engineering", "KiCad, FreeCAD, LibreCAD, Arduino IDE 2, circuit simulators, Octave and JupyterLab."],
        ["classroom", "applications-education-symbolic", "Classroom", "Veyon for the teacher, lab accounts reset at each start, Scratch, GeoGebra, Kiwix and learning apps."]
    ]
    property var chosen: ({})
    property var installed: ({})
    property string editionState: ""   // "", "busy", "done", "failed"
    property string editionLine: ""
    readonly property var chosenList: editionList.map(e => e[0]).filter(k => chosen[k] && !installed[k])
    function readInstalled() {
        const got = {}
        editionList.forEach(e => { if (System.exists("/usr/share/cybroid/editions/" + e[0])) got[e[0]] = true })
        installed = got
    }
    function installEditions() {
        if (!chosenList.length) return
        editionState = "busy"
        editionLine = "Asking for the administrator's password…"
        editionPoll.start()
        System.run(["pkexec", "/usr/libexec/cybroid/cybroid-editions", "install"].concat(chosenList), (o, code) => {
            editionPoll.stop()
            readInstalled()
            editionState = code === 0 ? "done" : "failed"
            editionLine = code === 0 ? "Installed. Your new apps are in Launchpad."
                : code === 126 || code === 127 ? "Not installed: the password wasn't given."
                : "Not installed. Check the internet connection and try again; Settings can install editions later too."
        })
    }
    Timer {
        id: editionPoll
        interval: 1000
        repeat: true
        onTriggered: {
            const lines = System.readText("/var/log/cybroid-editions.log").split("\n").filter(l => l.startsWith("== "))
            if (lines.length) win.editionLine = lines[lines.length - 1].slice(3)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Where you are: the steps, the current one lit.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 22
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            spacing: 8
            Kirigami.Icon { source: "cybroid-mark"; implicitWidth: 26; implicitHeight: 26 }
            Label {
                text: Theme.hex ? "CYBROIDOS" : "CybroidOS"
                font.family: Theme.labelFont
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.hex ? 3 : 0
                Layout.rightMargin: 16
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: win.steps
                RowLayout {
                    required property int index
                    required property string modelData
                    spacing: 6
                    Rectangle {
                        width: 8; height: 8
                        radius: Theme.hex ? 0 : 4
                        rotation: Theme.hex ? 45 : 0
                        color: index === win.step ? Theme.accent : index < win.step ? Theme.soft : Theme.track
                    }
                    Label {
                        text: Theme.hex ? modelData.toUpperCase() : modelData
                        font.family: Theme.labelFont
                        font.pixelSize: Theme.hex ? 11 : 12
                        color: index === win.step ? Theme.ink : Theme.faint
                        Layout.rightMargin: 8
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.step

            // 1. Hello
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(560, parent.width - 64)
                    spacing: 14
                    Kirigami.Icon { source: "cybroid-mark"; implicitWidth: 96; implicitHeight: 96; Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 8 }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: win.firstName ? "Welcome, " + win.firstName + "." : "Welcome."
                        font.family: Theme.hex ? Theme.mono : Theme.font
                        font.pixelSize: 34
                        font.weight: Theme.hex ? Font.Medium : Font.Bold
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        color: Theme.soft
                        font.pixelSize: 16
                        text: "Let's make this computer yours: choose how it looks, add your picture and get online. It takes a minute, and you can change all of it later in Settings."
                    }
                }
            }

            // 2. The look: Settings' Appearance page.
            AppearancePage { title: "Choose your look"; subtitle: "Horizon is calm and familiar. Hex keeps system and network status in view." }

            // 3. A picture for the account
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(560, parent.width - 64)
                    spacing: 16
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: "Add your picture"
                        font.family: Theme.hex ? Theme.mono : Theme.font
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        color: Theme.soft
                        text: "It shows at the top right of your screen, on the sign-in screen and on the lock screen."
                    }
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        implicitWidth: 132; implicitHeight: 132
                        Surface { anchors.fill: parent; radius: 66; cut: 18; fill: Theme.selected; strokeWidth: 0 }
                        Image {
                            id: face
                            anchors.fill: parent
                            anchors.margins: 3
                            visible: status === Image.Ready
                            source: win.picture ? "file://" + win.picture : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 264
                            cache: false
                        }
                        Label {
                            visible: !face.visible
                            anchors.centerIn: parent
                            text: (win.fullName || win.userName || "?").split(" ").filter(s => s).map(s => s[0]).slice(0, 2).join("").toUpperCase()
                            color: Theme.accent
                            font.pixelSize: 46
                            font.weight: Font.DemiBold
                        }
                    }
                    Btn {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.picture ? "Choose another picture" : "Choose a picture"
                        primary: !win.picture
                        enabled: win.userPath !== ""
                        onClicked: picker.open()
                    }
                }
            }

            // 4. Wi-Fi: Settings' Wi-Fi page.
            WifiPage { title: "Get online"; subtitle: "Join a Wi-Fi network. A cable or a network you already joined works too." }

            // 5. Editions: what this computer is for.
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(640, parent.width - 64)
                    spacing: 10
                    Component.onCompleted: win.readInstalled()
                    Label {
                        Layout.fillWidth: true
                        text: "What is this computer for?"
                        font.family: Theme.hex ? Theme.mono : Theme.font
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        color: Theme.soft
                        Layout.bottomMargin: 4
                        text: "Add the tools for your work. Choose any, or none: CybroidOS already has Office, a web browser and everyday apps. They download now, and Settings can add more later."
                    }
                    Repeater {
                        model: win.editionList
                        Card {
                            required property var modelData
                            Layout.fillWidth: true
                            SettingRow {
                                icon: modelData[1]
                                title: modelData[2] + (win.installed[modelData[0]] ? " · installed" : "")
                                subtitle: modelData[3]
                                Toggle {
                                    checked: win.installed[modelData[0]] || !!win.chosen[modelData[0]]
                                    enabled: !win.installed[modelData[0]] && win.editionState !== "busy"
                                    onToggled: (on) => { const c = Object.assign({}, win.chosen); c[modelData[0]] = on; win.chosen = c }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 12
                        Btn {
                            text: win.editionState === "busy" ? "Installing…" : "Install"
                            primary: true
                            enabled: win.chosenList.length > 0 && win.editionState !== "busy"
                            onClicked: win.installEditions()
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                            color: win.editionState === "failed" ? Theme.bad : Theme.soft
                            text: win.editionLine
                        }
                    }
                }
            }

            // 6. Ready: where things are.
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(620, parent.width - 64)
                    spacing: 12
                    Label {
                        Layout.fillWidth: true
                        text: "You're ready."
                        font.family: Theme.hex ? Theme.mono : Theme.font
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        Layout.bottomMargin: 6
                    }
                    Repeater {
                        model: [
                            ["view-app-grid-symbolic", "Apps", "The CybroidOS mark at the top left, or the Meta key, opens every app with search."],
                            ["system-users-symbolic", "You", "Your picture at the top right: your account, lock, sign out, restart and shut down."],
                            ["preferences-system-symbolic", "Settings", "Wi-Fi, sound, displays, your look and everything else, in Control Centre and Settings."],
                            ["system-software-update-symbolic", "Updates", "Security fixes and new versions install by themselves, without interrupting you."],
                            ["x-office-document-symbolic", "Office", "Word, Excel and PowerPoint files open in Office (ONLYOFFICE)."]
                        ]
                        Card {
                            required property var modelData
                            Layout.fillWidth: true
                            SettingRow {
                                icon: modelData[0]
                                title: modelData[1]
                                subtitle: modelData[2]
                            }
                        }
                    }
                }
            }
        }

        // Skip, Back, Continue.
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 18
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            spacing: 10
            Btn {
                visible: win.step < win.steps.length - 1
                enabled: win.editionState !== "busy"
                text: "Skip"
                onClicked: win.done()
            }
            Item { Layout.fillWidth: true }
            Btn {
                visible: win.step > 0
                text: "Back"
                onClicked: win.step--
            }
            Btn {
                primary: true
                enabled: win.editionState !== "busy"
                text: win.step === 0 ? "Let's start" : win.step === win.steps.length - 1 ? "Start using CybroidOS" : "Continue"
                onClicked: win.step < win.steps.length - 1 ? win.step++ : win.done()
            }
        }
    }
}
