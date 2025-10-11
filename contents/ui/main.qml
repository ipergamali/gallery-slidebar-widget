import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Qt.labs.platform
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    readonly property url defaultFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property url resolvedFolder: plasmoid.configuration.imagesFolder || defaultFolder
    property int currentIndex: 0

    preferredRepresentation: compactRepresentation
    implicitWidth: 220
    implicitHeight: 160

    Component {
        id: slideshowRepresentation

        Item {
            id: slideshow
            implicitWidth: 220
            implicitHeight: 160

            ToolButton {
                id: folderButton
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                text: qsTr("Φάκελος")
                z: 2
                onClicked: folderDialog.open()
            }

            FolderDialog {
                id: folderDialog
                title: qsTr("Επιλογή φακέλου εικόνων")
                folder: resolvedFolder
                onAccepted: {
                    plasmoid.configuration.imagesFolder = folder
                }
            }

            FolderListModel {
                id: fileModel
                folder: resolvedFolder
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp"]
                showDirs: false
                showOnlyReadable: true
            }

            Timer {
                id: slideTimer
                interval: Math.max(3, plasmoid.configuration.slideIntervalSeconds || 6) * 1000
                running: fileModel.count > 1
                repeat: true
                onTriggered: {
                    if (fileModel.count === 0) {
                        return
                    }
                    currentIndex = (currentIndex + 1) % fileModel.count
                }
            }

            Component.onCompleted: {
                if (fileModel.count > 1) {
                    slideTimer.start()
                }
            }

            Connections {
                target: fileModel
                function onCountChanged() {
                    if (currentIndex >= fileModel.count) {
                        currentIndex = 0
                    }
                    if (fileModel.count > 1 && !slideTimer.running) {
                        slideTimer.start()
                    } else if (fileModel.count <= 1 && slideTimer.running) {
                        slideTimer.stop()
                    }
                }
            }

            Loader {
                anchors.fill: parent
                active: fileModel.count === 0
                sourceComponent: emptyState
            }

            Image {
                id: photo
                anchors.fill: parent
                visible: fileModel.count > 0
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                source: fileModel.count > 0 ? fileModel.get(currentIndex).fileUrl : ""
                opacity: 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.InOutQuad
                    }
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        opacity = 1.0
                    } else if (status === Image.Loading) {
                        opacity = 0.0
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (fileModel.count <= 1) {
                            return
                        }
                        slideTimer.restart()
                        currentIndex = (currentIndex + 1) % fileModel.count
                    }
                }
            }
        }
    }

    Component {
        id: emptyState

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: PlasmaCore.Theme.backgroundColor

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: PlasmaCore.Theme.textColor
                text: qsTr("Δεν βρέθηκαν εικόνες στον φάκελο")
            }
        }
    }

    compactRepresentation: slideshowRepresentation
    fullRepresentation: slideshowRepresentation
}
