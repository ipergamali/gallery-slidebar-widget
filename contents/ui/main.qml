import QtQuick 6.5
import QtQuick.Controls 6.5 as Controls
import QtQuick.Dialogs 6.5 as Dialogs
import QtQuick.Layouts 6.5
import Qt.labs.folderlistmodel
import Qt.labs.platform
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property url defaultFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property url currentFolder: plasmoid.configuration.imagesFolder && plasmoid.configuration.imagesFolder.length > 0
        ? plasmoid.configuration.imagesFolder
        : defaultFolder
    readonly property int maxImages: 20
    readonly property int availableCount: Math.min(fileModel.count, maxImages)
    property int currentIndex: 0

    preferredRepresentation: fullRepresentation
    implicitWidth: Kirigami.Units.gridUnit * 12
    implicitHeight: Kirigami.Units.gridUnit * 9

    function nextImage() {
        if (availableCount <= 0) {
            return
        }
        currentIndex = (currentIndex + 1) % availableCount
    }

    function previousImage() {
        if (availableCount <= 0) {
            return
        }
        currentIndex = (currentIndex - 1 + availableCount) % availableCount
    }

    Connections {
        target: plasmoid.configuration
        function onImagesFolderChanged() {
            root.currentIndex = 0
        }
    }

    onAvailableCountChanged: {
        if (availableCount === 0) {
            currentIndex = 0
        } else if (currentIndex >= availableCount) {
            currentIndex = 0
        }
    }

    FolderListModel {
        id: fileModel
        folder: root.currentFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.webp"]
        showDirs: false
        showDotAndDotDot: false
        sortReversed: false
    }

    Component.onCompleted: {
        if (availableCount === 0) {
            currentIndex = 0
        }
    }

    Dialogs.FileDialog {
        id: folderDialog
        title: qsTr("Επιλογή φακέλου εικόνων")
        currentFolder: root.currentFolder
        fileMode: Dialogs.FileDialog.FileMode.Directory
        onAccepted: {
            if (folderDialog.selectedFolder && folderDialog.selectedFolder.toString().length > 0) {
                plasmoid.configuration.imagesFolder = folderDialog.selectedFolder

            }
        }
    }

    Component {
        id: galleryView

        Kirigami.ShadowedRectangle {
            id: background
            anchors.fill: parent
            radius: Kirigami.Units.largeSpacing
            color: Qt.rgba(0.08, 0.09, 0.11, 0.96)
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            shadow.size: Kirigami.Units.largeSpacing
            shadow.color: Qt.rgba(0, 0, 0, 0.35)

            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing * 2
                spacing: Kirigami.Units.smallSpacing * 2

                Rectangle {
                    id: sidebar
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                    Layout.fillHeight: true
                    radius: background.radius
                    color: Qt.rgba(0.12, 0.13, 0.16, 0.96)
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    Controls.ToolButton {
                        id: folderButton
                        anchors.centerIn: parent
                        icon.name: "folder-open"
                        display: Controls.AbstractButton.IconOnly
                        icon.width: Kirigami.Units.iconSizes.smallMedium
                        icon.height: Kirigami.Units.iconSizes.smallMedium
                        onClicked: folderDialog.open()

                        Controls.ToolTip.visible: hovered
                        Controls.ToolTip.text: qsTr("Change image folder")
                        Controls.ToolTip.delay: 0
                    }
                }

                Item {
                    id: viewerArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: true

                    Controls.Label {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: parent.width - Kirigami.Units.gridUnit * 2
                        text: qsTr("No images found in folder")
                        visible: availableCount === 0
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Item {
                        id: imageFrame
                        anchors.fill: parent
                        visible: availableCount > 0
                        clip: true
                        focus: true

                        Image {
                            id: imageView
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: availableCount > 0 ? fileModel.get(currentIndex, "fileUrl") : ""
                            opacity: 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 400
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

                            onSourceChanged: opacity = 0.0
                        }

                        Controls.ToolButton {
                            id: previousButton
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            icon.name: "go-previous"
                            display: Controls.AbstractButton.IconOnly
                            enabled: availableCount > 1
                            opacity: enabled ? 0.9 : 0.4
                            onClicked: root.previousImage()
                        }

                        Controls.ToolButton {
                            id: nextButton
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            icon.name: "go-next"
                            display: Controls.AbstractButton.IconOnly
                            enabled: availableCount > 1
                            opacity: enabled ? 0.9 : 0.4
                            onClicked: root.nextImage()
                        }

                        WheelHandler {
                            id: wheelHandler
                            target: imageFrame
                            onWheel: function(event) {
                                if (availableCount <= 1) {
                                    return
                                }
                                event.accepted = true
                                if (event.angleDelta.y < 0) {
                                    root.nextImage()
                                } else if (event.angleDelta.y > 0) {
                                    root.previousImage()
                                }
                            }
                        }

                        Keys.onLeftPressed: root.previousImage()
                        Keys.onRightPressed: root.nextImage()
                    }
                }
            }
        }
    }

    fullRepresentation: galleryView
    compactRepresentation: galleryView
}
