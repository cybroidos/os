import QtQuick
import QtQuick.Layouts
import CybroidUi

// Rows grouped on one surface, a hairline between them.
Surface {
    id: card
    default property alias rows: col.data
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 2
    Column {
        id: col
        x: 1; y: 1
        width: card.width - 2
    }
}
