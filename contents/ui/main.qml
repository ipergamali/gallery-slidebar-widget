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
            return ""
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
    property var transitionOptions: [
        {
            key: "fade",
            text: qsTr("Fade"),
            description: qsTr("Απαλή εναλλαγή"),
            icon: "preferences-desktop-theme-global",
            component: fadeComponent
        },
        {
            key: "slide",
            text: qsTr("Slide"),
            description: qsTr("Οριζόντια κύλιση"),
            icon: "view-catalog",
            component: slideComponent
        },
        {
            key: "zoom",
            text: qsTr("Zoom"),
            description: qsTr("Μεγέθυνση/σμίκρυνση"),
            icon: "zoom-in",
            component: zoomComponent
        },
        {
            key: "pan",
            text: qsTr("Pan"),
            description: qsTr("Απαλή μετατόπιση"),
            icon: "transform-move",
            component: panComponent
        },
        {
            key: "flip",
            text: qsTr("Flip"),
            description: qsTr("Αναστροφή"),
            icon: "view-refresh",
            component: flipComponent
        },
        {
            key: "rotate",
            text: qsTr("Rotate"),
            description: qsTr("Περιστροφή"),
            icon: "object-rotate-right",
            component: rotateComponent
        }
    ]

    function normalizedTransition(mode) {
        const requested = mode || ""
        const matched = transitionOptions.find((option) => option.key === requested)
        return matched ? matched.key : transitionOptions[0].key
    }

    property string transitionMode: normalizedTransition(plasmoid.configuration.transitionMode)

    readonly property var selectedTransition: transitionOptions.find((option) => option.key === transitionMode) || transitionOptions[0]
    readonly property string transitionLabel: selectedTransition ? selectedTransition.description : ""

    preferredRepresentation: fullRepresentation
    implicitWidth: Kirigami.Units.gridUnit * 20
    implicitHeight: Kirigami.Units.gridUnit * 12

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

        function onTransitionModeChanged() {
            const normalized = root.normalizedTransition(plasmoid.configuration.transitionMode)
            if (normalized !== root.transitionMode) {
                root.transitionMode = normalized
            }
            if (normalized !== plasmoid.configuration.transitionMode) {
                plasmoid.configuration.transitionMode = normalized
            }
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

    Component.onCompleted: {
        const normalized = root.normalizedTransition(plasmoid.configuration.transitionMode)
        if (normalized !== plasmoid.configuration.transitionMode) {
            plasmoid.configuration.transitionMode = normalized
        }
        if (normalized !== root.transitionMode) {
            root.transitionMode = normalized
        }
        refreshSlideshow()
    }

    // -- Διάλογος επιλογής φακέλου -------------------------------------------
    FolderDialog {
        id: folderDialog
        title: qsTr("Επιλογή φακέλου εικόνων")
        folder: root.resolvedFolder
        acceptLabel: qsTr("Select folder")
        onAccepted: {
            if (folderDialog.folder && folderDialog.folder.toString().length > 0) {
                plasmoid.configuration.imagesFolder = root.normalizeFolderUrl(folderDialog.folder)
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

                        Controls.ToolButton {
                            id: detailsButton
                            Layout.alignment: Qt.AlignHCenter
                            icon.name: "view-list-details"
                            display: Controls.AbstractButton.IconOnly
                            icon.width: Kirigami.Units.iconSizes.smallMedium
                            icon.height: Kirigami.Units.iconSizes.smallMedium
                            onClicked: detailsMenu.popup(detailsButton)

                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: qsTr("Folder details")
                            Controls.ToolTip.delay: 0
                        }

                        Controls.ToolButton {
                            id: transitionButton
                            Layout.alignment: Qt.AlignHCenter
                            icon.name: root.selectedTransition ? root.selectedTransition.icon : "preferences-desktop-theme-global"
                            display: Controls.AbstractButton.IconOnly
                            icon.width: Kirigami.Units.iconSizes.smallMedium
                            icon.height: Kirigami.Units.iconSizes.smallMedium
                            onClicked: transitionMenu.popup(transitionButton)

                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: root.transitionLabel
                            Controls.ToolTip.delay: 0
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: folderDisplayName && folderDisplayName.length > 0
                                ? folderDisplayName
                                : qsTr("Επιλέξτε φάκελο")
                            color: Kirigami.Theme.textColor
                            font.pixelSize: Kirigami.Units.smallSpacing * 2.3
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Εικόνες: %1").arg(fileModel.count)
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: Kirigami.Units.smallSpacing * 2.1
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
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

                        Loader {
                            id: transitionLoader
                            anchors.fill: parent
                            active: hasImages
                            sourceComponent: root.selectedTransition ? root.selectedTransition.component : fadeComponent
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

    // -- Μενού πληροφοριών φακέλου -------------------------------------------
    Controls.Menu {
        id: detailsMenu
        parent: Controls.Overlay.overlay

        Controls.MenuItem {
            text: folderDisplayName && folderDisplayName.length > 0
                ? qsTr("Φάκελος: %1").arg(folderDisplayName)
                : qsTr("Φάκελος: %1").arg(qsTr("Χωρίς επιλογή"))
            enabled: false
        }

        Controls.MenuItem {
            text: qsTr("Εικόνες: %1").arg(fileModel.count)
            enabled: false
        }
    }

    // -- Μενού επιλογής εφέ μετάβασης ---------------------------------------
    Controls.Menu {
        id: transitionMenu
        parent: Controls.Overlay.overlay

        Repeater {
            model: root.transitionOptions
            delegate: Controls.MenuItem {
                property var option: modelData
                text: option.text
                icon.name: option.icon
                checkable: true
                checked: root.transitionMode === option.key
                onTriggered: {
                    const normalized = root.normalizedTransition(option.key)
                    if (normalized !== root.transitionMode) {
                        root.transitionMode = normalized
                    }
                    if (normalized !== plasmoid.configuration.transitionMode) {
                        plasmoid.configuration.transitionMode = normalized
                    }
                }
            }
        }
    }

    // -- Components για διαφορετικά εφέ μετάβασης ---------------------------
    Component {
        id: fadeComponent

        Image {
            id: fadeImage
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
    }

    Component {
        id: slideComponent

        ListView {
            id: slideView
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            orientation: ListView.Horizontal
            spacing: 0
            interactive: false
            model: root.availableCount
            currentIndex: root.currentIndex
            cacheBuffer: width
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: width
            highlightMoveDuration: 450
            clip: true

            delegate: Item {
                width: slideView.width
                height: slideView.height

                Image {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    source: fileModel.get(index, "fileUrl")
                }
            }

            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    slideView.positionViewAtIndex(currentIndex, ListView.Center)
                }
            }

            onWidthChanged: {
                if (currentIndex >= 0) {
                    slideView.positionViewAtIndex(currentIndex, ListView.Center)
                }
            }

            Component.onCompleted: {
                if (currentIndex >= 0) {
                    slideView.positionViewAtIndex(currentIndex, ListView.Center)
                }
            }
        }
    }

    Component {
        id: zoomComponent

        Image {
            id: zoomImage
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
            opacity: hasImages ? 1.0 : 0.0
            scale: 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.InOutQuad
                }
            }

            NumberAnimation {
                id: zoomAnimator
                target: zoomImage
                property: "scale"
                duration: 450
                easing.type: Easing.InOutQuad
                from: 1.1
                to: 1.0
                onStarted: zoomImage.opacity = 0.0
                onFinished: zoomImage.opacity = 1.0
            }

            function restartAnimation() {
                zoomAnimator.stop()
                zoomImage.scale = 1.1
                zoomAnimator.start()
                zoomImage.opacity = 1.0
            }

            onStatusChanged: {
                if (status === Image.Ready) {
                    restartAnimation()
                } else if (status === Image.Loading) {
                    opacity = 0.0
                }
            }

            onSourceChanged: {
                if (hasImages) {
                    opacity = 0.0
                    zoomAnimator.stop()
                    zoomImage.scale = 1.1
                }
            }
        }
    }

    Component {
        id: panComponent

        Item {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            clip: true

            Image {
                id: panImage
                anchors.centerIn: parent
                width: parent.width * 1.1
                height: parent.height * 1.1
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
                opacity: hasImages ? 1.0 : 0.0
                x: 0
                y: 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.InOutQuad
                    }
                }

                ParallelAnimation {
                    id: panAnimator
                    running: false
                    NumberAnimation {
                        target: panImage
                        property: "x"
                        from: -Kirigami.Units.gridUnit
                        to: Kirigami.Units.gridUnit
                        duration: 450
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: panImage
                        property: "y"
                        from: -Kirigami.Units.gridUnit
                        to: Kirigami.Units.gridUnit
                        duration: 450
                        easing.type: Easing.InOutQuad
                    }
                    onStarted: panImage.opacity = 0.0
                    onFinished: {
                        panImage.opacity = 1.0
                        panImage.x = 0
                        panImage.y = 0
                    }
                }

                function restartAnimation() {
                    panAnimator.stop()
                    panImage.x = -Kirigami.Units.gridUnit
                    panImage.y = -Kirigami.Units.gridUnit
                    panAnimator.start()
                    panImage.opacity = 1.0
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        restartAnimation()
                    } else if (status === Image.Loading) {
                        opacity = 0.0
                    }
                }

                onSourceChanged: {
                    if (hasImages) {
                        opacity = 0.0
                        panAnimator.stop()
                        panImage.x = -Kirigami.Units.gridUnit
                        panImage.y = -Kirigami.Units.gridUnit
                    }
                }
            }
        }
    }

    Component {
        id: rotateComponent

        Item {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            clip: true

            Image {
                id: rotateImage
                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
                opacity: hasImages ? 1.0 : 0.0
                rotation: 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.InOutQuad
                    }
                }

                NumberAnimation {
                    id: rotateAnimator
                    target: rotateImage
                    property: "rotation"
                    duration: 450
                    easing.type: Easing.InOutQuad
                    from: -10
                    to: 0
                    onStarted: rotateImage.opacity = 0.0
                    onFinished: rotateImage.opacity = 1.0
                }

                function restartAnimation() {
                    rotateAnimator.stop()
                    rotateImage.rotation = -10
                    rotateAnimator.start()
                    rotateImage.opacity = 1.0
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        restartAnimation()
                    } else if (status === Image.Loading) {
                        opacity = 0.0
                    }
                }

                onSourceChanged: {
                    if (hasImages) {
                        opacity = 0.0
                        rotateAnimator.stop()
                        rotateImage.rotation = -10
                    }
                }
            }
        }
    }

    Component {
        id: flipComponent

        Item {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            clip: true

            Image {
                id: flipImage
                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
                opacity: hasImages ? 1.0 : 0.0

                transform: Rotation {
                    id: flipRotation
                    origin.x: flipImage.width / 2
                    origin.y: flipImage.height / 2
                    axis.y: 1
                    angle: 0
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.InOutQuad
                    }
                }

                NumberAnimation {
                    id: flipAnimator
                    target: flipRotation
                    property: "angle"
                    duration: 450
                    easing.type: Easing.InOutQuad
                    from: 90
                    to: 0
                    onStarted: flipImage.opacity = 0.0
                    onFinished: flipImage.opacity = 1.0
                }

                function restartAnimation() {
                    flipAnimator.stop()
                    flipRotation.angle = 90
                    flipAnimator.start()
                    flipImage.opacity = 1.0
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        restartAnimation()
                    } else if (status === Image.Loading) {
                        opacity = 0.0
                    }
                }

                onSourceChanged: {
                    if (hasImages) {
                        opacity = 0.0
                        flipAnimator.stop()
                        flipRotation.angle = 90
                    }
                }
            }
        }
    }
}
