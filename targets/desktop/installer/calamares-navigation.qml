/* CybroidOS installer: the buttons at the foot of each page, in the Horizon
 * design. Cancel quietly at the left; Back and the way on (Next, Install,
 * Done) at the right, the way on in CIT blue. Calamares loads this from the
 * branding folder (navigation: qml). */
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: nav
    color: "#0f1a3a"
    height: 64

    // A hairline above, between the page and the buttons.
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#22305c" }

    // A pill button: "primary" in CIT blue, otherwise quiet with a hairline.
    component Pill: Button {
        id: b
        property bool primary: false
        implicitHeight: 38
        implicitWidth: Math.max(108, label.implicitWidth + 40)
        hoverEnabled: true
        contentItem: Text {
            id: label
            // Without Qt's "&" shortcut markers.
            text: b.text.replace(/&(?!&)/g, "")
            color: !b.enabled ? "#5b6d96" : b.primary ? "#ffffff" : "#dfe7fb"
            font.pixelSize: 14; font.weight: b.primary ? Font.DemiBold : Font.Medium; font.family: "Inter"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 19
            color: !b.enabled ? (b.primary ? "#1a2c5c" : "transparent")
                : b.primary ? (b.down ? "#1a52c4" : b.hovered ? "#2b6cf0" : "#1f5fe0")
                : (b.down ? "#1b2a5a" : b.hovered ? "#16224a" : "transparent")
            border.width: b.primary ? 0 : 1
            border.color: b.hovered ? "#1ccbff" : "#2a3d6e"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20; anchors.rightMargin: 20
        spacing: 12

        Pill {
            text: ViewManager.quitLabel
            enabled: ViewManager.quitEnabled
            // At the end the way on is "Done": no second button for it.
            visible: ViewManager.quitVisible && ViewManager.currentStepIndex < ViewManager.rowCount() - 1
            onClicked: ViewManager.quit()
            ToolTip.visible: hovered && ViewManager.quitTooltip.length > 0
            ToolTip.text: ViewManager.quitTooltip
            ToolTip.delay: 800
        }
        Item { Layout.fillWidth: true }
        Pill {
            text: ViewManager.backLabel
            enabled: ViewManager.backEnabled
            visible: ViewManager.backAndNextVisible
            onClicked: ViewManager.back()
        }
        Pill {
            primary: true
            text: ViewManager.backAndNextVisible ? ViewManager.nextLabel : ViewManager.quitLabel
            enabled: ViewManager.backAndNextVisible ? ViewManager.nextEnabled : ViewManager.quitEnabled
            visible: ViewManager.backAndNextVisible || ViewManager.quitVisible
            onClicked: ViewManager.backAndNextVisible ? ViewManager.next() : ViewManager.quit()
        }
    }
}
