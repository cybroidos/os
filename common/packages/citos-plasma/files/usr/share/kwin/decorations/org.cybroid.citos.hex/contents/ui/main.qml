/*
 * CIT-OS Hex's window title bar (citos-plasma), the HUD design's window: the
 * top-left corner cut as Hangar's panels are, the colour keys at the left,
 * and the title in a tab the bar's top line bends down round, as the
 * desktop's frame bends round its tab under the top bar. Hex Light is the
 * same bar in the light palette, chosen by the colour scheme.
 *
 * A QML decoration rather than an Aurorae SVG theme: Aurorae repeats one
 * slice across the bar, so it cannot hold a tab in the middle.
 */
import QtQuick
import QtQuick.Shapes
import org.kde.kwin.decoration

Decoration {
    id: root
    alpha: true

    readonly property bool max: decoration.client.maximized
    readonly property bool act: decoration.client.active
    // The bar: 38 px, 32 when maximised (square, no shadow).
    readonly property int barH: max ? 32 : 38
    readonly property int cut: max ? 0 : 14
    // Room round the window for its shadow (none when maximised).
    readonly property int padL: max ? 0 : 24
    readonly property int padT: max ? 0 : 14
    readonly property int padR: max ? 0 : 24
    readonly property int padB: max ? 0 : 28

    // Hex or Hex Light: citos-appearance says which in the decoration's own
    // settings (auroraerc, group org.cybroid.citos.hex, key light), which KWin
    // reads again on every reconfigure; the colour scheme's title bar colour
    // is the fallback (KWin kept the old palette after a switch).
    property bool lightSetting: false
    readonly property bool light: lightSetting || options.titleBarColor.hslLightness > 0.6
    function readSettings() {
        const v = decoration.readConfig("light", false)
        root.lightSetting = v === true || String(v) === "true"
    }
    Connections {
        target: decoration
        function onConfigChanged() { root.readSettings() }
    }
    readonly property color acc: light ? "#1f5fe0" : "#1ccbff"
    readonly property color blue: light ? "#0b8fc4" : "#3a7cff"
    readonly property color line: act ? (light ? "#9db0d6" : "#2a3d6e") : (light ? "#c9d5ea" : "#16264a")
    readonly property color fg: act ? (light ? "#0b1634" : "#e8eefc") : (light ? "#4a5b85" : "#8fa3c8")
    readonly property color barTop: light ? (act ? "#ffffff" : "#eef3fb") : (act ? "#0c1734" : "#070e22")
    readonly property color barFoot: light ? (act ? "#f6f9ff" : "#eef3fb") : (act ? "#080f24" : "#070e22")
    readonly property color tabFill: light ? (act ? "#e9eff9" : "#e6eef9") : (act ? "#0a1532" : "#060c1e")

    // The window's own rectangle inside the shadow's room.
    readonly property real fx: padL
    readonly property real fy: padT
    readonly property real fw: width - padL - padR
    readonly property real fh: height - padT - padB

    DecorationOptions {
        id: options
        deco: decoration
    }

    // The shadow: a few faint layers close round the window (heavy shadows
    // muddied the design), lighter below a window that isn't in front.
    Repeater {
        model: root.max ? 0 : 6
        Rectangle {
            required property int index
            readonly property real k: (index + 1) * 2
            x: root.fx - k
            y: root.fy - k + 3
            width: root.fw + 2 * k
            height: root.fh + 2 * k
            radius: k
            color: "#000000"
            opacity: (root.act ? 0.016 : 0.009) * (root.light ? 0.7 : 1)
        }
    }

    // The bar, its top-left corner cut.
    Shape {
        x: root.fx; y: root.fy
        width: root.fw; height: root.barH
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.barH
                GradientStop { position: 0; color: root.barTop }
                GradientStop { position: 1; color: root.barFoot }
            }
            startX: root.cut; startY: 0
            PathLine { x: root.fw; y: 0 }
            PathLine { x: root.fw; y: root.barH }
            PathLine { x: 0; y: root.barH }
            PathLine { x: 0; y: root.cut }
            PathLine { x: root.cut; y: 0 }
        }
    }

    // The tab: as wide as the title needs, centred, its sides slanting in.
    readonly property real slant: 10
    readonly property real tabW: Math.min(caption.implicitWidth + 64, root.fw - 2 * (buttons.width + 40))
    readonly property real tabH: root.barH - 7
    readonly property real tabL: (root.fw - tabW) / 2
    readonly property real tabR: tabL + tabW

    Shape {
        x: root.fx; y: root.fy
        width: root.fw; height: root.barH
        preferredRendererType: Shape.CurveRenderer
        // The tab's fill, a shade deeper than the bar.
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillColor: root.tabFill
            startX: root.tabL; startY: 0
            PathLine { x: root.tabR; y: 0 }
            PathLine { x: root.tabR - root.slant; y: root.tabH }
            PathLine { x: root.tabL + root.slant; y: root.tabH }
            PathLine { x: root.tabL; y: 0 }
        }
        // The top line: from the cut corner along the top, down round the
        // tab and back up; dim along its length...
        ShapePath {
            strokeWidth: 1
            strokeColor: root.act ? Qt.alpha(root.acc, 0.38) : root.line
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            startX: 0; startY: root.cut + 24
            PathLine { x: 0; y: root.cut }
            PathLine { x: root.cut; y: 0.5 }
            PathLine { x: root.tabL; y: 0.5 }
            PathLine { x: root.tabL + root.slant; y: root.tabH }
            PathLine { x: root.tabR - root.slant; y: root.tabH }
            PathLine { x: root.tabR; y: 0.5 }
            PathLine { x: root.fw; y: 0.5 }
        }
        // ...lit cyan round the cut corner...
        ShapePath {
            strokeWidth: 1
            strokeColor: root.act ? root.acc : "transparent"
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            startX: 0; startY: root.cut + 24
            PathLine { x: 0; y: root.cut }
            PathLine { x: root.cut; y: 0.5 }
            PathLine { x: Math.min(root.tabL, root.cut + root.fw * 0.18); y: 0.5 }
        }
        // ...and blue at the far end.
        ShapePath {
            strokeWidth: 1
            strokeColor: root.act ? root.blue : "transparent"
            fillColor: "transparent"
            startX: Math.max(root.tabR, root.fw * 0.86); startY: 0.5
            PathLine { x: root.fw; y: 0.5 }
        }
    }
    // The bar's foot: a hairline over the window.
    Rectangle {
        x: root.fx; y: root.fy + root.barH - 1
        width: root.fw; height: 1
        color: root.light ? (root.act ? "#c9d5ea" : "#d3e0f6") : (root.act ? "#13224a" : "#101c3c")
    }

    // The title, in the tab.
    Text {
        id: caption
        x: root.fx + root.tabL + root.slant + 12
        width: root.tabW - 2 * (root.slant + 12)
        y: root.fy + (root.tabH - height) / 2
        horizontalAlignment: Text.AlignHCenter
        text: decoration.client.caption
        color: root.fg
        font.family: options.titleFont.family
        font.pixelSize: 13
        font.weight: root.act ? Font.DemiBold : Font.Normal
        elide: Text.ElideMiddle
        textFormat: Text.PlainText
    }

    // The colour keys at the left (the order follows the window manager's
    // settings: close, minimise, zoom in CIT-OS).
    Item {
        id: titleRow
        x: root.fx; y: root.fy
        width: root.fw; height: root.barH
        ButtonGroup {
            id: buttons
            x: root.max ? 12 : 16
            y: (root.barH - 13) / 2
            spacing: 7
            explicitSpacer: 13
            closeButton: closeComponent
            minimizeButton: minimizeComponent
            maximizeButton: maximizeComponent
            buttons: options.titleButtonsLeft
        }
        ButtonGroup {
            anchors.right: parent.right; anchors.rightMargin: 16
            y: (root.barH - 13) / 2
            spacing: 7
            explicitSpacer: 13
            closeButton: closeComponent
            minimizeButton: minimizeComponent
            maximizeButton: maximizeComponent
            buttons: options.titleButtonsRight
        }
        Component.onCompleted: decoration.installTitleItem(titleRow)
    }

    Component {
        id: closeComponent
        HexButton { light: root.light; buttonType: DecorationOptions.DecorationButtonClose; tint: "#ff6b5a"; glyph: "close" }
    }
    Component {
        id: minimizeComponent
        HexButton { light: root.light; buttonType: DecorationOptions.DecorationButtonMinimize; tint: "#f2c14b"; glyph: "minimize" }
    }
    Component {
        id: maximizeComponent
        HexButton { light: root.light; buttonType: DecorationOptions.DecorationButtonMaximizeRestore; tint: "#3ee0a0"; glyph: "maximize" }
    }

    function place() {
        borders.setBorders(0)
        borders.setTitle(38)
        maximizedBorders.setBorders(0)
        maximizedBorders.setTitle(32)
        padding.left = root.padL
        padding.top = root.padT
        padding.right = root.padR
        padding.bottom = root.padB
    }
    onMaxChanged: place()
    Component.onCompleted: {
        place()
        readSettings()
    }
}
