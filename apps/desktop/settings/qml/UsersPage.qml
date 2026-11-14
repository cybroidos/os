import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Cybroid.Ui

// Users (AccountsService over D-Bus): you, with your name and picture (your
// own account changes without a password), and the others on this computer;
// passwords and new accounts in KDE's page, which asks for them properly.
SettingsPage {
    id: page
    title: "Users"

    property var users: []         // {path, user, name, icon, admin, me}
    property string me: ""
    property bool renaming: false
    property string error: ""

    function bus(args, done) {
        System.run(["busctl", "--system", "--json=short"].concat(args), (o, code) => {
            if (code !== 0) { error = o.trim().split("\n").pop(); return }
            try { done(JSON.parse(o)) } catch (e) { }
        })
    }
    function refresh() {
        System.run(["id", "-un"], (o) => { me = o.trim(); listUsers() })
    }
    function listUsers() {
        bus(["call", "org.freedesktop.Accounts", "/org/freedesktop/Accounts", "org.freedesktop.Accounts", "ListCachedUsers"], (j) => {
            const paths = j.data[0], list = []
            for (const p of paths)
                bus(["call", "org.freedesktop.Accounts", p, "org.freedesktop.DBus.Properties", "GetAll", "s", "org.freedesktop.Accounts.User"], (props) => {
                    const v = props.data[0]
                    const val = (k) => v[k] ? v[k].data : ""
                    list.push({ path: p, user: val("UserName"), name: val("RealName") || val("UserName"),
                                icon: val("IconFile"), admin: val("AccountType") === 1, me: val("UserName") === me })
                    if (list.length === paths.length) users = list.sort((a, b) => (b.me - a.me) || a.name.localeCompare(b.name))
                })
        })
    }
    function mine() { return users.find(u => u.me) }
    Component.onCompleted: refresh()

    FileDialog {
        id: picker
        title: "Choose a picture"
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp)"]
        currentFolder: "file://" + System.folder("pictures")
        onAccepted: {
            const u = page.mine(); if (!u) return
            const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
            page.bus(["call", "org.freedesktop.Accounts", u.path, "org.freedesktop.Accounts.User", "SetIconFile", "s", path], () => refreshLater.start())
        }
    }
    Timer { id: refreshLater; interval: 500; onTriggered: page.refresh() }

    component Avatar: Item {
        property string icon
        property string name
        implicitWidth: 56; implicitHeight: 56
        Surface { anchors.fill: parent; radius: 28; cut: 10; fill: Theme.selected; strokeWidth: 0 }
        Image {
            id: img
            anchors.fill: parent
            anchors.margins: 2
            visible: status === Image.Ready
            source: parent.icon !== "" && System.exists(parent.icon) ? "file://" + parent.icon : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 112
            cache: false
        }
        Label {
            visible: !img.visible
            anchors.centerIn: parent
            text: (parent.name || "?").slice(0, 1).toUpperCase()
            color: Theme.accent
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }
    }

    Label {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: Theme.bad
        wrapMode: Text.WordWrap
    }

    // You
    Surface {
        visible: !!page.mine()
        Layout.fillWidth: true
        implicitHeight: 96
        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16
            Avatar { icon: page.mine() ? page.mine().icon : ""; name: page.mine() ? page.mine().name : "" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { visible: !page.renaming; text: page.mine() ? page.mine().name : ""; font.pixelSize: 18; font.weight: Font.DemiBold }
                Field {
                    id: nameField
                    visible: page.renaming
                    Layout.fillWidth: true
                    onAccepted: saveName.clicked()
                }
                Label { text: page.mine() ? page.mine().user + (page.mine().admin ? " · Administrator" : " · Standard user") : ""; color: Theme.soft }
            }
            Btn { visible: !page.renaming; text: "Picture"; onClicked: picker.open() }
            Btn {
                visible: !page.renaming
                text: "Name"
                onClicked: { nameField.text = page.mine().name; page.renaming = true; nameField.forceActiveFocus() }
            }
            Btn { visible: page.renaming; text: "Cancel"; onClicked: page.renaming = false }
            Btn {
                id: saveName
                visible: page.renaming
                text: "Save"; primary: true
                enabled: nameField.text.trim() !== ""
                onClicked: page.bus(["call", "org.freedesktop.Accounts", page.mine().path, "org.freedesktop.Accounts.User", "SetRealName", "s", nameField.text.trim()],
                                    () => { page.renaming = false; refreshLater.start() })
            }
        }
    }

    Card {
        SettingRow {
            title: "Password"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_users"])
        }
    }

    Section { visible: page.users.length > 1; title: "Others on this computer" }
    Card {
        visible: page.users.length > 1
        Repeater {
            model: page.users.filter(u => !u.me)
            SettingRow {
                required property var modelData
                title: modelData.name
                subtitle: modelData.user + (modelData.admin ? " · Administrator" : "")
                icon: "user-symbolic"
                iconColor: Theme.soft
            }
        }
    }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Add someone, or change who is an administrator"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_users"])
        }
    }
}
