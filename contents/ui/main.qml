import QtQuick 6.5
import QtQuick.Controls 6.5 as Controls
import QtQuick.Layouts 6.5
import Qt.labs.folderlistmodel
import Qt.labs.platform
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // -- Βοηθητικές ιδιότητες φακέλου -----------------------------------------
    readonly property url defaultFolder: {
        const picturesPath = StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        if (!picturesPath || picturesPath.length === 0) {
            return ""
        }
        if (picturesPath.startsWith("file:")) {
            return picturesPath
        }
        return Qt.platform.os === "windows"
            ? "file:///" + picturesPath.replace(/\\/g, "/")
            : "file://" + picturesPath
    }

    function normalizeFolderUrl(value) {
        if (!value) {
            return ""
        }
        const asString = value.toString()
        if (asString.startsWith("file:")) {
            return asString
        }
        return Qt.platform.os === "windows"
            ? "file:///" + asString.replace(/\\/g, "/")
            : "file://" + asString
    }

    readonly property url resolvedFolder: {
        const configured = plasmoid.configuration.imagesFolder
        if (configured && configured.toString().length > 0) {
            return normalizeFolderUrl(configured)
        }
        return defaultFolder
    }

    readonly property string folderDisplayName: {
        const folderUrl = resolvedFolder
        if (!folderUrl || folderUrl.toString().length === 0) {
            return qsTr("No folder selected")
        }
        const localPath = Qt.urlToLocalFile(folderUrl)
        if (localPath && localPath.length > 0) {
            const normalized = localPath.replace(/\\/g, "/").replace(/\/$/, "")
            const segments = normalized.split("/")
            const lastSegment = segments.length > 0 ? segments[segments.length - 1] : normalized
            return lastSegment.length > 0 ? lastSegment : normalized
        }
        return folderUrl.toString()
    }

    // -- Κατάσταση προβολής ---------------------------------------------------
    readonly property int maxImages: 20
    readonly property int availableCount: Math.min(fileModel.count, maxImages)
    readonly property bool hasImages: availableCount > 0
    property int currentIndex: 0
    property bool slideshowActive: false

    preferredRepresentation: fullRepresentation
    implicitWidth: Kirigami.Units.gridUnit * 12
    implicitHeight: Kirigami.Units.gridUnit * 9

    function nextImage() {
        if (!hasImages) {
            return
        }
        currentIndex = (currentIndex + 1) % availableCount
    }

    function previousImage() {
        if (!hasImages) {
            return
        }
        currentIndex = (currentIndex - 1 + availableCount) % availableCount
    }

    function handleManualNavigation() {
        if (slideshowActive && availableCount > 1) {
            slideshowTimer.restart()
        }
    }

    function refreshSlideshow() {
        if (slideshowActive && availableCount > 1) {
            slideshowTimer.start()
        } else {
            slideshowTimer.stop()
        }
    }

    Connections {
        target: plasmoid.configuration
        function onImagesFolderChanged() {
            root.currentIndex = 0
            root.refreshSlideshow()
        }
    }

    onAvailableCountChanged: {
        if (!hasImages) {
            currentIndex = 0
        } else if (currentIndex >= availableCount) {
            currentIndex = 0
        }
        refreshSlideshow()
    }

    // -- Δεδομένα: φόρτωση αρχείων από φάκελο ---------------------------------
    FolderListModel {
        id: fileModel
        folder: root.resolvedFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.webp"]
        showDirs: false
        showDotAndDotDot: false
        sortReversed: false
    }

    Connections {
        target: fileModel
        function onCountChanged() {
            if (root.currentIndex >= root.availableCount) {
                root.currentIndex = 0
            }
        }
    }

    // -- Λογική slideshow ----------------------------------------------------
    Timer {
        id: slideshowTimer
        interval: 5000
        repeat: true
        running: false
        onTriggered: root.nextImage()
    }

    Component.onCompleted: refreshSlideshow()

    // -- Διάλογος επιλογής φακέλου -------------------------------------------
    FolderDialog {
        id: folderDialog
        title: qsTr("Επιλογή φακέλου εικόνων")
        folder: root.resolvedFolder
        acceptLabel: qsTr("Select folder")
        onAccepted: {
            if (folderDialog.folder && folderDialog.folder.toString().length > 0) {
                plasmoid.configuration.imagesFolder = folderDialog.folder
            }
        }
    }

    // -- Παρουσίαση: κοινή σύνθεση -------------------------------------------
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

                // -- Sidebar με πληροφορίες & χειριστήρια ---------------------
                Rectangle {
                    id: sidebar
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                    Layout.fillHeight: true
                    radius: background.radius
                    color: Qt.rgba(0.12, 0.13, 0.16, 0.96)
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing
                        Layout.alignment: Qt.AlignTop

                        Controls.ToolButton {
                            id: folderButton
                            Layout.alignment: Qt.AlignHCenter
                            icon.name: "folder-open"
                            display: Controls.AbstractButton.IconOnly
                            icon.width: Kirigami.Units.iconSizes.smallMedium
                            icon.height: Kirigami.Units.iconSizes.smallMedium
                            onClicked: folderDialog.open()

                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: qsTr("Change image folder")
                            Controls.ToolTip.delay: 0
                        }

                        Controls.ToolButton {
                            id: playButton
                            Layout.alignment: Qt.AlignHCenter
                            icon.name: root.slideshowActive ? "media-playback-pause" : "media-playback-start"
                            display: Controls.AbstractButton.IconOnly
                            icon.width: Kirigami.Units.iconSizes.smallMedium
                            icon.height: Kirigami.Units.iconSizes.smallMedium
                            onClicked: {
                                root.slideshowActive = !root.slideshowActive
                                root.refreshSlideshow()
                            }

                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: root.slideshowActive
                                ? qsTr("Pause slideshow")
                                : qsTr("Start slideshow")
                            Controls.ToolTip.delay: 0
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            text: folderDisplayName
                            color: Kirigami.Theme.textColor
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: hasImages
                                ? qsTr("%1 images").arg(availableCount)
                                : qsTr("No images")
                            color: Kirigami.Theme.disabledTextColor
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }

                // -- Κύριος χώρος προβολής εικόνας ---------------------------
                Item {
                    id: viewerArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: true

                    Controls.Label {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: Math.min(parent.width * 0.8, Kirigami.Units.gridUnit * 10)
                        text: qsTr("Δεν βρέθηκαν εικόνες στον φάκελο")
                        visible: !hasImages
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Item {
                        id: imageFrame
                        anchors.fill: parent
                        visible: hasImages
                        clip: true

                        Image {
                            id: photo
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
                            opacity: hasImages ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 450
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

                            onSourceChanged: {
                                if (hasImages) {
                                    opacity = 0.0
                                }
                            }
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
                            onClicked: {
                                root.previousImage()
                                root.handleManualNavigation()
                            }
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
                            onClicked: {
                                root.nextImage()
                                root.handleManualNavigation()
                            }
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
                                root.handleManualNavigation()
                            }
                        }

                        Keys.onLeftPressed: {
                            root.previousImage()
                            root.handleManualNavigation()
                        }

                        Keys.onRightPressed: {
                            root.nextImage()
                            root.handleManualNavigation()
                        }
                    }
                }
            }
        }
    }

    fullRepresentation: galleryView
    compactRepresentation: galleryView
}
