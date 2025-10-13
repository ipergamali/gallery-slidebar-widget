import QtQuick 6.5
import QtQuick.Controls 6.5 as Controls
import QtQuick.Layouts 6.5
import Qt.labs.folderlistmodel
import Qt.labs.platform
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

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
    readonly property url currentFolder: {
        const configuredFolder = plasmoid.configuration.imagesFolder
        if (configuredFolder && configuredFolder.toString().length > 0) {
            return configuredFolder
        }
        return defaultFolder
    }
    readonly property int maxImages: 20
    readonly property int availableCount: Math.min(fileModel.count, maxImages)
    property string transitionStyle: {
        const style = plasmoid.configuration.transitionStyle
        if (style === "slide" || style === "fade") {
            return style
        }
        return "fade"
    }
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

    FolderDialog {
        id: folderDialog
        title: qsTr("Επιλογή φακέλου εικόνων")
        folder: root.currentFolder
        acceptLabel: qsTr("Select folder")
        onAccepted: {
            if (folderDialog.folder && folderDialog.folder.toString().length > 0) {
                plasmoid.configuration.imagesFolder = folderDialog.folder
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

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

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
                            id: animationButton
                            Layout.alignment: Qt.AlignHCenter
                            icon.name: "preferences-desktop-animations"
                            display: Controls.AbstractButton.IconOnly
                            icon.width: Kirigami.Units.iconSizes.smallMedium
                            icon.height: Kirigami.Units.iconSizes.smallMedium
                            onClicked: animationMenu.popup(animationButton)

                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: qsTr("Change transition animation")
                            Controls.ToolTip.delay: 0
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    Controls.Menu {
                        id: animationMenu
                        Controls.ExclusiveGroup { id: animationGroup }

                        Controls.MenuItem {
                            text: qsTr("Fade")
                            checkable: true
                            checked: root.transitionStyle === "fade"
                            exclusiveGroup: animationGroup
                            onTriggered: plasmoid.configuration.transitionStyle = "fade"
                        }

                        Controls.MenuItem {
                            text: qsTr("Slide")
                            checkable: true
                            checked: root.transitionStyle === "slide"
                            exclusiveGroup: animationGroup
                            onTriggered: plasmoid.configuration.transitionStyle = "slide"
                        }
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

                        Loader {
                            id: transitionLoader
                            anchors.fill: parent
                            sourceComponent: root.transitionStyle === "slide" ? slideImageComponent : fadeImageComponent
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

    Component {
        id: fadeImageComponent

        Image {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: availableCount > 0 ? fileModel.get(root.currentIndex, "fileUrl") : ""
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

            onSourceChanged: {
                if (availableCount > 0) {
                    opacity = 0.0
                }
            }
        }
    }

    Component {
        id: slideImageComponent

        Item {
            id: slideArea
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            clip: true

            property int displayedIndex: -1
            property bool animating: false

            Image {
                id: currentSlideImage
                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }
    }

            Image {
                id: nextSlideImage
                anchors.fill: parent
                visible: false
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            ParallelAnimation {
                id: slideAnimation

                NumberAnimation {
                    id: currentOutAnimation
                    target: currentSlideImage
                    property: "x"
                    duration: 400
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    id: nextInAnimation
                    target: nextSlideImage
                    property: "x"
                    duration: 400
                    easing.type: Easing.InOutQuad
                }

                onStopped: {
                    if (!slideArea.animating) {
                        return
                    }
                    currentSlideImage.source = nextSlideImage.source
                    currentSlideImage.x = 0
                    nextSlideImage.visible = false
                    nextSlideImage.source = ""
                    nextSlideImage.x = 0
                    slideArea.displayedIndex = root.currentIndex
                    slideArea.animating = false
                }
            }

            function computeDirection(oldIndex, newIndex) {
                if (availableCount <= 1) {
                    return 1
                }
                if (oldIndex === newIndex) {
                    return 1
                }
                if (oldIndex === availableCount - 1 && newIndex === 0) {
                    return 1
                }
                if (oldIndex === 0 && newIndex === availableCount - 1) {
                    return -1
                }
                return newIndex > oldIndex ? 1 : -1
            }

            function resetToCurrent() {
                slideAnimation.stop()
                slideArea.animating = false
                nextSlideImage.visible = false
                nextSlideImage.source = ""
                nextSlideImage.x = 0
                currentSlideImage.x = 0

                if (availableCount > 0) {
                    slideArea.displayedIndex = root.currentIndex
                    currentSlideImage.source = fileModel.get(root.currentIndex, "fileUrl")
                } else {
                    slideArea.displayedIndex = -1
                    currentSlideImage.source = ""
                }
            }

            function startSlide() {
                if (availableCount <= 0) {
                    resetToCurrent()
                    return
                }

                const newSource = fileModel.get(root.currentIndex, "fileUrl")

                if (slideArea.displayedIndex === -1 || !currentSlideImage.source) {
                    resetToCurrent()
                    return
                }

                if (newSource === currentSlideImage.source) {
                    return
                }

                slideAnimation.stop()
                slideArea.animating = true
                nextSlideImage.source = newSource
                nextSlideImage.visible = true

                const direction = computeDirection(slideArea.displayedIndex, root.currentIndex)

                currentSlideImage.x = 0
                nextSlideImage.x = direction * slideArea.width

                currentOutAnimation.to = -direction * slideArea.width
                nextInAnimation.to = 0

                slideAnimation.start()
            }

            Connections {
                target: root
                function onCurrentIndexChanged() {
                    if (availableCount === 0) {
                        resetToCurrent()
                        return
                    }
                    if (slideArea.animating) {
                        slideAnimation.stop()
                    }
                    startSlide()
                }
            }

            Connections {
                target: fileModel
                function onCountChanged() {
                    resetToCurrent()
                }
            }

            Component.onCompleted: resetToCurrent()

            onVisibleChanged: {
                if (visible) {
                    resetToCurrent()
                }
            }
        }
    }
}
