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
        }
    }
}
