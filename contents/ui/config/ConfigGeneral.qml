import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.configuration 2.0

ConfigPage {
    id: root
    title: i18n("Gallery Slidebar Settings")

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            text: i18n("General")
            level: 2
            Layout.fillWidth: true
        }

        // --- Folder selection field ---
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Label {
                text: i18n("Images Folder:")
                Layout.alignment: Qt.AlignVCenter
                width: 150
            }

            TextField {
                id: folderPath
                text: cfg.ImagesFolder
                placeholderText: i18n("Select a folder containing your images...")
                Layout.fillWidth: true
            }

            Button {
                text: i18n("Browse")
                icon.name: "folder-pictures"
                onClicked: {
                    var dialog = FileDialog {
                        title: i18n("Select Image Folder")
                        folder: folderPath.text !== "" ? folderPath.text : "file:///"
                        selectFolder: true
                        onAccepted: {
                            folderPath.text = folder.toString()
                            cfg.ImagesFolder = folderPath.text
                        }
                    }
                    dialog.open()
                }
            }
        }

        // --- Transition animation selection ---
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Label {
                text: i18n("Transition Mode:")
                Layout.alignment: Qt.AlignVCenter
                width: 150
            }

            ComboBox {
                id: transitionModeBox
                model: ["fade", "slide", "zoom"]
                currentIndex: model.indexOf(cfg.TransitionMode)
                onCurrentIndexChanged: cfg.TransitionMode = model[currentIndex]
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true } // Spacer
    }
}
