/*
 * CIT-OS Launchpad (citos-plasma): every app in one big grid over a blurred
 * desktop, with search as you type. Opened from its icon (the CIT-OS mark in
 * the top bar), the Meta key, Alt+F1 and the dock's Apps tile (it provides
 * the launcher menu). The app list comes from Plasma's own launcher model.
 */
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker

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
            source: Plasmoid.configuration.backdrop
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle { anchors.fill: parent; color: "#99050b20" }
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
                color: "#ffffff"
                placeholderTextColor: "#b6c4e4"
                font.family: "Inter"
                font.pixelSize: 15
                leftPadding: 40
                horizontalAlignment: TextInput.AlignLeft
                background: Rectangle {
                    radius: 20
                    color: "#2effffff"
                    border.color: search.activeFocus ? "#661ccbff" : "#26ffffff"
                    border.width: 1
                    Kirigami.Icon {
                        source: "search"
                        width: 18; height: 18
                        anchors.left: parent.left; anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#b6c4e4"
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

                    Rectangle {
                        anchors.centerIn: parent
                        width: grid.cellWidth - 18
                        height: grid.cellHeight - 14
                        radius: 18
                        color: hover.containsMouse || tile.GridView.isCurrentItem && grid.activeFocus ? "#24ffffff" : "transparent"
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
                            color: "#f2f6ff"
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
                color: "#b6c4e4"
                font.family: "Inter"
                font.pixelSize: 16
            }
        }
    }
}
