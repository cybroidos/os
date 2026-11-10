// CIT-OS Horizon sign-in (citos-plasma). The CIT-OS wallpaper carries the
// logo in the middle; the date and clock sit above it, and the person's
// avatar and password in one row below the wordmark. Shut down, restart
// and "other user" in the corner. SDDM's objects: sddm, userModel,
// sessionModel.
import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root
    width: 1440
    height: 900
    color: "#0b1638"

    readonly property color ink: "#eef3ff"
    readonly property color soft: "#b6c4e4"
    readonly property color accent: "#1ccbff"
    property string message: ""
    property bool otherUser: false

    Image {
        anchors.fill: parent
        source: "file:///usr/share/backgrounds/citos/citos-1920x1080.png"
        fillMode: Image.PreserveAspectCrop
    }

    // No last user yet (a first boot): the first person with an account.
    Repeater {
        model: userModel
        delegate: Item {
            Component.onCompleted: {
                if (index === 0 && userField.text.length === 0) userField.text = model.name
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.045
        spacing: 0
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "dddd d MMMM")
            color: root.soft
            font.family: "Inter"
            font.pixelSize: Math.round(root.height * 0.021)
        }
        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            color: root.ink
            font.family: "Inter"
            font.weight: Font.DemiBold
            font.pixelSize: Math.round(root.height * 0.085)
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            timeText.text = Qt.formatTime(new Date(), "HH:mm")
            dateText.text = Qt.formatDate(new Date(), "dddd d MMMM")
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.785
        spacing: 10

        TextField {
            id: userField
            visible: root.otherUser
            width: 360; height: 40
            anchors.horizontalCenter: parent.horizontalCenter
            text: userModel.lastUser
            placeholderText: "Name"
            horizontalAlignment: TextInput.AlignHCenter
            color: root.ink
            placeholderTextColor: root.soft
            font.family: "Inter"; font.pixelSize: 15
            background: Rectangle { radius: 20; color: "#1fffffff"; border.color: userField.activeFocus ? root.accent : "#2effffff" }
            KeyNavigation.tab: passField
            onAccepted: passField.forceActiveFocus()
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                width: 48; height: 48; radius: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3a7cff" }
                    GradientStop { position: 1.0; color: "#1ccbff" }
                }
                border.color: "#40ffffff"; border.width: 2
                Text {
                    anchors.centerIn: parent
                    text: (userField.text.length ? userField.text[0] : "?").toUpperCase()
                    color: "#06122e"
                    font.family: "Inter"; font.weight: Font.DemiBold; font.pixelSize: 20
                }
            }

            Rectangle {
                width: 330; height: 48; radius: 24
                color: "#24ffffff"
                border.color: passField.activeFocus ? root.accent : "#33ffffff"
                border.width: 1

                TextField {
                    id: passField
                    anchors.left: parent.left; anchors.right: go.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 18; anchors.rightMargin: 6
                    echoMode: TextInput.Password
                    placeholderText: userField.text.length ? "Password for " + userField.text : "Password"
                    color: "white"
                    placeholderTextColor: root.soft
                    font.family: "Inter"; font.pixelSize: 15
                    background: Item {}
                    focus: true
                    onAccepted: root.signIn()
                }
                Button {
                    id: go
                    width: 36; height: 36
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Accessible.name: "Sign in"
                    onClicked: root.signIn()
                    background: Rectangle { radius: 18; color: go.down ? "#14a8d8" : root.accent }
                    contentItem: Text {
                        text: "→"; color: "#06122e"
                        font.pixelSize: 18; font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.message
            visible: root.message.length > 0
            color: "#ffb4b4"
            font.family: "Inter"; font.pixelSize: 13
        }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: 28
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        spacing: 10
        Repeater {
            model: [
                { label: root.otherUser ? "Back" : "Other user", glyph: "◐", act: function () { root.otherUser = !root.otherUser; if (root.otherUser) userField.forceActiveFocus(); else passField.forceActiveFocus() }, ok: true },
                { label: "Restart", glyph: "↻", act: function () { sddm.reboot() }, ok: sddm.canReboot },
                { label: "Shut down", glyph: "⏻", act: function () { sddm.powerOff() }, ok: sddm.canPowerOff }
            ]
            delegate: Button {
                visible: modelData.ok
                height: 34
                Accessible.name: modelData.label
                onClicked: modelData.act()
                background: Rectangle { radius: 17; color: parent.hovered ? "#33ffffff" : "#1fffffff" }
                contentItem: Row {
                    spacing: 8
                    leftPadding: 12; rightPadding: 14
                    Text { text: modelData.glyph; color: root.ink; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: modelData.label; color: "#dbe4f5"; font.family: "Inter"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    Row {
        anchors.left: parent.left; anchors.leftMargin: 28
        anchors.bottom: parent.bottom; anchors.bottomMargin: 30
        spacing: 10
        Image {
            source: "file:///usr/share/citos/branding/mark.svg"
            sourceSize.width: 20; sourceSize.height: 20
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "CIT-OS · " + sddm.hostName
            color: "#9fb3d9"
            font.family: "Inter"; font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    function signIn() {
        root.message = ""
        sddm.login(userField.text, passField.text, sessionModel.lastIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.message = "That password didn't work. Try again."
            passField.text = ""
            passField.forceActiveFocus()
        }
    }

    Component.onCompleted: passField.forceActiveFocus()
}
