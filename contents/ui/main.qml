import QtQuick
import QtQuick.Controls
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation

    Component {
        id: greetingCard

        Rectangle {
            implicitWidth: 200
            implicitHeight: 100
            radius: 10
            color: "#45533C"

            Text {
                anchors.centerIn: parent
                text: "Γεια σου Joanne!"
                color: "white"
                font.pixelSize: 20
            }
        }
    }

    compactRepresentation: greetingCard
    fullRepresentation: greetingCard
}
