pragma Singleton
import QtQuick
import Cybroid.Settings

// CybroidOS Settings' design tokens, for the design in use: Horizon (rounded,
// calm) or Hex (cut corners, mono labels, cyan), each Dark or Light. The
// colours are the desktop's own (cybroid-plasma's colour schemes and Hex's
// widgets), so Settings sits in the desktop as one piece.
QtObject {
    readonly property bool hex: System.design === "hex"
    readonly property bool light: System.light

    readonly property color bg: hex ? (light ? "#e9eff9" : "#060c1e") : (light ? "#f2f4f8" : "#0e1735")
    readonly property color side: hex ? (light ? "#dfe7f5" : "#081026") : (light ? "#e8ecf3" : "#121d42")
    readonly property color card: hex ? (light ? "#ffffff" : "#0b1530") : (light ? "#ffffff" : "#17244d")
    readonly property color cardHover: hex ? (light ? "#f1f5fd" : "#102044") : (light ? "#f5f7fb" : "#1c2b5a")
    readonly property color line: hex ? (light ? "#c5d5f1" : "#1b2f63") : (light ? Qt.rgba(0.09, 0.12, 0.2, 0.09) : Qt.rgba(0.91, 0.93, 0.99, 0.08))
    readonly property color edge: hex ? (light ? "#7d9bd3" : "#2a4686") : (light ? Qt.rgba(0.09, 0.12, 0.2, 0.08) : Qt.rgba(0.91, 0.93, 0.99, 0.06))
    readonly property color ink: hex ? (light ? "#0b1634" : "#e8eefc") : (light ? "#161e34" : "#e8eefc")
    readonly property color soft: hex ? (light ? "#4a5b85" : "#8fa3c8") : (light ? "#606c87" : "#9fb3d9")
    readonly property color faint: hex ? (light ? "#8a9cc2" : "#4a5b85") : (light ? "#9aa4ba" : "#5d6f99")
    readonly property color accent: hex ? (light ? "#1f5fe0" : "#1ccbff") : (light ? "#2563eb" : "#3a7cff")
    readonly property color onAccent: hex && !light ? "#04101f" : "#ffffff"
    readonly property color selected: hex ? (light ? "#cfdcf8" : "#0c4f72") : (light ? "#dbe6fd" : "#26407f")
    readonly property color ok: hex ? (light ? "#0f7a4b" : "#3ee0a0") : (light ? "#15803d" : "#4ade80")
    readonly property color warn: light ? "#a86400" : "#ffb547"
    readonly property color bad: hex ? (light ? "#c8102e" : "#ff6b5a") : (light ? "#dc2626" : "#f87171")
    readonly property color track: hex ? (light ? "#c5d5f1" : "#1b2f63") : (light ? "#d5dbe7" : "#2a3963")

    readonly property string font: "Inter"
    readonly property string mono: "JetBrains Mono"
    // Hex labels are mono capitals, spaced, as on its desktop readouts.
    readonly property string labelFont: hex ? mono : font
    readonly property real radius: hex ? 0 : 12
    readonly property real cut: hex ? 9 : 0
    readonly property int duration: 160
}
