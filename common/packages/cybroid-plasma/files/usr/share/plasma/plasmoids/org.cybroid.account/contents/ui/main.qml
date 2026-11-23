/*
 * CybroidOS Account (cybroid-plasma): the person's picture at the far right of
 * the top bar. A click opens who is signed in (picture, name, administrator
 * or not, this computer's name), their account and this computer in
 * Settings, then Lock, Sleep, Switch user, Sign out, Restart and Shut down.
 * Restart, Shut down and Sign out go through Plasma's own confirmation (it
 * counts down and warns about unsaved work and other signed-in people).
 *
 * In Hex (the colour scheme's name, read as it opens) the picture is a
 * hexagon and the menu a panel with two corners cut, as in Today.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.sessions as Sessions

PlasmoidItem {
    id: root

    readonly property color ink: Kirigami.Theme.textColor
    readonly property color faint: Qt.alpha(Kirigami.Theme.textColor, 0.55)
    readonly property color accent: Kirigami.Theme.focusColor
    readonly property color card: Qt.alpha(Kirigami.Theme.textColor, 0.06)
    property bool hex: false
    property bool admin: false
    property string host: ""

    readonly property string name: kuser.fullName || kuser.loginName
    readonly property string initials: {
        const w = root.name.trim().split(/\s+/).filter(s => s.length)
        return ((w[0] || "?")[0] + (w.length > 1 ? w[w.length - 1][0] : "")).toUpperCase()
    }
    // A picture once one is set (Settings → Users, or the sign-in screen's);
    // until then the initials on the accent colour.
    readonly property bool hasFace: face.status === Image.Ready

    KCoreAddons.KUser { id: kuser }
    Sessions.SessionManagement { id: sm }

    Plasmoid.icon: "system-shutdown"
    toolTipMainText: root.name
    toolTipSubText: "Account, lock, sign out, restart and shut down"

    P5Support.DataSource {
        id: sh
        engine: "executable"
        // A Map, not an object (Qt 6.8's engine crashes on keys added and
        // deleted on a plain object; see Today).
        property var handlers: new Map()
        function run(cmd, handler) { handlers.set(cmd, handler); connectSource(cmd) }
        onNewData: (source, data) => {
            const h = handlers.get(source)
            disconnectSource(source)
            handlers.delete(source)
            if (h) h(String(data["stdout"] || ""), Number(data["exit code"]))
        }
    }

    function refresh() {
        sh.run("kreadconfig6 --file kdeglobals --group General --key ColorScheme", (out) => { root.hex = /Hex/.test(out) })
        sh.run("sh -c 'hostname; id -nG'", (out) => {
            const l = out.trim().split("\n")
            root.host = l[0] || ""
            root.admin = /(^|\s)sudo(\s|$)/.test(l[1] || "")
        })
    }
    Component.onCompleted: refresh()
    onExpandedChanged: if (root.expanded) refresh()

    function settings(page) {
        sh.run("sh -c 'cybroid-settings " + page + " >/dev/null 2>&1 &'", () => {})
        root.expanded = false
    }
    function act(f) { root.expanded = false; f() }
    // Restart, Shut down and Sign out always ask first: ConfirmationMode.ForcePrompt (1).

    // The picture, round in Horizon and a hexagon in Hex, at any size.
    component Avatar: Item {
        id: av
        property real size: 22
        width: size; height: size
        Rectangle {
            id: disc
            anchors.fill: parent
            visible: false
            radius: width / 2
            color: root.accent
            layer.enabled: true
        }
        Shape {
            id: hexMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "black"; strokeWidth: 0
                startX: av.width * 0.25; startY: av.height * 0.03
                PathLine { x: av.width * 0.75; y: av.height * 0.03 }
                PathLine { x: av.width; y: av.height * 0.5 }
                PathLine { x: av.width * 0.75; y: av.height * 0.97 }
                PathLine { x: av.width * 0.25; y: av.height * 0.97 }
                PathLine { x: 0; y: av.height * 0.5 }
                PathLine { x: av.width * 0.25; y: av.height * 0.03 }
            }
        }
        Item {
            id: content
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle { anchors.fill: parent; color: root.accent; visible: !root.hasFace }
            QQC2.Label {
                anchors.centerIn: parent
                visible: !root.hasFace
                text: root.initials
                color: Kirigami.ColorUtils.brightnessForColor(root.accent) === Kirigami.ColorUtils.Light ? "#06122e" : "#ffffff"
                font.pixelSize: Math.round(av.size * 0.4)
                font.weight: Font.DemiBold
            }
            Image {
                anchors.fill: parent
                source: kuser.faceIconUrl
                visible: root.hasFace
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(av.size * 2, av.size * 2)
                cache: false
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: content
            maskEnabled: true
            maskSource: root.hex ? hexMask : disc
        }
    }
    // Loads the picture once, to know whether there is one.
    Image { id: face; visible: false; source: kuser.faceIconUrl; sourceSize: Qt.size(8, 8); cache: false }

    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        Layout.minimumWidth: height + 8
        Layout.preferredWidth: height + 8
        onClicked: root.expanded = !root.expanded
        Rectangle {
            anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3
            radius: 6
            color: root.expanded ? Qt.alpha(root.ink, 0.16) : button.containsMouse ? Qt.alpha(root.ink, 0.08) : "transparent"
        }
        Avatar { anchors.centerIn: parent; size: Math.round(button.height * 0.62) }
    }

    // One line of the menu: a symbol, the words, and a shortcut if it has one.
    component MenuRow: QQC2.ItemDelegate {
        id: it
        property string icon_: ""
        property string hint: ""
        property var run: () => {}
        Layout.fillWidth: true
        visible: enabled
        implicitHeight: 34
        leftPadding: 10; rightPadding: 10
        onClicked: run()
        background: Rectangle {
            radius: root.hex ? 0 : 8
            color: it.hovered || it.visualFocus ? Qt.alpha(root.ink, 0.08) : "transparent"
            Rectangle {
                visible: root.hex && (it.hovered || it.visualFocus)
                width: 2; height: parent.height; color: root.accent
            }
        }
        contentItem: RowLayout {
            spacing: 10
            Kirigami.Icon { source: it.icon_; Layout.preferredWidth: 16; Layout.preferredHeight: 16; color: root.ink; isMask: true }
            QQC2.Label { text: it.text; color: root.ink; font.pixelSize: 13; Layout.fillWidth: true }
            QQC2.Label { visible: it.hint !== ""; text: it.hint; color: root.faint; font.pixelSize: 11; font.family: root.hex ? "JetBrains Mono" : Kirigami.Theme.defaultFont.family }
        }
    }
    component Rule: Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4; implicitHeight: 1; color: Qt.alpha(root.ink, 0.1) }

    fullRepresentation: Item {
        Layout.preferredWidth: 300
        Layout.minimumWidth: 300
        Layout.maximumWidth: 300
        // As tall as what's in it: Plasma otherwise reopens a popup at the
        // largest size it ever had.
        Layout.preferredHeight: menu.implicitHeight + 20
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight

        ColumnLayout {
            id: menu
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 2

            // Who is signed in, on a card (Hex: cut corners, the lit hairline).
            Item {
                id: who
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                implicitHeight: whoRow.implicitHeight + 24
                Rectangle { anchors.fill: parent; visible: !root.hex; radius: 14; color: root.card }
                Shape {
                    anchors.fill: parent
                    visible: root.hex
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 1; strokeColor: Qt.alpha(root.ink, 0.16); fillColor: root.card
                        startX: 10; startY: 0.5
                        PathLine { x: who.width - 0.5; y: 0.5 }
                        PathLine { x: who.width - 0.5; y: who.height - 10 }
                        PathLine { x: who.width - 10; y: who.height - 0.5 }
                        PathLine { x: 0.5; y: who.height - 0.5 }
                        PathLine { x: 0.5; y: 10 }
                        PathLine { x: 10; y: 0.5 }
                    }
                    ShapePath {
                        strokeWidth: 1.5; strokeColor: root.accent; fillColor: "transparent"
                        startX: 0.75; startY: 26
                        PathLine { x: 0.75; y: 10 }
                        PathLine { x: 10; y: 0.75 }
                        PathLine { x: 40; y: 0.75 }
                    }
                }
                RowLayout {
                    id: whoRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    spacing: 12
                    Avatar { size: 46 }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        QQC2.Label { text: root.name; color: root.ink; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                        QQC2.Label {
                            text: (root.admin ? "Administrator" : "Standard account") + (root.host ? (root.hex ? "  //  " : " · ") + root.host : "")
                            color: root.faint; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true
                            font.family: root.hex ? "JetBrains Mono" : Kirigami.Theme.defaultFont.family
                        }
                    }
                }
            }

            MenuRow { text: "Account settings"; icon_: "system-users-symbolic"; run: () => root.settings("users") }
            MenuRow { text: "About this computer"; icon_: "help-about-symbolic"; run: () => root.settings("about") }
            Rule {}
            MenuRow { text: "Lock"; icon_: "system-lock-screen-symbolic"; hint: "Meta+L"; enabled: sm.canLock; run: () => root.act(() => sm.lock()) }
            MenuRow { text: "Sleep"; icon_: "system-suspend-symbolic"; enabled: sm.canSuspend; run: () => root.act(() => sm.suspend()) }
            MenuRow { text: "Switch user"; icon_: "system-switch-user-symbolic"; enabled: sm.canSwitchUser; run: () => root.act(() => sm.switchUser()) }
            MenuRow { text: "Sign out…"; icon_: "system-log-out-symbolic"; enabled: sm.canLogout; run: () => root.act(() => sm.requestLogout(1)) }
            Rule {}
            MenuRow { text: "Restart…"; icon_: "system-reboot-symbolic"; enabled: sm.canReboot; run: () => root.act(() => sm.requestReboot(1)) }
            MenuRow { text: "Shut down…"; icon_: "system-shutdown-symbolic"; enabled: sm.canShutdown; run: () => root.act(() => sm.requestShutdown(1)) }
        }
    }
}
