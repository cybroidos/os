/* CybroidOS installer slideshow: what the new system looks like, one slide
 * every few seconds while it installs. Calamares' slideshow API 2. */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function onActivate() { presentation.currentSlide = 0; timer.restart() }
    function onLeave() { timer.stop() }

    Timer {
        id: timer
        interval: 6000
        repeat: true
        running: false
        onTriggered: presentation.goToNextSlide()
    }

    // One slide: the screenshot, framed like a window, with its line.
    component Shot: Slide {
        id: sl
        property string image
        property string title
        property string line
        Rectangle { anchors.fill: parent; color: "#0d1530" }
        Rectangle {
            id: frame
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: Math.round(parent.height * 0.06)
            width: Math.min(parent.width * 0.82, (parent.height * 0.66) * 1.6)
            height: width / 1.6
            radius: 14
            color: "#16224a"
            border.color: "#2a3d6e"
            clip: true
            Image {
                anchors.fill: parent; anchors.margins: 1
                source: sl.image
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
            }
        }
        Text {
            id: head
            anchors.top: frame.bottom; anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            text: sl.title
            color: "#eef3ff"; font.pixelSize: 22; font.weight: Font.DemiBold; font.family: "Inter"
        }
        Text {
            anchors.top: head.bottom; anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: frame.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: sl.line
            color: "#a9b8da"; font.pixelSize: 14; font.family: "Inter"
        }
    }

    Shot {
        image: "slides/1-horizon.jpg"
        title: "Welcome to CybroidOS"
        line: "A calm, fast desktop: the dock for your apps, Today for the time and weather, Control Centre for Wi-Fi, sound and more."
    }
    Shot {
        image: "slides/2-hex.jpg"
        title: "Two designs: Horizon and Hex"
        line: "Hex shows the machine at work: live readouts for the processor, memory and network. Switch in Control Centre."
    }
    Shot {
        image: "slides/3-hex-light.jpg"
        title: "Light or Dark"
        line: "Every design comes in Light and Dark, windows and all."
    }
    Shot {
        image: "slides/4-apps.jpg"
        title: "Everything to start with"
        line: "Firefox, Office, VLC, Files and Photos are ready; the App Centre brings thousands more."
    }
}
