/*
 * The Hex wallpaper's settings in Plasma's "Configure Desktop and Wallpaper":
 * a picture behind Hex's interface (or Hex's own ground), and how far it is
 * toned toward Hex's colours.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout
    property alias formLayout: root

    property string cfg_Image
    property int cfg_Dim

    FileDialog {
        id: picker
        title: "Choose a picture"
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: root.cfg_Image = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
    }

    RowLayout {
        Kirigami.FormData.label: "Background:"
        QQC2.Label { text: root.cfg_Image ? root.cfg_Image.split("/").pop() : "Hex's own"; elide: Text.ElideMiddle; Layout.maximumWidth: Kirigami.Units.gridUnit * 14 }
        QQC2.Button { text: "Choose a picture…"; onClicked: picker.open() }
        QQC2.Button { text: "Use Hex's own"; visible: root.cfg_Image !== ""; onClicked: root.cfg_Image = "" }
    }
    QQC2.Slider {
        Kirigami.FormData.label: "Tone the picture:"
        enabled: root.cfg_Image !== ""
        from: 20; to: 90; stepSize: 5
        value: root.cfg_Dim
        onMoved: root.cfg_Dim = value
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
    }
    QQC2.Label {
        Kirigami.FormData.label: ""
        text: "Hex's dial and readouts always stay on top of the picture."
        opacity: 0.7
    }
}
