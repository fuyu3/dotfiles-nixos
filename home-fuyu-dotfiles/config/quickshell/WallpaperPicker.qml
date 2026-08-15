import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Scope {
    id: root

    Theme { id: theme }

    property color fundo: theme.fundo
    property color fundo2: theme.fundo2
    property color branco: theme.branco
    property color destaque: theme.glassAccentStrong
    property color hover: theme.glassHover
    property color pretoSuave: theme.pretoSuave

    property bool pickerOpen: false
    property bool surfaceVisible: false
    property bool loadingWallpapers: false
    property var allWallpapers: []
    property var wallpaperController: null
    property string searchQuery: ""
    property int selectedIndex: -1

    readonly property string homeDir: String(Quickshell.env("HOME") || StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string picturesDir: homeDir + "/Imagens"
    readonly property string activeWallpaperPath: wallpaperController && wallpaperController.wallpaperPath
                                                 ? String(wallpaperController.wallpaperPath)
                                                 : ""
    readonly property string normalizedSearchQuery: searchQuery.trim().toLowerCase()
    readonly property string resultsSummary: loadingWallpapers && allWallpapers.length === 0
                                           ? "Carregando wallpapers..."
                                           : filteredWallpapers.length + " resultado" + (filteredWallpapers.length === 1 ? "" : "s")

    property var filteredWallpapers: {
        var query = normalizedSearchQuery
        if (query === "")
            return allWallpapers

        return allWallpapers.filter(function(wallpaper) {
            return wallpaper.searchText.indexOf(query) !== -1
        })
    }

    function toggle() {
        pickerOpen ? close() : open()
    }

    function open() {
        surfaceVisible = true
        pickerOpen = true
        clearSearch()
        reloadWallpapers()
        searchInput.focus = true
        focusTimer.start()
    }

    function close() {
        pickerOpen = false
    }

    function finishClose() {
        surfaceVisible = false
        selectedIndex = -1
        clearSearch()
    }

    function clearSearch() {
        searchQuery = ""
        searchInput.text = ""
    }

    function focusSearch(selectText) {
        searchInput.forceActiveFocus()
        if (selectText)
            searchInput.selectAll()
    }

    function fileNameForPath(path) {
        return path.substring(path.lastIndexOf("/") + 1)
    }

    function relativePathFor(path) {
        if (path.indexOf(picturesDir + "/") === 0)
            return "~/" + path.substring(homeDir.length + 1)

        return path
    }

    function indexForWallpaperPath(path, wallpapers) {
        if (path === "")
            return -1

        var items = wallpapers || filteredWallpapers
        for (var i = 0; i < items.length; i++) {
            if (items[i].path === path)
                return i
        }

        return -1
    }

    function syncSelection() {
        if (filteredWallpapers.length === 0) {
            selectedIndex = -1
            if (resultsView)
                resultsView.currentIndex = -1
            return
        }

        if (selectedIndex < 0 || selectedIndex >= filteredWallpapers.length) {
            var activeIndex = indexForWallpaperPath(activeWallpaperPath, filteredWallpapers)
            selectedIndex = activeIndex >= 0 ? activeIndex : 0
        }

        if (resultsView) {
            resultsView.currentIndex = selectedIndex
            resultsView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function selectIndex(index) {
        if (index < 0 || index >= filteredWallpapers.length)
            return

        selectedIndex = index
        if (resultsView) {
            resultsView.currentIndex = index
            resultsView.positionViewAtIndex(index, ListView.Contain)
        }
    }

    function moveSelection(step) {
        if (filteredWallpapers.length === 0)
            return

        var nextIndex = selectedIndex < 0 ? 0 : selectedIndex + step
        nextIndex = Math.max(0, Math.min(filteredWallpapers.length - 1, nextIndex))
        selectIndex(nextIndex)
    }

    function applyCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filteredWallpapers.length)
            applyWallpaper(filteredWallpapers[selectedIndex])
    }

    function applyWallpaper(wallpaper) {
        if (!wallpaper || !wallpaper.path)
            return

        if (wallpaperController && wallpaperController.setWallpaper)
            wallpaperController.setWallpaper(wallpaper.path)

        close()
    }

    function handleWallpaperOutput(output) {
        var lines = output.split("\n")
        var wallpapers = []

        for (var i = 0; i < lines.length; i++) {
            var path = lines[i].trim()
            if (path === "")
                continue

            var name = fileNameForPath(path)
            var relativePath = relativePathFor(path)

            wallpapers.push({
                path: path,
                name: name,
                relativePath: relativePath,
                searchText: (name + "\n" + relativePath).toLowerCase()
            })
        }

        wallpapers.sort(function(a, b) {
            return a.name.localeCompare(b.name)
        })

        allWallpapers = wallpapers
        loadingWallpapers = false
        syncSelection()
    }

    function reloadWallpapers() {
        loadingWallpapers = true
        wallpaperScanner.command = [
            "find",
            picturesDir,
            "-type", "f",
            "(",
            "-iname", "*.jpg",
            "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp",
            "-o", "-iname", "*.bmp",
            "-o", "-iname", "*.gif",
            ")"
        ]
        wallpaperScanner.running = true
    }

    onFilteredWallpapersChanged: syncSelection()
    onActiveWallpaperPathChanged: {
        var activeIndex = indexForWallpaperPath(activeWallpaperPath, filteredWallpapers)
        if (activeIndex >= 0)
            selectIndex(activeIndex)
    }

    Process {
        id: wallpaperScanner

        running: false
        command: []
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleWallpaperOutput(text)
        }
        onExited: function() {
            if (running)
                return

            root.loadingWallpapers = false
        }
    }

    Timer {
        id: focusTimer
        property int attempts: 0

        interval: 35
        repeat: true

        onTriggered: {
            if (!root.surfaceVisible || !root.pickerOpen) {
                stop()
                attempts = 0
                return
            }

            root.focusSearch(true)
            attempts += 1

            if (searchInput.activeFocus || attempts >= 6) {
                stop()
                attempts = 0
            }
        }
    }

    PanelWindow {
        id: win
        visible: root.surfaceVisible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: root.surfaceVisible
                                     ? WlrKeyboardFocus.Exclusive
                                     : WlrKeyboardFocus.None

        Item {
            id: keyTrap
            width: 1
            height: 1
            opacity: 0
            focus: root.pickerOpen

            Keys.priority: Keys.BeforeItem
            Keys.onEscapePressed: root.close()
        }

        onVisibleChanged: {
            if (visible && root.pickerOpen)
                focusTimer.start()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.close()
        }

        Rectangle {
            id: pickerCard
            width: Math.min(860, win.width - 40)
            height: Math.min(620, win.height - 72)
            radius: theme.widgetRadius
            color: root.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth
            clip: true
            transformOrigin: Item.Center

            anchors.centerIn: parent

            opacity: root.pickerOpen ? 1 : 0
            scale: root.pickerOpen ? 1 : 0.9

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.fundo }
                GradientStop { position: 1.0; color: root.fundo2 }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic

                    onRunningChanged: {
                        if (!running && !root.pickerOpen)
                            root.finishClose()
                    }
                }
            }

            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.focusSearch(false)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 14
                    color: root.pretoSuave

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: "⌕"
                            color: "#a5a5a5"
                            font.family: "Rubik"
                            font.pixelSize: 17
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text.length === 0
                                text: "Wallpapers em ~/Imagens"
                                color: "#888888"
                                font.family: "Rubik"
                                font.pixelSize: 15
                            }

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                focus: root.pickerOpen
                                activeFocusOnPress: true
                                verticalAlignment: TextInput.AlignVCenter
                                color: root.branco
                                font.family: "Rubik"
                                font.pixelSize: 15
                                selectionColor: "#40ffffff"
                                clip: true

                                onTextChanged: root.searchQuery = text

                                Keys.priority: Keys.BeforeItem
                                Keys.onEscapePressed: root.close()
                                Keys.onReturnPressed: root.applyCurrent()
                                Keys.onEnterPressed: root.applyCurrent()
                                Keys.onDownPressed: root.moveSelection(1)
                                Keys.onUpPressed: root.moveSelection(-1)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.normalizedSearchQuery !== "" || root.loadingWallpapers
                    text: root.resultsSummary
                    color: "#8f8f8f"
                    font.family: "Rubik"
                    font.pixelSize: 11
                    leftPadding: 4
                }

                ListView {
                    id: resultsView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: root.filteredWallpapers
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Keys.priority: Keys.BeforeItem
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.applyCurrent()
                    Keys.onEnterPressed: root.applyCurrent()

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredWallpapers.length === 0
                        text: root.loadingWallpapers
                              ? root.resultsSummary
                              : "Nenhum wallpaper encontrado em ~/Imagens"
                        color: "#7a7a7a"
                        font.family: "Rubik"
                        font.pixelSize: 14
                    }

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        readonly property var wallpaper: modelData
                        property bool hovered: delegateArea.containsMouse
                        property bool selected: root.selectedIndex === index
                        readonly property bool active: root.activeWallpaperPath === wallpaper.path

                        width: resultsView.width
                        height: 72
                        radius: 16
                        color: selected ? root.destaque : hovered ? root.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                radius: 12
                                color: "#16000000"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: wallpaper.path
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: wallpaper.name
                                        color: root.branco
                                        font.family: "Rubik"
                                        font.pixelSize: selected ? 15 : 14
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: active
                                        radius: 999
                                        color: "#1fffffff"
                                        border.color: "#32ffffff"
                                        border.width: 1
                                        implicitWidth: activeLabel.implicitWidth + 14
                                        implicitHeight: activeLabel.implicitHeight + 6

                                        Text {
                                            id: activeLabel
                                            anchors.centerIn: parent
                                            text: "Atual"
                                            color: root.branco
                                            font.family: "Rubik"
                                            font.pixelSize: 10
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: wallpaper.relativePath
                                    color: "#9b9b9b"
                                    font.family: "Rubik"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        MouseArea {
                            id: delegateArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectIndex(index)
                            onClicked: root.applyWallpaper(wallpaper)
                        }
                    }
                }
            }
        }
    }
}
