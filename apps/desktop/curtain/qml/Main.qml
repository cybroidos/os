import QtQuick
import QtQuick.Window

// One borderless window over each screen, above everything (the window
// manager doesn't manage it), showing the picture; fades in and out.
QtObject {
    id: root
    property real shown: 0
    // True once the picture has faded fully in (the caller then changes
    // the desktop underneath).
    property bool covered: false
    property int loaded: 0
    Behavior on shown { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
    onLoadedChanged: if (loaded >= Qt.application.screens.length) { shown = 1; coveredLater.start() }
    property Timer coveredLater: Timer { interval: 220; onTriggered: root.covered = true }
    function finish() { shown = 0; quit.start() }
    property Timer quit: Timer { interval: 260; onTriggered: Qt.quit() }

    property Instantiator windows: Instantiator {
        model: Qt.application.screens
        delegate: Window {
            required property var modelData
            screen: modelData
            x: modelData.virtualX
            y: modelData.virtualY
            width: modelData.width
            height: modelData.height
            flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.X11BypassWindowManagerHint
            color: "transparent"
            visible: true
            Image {
                anchors.fill: parent
                source: picture
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 1920
                opacity: root.shown
                // Shown only once decoded: a window up before its picture
                // was a black frame.
                onStatusChanged: if (status === Image.Ready || status === Image.Error) root.loaded++
            }
            // After half a second, a quiet word that it is working.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(parent.height * 0.12)
                // As wide as with all three dots, so it doesn't change size.
                width: full.implicitWidth + 36
                height: 34
                radius: 17
                color: Qt.rgba(0.02, 0.05, 0.12, 0.55)
                opacity: root.shown * (late.running ? 0 : 1)
                Behavior on opacity { NumberAnimation { duration: 300 } }
                Text { id: full; visible: false; text: "Changing design..."; font: hint.font }
                Text {
                    id: hint
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Changing design" + ".".repeat(1 + dots.n % 3)
                    color: "#e8eefc"
                    font.family: "Inter"
                    font.pixelSize: 14
                }
                Timer { id: dots; property int n: 0; interval: 450; repeat: true; running: true; onTriggered: n++ }
            }
            Timer { id: late; interval: 600; running: true }
        }
    }
}
