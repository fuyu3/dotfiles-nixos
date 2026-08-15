import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    Theme { id: theme }
    property bool widgetOpen: false
    property bool surfaceVisible: false
    property color fundo: theme.fundo
    property color fundo2: theme.fundo2
    property color branco: theme.branco
    property color cinza: theme.cinzaWorkspace
    property color cardColor: theme.glassCard
    property color activeCardColor: theme.glassAccentStrong
    property color chipColor: theme.chipInset
    property color chipHoverColor: theme.glassAccent
    property color dropColor: theme.workspaceDrop
    property var workspaceIds: [1, 2, 3, 4]
    property var workspaceCards: ({})
    property var draggedToplevel: null
    property int draggedFromWorkspaceId: -1
    property int hoveredWorkspaceId: -1
    property real dragX: 0
    property real dragY: 0
    property string draggedTitle: ""
    property string draggedAppId: ""

    readonly property int availableScreenWidth: screen ? screen.width : 1280
    readonly property int availableScreenHeight: screen ? screen.height : 720
    readonly property int panelWidth: Math.max(720, Math.min(1180, availableScreenWidth - 72))
    readonly property int panelHeight: Math.max(240, Math.min(340, availableScreenHeight - 96))

    visible: surfaceVisible
    color: "transparent"
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: surfaceVisible
                                 ? WlrKeyboardFocus.Exclusive
                                 : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible && widgetOpen)
            focusTimer.start()
    }

    Timer {
        id: focusTimer
        property int attempts: 0

        interval: 35
        repeat: true

        onTriggered: {
            if (!root.widgetOpen || !root.visible) {
                stop()
                attempts = 0
                return
            }

            keyTrap.forceActiveFocus()
            attempts += 1

            if (keyTrap.activeFocus || attempts >= 6) {
                stop()
                attempts = 0
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 120
        repeat: false
        onTriggered: {
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
        }
    }

    Process {
        id: moveProcess
        running: false
        command: []
    }

    function toggle() {
        widgetOpen ? close() : open()
    }

    function open() {
        surfaceVisible = true
        widgetOpen = true
        cancelDrag()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        focusTimer.start()
    }

    function close() {
        cancelDrag()
        widgetOpen = false
    }

    function finishClose() {
        surfaceVisible = false
    }

    function registerWorkspaceCard(workspaceId, item) {
        workspaceCards[workspaceId] = item
    }

    function unregisterWorkspaceCard(workspaceId, item) {
        if (workspaceCards[workspaceId] === item)
            delete workspaceCards[workspaceId]
    }

    function workspaceIdAt(x, y) {
        for (var i = 0; i < workspaceIds.length; i++) {
            var workspaceId = workspaceIds[i]
            var card = workspaceCards[workspaceId]
            if (!card)
                continue

            var local = card.mapFromItem(panelFrame, x, y)
            if (local.x >= 0 && local.x <= card.width && local.y >= 0 && local.y <= card.height)
                return workspaceId
        }

        return -1
    }

    function beginDrag(toplevel, workspaceId, item, localX, localY) {
        draggedToplevel = toplevel
        draggedFromWorkspaceId = workspaceId
        draggedAppId = appIdFor(toplevel)
        draggedTitle = titleFor(toplevel)
        updateDragFromItem(item, localX, localY)
    }

    function updateDragFromItem(item, localX, localY) {
        if (!item)
            return

        var point = item.mapToItem(panelFrame, localX, localY)
        dragX = point.x
        dragY = point.y
        hoveredWorkspaceId = workspaceIdAt(point.x, point.y)
    }

    function finishDrag() {
        if (draggedToplevel && hoveredWorkspaceId > 0 && hoveredWorkspaceId !== draggedFromWorkspaceId)
            moveToplevelToWorkspace(draggedToplevel, hoveredWorkspaceId)

        cancelDrag()
    }

    function cancelDrag() {
        draggedToplevel = null
        draggedFromWorkspaceId = -1
        hoveredWorkspaceId = -1
        draggedTitle = ""
        draggedAppId = ""
    }

    function workspaceForId(workspaceId) {
        return Hyprland.workspaces.values.find(function(workspace) {
            return workspace.id === workspaceId
        }) || null
    }

    function activateWorkspace(workspaceId) {
        var workspace = workspaceForId(workspaceId)
        if (workspace) {
            workspace.activate()
            return
        }

        var id = String(workspaceId)
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else
            Hyprland.dispatch("workspace " + id)

        Hyprland.refreshWorkspaces()
    }

    function appIdFor(toplevel) {
        if (!toplevel)
            return ""

        if (toplevel.wayland && toplevel.wayland.appId)
            return toplevel.wayland.appId

        var ipcData = toplevel.lastIpcObject || ({})
        return ipcData["class"] || ipcData["initialClass"] || ""
    }

    function titleFor(toplevel) {
        if (!toplevel)
            return "Janela sem titulo"

        if (toplevel.title && toplevel.title !== "")
            return toplevel.title

        if (toplevel.wayland && toplevel.wayland.title)
            return toplevel.wayland.title

        var appId = appIdFor(toplevel)
        return appId !== "" ? appId : "Janela sem titulo"
    }

    function iconFor(toplevel) {
        var appId = appIdFor(toplevel)
        return Quickshell.iconPath(appId !== "" ? appId : "application-x-executable",
                                   "application-x-executable")
    }

    function windowSelectorFor(toplevel) {
        if (!toplevel || !toplevel.address)
            return ""

        var address = String(toplevel.address)
        if (address.indexOf("0x") !== 0)
            address = "0x" + address

        return "address:" + address
    }

    function toplevelsForWorkspace(workspaceId) {
        var workspace = workspaceForId(workspaceId)
        if (!workspace || !workspace.toplevels || !workspace.toplevels.values)
            return []

        var toplevels = workspace.toplevels.values.filter(function(toplevel) {
            return !!toplevel && (!toplevel.wayland || !toplevel.wayland.parent)
        })

        toplevels.sort(function(a, b) {
            if (a.activated !== b.activated)
                return a.activated ? -1 : 1

            if (a.urgent !== b.urgent)
                return a.urgent ? -1 : 1

            return titleFor(a).localeCompare(titleFor(b))
        })

        return toplevels
    }

    function moveToplevelToWorkspace(toplevel, workspaceId) {
        var selector = windowSelectorFor(toplevel)
        if (selector === "")
            return

        if (toplevel.workspace && toplevel.workspace.id === workspaceId)
            return

        moveProcess.command = ["hyprctl", "dispatch", "movetoworkspacesilent", workspaceId + "," + selector]
        moveProcess.running = true
        refreshTimer.restart()
    }

    function activateToplevel(toplevel, workspaceId) {
        if (toplevel && toplevel.wayland) {
            toplevel.wayland.activate()
            return
        }

        activateWorkspace(workspaceId)
    }

    Item {
        id: keyTrap
        width: 1
        height: 1
        opacity: 0
        focus: root.widgetOpen

        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: root.close()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.close()
    }

    Rectangle {
        id: panelFrame
        width: root.panelWidth
        height: root.panelHeight
        anchors.centerIn: parent
        radius: theme.widgetRadius + 2
        color: root.fundo
        border.color: theme.widgetBorderColor
        border.width: theme.widgetBorderWidth
        transformOrigin: Item.Center

        opacity: root.widgetOpen ? 1 : 0
        scale: root.widgetOpen ? 1 : 0.9

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.fundo }
            GradientStop { position: 1.0; color: root.fundo2 }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic

                onRunningChanged: {
                    if (!running && !root.widgetOpen)
                        root.finishClose()
                }
            }
        }

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: {}
        }

        RowLayout {
            id: workspaceRow
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Repeater {
                model: root.workspaceIds

                delegate: Rectangle {
                    id: workspaceCard
                    required property int modelData

                    readonly property int workspaceId: modelData
                    readonly property var workspace: root.workspaceForId(workspaceId)
                    readonly property var windows: root.toplevelsForWorkspace(workspaceId)
                    readonly property bool active: workspace
                                                   ? workspace.active
                                                   : (Hyprland.focusedWorkspace
                                                      && Hyprland.focusedWorkspace.id === workspaceId)
                    readonly property bool dropHover: root.hoveredWorkspaceId === workspaceId
                                                     && root.draggedFromWorkspaceId !== workspaceId

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: dropHover ? root.dropColor : active ? root.activeCardColor : root.cardColor
                    clip: true

                    Component.onCompleted: root.registerWorkspaceCard(workspaceId, workspaceCard)
                    Component.onDestruction: root.unregisterWorkspaceCard(workspaceId, workspaceCard)

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 12
                            color: "#12000000"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: 11
                                    color: workspaceCard.active ? "#ff8800" : "#1effffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: workspaceCard.workspaceId
                                        color: root.branco
                                        font.family: "Rubik"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: workspaceCard.active ? "Ativo" : "Workspace"
                                    color: workspaceCard.active ? root.branco : root.cinza
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    font.bold: workspaceCard.active
                                }

                                Rectangle {
                                    implicitWidth: countLabel.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: "#1effffff"

                                    Text {
                                        id: countLabel
                                        anchors.centerIn: parent
                                        text: workspaceCard.windows.length
                                        color: root.branco
                                        font.family: "Rubik"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateWorkspace(workspaceCard.workspaceId)
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Flickable {
                                anchors.fill: parent
                                clip: true
                                contentHeight: windowsColumn.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: contentHeight > height && !root.draggedToplevel

                                Column {
                                    id: windowsColumn
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: workspaceCard.windows

                                        delegate: Rectangle {
                                            id: toplevelChip
                                            required property var modelData

                                            readonly property var toplevel: modelData
                                            readonly property int sourceWorkspaceId: workspaceCard.workspaceId
                                            readonly property string appId: root.appIdFor(toplevel)
                                            readonly property string titleText: root.titleFor(toplevel)
                                            readonly property bool draggingThis: root.draggedToplevel
                                                                                && root.draggedToplevel.address === toplevel.address
                                            readonly property bool highlighted: chipArea.containsMouse || toplevel.activated

                                            width: windowsColumn.width
                                            implicitHeight: 54
                                            radius: 14
                                            color: draggingThis ? root.chipHoverColor : highlighted ? root.chipHoverColor : root.chipColor
                                            opacity: draggingThis ? 0.35 : 1

                                            Behavior on color {
                                                ColorAnimation { duration: 120 }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 10

                                                Item {
                                                    Layout.preferredWidth: 24
                                                    Layout.preferredHeight: 24
                                                    Layout.alignment: Qt.AlignTop

                                                    IconImage {
                                                        id: windowIcon
                                                        anchors.fill: parent
                                                        asynchronous: true
                                                        source: root.iconFor(toplevelChip.toplevel)
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: windowIcon.status !== Image.Ready
                                                        text: (toplevelChip.appId || toplevelChip.titleText).charAt(0).toUpperCase()
                                                        color: root.branco
                                                        font.family: "Rubik"
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: toplevelChip.appId !== "" ? toplevelChip.appId : "Aplicativo"
                                                        color: "#a9a9a9"
                                                        font.family: "Rubik"
                                                        font.pixelSize: 10
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: toplevelChip.titleText
                                                        color: root.branco
                                                        font.family: "Rubik"
                                                        font.pixelSize: 12
                                                        font.bold: toplevelChip.toplevel.activated
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 2
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: chipArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                preventStealing: true
                                                cursorShape: Qt.OpenHandCursor

                                                property real pressX: 0
                                                property real pressY: 0
                                                property bool dragStarted: false

                                                onPressed: function(mouse) {
                                                    pressX = mouse.x
                                                    pressY = mouse.y
                                                    dragStarted = false
                                                }

                                                onPositionChanged: function(mouse) {
                                                    if (!(mouse.buttons & Qt.LeftButton))
                                                        return

                                                    var dx = mouse.x - pressX
                                                    var dy = mouse.y - pressY
                                                    if (!dragStarted && (dx * dx + dy * dy) > 64) {
                                                        dragStarted = true
                                                        root.beginDrag(toplevelChip.toplevel,
                                                                       toplevelChip.sourceWorkspaceId,
                                                                       toplevelChip,
                                                                       mouse.x,
                                                                       mouse.y)
                                                    }

                                                    if (dragStarted)
                                                        root.updateDragFromItem(toplevelChip, mouse.x, mouse.y)
                                                }

                                                onReleased: function(mouse) {
                                                    if (dragStarted) {
                                                        root.updateDragFromItem(toplevelChip, mouse.x, mouse.y)
                                                        root.finishDrag()
                                                    } else {
                                                        root.activateToplevel(toplevelChip.toplevel,
                                                                             toplevelChip.sourceWorkspaceId)
                                                    }

                                                    dragStarted = false
                                                }

                                                onCanceled: {
                                                    if (dragStarted)
                                                        root.cancelDrag()

                                                    dragStarted = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: workspaceCard.windows.length === 0
                                radius: 14
                                color: "#0f000000"

                                Text {
                                    anchors.centerIn: parent
                                    text: workspaceCard.dropHover ? "Solte aqui" : "Sem janelas"
                                    color: workspaceCard.dropHover ? "#ffb15a" : "#7d7d7d"
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: dragGhost
            visible: root.draggedToplevel !== null
            z: 200
            width: Math.min(250, panelFrame.width * 0.23)
            height: 56
            x: Math.max(0, Math.min(panelFrame.width - width, root.dragX - width / 2))
            y: Math.max(0, Math.min(panelFrame.height - height, root.dragY - height / 2))
            radius: 14
            color: "#3a111111"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

                    IconImage {
                        id: dragIcon
                        anchors.fill: parent
                        asynchronous: true
                        source: root.iconFor(root.draggedToplevel)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: dragIcon.status !== Image.Ready
                        text: (root.draggedAppId || root.draggedTitle).charAt(0).toUpperCase()
                        color: root.branco
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.draggedAppId !== "" ? root.draggedAppId : "Aplicativo"
                        color: "#b0b0b0"
                        font.family: "Rubik"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.draggedTitle
                        color: root.branco
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
