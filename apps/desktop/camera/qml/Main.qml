import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Window
import QtMultimedia
import org.kde.kirigami as Kirigami
import Cybroid.Ui

// CybroidOS Camera: the picture fills the window; photo or video, a timer,
// mirror, the other camera; the last shot at the left, opened in Photos.
// Photos go to ~/Pictures/Camera, videos to ~/Videos/Camera.
Window {
    id: win
    width: 960
    height: 680
    minimumWidth: 560
    minimumHeight: 420
    visible: true
    title: "Camera"
    color: "#05070d"

    property bool video: false
    property int timer: 0            // seconds before the shot
    property bool mirror: true       // the preview as in a mirror (not the saved picture)
    property int counting: 0
    property int camIndex: 0
    property int micIndex: -1        // -1: the system's default microphone
    property string last: ""
    property bool saving: false          // a video still being written after Stop
    readonly property bool recording: rec.recorderState === MediaRecorder.RecordingState
    readonly property bool hasCamera: devices.videoInputs.length > 0
    readonly property string photoDir: System.folder("pictures") + "/Camera"
    readonly property string videoDir: System.folder("videos") + "/Camera"
    readonly property var photoTypes: ["*.jpg", "*.jpeg", "*.png"]
    readonly property var videoTypes: ["*.mp4", "*.mkv", "*.webm", "*.mov"]

    // cybroid-camera photo|video, from a second start.
    function showPage(p) {
        if (p === "video") video = true
        else if (p === "photo") video = false
    }
    function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss") }
    function refreshLast() {
        const n = System.newest([photoDir, videoDir], photoTypes.concat(videoTypes), 1)
        last = n.length ? n[0] : ""
    }
    function isVideo(f) { return /\.(mp4|mkv|webm|mov)$/i.test(f) }
    function shutter() {
        if (!hasCamera || counting > 0) return
        if (recording) { saving = true; rec.stop(); return }
        if (saving) return
        if (timer > 0) { counting = timer; countdown.start(); return }
        take()
    }
    function take() {
        if (video) {
            System.makeDir(videoDir)
            rec.outputLocation = "file://" + videoDir + "/Video_" + stamp()
            rec.record()
        } else {
            System.makeDir(photoDir)
            shot.captureToFile(photoDir + "/Photo_" + stamp() + ".jpg")
            flash.restart()
        }
    }
    function clock(ms) {
        const s = Math.floor(ms / 1000)
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    Component.onCompleted: { refreshLast(); showPage(startPage) }

    MediaDevices { id: devices }
    CaptureSession {
        camera: Camera {
            id: cam
            cameraDevice: win.hasCamera ? devices.videoInputs[win.camIndex % devices.videoInputs.length] : devices.defaultVideoInput
            active: win.hasCamera
        }
        imageCapture: ImageCapture {
            id: shot
            onImageSaved: (id, path) => win.last = path
        }
        // H.264 at 720p: light enough for a modest laptop (the default,
        // H.265, ran at about one frame a second on two cores) and plays
        // everywhere; the graphics chip's encoder is used where there is one.
        recorder: MediaRecorder {
            id: rec
            mediaFormat {
                fileFormat: MediaFormat.MPEG4
                videoCodec: MediaFormat.VideoCodec.H264
                audioCodec: MediaFormat.AudioCodec.AAC
            }
            videoResolution: Qt.size(1280, 720)
            quality: MediaRecorder.NormalQuality
            onRecorderStateChanged: if (recorderState === MediaRecorder.StoppedState) { win.saving = false; win.refreshLast() }
        }
        // The microphone chosen in Video mode, or the system's default one.
        audioInput: AudioInput {
            device: win.micIndex >= 0 && win.micIndex < devices.audioInputs.length ? devices.audioInputs[win.micIndex] : devices.defaultAudioInput
        }
        videoOutput: out
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            win.counting--
            if (win.counting <= 0) { stop(); win.take() }
        }
    }

    // The picture
    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        transform: Scale { origin.x: out.width / 2; xScale: win.mirror ? -1 : 1 }
    }

    // No camera: say so, and wait for one to be plugged in.
    ColumnLayout {
        visible: !win.hasCamera
        anchors.centerIn: parent
        spacing: 10
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 56; implicitHeight: 56
            source: "camera-photo-symbolic"; isMask: true; color: "#5d6f99"
        }
        Label { Layout.alignment: Qt.AlignHCenter; text: "No camera found"; color: "#e8eefc"; font.pixelSize: 18; font.weight: Font.DemiBold }
        Label { Layout.alignment: Qt.AlignHCenter; text: "Plug one in, or check that the laptop's camera is switched on."; color: "#8fa3c8" }
    }

    // A white flash as the photo is taken.
    Rectangle {
        id: flashRect
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
        NumberAnimation on opacity { id: flash; running: false; from: 0.85; to: 0; duration: 380; easing.type: Easing.OutQuad }
    }

    // The countdown, large.
    Label {
        visible: win.counting > 0
        anchors.centerIn: parent
        text: win.counting
        color: "#ffffff"
        font.family: Theme.hex ? Theme.mono : Theme.font
        font.pixelSize: 140
        font.weight: Font.Light
        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
    }

    // A video still being written.
    Rectangle {
        visible: win.saving && !win.recording
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        width: savingLabel.implicitWidth + 24; height: 32
        radius: Theme.hex ? 0 : 16
        color: Qt.rgba(0, 0, 0, 0.55)
        Label { id: savingLabel; anchors.centerIn: parent; text: "Saving video…"; color: "#ffffff"; font.pixelSize: 13 }
    }

    // Recording: the time so far, at the top.
    Rectangle {
        visible: win.recording
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        width: recRow.implicitWidth + 24; height: 32
        radius: Theme.hex ? 0 : 16
        color: Qt.rgba(0, 0, 0, 0.55)
        RowLayout {
            id: recRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                implicitWidth: 10; implicitHeight: 10; radius: 5; color: "#ff4d4f"
                SequentialAnimation on opacity { running: win.recording; loops: Animation.Infinite; NumberAnimation { to: 0.2; duration: 600 } NumberAnimation { to: 1; duration: 600 } }
            }
            Label { text: win.clock(rec.duration); color: "#ffffff"; font.family: Theme.mono; font.pixelSize: 14 }
        }
    }

    // A round (Horizon) or hexagonal (Hex) button over the picture.
    component RoundButton: Item {
        id: rb
        property string icon
        property bool on: false
        property string tip
        signal clicked()
        implicitWidth: 44; implicitHeight: 44
        Surface {
            anchors.fill: parent
            radius: 22
            cut: 9
            fill: rb.on ? Theme.accent : (rbm.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.45))
            stroke: Theme.hex ? (rb.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.35)) : "transparent"
            strokeWidth: Theme.hex ? 1 : 0
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 20; height: 20
            source: rb.icon; isMask: true
            color: rb.on ? Theme.onAccent : "#ffffff"
        }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    // Video: which microphone records the sound (the default first).
    Choice {
        visible: win.hasCamera && win.video && !win.recording
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        implicitWidth: 260
        readonly property var mics: devices.audioInputs
        options: ["Microphone: " + (devices.defaultAudioInput.description || "default")].concat(mics.map(m => m.description))
        current: win.micIndex + 1
        onPicked: (i) => win.micIndex = i - 1
    }
    Label {
        visible: win.hasCamera && win.video && !win.recording && devices.audioInputs.length === 0
        anchors.top: parent.top; anchors.left: parent.left
        anchors.margins: 22
        text: "No microphone: videos will be silent"
        color: "#ffb547"
    }

    // The top: timer and mirror.
    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 10
        visible: win.hasCamera && !win.recording
        Item {
            implicitWidth: timerBtn.implicitWidth; implicitHeight: timerBtn.implicitHeight
            RoundButton {
                id: timerBtn
                icon: "chronometer-symbolic"
                on: win.timer > 0
                onClicked: win.timer = win.timer === 0 ? 3 : win.timer === 3 ? 10 : 0
            }
            Label {
                visible: win.timer > 0
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.rightMargin: -4; anchors.bottomMargin: -4
                text: win.timer + "s"
                color: "#ffffff"; font.pixelSize: 11; font.weight: Font.Bold
                style: Text.Outline; styleColor: "#000000"
            }
        }
        RoundButton { icon: "object-flip-horizontal-symbolic"; on: win.mirror; onClicked: win.mirror = !win.mirror }
    }

    // The bottom: the last shot, Photo or Video, the shutter, the other camera.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 132
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
        }
    }
    Segmented {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: shutterBtn.top
        anchors.bottomMargin: 14
        visible: win.hasCamera && !win.recording
        options: ["Photo", "Video"]
        current: win.video ? 1 : 0
        onPicked: (i) => win.video = i === 1
    }
    Item {
        id: shutterBtn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        width: 72; height: 72
        opacity: win.hasCamera ? 1 : 0.35
        // The ring
        Rectangle {
            visible: !Theme.hex
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: "#ffffff"; border.width: 4
        }
        Shape {
            visible: Theme.hex
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: "#ffffff"; strokeWidth: 3
                startX: 18; startY: 4
                PathLine { x: 54; y: 4 } PathLine { x: 70; y: 36 } PathLine { x: 54; y: 68 }
                PathLine { x: 18; y: 68 } PathLine { x: 2; y: 36 } PathLine { x: 18; y: 4 }
            }
        }
        // Inside: white for a photo, red for video, a red square while recording.
        Rectangle {
            anchors.centerIn: parent
            width: win.recording ? 26 : (sm.pressed ? 50 : 56)
            height: width
            radius: win.recording ? (Theme.hex ? 0 : 6) : (Theme.hex ? 0 : width / 2)
            color: win.video ? "#ff4d4f" : "#ffffff"
            Behavior on width { NumberAnimation { duration: 140 } }
            Behavior on radius { NumberAnimation { duration: 140 } }
            visible: !Theme.hex || win.recording
        }
        Shape {
            id: hexIn
            visible: Theme.hex && !win.recording
            anchors.centerIn: parent
            width: sm.pressed ? 46 : 52; height: width * 0.9
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: win.video ? "#ff4d4f" : "#ffffff"; strokeColor: "transparent"
                startX: hexIn.width * 0.25; startY: 0
                PathLine { x: hexIn.width * 0.75; y: 0 }
                PathLine { x: hexIn.width; y: hexIn.height / 2 }
                PathLine { x: hexIn.width * 0.75; y: hexIn.height }
                PathLine { x: hexIn.width * 0.25; y: hexIn.height }
                PathLine { x: 0; y: hexIn.height / 2 }
                PathLine { x: hexIn.width * 0.25; y: 0 }
            }
        }
        MouseArea { id: sm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.shutter() }
    }

    // The last shot: opens in Photos (or the video player).
    Item {
        visible: win.last !== "" && !win.recording
        anchors.verticalCenter: shutterBtn.verticalCenter
        anchors.right: shutterBtn.left
        anchors.rightMargin: Math.min(160, win.width / 5)
        width: 52; height: 52
        Surface { anchors.fill: parent; radius: 10; cut: 8; fill: "#111827"; stroke: Qt.rgba(1, 1, 1, 0.5); strokeWidth: 2 }
        Image {
            anchors.fill: parent
            anchors.margins: 3
            visible: !win.isVideo(win.last)
            source: win.last !== "" && !win.isVideo(win.last) ? "file://" + win.last : ""
            sourceSize.width: 128
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
        Kirigami.Icon {
            visible: win.isVideo(win.last)
            anchors.centerIn: parent
            width: 22; height: 22
            source: "media-playback-start-symbolic"; isMask: true; color: "#ffffff"
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: System.launch(["xdg-open", win.last]) }
    }

    RoundButton {
        visible: devices.videoInputs.length > 1 && !win.recording
        anchors.verticalCenter: shutterBtn.verticalCenter
        anchors.left: shutterBtn.right
        anchors.leftMargin: Math.min(164, win.width / 5 + 4)
        icon: "camera-switch-symbolic"
        onClicked: win.camIndex++
    }

    Shortcut { sequence: "Space"; onActivated: win.shutter() }
    Shortcut { sequence: "Return"; onActivated: win.shutter() }
}
