/*
 * CybroidOS Hex's desktop, as layers: the ground (Hex's own, or a picture the
 * person chose, toned toward Hex's navy or sky so the interface stays
 * readable) and over it Hex's interface: the frame, the dial with the mark,
 * the six leaders the desktop's readouts sit beside, and the grid
 * (render-brand.py draws both: cybroid-hex-<W>x<H>.png and its -hud- twin).
 * Each screen gets the drawing made for its shape (hexPick, kept in step with
 * cybroid-appearance and org.cybroid.widgets), scaled to cover it exactly as
 * the readouts' places assume.
 */
import QtQuick
import QtQuick.Shapes

Item {
    id: scene
    property string image: ""      // a file URL or path; "" for Hex's own ground
    property bool light: false
    property real dim: 0.6        // 0.2 to 0.9: how far the picture is toned
    property string folder: "/usr/share/backgrounds/cybroid"

    readonly property bool own: image === ""
    readonly property var shape: hexPick(width, height)
    readonly property string base: "file://" + folder + "/cybroid-" + (light ? "hex-light" : "hex")
    readonly property string size: shape[0] + "x" + shape[1]

    function hexPick(W, H) {
        if (W <= 0 || H <= 0) return [1920, 1080]
        const shapes = [[1920, 1080], [2560, 1440], [3840, 2160], [1920, 1200], [2560, 1600],
            [1600, 1200], [1280, 1024], [2560, 1080], [3440, 1440], [5120, 1440], [1080, 1920]]
        const la = Math.log(W / H)
        let best = 1e9
        for (const s of shapes) best = Math.min(best, Math.abs(Math.log(s[0] / s[1]) - la))
        const near = shapes.filter(s => Math.abs(Math.log(s[0] / s[1]) - la) <= best + 0.02).sort((a, b) => a[0] - b[0])
        for (const s of near) if (s[0] >= W) return s
        return near[near.length - 1]
    }

    // Hex's own ground and interface, in one picture (as before).
    Image {
        anchors.fill: parent
        visible: scene.own
        source: scene.own ? scene.base + "-" + scene.size + ".png" : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    // The person's picture…
    Image {
        id: photo
        anchors.fill: parent
        visible: !scene.own
        source: scene.own ? "" : (scene.image.indexOf("://") > 0 ? scene.image : "file://" + scene.image)
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: scene.width
        sourceSize.height: scene.height
        asynchronous: true
        smooth: true
    }
    // …toned toward Hex's ground, as Hex's own is (a brighter navy round the
    // dial, deepest at the edges), and enough round the dial that it reads
    // over the busiest part of a photo.
    Shape {
        anchors.fill: parent
        visible: !scene.own
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: scene.width / 2; centerY: scene.height * 0.49
                focalX: scene.width / 2; focalY: scene.height * 0.49
                centerRadius: Math.max(scene.width, scene.height) * 0.62
                focalRadius: 0
                GradientStop { position: 0; color: scene.light ? Qt.rgba(0.89, 0.93, 0.99, scene.dim * 0.85) : Qt.rgba(0.05, 0.11, 0.27, scene.dim * 0.92) }
                GradientStop { position: 0.55; color: scene.light ? Qt.rgba(0.71, 0.80, 0.95, scene.dim * 0.9) : Qt.rgba(0.03, 0.06, 0.15, scene.dim * 0.92) }
                GradientStop { position: 1; color: scene.light ? Qt.rgba(0.53, 0.66, 0.90, Math.min(1, scene.dim * 1.05)) : Qt.rgba(0.01, 0.03, 0.07, Math.min(1, scene.dim * 1.1)) }
            }
            startX: 0; startY: 0
            PathLine { x: scene.width; y: 0 }
            PathLine { x: scene.width; y: scene.height }
            PathLine { x: 0; y: scene.height }
            PathLine { x: 0; y: 0 }
        }
    }
    // Hex's interface on top, so the readouts' leaders are always there.
    Image {
        anchors.fill: parent
        visible: !scene.own
        source: scene.own ? "" : scene.base + "-hud-" + scene.size + ".png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
}
