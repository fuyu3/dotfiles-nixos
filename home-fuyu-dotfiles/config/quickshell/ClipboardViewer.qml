import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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

    property bool viewerOpen: false
    property bool surfaceVisible: false
    property bool loadingEntries: false
    property var allEntries: []
    property string searchQuery: ""
    property int selectedIndex: -1

    readonly property string normalizedSearchQuery: searchQuery.trim().toLowerCase()
    readonly property string resultsSummary: loadingEntries && allEntries.length === 0
                                           ? "Carregando historico..."
                                           : filteredEntries.length + " item" + (filteredEntries.length === 1 ? "" : "s")

    property var filteredEntries: {
        var query = normalizedSearchQuery
        if (query === "")
            return allEntries

        return allEntries.filter(function(entry) {
            return entry.searchText.indexOf(query) !== -1
        })
    }

    function toggle() {
        viewerOpen ? close() : open()
    }

    function open() {
        surfaceVisible = true
        viewerOpen = true
        clearSearch()
        reloadEntries()
        searchInput.focus = true
        focusTimer.start()
    }

    function close() {
        viewerOpen = false
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

    function syncSelection() {
        if (filteredEntries.length === 0) {
            selectedIndex = -1
            if (resultsView)
                resultsView.currentIndex = -1
            return
        }

        if (selectedIndex < 0 || selectedIndex >= filteredEntries.length)
            selectedIndex = 0

        if (resultsView) {
            resultsView.currentIndex = selectedIndex
            resultsView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function selectIndex(index) {
        if (index < 0 || index >= filteredEntries.length)
            return

        selectedIndex = index
        if (resultsView) {
            resultsView.currentIndex = index
            resultsView.positionViewAtIndex(index, ListView.Contain)
        }
    }

    function moveSelection(step) {
        if (filteredEntries.length === 0)
            return

        var nextIndex = selectedIndex < 0 ? 0 : selectedIndex + step
        nextIndex = Math.max(0, Math.min(filteredEntries.length - 1, nextIndex))
        selectIndex(nextIndex)
    }

    function restoreCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filteredEntries.length)
            restoreEntry(filteredEntries[selectedIndex])
    }

    function iconTextFor(entry) {
        if (!entry)
            return "⧉"

        return entry.binary ? "◫" : "⧉"
    }

    function titleFor(entry) {
        if (!entry)
            return ""

        return entry.preview
    }

    function subtitleFor(entry) {
        if (!entry)
            return ""

        return entry.binary ? "Conteudo binario" : "#" + entry.id
    }

    function restoreEntry(entry) {
        if (!entry)
            return

        clipboardSetter.command = ["bash", "-lc", "cliphist decode \"$1\" | wl-copy", "_", String(entry.id)]
        clipboardSetter.running = true
        close()
    }

    function handleEntriesOutput(output) {
        var lines = output.split("\n")
        var entries = []

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.trim() === "")
                continue

            var tabIndex = line.indexOf("\t")
            if (tabIndex === -1)
                continue

            var id = line.substring(0, tabIndex)
            var preview = line.substring(tabIndex + 1)
            var binary = preview.indexOf("[[ binary data") === 0

            entries.push({
                id: id,
                preview: preview,
                binary: binary,
                searchText: (id + "\n" + preview).toLowerCase()
            })
        }

        allEntries = entries
        loadingEntries = false
        syncSelection()
    }

    function reloadEntries() {
        loadingEntries = true
        clipboardScanner.command = ["cliphist", "list"]
        clipboardScanner.running = true
    }

    onFilteredEntriesChanged: syncSelection()

    Process {
        id: clipboardScanner

        running: false
        command: []
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleEntriesOutput(text)
        }
        onExited: function() {
            if (running)
                return

            root.loadingEntries = false
        }
    }

    Process {
        id: clipboardSetter

        running: false
        command: []
    }

    Timer {
        id: focusTimer
        property int attempts: 0

        interval: 35
        repeat: true

        onTriggered: {
            if (!root.surfaceVisible || !root.viewerOpen) {
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
            focus: root.viewerOpen

            Keys.priority: Keys.BeforeItem
            Keys.onEscapePressed: root.close()
        }

        onVisibleChanged: {
            if (visible && root.viewerOpen)
                focusTimer.start()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.close()
        }

        Rectangle {
            id: viewerCard
            width: Math.min(820, win.width - 40)
            height: Math.min(620, win.height - 72)
            radius: theme.widgetRadius
            color: root.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth
            clip: true
            transformOrigin: Item.Center

            anchors.centerIn: parent

            opacity: root.viewerOpen ? 1 : 0
            scale: root.viewerOpen ? 1 : 0.9

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.fundo }
                GradientStop { position: 1.0; color: root.fundo2 }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic

                    onRunningChanged: {
                        if (!running && !root.viewerOpen)
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
                                text: "Historico da area de transferencia"
                                color: "#888888"
                                font.family: "Rubik"
                                font.pixelSize: 15
                            }

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                focus: root.viewerOpen
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
                                Keys.onReturnPressed: root.restoreCurrent()
                                Keys.onEnterPressed: root.restoreCurrent()
                                Keys.onDownPressed: root.moveSelection(1)
                                Keys.onUpPressed: root.moveSelection(-1)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.normalizedSearchQuery !== "" || root.loadingEntries
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
                    model: root.filteredEntries
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Keys.priority: Keys.BeforeItem
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.restoreCurrent()
                    Keys.onEnterPressed: root.restoreCurrent()

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredEntries.length === 0
                        text: root.loadingEntries
                              ? root.resultsSummary
                              : "Historico vazio"
                        color: "#7a7a7a"
                        font.family: "Rubik"
                        font.pixelSize: 14
                    }

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        readonly property var entry: modelData
                        property bool hovered: delegateArea.containsMouse
                        property bool selected: root.selectedIndex === index

                        width: resultsView.width
                        height: 68
                        radius: 16
                        color: selected ? root.destaque : hovered ? root.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 12
                                color: "#18000000"

                                Text {
                                    anchors.centerIn: parent
                                    text: root.iconTextFor(entry)
                                    color: root.branco
                                    font.family: "Rubik"
                                    font.pixelSize: 15
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: root.titleFor(entry)
                                    color: root.branco
                                    font.family: "Rubik"
                                    font.pixelSize: selected ? 14 : 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.subtitleFor(entry)
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
                            onClicked: root.restoreEntry(entry)
                        }
                    }
                }
            }
        }
    }
}
