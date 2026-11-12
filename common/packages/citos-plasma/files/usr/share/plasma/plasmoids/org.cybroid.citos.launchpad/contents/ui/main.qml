/*
 * CIT-OS Launchpad (citos-plasma): every app in one big grid over a blurred
 * desktop, with search as you type. Opened from its icon (the CIT-OS mark in
 * the top bar), the Meta key, Alt+F1 and the dock's Apps tile (it provides
 * the launcher menu). The app list comes from Plasma's own launcher model.
 *
 * It follows the design in use (from the colour scheme's name, read as it
 * opens): Horizon or Hex, Dark or Light. Hex gets its wallpaper behind the
 * grid, a cut-corner search field and tiles lit from their left edge.
 */
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.plasma5support as P5Support
import QtQuick.Shapes

PlasmoidItem {
    id: root

    // The button is the widget's full representation, never a popup (as
    // Plasma's own dashboard launcher does): the grid is a window of its own.
    switchWidth: 0
    switchHeight: 0
    preferredRepresentation: fullRepresentation
    compactRepresentation: null
    Plasmoid.icon: Plasmoid.configuration.icon || "citos-mark"

    fullRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        // A square in the bar, a little wider for breathing room.
        Layout.minimumWidth: Math.round(height * 1.4)
        Layout.preferredWidth: Math.round(height * 1.4)
        Layout.maximumWidth: Math.round(height * 1.4)
        onClicked: launchpad.toggle()
        Kirigami.Icon {
            anchors.centerIn: parent
            height: Math.round(parent.height * 0.62)
            width: height
            source: Plasmoid.icon
            active: button.containsMouse
        }
    }

    Connections {
        target: Plasmoid
        function onActivated() { launchpad.toggle() }
    }

    // The design in use: "CITOSHorizon", "CITOSHorizonLight", "CITOSHex" or
    // "CITOSHexLight".
    property string scheme: ""
    readonly property bool hex: /Hex/.test(scheme)
    readonly property bool light: /Light/.test(scheme)
    readonly property color ink: light ? "#0b1634" : "#f2f6ff"
    readonly property color soft: light ? "#4a5b85" : "#b6c4e4"
    readonly property color acc: light ? "#1f5fe0" : "#1ccbff"
    P5Support.DataSource {
        id: sh
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            root.scheme = String(data["stdout"] || "").trim()
        }
    }
    function readScheme() {
        sh.connectSource("kreadconfig6 --file kdeglobals --group General --key ColorScheme")
    }
    Component.onCompleted: readScheme()

    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appletInterface: root
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false
        Component.onCompleted: refresh()
        onRefreshed: launchpad.appsModel = rootModel.modelForRow(0)
    }

    Window {
        id: launchpad
        property var appsModel: null
        // A tool window: docks and task switchers leave it out.
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        color: "transparent"
        title: "Launchpad"

        function toggle() {
            if (visible) {
                close()
                return
            }
            root.readScheme()
            search.text = ""
            apps.refilter("")
            grid.positionViewAtBeginning()
            // Covers the whole screen. Set by hand: KWin doesn't make tool
            // windows full screen.
            x = Screen.virtualX
            y = Screen.virtualY
            width = Screen.width
            height = Screen.height
            show()
            raise()
            requestActivate()
            search.forceActiveFocus()
        }
        function launch(row) {
            if (appsModel && row >= 0) appsModel.trigger(row, "", null)
            close()
        }

        // The plain CIT-OS wallpaper, dimmed, behind the grid: calm and solid
        // (a live blur shows banding in software rendering on VMs).
        Image {
            anchors.fill: parent
            source: root.hex
                ? "file:///usr/share/backgrounds/citos/citos-" + (root.light ? "hex-light" : "hex") + "-1920x1080.png"
                : root.light ? "file:///usr/share/backgrounds/citos/citos-light-1920x1080.png" : Plasmoid.configuration.backdrop
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle { anchors.fill: parent; color: root.light ? "#b3e6eefb" : "#99050b20" }
        MouseArea { anchors.fill: parent; onClicked: launchpad.close() }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: launchpad.close()

            QQC2.TextField {
                id: search
                width: Math.min(420, parent.width - 64)
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(parent.height * 0.06)
                placeholderText: "Search"
                color: root.ink
                placeholderTextColor: root.soft
                font.family: root.hex ? "JetBrains Mono" : "Inter"
                font.pixelSize: root.hex ? 14 : 15
                leftPadding: 40
                horizontalAlignment: TextInput.AlignLeft
                background: Item {
                    // Horizon: a soft pill.
                    Rectangle {
                        anchors.fill: parent
                        visible: !root.hex
                        radius: 20
                        color: root.light ? "#b3ffffff" : "#2effffff"
                        border.color: search.activeFocus ? Qt.alpha(root.acc, 0.4) : root.light ? "#33223a6e" : "#26ffffff"
                        border.width: 1
                    }
                    // Hex: the corners cut (top-left and bottom-right), a
                    // hairline that lights when it has the focus.
                    Shape {
                        anchors.fill: parent
                        visible: root.hex
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: 1
                            strokeColor: search.activeFocus ? root.acc : root.light ? "#7d9bd3" : "#2a3d6e"
                            fillColor: root.light ? "#d9ffffff" : "#cc060c1e"
                            readonly property real c: 10
                            startX: c; startY: 0.5
                            PathLine { x: search.width - 0.5; y: 0.5 }
                            PathLine { x: search.width - 0.5; y: search.height - 10 }
                            PathLine { x: search.width - 10; y: search.height - 0.5 }
                            PathLine { x: 0.5; y: search.height - 0.5 }
                            PathLine { x: 0.5; y: 10 }
                            PathLine { x: 10; y: 0.5 }
                        }
                    }
                    Kirigami.Icon {
                        source: "search"
                        width: 18; height: 18
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.soft
                        isMask: true
                    }
                }
                onTextChanged: apps.refilter(text)
                Keys.onEscapePressed: launchpad.close()
                Keys.onReturnPressed: if (shown.count > 0) launchpad.launch(shown.get(0).itemsIndex)
                Keys.onDownPressed: grid.forceActiveFocus()
            }

            DelegateModel {
                id: apps
                model: launchpad.appsModel
                groups: [DelegateModelGroup { id: shown; name: "shown"; includeByDefault: true }]
                filterOnGroup: "shown"
                // How many apps match the search (for the "No apps match" line).
                readonly property alias count: shown.count
                function refilter(q) {
                    q = String(q).toLowerCase()
                    for (var i = 0; i < items.count; ++i) {
                        var it = items.get(i)
                        var name = String(it.model.display || "").toLowerCase()
                        it.inShown = q.length === 0 || name.indexOf(q) >= 0
                    }
                }
                delegate: Item {
                    id: tile
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property int sourceRow: DelegateModel.itemsIndex

                    readonly property bool lit: hover.containsMouse || tile.GridView.isCurrentItem && grid.activeFocus
                    Rectangle {
                        anchors.centerIn: parent
                        width: grid.cellWidth - 18
                        height: grid.cellHeight - 14
                        visible: !root.hex
                        radius: 18
                        color: tile.lit ? (root.light ? "#33ffffff" : "#24ffffff") : "transparent"
                    }
                    // Hex: a wash of the accent, its left edge lit (Hex's
                    // selected rows), the top-left corner cut.
                    Shape {
                        id: hexTile
                        anchors.centerIn: parent
                        width: grid.cellWidth - 18
                        height: grid.cellHeight - 14
                        visible: root.hex && tile.lit
                        ShapePath {
                            strokeWidth: 0; strokeColor: "transparent"
                            fillColor: Qt.alpha(root.acc, root.light ? 0.14 : 0.16)
                            startX: 12; startY: 0
                            PathLine { x: hexTile.width; y: 0 }
                            PathLine { x: hexTile.width; y: hexTile.height }
                            PathLine { x: 0; y: hexTile.height }
                            PathLine { x: 0; y: 12 }
                            PathLine { x: 12; y: 0 }
                        }
                        Rectangle { x: 0; y: 12; width: 2; height: hexTile.height - 12; color: root.acc }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Kirigami.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 72; height: 72
                            source: model.decoration
                            scale: hover.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90 } }
                        }
                        Text {
                            width: grid.cellWidth - 20
                            horizontalAlignment: Text.AlignHCenter
                            text: model.display
                            color: root.ink
                            font.family: "Inter"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: launchpad.launch(tile.sourceRow)
                    }
                    Keys.onReturnPressed: launchpad.launch(tile.sourceRow)
                }
            }

            GridView {
                id: grid
                anchors.top: search.bottom
                anchors.topMargin: Math.round(parent.height * 0.05)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(parent.height * 0.08)
                anchors.horizontalCenter: parent.horizontalCenter
                // Seven columns where they fit, as many as fit otherwise.
                readonly property int columns: Math.max(3, Math.min(7, Math.floor((parent.width - 120) / 150)))
                width: columns * cellWidth
                cellWidth: 150
                cellHeight: 142
                clip: true
                model: apps
                keyNavigationEnabled: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }
                Keys.onEscapePressed: launchpad.close()
                Keys.onUpPressed: if (currentIndex < columns) search.forceActiveFocus(); else moveCurrentIndexUp()
                // Clicks between tiles close it, like the empty space around.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: launchpad.close()
                }
            }

            Text {
                anchors.centerIn: grid
                visible: apps.count === 0 && search.text.length > 0
                text: "No apps match “" + search.text + "”"
                color: root.soft
                font.family: "Inter"
                font.pixelSize: 16
            }
        }
    }
}
