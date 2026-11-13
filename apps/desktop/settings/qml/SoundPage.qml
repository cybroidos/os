import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// Sound through PipeWire (pactl): where sound plays and what listens, each
// device's volume, mute, and its connector (speakers or headphones).
SettingsPage {
    id: page
    title: "Sound"

    property var sinks: []
    property var sources: []
    property string defSink: ""
    property string defSource: ""

    function pct(v) {
        const ch = Object.values(v.volume || {})
        if (!ch.length) return 0
        return Math.round(ch.reduce((a, c) => a + parseInt(c.value_percent), 0) / ch.length)
    }
    function usable(d) {
        return (d.ports || []).filter(p => p.availability !== "not available")
    }
    function refresh() {
        System.run(["pactl", "get-default-sink"], (o) => defSink = o.trim())
        System.run(["pactl", "get-default-source"], (o) => defSource = o.trim())
        System.run(["pactl", "-f", "json", "list", "sinks"], (o) => { try { sinks = JSON.parse(o) } catch (e) {} })
        System.run(["pactl", "-f", "json", "list", "sources"], (o) => {
            try { sources = JSON.parse(o).filter(s => !(s.name || "").endsWith(".monitor")) } catch (e) {}
        })
    }
    function nice(d) {
        // "Built-in Audio Analog Stereo" reads better as "Built-in Audio".
        return (d.description || d.name).replace(/ (Analog|Digital) (Stereo|Surround.*|Mono)$/, "")
    }
    Component.onCompleted: refresh()
    Timer { interval: 2500; running: page.visible; repeat: true; onTriggered: page.refresh() }

    component DeviceCard: Card {
        id: dc
        property var devices: []
        property string chosen: ""
        property bool output: true
        Repeater {
            model: dc.devices
            Item {
                id: dev
                required property var modelData
                readonly property bool on: modelData.name === dc.chosen
                width: parent ? parent.width : 400
                implicitHeight: pick.implicitHeight + (on ? controls.implicitHeight + 10 : 0)
                SettingRow {
                    id: pick
                    first: dev.Positioner.index <= 0
                    title: page.nice(dev.modelData)
                    icon: dc.output ? "audio-speakers-symbolic" : "audio-input-microphone-symbolic"
                    iconColor: dev.on ? Theme.accent : Theme.soft
                    clickable: !dev.on
                    chevron: false
                    onClicked: System.run(["pactl", dc.output ? "set-default-sink" : "set-default-source", dev.modelData.name], () => page.refresh())
                    Kirigami.Icon {
                        visible: dev.on
                        implicitWidth: 18; implicitHeight: 18
                        source: "checkmark-symbolic"; isMask: true; color: Theme.accent
                    }
                }
                ColumnLayout {
                    id: controls
                    visible: dev.on
                    anchors.top: pick.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 50
                    anchors.rightMargin: 16
                    spacing: 8
                    RowLayout {
                        spacing: 12
                        Kirigami.Icon {
                            implicitWidth: 18; implicitHeight: 18
                            source: dev.modelData.mute ? (dc.output ? "audio-volume-muted-symbolic" : "microphone-sensitivity-muted-symbolic")
                                                       : (dc.output ? "audio-volume-high-symbolic" : "audio-input-microphone-symbolic")
                            isMask: true; color: dev.modelData.mute ? Theme.bad : Theme.soft
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: System.run(["pactl", dc.output ? "set-sink-mute" : "set-source-mute", dev.modelData.name, "toggle"], () => page.refresh())
                            }
                        }
                        Slide {
                            id: vol
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 1
                            // Follows the device, except while being dragged.
                            Binding on value { when: !vol.pressed; value: page.pct(dev.modelData); restoreMode: Binding.RestoreNone }
                            onMoved: System.run(["pactl", dc.output ? "set-sink-volume" : "set-source-volume", dev.modelData.name, Math.round(value) + "%"], () => {})
                        }
                        Label {
                            text: Math.round(vol.value) + "%"
                            color: Theme.soft
                            font.family: Theme.hex ? Theme.mono : Theme.font
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    // Speakers or headphones (the jack), when the device has both.
                    Segmented {
                        visible: page.usable(dev.modelData).length > 1
                        Layout.bottomMargin: 6
                        options: page.usable(dev.modelData).map(p => p.description.replace(/ \(.*\)$/, ""))
                        current: page.usable(dev.modelData).findIndex(p => p.name === dev.modelData.active_port)
                        onPicked: (i) => System.run(["pactl", dc.output ? "set-sink-port" : "set-source-port", dev.modelData.name, page.usable(dev.modelData)[i].name], () => page.refresh())
                    }
                    Item { implicitHeight: 4 }
                }
            }
        }
        SettingRow {
            visible: dc.devices.length === 0
            title: dc.output ? "No speakers or headphones found" : "No microphone found"
        }
    }

    Section { title: "Output"; caption: "Where sound plays" }
    DeviceCard { devices: page.sinks; chosen: page.defSink; output: true }

    Section { title: "Input"; caption: "What listens: a microphone or headset" }
    DeviceCard { devices: page.sources; chosen: page.defSource; output: false }

    Section { title: "More" }
    Card {
        SettingRow {
            title: "Each app's volume, and more devices"
            subtitle: "Opens the full sound settings"
            clickable: true
            onClicked: System.launch(["systemsettings", "kcm_pulseaudio"])
        }
    }
}
