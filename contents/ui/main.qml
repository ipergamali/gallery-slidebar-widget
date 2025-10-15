import QtQuick 6.5
import QtQuick.Controls 6.5 as Controls
// Σημείωση: Στο Qt 6 / Plasma 6 οι τύποι των QtQuick.Controls απαιτούν ρητή
// δήλωση import. Εδώ χρησιμοποιούμε alias "Controls" ώστε να προσπελάζουμε
// τα στοιχεία ως Controls.Menu, Controls.MenuItem κ.ο.κ. Εναλλακτικά, μπορεί
// να γραφτεί `import QtQuick.Controls` χωρίς alias και να χρησιμοποιηθούν οι
// τύποι απευθείας (Menu, MenuItem).
import QtQuick.Layouts 6.5
import Qt.labs.folderlistmodel
import Qt.labs.platform
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // -- Ρυθμίσεις φακέλου -----------------------------------------------------
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
        const text = value.toString()
        if (text.startsWith("file:")) {
            return text
        }
        return Qt.platform.os === "windows"
            ? "file:///" + text.replace(/\\/g, "/")
            : "file://" + text
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
        const localPath = Qt.urlToLocalFile(folderUrl)
        if (localPath && localPath.length > 0) {
            const normalized = localPath.replace(/\\/g, "/").replace(/\/$/, "")
            const parts = normalized.split("/")
            return parts.length > 0 ? parts[parts.length - 1] : normalized
        }
        return folderUrl ? folderUrl.toString() : ""
    }

    // -- Κατάσταση προβολής ---------------------------------------------------
    readonly property int maxImages: 20
    readonly property int availableCount: Math.min(fileModel.count, maxImages)
    readonly property bool hasImages: availableCount > 0
    property int currentIndex: 0
    property bool slideshowActive: false

    // -- Επιλογές animation ----------------------------------------------------
    property var transitions: [
        { key: "fade", text: qsTr("Fade"), icon: "preferences-desktop-theme-global", component: fadeComponent },
        { key: "slide", text: qsTr("Slide"), icon: "view-catalog", component: slideComponent },
        { key: "zoom", text: qsTr("Zoom"), icon: "zoom-in", component: zoomComponent },
        { key: "pan", text: qsTr("Pan"), icon: "transform-move", component: panComponent },
        { key: "flip", text: qsTr("Flip"), icon: "view-refresh", component: flipComponent },
        { key: "rotate", text: qsTr("Rotate"), icon: "object-rotate-right", component: rotateComponent }
    ]

    function normalizeTransition(key) {
        const requested = key ? key.toString() : ""
        for (let i = 0; i < transitions.length; ++i) {
            if (transitions[i].key === requested) {
                return transitions[i].key
            }
        }
        return transitions[0].key
    }

    property string transitionMode: normalizeTransition(plasmoid.configuration.transitionMode)

    function currentTransition() {
        for (let i = 0; i < transitions.length; ++i) {
            if (transitions[i].key === transitionMode) {
                return transitions[i]
            }
        }
        return transitions[0]
    }

    readonly property var transitionInfo: currentTransition()

    preferredRepresentation: fullRepresentation
    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Kirigami.Units.gridUnit * 14

    // -- Βοηθητικές λειτουργίες -----------------------------------------------
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

    property bool kioModuleChecked: false
    property bool kioModuleAvailable: false
    property var kioComponent: null
    readonly property url kioHelperUrl: Qt.resolvedUrl("helpers/KioOpenUrlJob.qml")

    function ensureKioComponent() {
        if (kioModuleChecked) {
            return kioModuleAvailable
        }

        kioModuleChecked = true

        try {
            const component = Qt.createComponent(kioHelperUrl, Component.PreferSynchronous)

            if (component.status === Component.Ready) {
                kioComponent = component
                kioModuleAvailable = true
                return true
            }

            if (component.status === Component.Error) {
                const message = component.errorString ? component.errorString() : ""
                console.warn("Το module org.kde.kio δεν είναι διαθέσιμο ή δεν φορτώθηκε σωστά. Βεβαιωθείτε ότι έχει εγκατασταθεί το πακέτο qml6-module-org-kde-kio.", message)
            } else {
                console.warn("Το module org.kde.kio δεν φορτώθηκε συγχρονισμένα (κατάσταση:", component.status, ")")
            }

            if (component.destroy) {
                component.destroy()
            }

            kioComponent = null
            kioModuleAvailable = false
            return false
        } catch (error) {
            console.warn("Σφάλμα κατά τον έλεγχο του module org.kde.kio:", error)
            kioComponent = null
            kioModuleAvailable = false
            return false
        }
    }

    function startKioJob(url) {
        if (!kioComponent) {
            return false
        }

        const job = kioComponent.createObject(root, {
            url: url
        })

        if (!job) {
            console.warn("Αδυναμία δημιουργίας KIO.OpenUrlJob για", url)
            return false
        }

        job.finished.connect(function() {
            if (job.error) {
                console.warn("Αποτυχία ανοίγματος εικόνας με KIO:", job.errorText)
            }
            job.destroy()
        })

        job.start()
        return true
    }

    function openCurrentImage() {
        if (!hasImages) {
            return
        }

        const current = fileModel.get(currentIndex, "fileUrl")
        if (!current || current.toString().length === 0) {
            return
        }

        let opened = false

        if (ensureKioComponent()) {
            opened = startKioJob(current)
        }

        if (!opened) {
            const fallbackOk = Qt.openUrlExternally(current)
            if (!fallbackOk) {
                console.warn("Αποτυχία ανοίγματος εικόνας με Qt.openUrlExternally για", current)
            }
        }
    }

    function restartSlideshow() {
        slideshowTimer.running = slideshowActive && availableCount > 1
    }

    function chooseTransition(key) {
        const normalized = normalizeTransition(key)
        if (normalized === transitionMode) {
            return
        }
        transitionMode = normalized
        plasmoid.configuration.transitionMode = normalized
    }

    onAvailableCountChanged: {
        if (!hasImages) {
            currentIndex = 0
        } else if (currentIndex >= availableCount) {
            currentIndex = 0
        }
        restartSlideshow()
    }

    onSlideshowActiveChanged: restartSlideshow()

    Connections {
        target: plasmoid.configuration
        function onImagesFolderChanged() {
            root.currentIndex = 0
            restartSlideshow()
        }
        function onTransitionModeChanged() {
            const normalized = root.normalizeTransition(plasmoid.configuration.transitionMode)
            if (normalized !== root.transitionMode) {
                root.transitionMode = normalized
            }
            if (normalized !== plasmoid.configuration.transitionMode) {
                plasmoid.configuration.transitionMode = normalized
            }
        }
    }

    FolderListModel {
        id: fileModel
        folder: root.resolvedFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.webp"]
        showDirs: false
        showDotAndDotDot: false
    }

    Connections {
        target: fileModel
        function onCountChanged() {
            if (root.currentIndex >= root.availableCount) {
                root.currentIndex = root.availableCount > 0 ? root.availableCount - 1 : 0
            }
            root.restartSlideshow()
        }
    }

    Timer {
        id: slideshowTimer
        interval: 5000
        repeat: true
        running: false
        onTriggered: root.nextImage()
    }

    Component.onCompleted: {
        const normalizedTransition = normalizeTransition(plasmoid.configuration.transitionMode)
        if (normalizedTransition !== transitionMode) {
            transitionMode = normalizedTransition
        }
        if (normalizedTransition !== plasmoid.configuration.transitionMode) {
            plasmoid.configuration.transitionMode = normalizedTransition
        }
        restartSlideshow()
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Επιλογή φακέλου εικόνων")
        folder: root.resolvedFolder
        acceptLabel: qsTr("Select folder")
        onAccepted: {
            if (folderDialog.folder && folderDialog.folder.toString().length > 0) {
                plasmoid.configuration.imagesFolder = normalizeFolderUrl(folderDialog.folder)
            }
        }
    }

    // -- Κύριο περιεχόμενο -----------------------------------------------------
    Component {
        id: fullRepresentation

        Kirigami.ShadowedRectangle {
            anchors.fill: parent
            radius: Kirigami.Units.largeSpacing
            color: Qt.rgba(0.08, 0.09, 0.11, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            shadow.size: Kirigami.Units.largeSpacing
            shadow.color: Qt.rgba(0, 0, 0, 0.35)

            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing * 2
                spacing: Kirigami.Units.smallSpacing * 2

                // -- Sidebar με κουμπιά ---------------------------------------
                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
                    Layout.fillHeight: true
                    radius: Kirigami.Units.mediumSpacing
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
                            Controls.ToolTip.text: qsTr("Αλλαγή φακέλου εικόνων")
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
                                root.restartSlideshow()
                            }

                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: root.slideshowActive
                                ? qsTr("Παύση slideshow")
                                : qsTr("Έναρξη slideshow")
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
                            Controls.ToolTip.text: qsTr("Πληροφορίες φακέλου")
                            Controls.ToolTip.delay: 0
                        }

                        Controls.Menu {
                            id: detailsMenu

                            Controls.MenuItem {
                                enabled: false
                                text: folderDisplayName.length > 0
                                    ? qsTr("Φάκελος: %1").arg(folderDisplayName)
                                    : qsTr("Φάκελος: %1").arg(qsTr("Προεπιλογή"))
                            }

                            Controls.MenuItem {
                                enabled: false
                                text: qsTr("Εικόνες: %1").arg(fileModel.count)
                            }
                        }

                        Controls.ToolButton {
                            id: transitionButton
                            Layout.alignment: Qt.AlignHCenter
                            icon.name: transitionInfo ? transitionInfo.icon : "preferences-desktop-theme-global"
                            display: Controls.AbstractButton.IconOnly
                            icon.width: Kirigami.Units.iconSizes.smallMedium
                            icon.height: Kirigami.Units.iconSizes.smallMedium
                            onClicked: transitionMenu.popup(transitionButton)

                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: transitionInfo ? transitionInfo.text : ""
                            Controls.ToolTip.delay: 0
                        }

                        Controls.Menu {
                            id: transitionMenu

                            Repeater {
                                model: root.transitions
                                delegate: Controls.MenuItem {
                                    required property var modelData
                                    text: modelData.text
                                    icon.name: modelData.icon
                                    checkable: true
                                    checked: root.transitionMode === modelData.key
                                    onTriggered: root.chooseTransition(modelData.key)
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        // Η ένδειξη αριθμού εικόνων παραμένει διαθέσιμη μόνο
                        // μέσα από το μενού πληροφοριών φακέλου.
                    }
                }

                // -- Χώρος προβολής εικόνας ----------------------------------
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focus: true

                    Controls.Label {
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.8, Kirigami.Units.gridUnit * 12)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: !hasImages
                        text: qsTr("Δεν βρέθηκαν εικόνες στον φάκελο")
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Loader {
                        id: transitionLoader
                        anchors.fill: parent
                        active: hasImages
                        asynchronous: true
                        sourceComponent: hasImages && root.transitionInfo
                            ? root.transitionInfo.component
                            : fadeComponent
                    }

                    MouseArea {
                        anchors.fill: transitionLoader
                        enabled: hasImages
                        hoverEnabled: hasImages
                        cursorShape: hasImages ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: root.openCurrentImage()
                    }

                    Controls.ToolButton {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        icon.name: "go-previous"
                        display: Controls.AbstractButton.IconOnly
                        enabled: hasImages && availableCount > 1
                        opacity: enabled ? 0.9 : 0.3
                        onClicked: {
                            root.previousImage()
                            root.restartSlideshow()
                        }
                    }

                    Controls.ToolButton {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        icon.name: "go-next"
                        display: Controls.AbstractButton.IconOnly
                        enabled: hasImages && availableCount > 1
                        opacity: enabled ? 0.9 : 0.3
                        onClicked: {
                            root.nextImage()
                            root.restartSlideshow()
                        }
                    }

                    Keys.onLeftPressed: {
                        root.previousImage()
                        root.restartSlideshow()
                    }

                    Keys.onRightPressed: {
                        root.nextImage()
                        root.restartSlideshow()
                    }
                }
            }
        }
    }

    fullRepresentation: fullRepresentation
    compactRepresentation: fullRepresentation

    // -- Components εφέ μετάβασης ---------------------------------------------
    Component {
        id: fadeComponent

        Image {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
            opacity: 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.InOutQuad
                }
            }

            onSourceChanged: {
                opacity = 0.0
            }

            onStatusChanged: {
                if (status === Image.Ready) {
                    opacity = 1.0
                } else if (status === Image.Loading) {
                    opacity = 0.0
                }
            }
        }
    }

    Component {
        id: slideComponent

        Image {
            id: slideImage
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
            opacity: 1.0
            x: 0
            property bool initialized: false

            Behavior on opacity {
                NumberAnimation { duration: 260; easing.type: Easing.InOutQuad }
            }

            Behavior on x {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.InOutQuad
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
            opacity: 0.0
            scale: 1.1

            Behavior on opacity {
                NumberAnimation { duration: 320; easing.type: Easing.InOutQuad }
            }

            PropertyAnimation {
                id: zoomAnimation
                target: zoomImage
                property: "scale"
                duration: 420
                easing.type: Easing.InOutQuad
                from: 1.1
                to: 1.0
            }

            onSourceChanged: {
                zoomAnimation.stop()
                scale = 1.1
                opacity = 0.0
                zoomAnimation.start()
            }

            onStatusChanged: {
                if (status === Image.Ready) {
                    opacity = 1.0
                } else if (status === Image.Loading) {
                    opacity = 0.0
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
                opacity: 0.0
                x: -Kirigami.Units.gridUnit
                y: -Kirigami.Units.gridUnit

                Behavior on opacity {
                    NumberAnimation { duration: 320; easing.type: Easing.InOutQuad }
                }

                ParallelAnimation {
                    id: panAnimation
                    NumberAnimation { target: panImage; property: "x"; duration: 420; easing.type: Easing.InOutQuad; to: 0 }
                    NumberAnimation { target: panImage; property: "y"; duration: 420; easing.type: Easing.InOutQuad; to: 0 }
                }

                onSourceChanged: {
                    panAnimation.stop()
                    x = -Kirigami.Units.gridUnit
                    y = -Kirigami.Units.gridUnit
                    opacity = 0.0
                    panAnimation.start()
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        opacity = 1.0
                    } else if (status === Image.Loading) {
                        opacity = 0.0
                    }
                }
            }
        }
    }

    Component {
        id: rotateComponent

        Image {
            id: rotateImage
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: hasImages ? fileModel.get(root.currentIndex, "fileUrl") : ""
            opacity: 0.0
            rotation: -12

            Behavior on opacity {
                NumberAnimation { duration: 320; easing.type: Easing.InOutQuad }
            }

            PropertyAnimation {
                id: rotateAnimation
                target: rotateImage
                property: "rotation"
                duration: 420
                easing.type: Easing.InOutQuad
                from: -12
                to: 0
            }

            onSourceChanged: {
                rotateAnimation.stop()
                rotation = -12
                opacity = 0.0
                rotateAnimation.start()
            }

            onStatusChanged: {
                if (status === Image.Ready) {
                    opacity = 1.0
                } else if (status === Image.Loading) {
                    opacity = 0.0
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
                opacity: 0.0

                transform: Rotation {
                    id: flipRotation
                    origin.x: flipImage.width / 2
                    origin.y: flipImage.height / 2
                    axis.y: 1
                    angle: 90
                }

                Behavior on opacity {
                    NumberAnimation { duration: 320; easing.type: Easing.InOutQuad }
                }

                PropertyAnimation {
                    id: flipAnimation
                    target: flipRotation
                    property: "angle"
                    duration: 420
                    easing.type: Easing.InOutQuad
                    from: 90
                    to: 0
                }

                onSourceChanged: {
                    flipAnimation.stop()
                    flipRotation.angle = 90
                    opacity = 0.0
                    flipAnimation.start()
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        opacity = 1.0
                    } else if (status === Image.Loading) {
                        opacity = 0.0
                    }
                }
            }
        }
    }
}
