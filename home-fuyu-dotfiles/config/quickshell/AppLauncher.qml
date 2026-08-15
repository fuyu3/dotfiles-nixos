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

    property bool launcherOpen: false
    property bool surfaceVisible: false
    property var allApps: []
    property var usageCounts: ({})
    property string searchQuery: ""
    property int selectedIndex: -1
    property string normalizedSearchQuery: searchQuery.trim().toLowerCase()
    readonly property bool loadingApps: allApps.length === 0
    readonly property string resultsSummary: loadingApps
                                           ? "Carregando aplicativos..."
                                           : filteredApps.length + " resultado" + (filteredApps.length === 1 ? "" : "s")

    property var filteredApps: {
        var query = normalizedSearchQuery
        if (query === "")
            return allApps

        return allApps.filter(function(app) {
            return app.searchText.indexOf(query) !== -1
        })
    }

    function toggle() {
        launcherOpen ? close() : open()
    }

    function open() {
        if (loadingApps)
            rebuildApps()

        surfaceVisible = true
        launcherOpen = true
        selectedIndex = allApps.length > 0 ? 0 : -1
        clearSearch()
        searchInput.focus = true
        focusTimer.start()
    }

    function close() {
        launcherOpen = false
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
        if (filteredApps.length === 0) {
            selectedIndex = -1
            if (resultsView)
                resultsView.currentIndex = -1
            return
        }

        if (selectedIndex < 0 || selectedIndex >= filteredApps.length)
            selectedIndex = 0

        if (resultsView) {
            resultsView.currentIndex = selectedIndex
            resultsView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function selectIndex(index) {
        if (index < 0 || index >= filteredApps.length)
            return

        selectedIndex = index
        if (resultsView) {
            resultsView.currentIndex = index
            resultsView.positionViewAtIndex(index, ListView.Contain)
        }
    }

    function moveSelection(step) {
        if (filteredApps.length === 0)
            return

        var nextIndex = selectedIndex < 0 ? 0 : selectedIndex + step
        nextIndex = Math.max(0, Math.min(filteredApps.length - 1, nextIndex))
        selectIndex(nextIndex)
    }

    function launchCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length)
            launch(filteredApps[selectedIndex])
    }

    function launch(app) {
        if (!app)
            return

        rememberLaunch(app)

        var entry = app.id ? DesktopEntries.byId(app.id) : null
        if (entry) {
            entry.execute()
            close()
            return
        }

        if (!app.command || app.command.length === 0)
            return

        launcher.command = app.command
        launcher.running = true
        close()
    }

    function usageKey(app) {
        return app && (app.id || app.name) ? (app.id || app.name) : ""
    }

    function usageCount(app) {
        var key = usageKey(app)
        return key !== "" && usageCounts[key] ? usageCounts[key] : 0
    }

    function compareApps(a, b) {
        var usageDiff = usageCount(b) - usageCount(a)
        if (usageDiff !== 0)
            return usageDiff

        return a.name.localeCompare(b.name)
    }

    function rememberLaunch(app) {
        var key = usageKey(app)
        if (key === "")
            return

        var nextUsage = {}
        for (var existingKey in usageCounts)
            nextUsage[existingKey] = usageCounts[existingKey]

        nextUsage[key] = (nextUsage[key] || 0) + 1
        usageCounts = nextUsage
        usageStore.usageData = JSON.stringify(nextUsage)
        rebuildApps()
    }

    function loadUsage() {
        try {
            usageCounts = usageStore.usageData ? JSON.parse(usageStore.usageData) : {}
        } catch (error) {
            usageCounts = {}
            usageStore.usageData = "{}"
        }
    }

    function resolveIcon(iconName) {
        if (!iconName || iconName === "")
            return Quickshell.iconPath("application-x-executable")

        if (iconName.indexOf("/") === 0)
            return iconName

        return Quickshell.iconPath(iconName, "application-x-executable")
    }

    function rebuildApps() {
        var list = []
        var model = DesktopEntries.applications
        var entries = model && model.values ? model.values : []

        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            if (!entry || !entry.name || entry.noDisplay)
                continue

            var name = entry.name || ""
            var genericName = entry.genericName || ""
            var comment = entry.comment || ""
            var command = []
            if (entry.command) {
                for (var j = 0; j < entry.command.length; j++)
                    command.push(entry.command[j])
            }

            list.push({
                id: entry.id || "",
                name: name,
                iconPath: resolveIcon(entry.icon || ""),
                genericName: genericName,
                comment: comment,
                searchText: [name, genericName, comment].join("\n").toLowerCase(),
                command: command
            })
        }

        list.sort(compareApps)
        allApps = list
    }

    onFilteredAppsChanged: syncSelection()

    Component.onCompleted: {
        loadUsage()
        rebuildApps()
    }

    Settings {
        id: usageStore
        category: "appLauncher"
        location: "file://" + Quickshell.stateDir + "/app-launcher.ini"
        property string usageData: "{}"
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.rebuildApps()
        }
    }

    Connections {
        target: DesktopEntries.applications
        ignoreUnknownSignals: true

        function onValuesChanged() {
            root.rebuildApps()
        }

        function onObjectInsertedPost() {
            root.rebuildApps()
        }

        function onObjectRemovedPost() {
            root.rebuildApps()
        }
    }

    Process {
        id: launcher

        running: false
        command: []
    }

    Timer {
        id: focusTimer
        property int attempts: 0

        interval: 35
        repeat: true

        onTriggered: {
            if (!root.surfaceVisible || !root.launcherOpen) {
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
            focus: root.launcherOpen

            Keys.priority: Keys.BeforeItem
            Keys.onEscapePressed: root.close()
        }

        onVisibleChanged: {
            if (visible && root.launcherOpen)
                focusTimer.start()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.close()
        }

        Rectangle {
            id: launcherCard
            width: Math.min(780, win.width - 40)
            height: Math.min(620, win.height - 72)
            radius: theme.widgetRadius
            color: root.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth
            clip: true
            transformOrigin: Item.Center

            anchors.centerIn: parent

            opacity: root.launcherOpen ? 1 : 0
            scale: root.launcherOpen ? 1 : 0.9

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.fundo }
                GradientStop { position: 1.0; color: root.fundo2 }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic

                    onRunningChanged: {
                        if (!running && !root.launcherOpen)
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
                            font.bold: false
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text.length === 0
                                text: "Apps"
                                color: "#888888"
                                font.family: "Rubik"
                                font.pixelSize: 15
                                font.bold: false
                            }

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                focus: root.launcherOpen
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
                                Keys.onReturnPressed: root.launchCurrent()
                                Keys.onEnterPressed: root.launchCurrent()
                                Keys.onDownPressed: root.moveSelection(1)
                                Keys.onUpPressed: root.moveSelection(-1)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.normalizedSearchQuery !== "" || root.loadingApps
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
                    model: root.filteredApps
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Keys.priority: Keys.BeforeItem
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.launchCurrent()
                    Keys.onEnterPressed: root.launchCurrent()

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredApps.length === 0
                        text: root.loadingApps
                              ? root.resultsSummary
                              : "Nenhum aplicativo encontrado"
                        color: "#7a7a7a"
                        font.family: "Rubik"
                        font.pixelSize: 14
                    }

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        readonly property var app: modelData
                        property bool hovered: delegateArea.containsMouse
                        property bool selected: root.selectedIndex === index

                        width: resultsView.width
                        height: 56
                        radius: 16
                        color: selected ? root.destaque : hovered ? root.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Item {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignVCenter

                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    asynchronous: true
                                    source: app.iconPath
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: appIcon.status !== Image.Ready
                                    text: app.name.charAt(0).toUpperCase()
                                    color: root.branco
                                    font.family: "Rubik"
                                    font.pixelSize: 14
                                    font.bold: false
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: app.name
                                color: root.branco
                                font.family: "Rubik"
                                font.pixelSize: selected ? 15 : 14
                                font.bold: false
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
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
                            onClicked: root.launch(app)
                        }
                    }
                }
            }
        }
    }
}
