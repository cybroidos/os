/* CybroidOS installer: the steps at the left, in the Horizon design. The
 * mark and the name at the top; each step a row with its number in a circle
 * (a tick once done, CIT blue and lit while current); the version at the
 * foot. Calamares loads this from the branding folder (sidebar: qml). */
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: side
    anchors.fill: parent
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#101d45" }
        GradientStop { position: 1.0; color: "#0a1330" }
    }

    // A hairline at the right edge, between the steps and the page.
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#22305c" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 6

        RowLayout {
            Layout.bottomMargin: 18
            spacing: 10
            Image {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                source: "file:/" + Branding.imagePath(Branding.ProductLogo)
                sourceSize.width: 80; sourceSize.height: 80
                fillMode: Image.PreserveAspectFit
            }
            ColumnLayout {
                spacing: 0
                Text { text: "CybroidOS"; color: "#eef3ff"; font.pixelSize: 17; font.weight: Font.DemiBold; font.family: "Inter" }
                Text { text: "Installer"; color: "#8fa3c8"; font.pixelSize: 12; font.family: "Inter" }
            }
        }

        Repeater {
            model: ViewManager
            delegate: Item {
                id: step
                required property int index
                required property string display
                readonly property bool current: index === ViewManager.currentStepIndex
                readonly property bool done: index < ViewManager.currentStepIndex
                Layout.fillWidth: true
                implicitHeight: 38
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: step.current ? "#1a2c5e" : "transparent"
                    border.color: step.current ? "#2a4a96" : "transparent"
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                        radius: 12
                        color: step.current ? "#1f5fe0" : step.done ? "#123a7a" : "transparent"
                        border.width: step.current || step.done ? 0 : 1.5
                        border.color: "#3d5fa8"
                        Text {
                            anchors.centerIn: parent
                            text: step.done ? "✓" : String(step.index + 1)
                            color: step.current ? "#ffffff" : step.done ? "#1ccbff" : "#8fa3c8"
                            font.pixelSize: 12; font.weight: Font.DemiBold; font.family: "Inter"
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: step.display
                        elide: Text.ElideRight
                        color: step.current ? "#ffffff" : step.done ? "#c9d6f2" : "#8fa3c8"
                        font.pixelSize: 14
                        font.weight: step.current ? Font.DemiBold : Font.Normal
                        font.family: "Inter"
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            text: Branding.string(Branding.VersionedName)
            color: "#5b6d96"; font.pixelSize: 11; font.family: "Inter"
            horizontalAlignment: Text.AlignLeft
        }
    }
}
