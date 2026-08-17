import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Wayland
import QtQuick.Layouts
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick.Controls

PanelWindow {
    id: bar

    Theme { id: theme }
    
    property color fundo: theme.fundo
    property color fundo2: theme.fundo2
    property color branco: theme.branco
    property color cinza: theme.cinzaEscuro
    property color popupShadow: theme.popupShadow
    property color popupFill: theme.popupFill
    property color popupMuted: theme.neutralTextMuted
    property date currentDateTime: new Date()
    property bool autoDetectBattery: true
    property bool showBatteryIcon: false

    property bool clockButtonHover: false
    property bool clockPopupHover: false
    property bool clockPopupShown: false
    property bool statsButtonHover: false
    property bool statsDrawerHover: false
    property bool statsDrawerShown: false
    property bool powerDrawerShown: false
    property bool idleInhibited: false
    property int brightnessPercent: 0
    property bool brightnessAvailable: false

    PowerProfileController {
        id: powerProfile
    }

    readonly property string monthTitle: Qt.locale("pt_BR").toString(currentDateTime, "MMMM yyyy")
    readonly property var weekDayLabels: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"]
    readonly property int popupOffsetX: width + 8
    readonly property int popupAnimDuration: 170
    readonly property int popupSlideDistance: 10
    readonly property real bottomSectionWidth: bar.implicitWidth
    
    margins {
        top: 8
        left: 8
        right: 0
        bottom: 8
    }

    anchors {
        top: true
        left: true
        right: false
        bottom: true
    }

    implicitHeight: 30
    implicitWidth: 40
    color: 'transparent'

    // ── Rastreamento de nós de áudio ───────────────────────────
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: bar.currentDateTime = new Date()
    }

    Timer {
        id: clockPopupCloseTimer
        interval: bar.popupAnimDuration + 20
        repeat: false
        onTriggered: {
            bar.clockPopupHover = false
            bar.clockPopupShown = false
            clockPopup.visible = false
        }
    }

    Timer {
        id: powerDrawerCloseTimer
        interval: bar.popupAnimDuration + 20
        repeat: false
        onTriggered: bar.powerDrawerShown = false
    }

    Timer {
        id: statsDrawerCloseTimer
        interval: bar.popupAnimDuration + 20
        repeat: false
        onTriggered: {
            bar.statsDrawerHover = false
            bar.statsDrawerShown = false
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.refreshBrightness()
    }

    // ── Helpers de volume ───────────────────────────────────────
    // Converte volume linear (0-1) para percentual exibido
    function volPct(node) {
        if (!node || !node.audio) return 0
        return Math.round(node.audio.volume * 100)
    }

    // Ícone de speaker de acordo com volume/mute
    function speakerIcon(node) {
        if (!node || !node.audio) return "󰖁"
        if (node.audio.muted || node.audio.volume === 0) return "󰖁"
        if (node.audio.volume < 0.33) return "󰕿"
        if (node.audio.volume < 0.66) return "󰖀"
        return "󰕾"
    }

    // Ícone de microfone
    function micIcon(node) {
        if (!node || !node.audio) return "󰍭"
        return node.audio.muted ? "󰍭" : "󰍬"
    }

    function parseBrightness(text) {
        var parts = String(text).trim().split(",")
        if (parts.length < 4) {
            brightnessAvailable = false
            return
        }

        var pct = parseInt(parts[3].replace("%", ""))
        brightnessAvailable = !isNaN(pct)
        if (brightnessAvailable)
            brightnessPercent = Math.max(0, Math.min(100, pct))
    }

    function refreshBrightness() {
        if (!brightnessReadProc.running)
            brightnessReadProc.running = true
    }

    function changeBrightness(step) {
        if (brightnessChangeProc.running)
            return

        brightnessChangeProc.command = ["brightnessctl", "set", step > 0 ? "5%+" : "5%-"]
        brightnessChangeProc.running = true
    }

    function brightnessIcon() {
        if (!brightnessAvailable || brightnessPercent <= 20) return "󰃞"
        if (brightnessPercent < 70) return "󰃟"
        return "󰃠"
    }

    function idleInhibitIcon() {
        return idleInhibited ? "" : ""
    }

    function toggleIdleInhibit() {
        idleInhibited = !idleInhibited
        idleInhibitProc.running = idleInhibited
    }

    function switchWorkspace(workspaceId) {
        var id = String(workspaceId)
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else
            Hyprland.dispatch("workspace " + id)

        Hyprland.refreshWorkspaces()
    }

    function calendarCellDay(index) {
        var year = currentDateTime.getFullYear()
        var month = currentDateTime.getMonth()
        var firstDay = new Date(year, month, 1)
        var firstWeekday = firstDay.getDay()
        var maxDay = new Date(year, month + 1, 0).getDate()
        var day = index - firstWeekday + 1

        return day >= 1 && day <= maxDay ? day : 0
    }

    function calendarCellIsToday(day) {
        return day > 0
            && day === currentDateTime.getDate()
            && currentDateTime.getMonth() === new Date().getMonth()
            && currentDateTime.getFullYear() === new Date().getFullYear()
    }

    function popupYFor(item, popupHeight) {
        if (!item)
            return 8

        var rect = itemRect(item)
        var target = Math.round(rect.y + (rect.height - popupHeight) / 2)
        var maxY = Math.max(8, height - popupHeight - 8)
        return Math.max(8, Math.min(maxY, target))
    }

    function syncClockPopup() {
        if (clockButtonHover || clockPopupHover) {
            clockPopupCloseTimer.stop()
            if (!clockPopup.visible)
                clockPopup.visible = true
            clockPopupShown = true
        } else if (clockPopup.visible) {
            clockPopupShown = false
            clockPopupCloseTimer.restart()
        }
    }

    function syncStatsDrawer() {
        if (statsButtonHover || statsDrawerHover) {
            statsDrawerCloseTimer.stop()
            statsDrawerShown = true
        } else if (statsDrawerShown) {
            statsDrawerCloseTimer.restart()
        }
    }

    function syncPowerDrawer() {
        if (powerArea.containsMouse || powerProfileButton.hovered || brightnessButton.hovered || idleInhibitButton.hovered) {
            powerDrawerCloseTimer.stop()
            powerDrawerShown = true
        } else if (powerDrawerShown) {
            powerDrawerCloseTimer.restart()
        }
    }

    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "-m"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: bar.parseBrightness(text)
        }
    }

    Process {
        id: brightnessChangeProc
        command: []
        running: false
        onExited: bar.refreshBrightness()
    }

    Process {
        id: idleInhibitProc
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Quickshell idle inhibit", "sleep", "infinity"]
        running: false
        onExited: bar.idleInhibited = false
    }

    // ── Retângulo do topo (workspaces) ──────────────────────────
    Rectangle {
        id: rectangleTop
        implicitWidth: bar.implicitWidth
        implicitHeight: topColumn.implicitHeight + 16
        radius: theme.widgetRadius - 2
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        color: bar.fundo
        border.color: theme.widgetBorderColor
        border.width: theme.widgetBorderWidth

        gradient: Gradient { 
            GradientStop { position: 0.0; color: bar.fundo }
            GradientStop { position: 1.0; color: bar.fundo2 }
        }

    }

    Column {
        id: topColumn
        anchors.top: rectangleTop.top
        anchors.topMargin: 8
        anchors.horizontalCenter: rectangleTop.horizontalCenter
        spacing: 6

        Item {
            id: statsButtonItem
            width: bar.implicitWidth
            height: 20

            Text {
                anchors.centerIn: parent
                text: ""
                color: bar.branco
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 13
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: {
                    bar.statsButtonHover = containsMouse
                    bar.syncStatsDrawer()
                }
            }
        }

        Item {
            id: statsDrawerItem
            width: Math.max(bar.implicitWidth, statsWidgetVertical.implicitWidth + 6)
            height: bar.statsDrawerShown ? statsWidgetVertical.implicitHeight : 0
            clip: true

            Behavior on height {
                NumberAnimation { duration: bar.popupAnimDuration; easing.type: Easing.OutCubic }
            }

            SystemStatsWidget {
                id: statsWidgetVertical
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                vertical: true
                active: bar.visible && bar.statsDrawerShown
                opacity: bar.statsDrawerShown ? 1 : 0
                foregroundColor: bar.branco
                mutedColor: "#a5a5a5"

                Behavior on opacity {
                    NumberAnimation { duration: bar.popupAnimDuration }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: {
                    bar.statsDrawerHover = containsMouse
                    bar.syncStatsDrawer()
                }
            }
        }

        Rectangle {
            width: bar.implicitWidth * 0.55
            height: 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#60ffffff"
        }

        Column {
            id: workspaceColumn
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Repeater {
                model: 5

                Item {
                    id: workspaceButton
                    width: bar.implicitWidth
                    height: 18
                    property bool isActive: Hyprland.focusedWorkspace
                                            ? Hyprland.focusedWorkspace.id === (index + 1)
                                            : false

                    Text {
                        id: workspacesText
                        anchors.centerIn: parent
                        text: ""
                        color: workspaceButton.isActive ? bar.branco : bar.cinza
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 15

                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.switchWorkspace(index + 1)
                    }

                    LinearGradient {
                        anchors.fill: workspacesText
                        source: workspacesText
                        cached: true
                        visible: false
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: '#00ffffff' }
                            GradientStop { position: 1.0; color: '#a5a5a5' }
                        }
                    }
                }
            }
        }
    }

    // ── Retângulo do meio ───────────────────────────────────────
    Rectangle {
        id: rectangleMiddle
        implicitWidth: bar.implicitWidth
        implicitHeight: midColumn.height + 16
        radius: theme.widgetRadius - 2
        anchors.centerIn: parent
        color: bar.fundo
        border.color: theme.widgetBorderColor
        border.width: theme.widgetBorderWidth

        gradient: Gradient { 
            GradientStop { position: 0.0; color: bar.fundo }
            GradientStop { position: 1.0; color: bar.fundo2 }
        }

    }

    Column {
        id: midColumn
        anchors.centerIn: rectangleMiddle
        spacing: 8

        // ── Relógio ─────────────────────────────────────────────
        Item {
            id: clockItem
            width: bar.implicitWidth
            height: 50
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: relogio
                anchors.centerIn: parent
                text: Qt.formatTime(bar.currentDateTime, "HH\nmm")
                color: bar.branco
                font.family: "Rubik"
                font.letterSpacing: 0.5
                font { pixelSize: 20; bold: true }
            }

            LinearGradient {
                anchors.fill: relogio
                source: relogio
                cached: true
                visible: false
                gradient: Gradient {
                    GradientStop { position: 0.0; color: '#ffffff' }
                    GradientStop { position: 1.0; color: '#a5a5a5' }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: {
                    bar.clockButtonHover = containsMouse
                    bar.syncClockPopup()
                }
            }
        }

        Rectangle {
            width: parent.width * 0.7
            height: 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: '#60ffffff'
        }

        // ── Notificações ────────────────────────────────────────
        Item {
            id: notifItem
            width: bar.implicitWidth
            height: 25
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: NotifServer.unreadCount > 0 ? "󰂚" : "󰂜"
                color: NotifServer.unreadCount > 0 ? "#ff8800" : bar.branco
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 15
            }

            Rectangle {
                visible: NotifServer.unreadCount > 0
                width: 14; height: 14
                radius: 7
                color: "#ff4444"
                anchors { top: parent.top; right: parent.right; rightMargin: 2 }

                Text {
                    anchors.centerIn: parent
                    text: NotifServer.unreadCount > 9 ? "9+" : NotifServer.unreadCount
                    color: "#ffffff"
                    font.pixelSize: 8
                    font.bold: true
                    font.family: "Rubik"
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: NotifServer.toggleCenter()
            }
        }
    }

    // ── Retângulo do fundo ──────────────────────────────────────
    Rectangle {
        id: rectangleBottom
        implicitWidth: bar.bottomSectionWidth
        implicitHeight: bottomColumn.implicitHeight + 16
        radius: theme.widgetRadius - 2
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        color: bar.fundo
        border.color: theme.widgetBorderColor
        border.width: theme.widgetBorderWidth

        gradient: Gradient { 
            GradientStop { position: 0.0; color: bar.fundo }
            GradientStop { position: 1.0; color: bar.fundo2 }
        }

    }

    Column {
        id: bottomColumn
        anchors.centerIn: rectangleBottom
        width: bar.bottomSectionWidth
        spacing: 4
    
        Repeater {
            model: SystemTray.items

            Item {
                width: parent.width
                height: 25
                anchors.horizontalCenter: parent.horizontalCenter
                Image {
                    width: 22
                    height: 22
                    anchors.centerIn: parent
                    source: modelData.icon
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: false
                    sourceSize.width: Math.round(width * 2)
                    sourceSize.height: Math.round(height * 2)
                }

                QsMenuOpener {
                    id: trayMenu
                    menu: modelData.menu
                }

                Menu {
                    id: contextMenu
                    clip: false 
                    popupType: Popup.Window
                    property real contentWidthHint: 1
                    width: contentWidthHint
                    Instantiator {
                        model: trayMenu.children
                        delegate: MenuItem {
                            id: menuItem
                            visible: modelData.text !== "" && !modelData.isSeparator
                            implicitWidth: visible ? menuLabel.implicitWidth + 24 : 0
                            implicitHeight: menuLabel.implicitHeight + 10
                            height: visible ? implicitHeight : 0
                            text: modelData.text
                            enabled: modelData.enabled
                            checkable: modelData.checkable === true
                            checked: modelData.checked === true
                            onTriggered: modelData.triggered()
                            contentItem: Text {
                                id: menuLabel
                                anchors.fill: parent
                                text: menuItem.text
                                color: menuItem.enabled ? "#ffffff" : "#666666"
                                font.family: "Rubik"
                                font.pixelSize: 13
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                                rightPadding: 12
                                elide: Text.ElideNone
                            }
                            background: Rectangle {
                                radius: 20
                                color: parent.highlighted ? '#00ffffff' : "transparent"
                            }

                            Component.onCompleted: {
                                if (implicitWidth > contextMenu.contentWidthHint)
                                    contextMenu.contentWidthHint = implicitWidth
                            }

                            onImplicitWidthChanged: {
                                if (implicitWidth > contextMenu.contentWidthHint)
                                    contextMenu.contentWidthHint = implicitWidth
                            }
                        }

                        onObjectAdded: function(index, object) {
                            contextMenu.insertItem(index, object)
                        }

                        onObjectRemoved: function(index, object) {
                            contextMenu.removeItem(object)
                        }
                    }

                    background: Rectangle {
                        implicitWidth: contextMenu.contentWidthHint
                        color: "#cc1e1e1e"
                        radius: 10
                        border.color: "#30ffffff"
                        border.width: 1
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function(event) {
                        if (event.button === Qt.RightButton) {
                            contextMenu.popup()
                        } else {
                            modelData.activate()
                        }
                    }

                    onWheel: function(event) {
                        modelData.scroll(event.angleDelta.x, event.angleDelta.y)
                    }
                }
            }
        }

        // ── Volume do Speaker ───────────────────────────────────
        Item {
            id: speakerItem
            width: parent.width
            height: 40
            anchors.horizontalCenter: parent.horizontalCenter

            property var sink: Pipewire.defaultAudioSink

            Column {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bar.speakerIcon(speakerItem.sink)
                    color: speakerItem.sink && speakerItem.sink.audio && speakerItem.sink.audio.muted
                           ? "#ff4444"
                           : bar.branco
                    font.family: "Rubik"
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (speakerItem.sink && speakerItem.sink.audio)
                                speakerItem.sink.audio.muted = !speakerItem.sink.audio.muted
                        }
                        onWheel: function(event) {
                            if (!speakerItem.sink || !speakerItem.sink.audio)
                                return
                            var delta = event.angleDelta.y > 0 ? 0.05 : -0.05
                            speakerItem.sink.audio.volume = Math.max(0, Math.min(1.5,
                                speakerItem.sink.audio.volume + delta))
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bar.volPct(speakerItem.sink) + "%"
                    color: speakerItem.sink && speakerItem.sink.audio && speakerItem.sink.audio.muted
                           ? "#ff4444"
                           : "#a5a5a5"
                    font.family: "Rubik"
                    font.pixelSize: 9
                    font { pixelSize: 10; bold: true }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }

        // ── Volume do Microfone ─────────────────────────────────
        Item {
            id: microphoneItem
            width: parent.width
            height: 40
            anchors.horizontalCenter: parent.horizontalCenter

            property var source: Pipewire.defaultAudioSource

            Column {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bar.micIcon(microphoneItem.source)
                    color: microphoneItem.source && microphoneItem.source.audio && microphoneItem.source.audio.muted
                           ? "#ff4444"
                           : bar.branco
                    font.family: "Rubik"
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (microphoneItem.source && microphoneItem.source.audio)
                                microphoneItem.source.audio.muted = !microphoneItem.source.audio.muted
                        }
                        onWheel: function(event) {
                            if (!microphoneItem.source || !microphoneItem.source.audio)
                                return
                            var delta = event.angleDelta.y > 0 ? 0.05 : -0.05
                            microphoneItem.source.audio.volume = Math.max(0, Math.min(1.5,
                                microphoneItem.source.audio.volume + delta))
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bar.volPct(microphoneItem.source) + "%"
                    color: microphoneItem.source && microphoneItem.source.audio && microphoneItem.source.audio.muted
                           ? "#ff4444"
                           : "#a5a5a5"
                    font.family: "Rubik"
                    font.pixelSize: 9
                    font { pixelSize: 10; bold: true }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }

        BatteryIndicator {
            id: batteryItem
            anchors.horizontalCenter: parent.horizontalCenter
            vertical: true
            autoDetect: bar.autoDetectBattery
            showWhenManual: bar.showBatteryIcon
            foregroundColor: bar.branco
            mutedColor: "#a5a5a5"
        }

        Rectangle {
            width: parent.width * 0.7
            height: 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: '#60ffffff'
        }

        Item {
            id: powerItem
            width: Math.max(28, bar.powerDrawerShown ? powerDrawerColumn.implicitWidth : 28)
            height: 28 + (bar.powerDrawerShown ? powerDrawerColumn.implicitHeight + 6 : 0)
            anchors.horizontalCenter: parent.horizontalCenter
            z: 2

            Behavior on height {
                NumberAnimation { duration: bar.popupAnimDuration; easing.type: Easing.OutCubic }
            }

            Behavior on width {
                NumberAnimation { duration: bar.popupAnimDuration; easing.type: Easing.OutCubic }
            }

            Process {
                id: lockScreenProc
                command: ["qs", "ipc", "call", "lockScreen", "open"]
                running: false
            }

            Column {
                id: powerDrawerColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 6
                opacity: bar.powerDrawerShown ? 1 : 0
                z: 3

                Behavior on opacity {
                    NumberAnimation { duration: bar.popupAnimDuration }
                }

                PowerProfileButton {
                    id: powerProfileButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: powerDrawerColumn.opacity
                    enabled: opacity > 0.05
                    label: powerProfile.iconFor(powerProfile.profile)
                    textColor: "#ffffff"
                    fontFamily: "JetBrains Mono Nerd Font"
                    fontPixelSize: 14

                    onClicked: powerProfile.cycle(1)
                    onWheelStep: function(step) {
                        powerProfile.cycle(step)
                    }
                    onHoveredChanged: bar.syncPowerDrawer()
                }

                PowerProfileButton {
                    id: idleInhibitButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: powerDrawerColumn.opacity
                    enabled: opacity > 0.05
                    label: bar.idleInhibitIcon()
                    textColor: bar.idleInhibited ? "#8bdc97" : "#ffffff"
                    fontFamily: "JetBrains Mono Nerd Font"
                    fontPixelSize: 14

                    onClicked: bar.toggleIdleInhibit()
                    onHoveredChanged: bar.syncPowerDrawer()
                }

                Item {
                    id: brightnessButton
                    readonly property bool hovered: brightnessArea.containsMouse

                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: Math.max(28, brightnessIconText.implicitWidth, brightnessPercentText.implicitWidth)
                    implicitHeight: brightnessColumn.implicitHeight
                    opacity: powerDrawerColumn.opacity
                    enabled: opacity > 0.05 && bar.brightnessAvailable

                    Column {
                        id: brightnessColumn
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            id: brightnessIconText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: bar.brightnessIcon()
                            color: bar.brightnessAvailable ? bar.branco : "#777777"
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 15
                        }

                        Text {
                            id: brightnessPercentText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: bar.brightnessPercent + "%"
                            color: bar.brightnessAvailable ? "#a5a5a5" : "#777777"
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: brightnessArea
                        anchors.fill: parent
                        enabled: brightnessButton.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.changeBrightness(1)
                        onWheel: function(event) {
                            var step = event.angleDelta.y > 0 ? 1 : -1
                            bar.changeBrightness(step)
                        }
                        onContainsMouseChanged: bar.syncPowerDrawer()
                    }
                }
            }

            Rectangle {
                id: powerBubble
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 28
                height: 28
                radius: 14
                color: "transparent"
                border.color: "transparent"
                border.width: 1
            }

            Text {
                anchors.centerIn: powerBubble
                text: "󰐥"
                color: bar.branco
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 25
            }

            MouseArea {
                id: powerArea
                anchors.fill: powerBubble
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: lockScreenProc.running = true
                onContainsMouseChanged: bar.syncPowerDrawer()
            }
        }
    }

    PopupWindow {
        id: clockPopup
        anchor.window: bar
        color: "transparent"
        visible: false
        anchor.rect.x: bar.popupOffsetX
        anchor.rect.y: bar.popupYFor(clockItem, implicitHeight)
        implicitWidth: 286
        implicitHeight: clockPopupCard.implicitHeight

        Item {
            id: clockPopupCard
            implicitWidth: 286
            implicitHeight: clockPopupLayout.implicitHeight + 24
            width: implicitWidth
            height: implicitHeight
            x: bar.clockPopupShown ? 0 : -bar.popupSlideDistance
            opacity: bar.clockPopupShown ? 1 : 0

            Behavior on x {
                NumberAnimation { duration: bar.popupAnimDuration; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: bar.popupAnimDuration }
            }

            RectangularGlow {
                anchors.fill: clockPopupSurface
                glowRadius: 18
                spread: 0.08
                color: bar.popupShadow
                cornerRadius: clockPopupSurface.radius + 18
                opacity: 0.85
            }

            Rectangle {
                id: clockPopupSurface
                anchors.fill: parent
                radius: theme.widgetRadius
                color: bar.popupFill
                border.color: theme.widgetBorderColor
                border.width: theme.widgetBorderWidth
                gradient: Gradient {
                    GradientStop { position: 0.0; color: bar.fundo }
                    GradientStop { position: 1.0; color: bar.fundo2 }
                }

            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: {
                    bar.clockPopupHover = containsMouse
                    bar.syncClockPopup()
                }
            }

            ColumnLayout {
                id: clockPopupLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatTime(bar.currentDateTime, "HH:mm")
                    color: bar.branco
                    font.family: "Rubik"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: Qt.locale("pt_BR").toString(bar.currentDateTime, "dddd, d 'de' MMMM 'de' yyyy")
                    color: "#cfcfcf"
                    font.family: "Rubik"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#18ffffff"
                }

                Text {
                    Layout.fillWidth: true
                    text: bar.monthTitle
                    color: bar.branco
                    font.family: "Rubik"
                    font.pixelSize: 13
                    font.bold: true
                    font.capitalization: Font.Capitalize
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: bar.weekDayLabels

                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            color: bar.popupMuted
                            font.family: "Rubik"
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: 42

                        Item {
                            required property int index
                            readonly property int day: bar.calendarCellDay(index)
                            readonly property bool today: bar.calendarCellIsToday(day)

                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 26

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: today ? "#20ffffff" : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: day > 0 ? String(day) : ""
                                color: today ? bar.branco : "#c2c2c2"
                                font.family: "Rubik"
                                font.pixelSize: 11
                                font.bold: today
                            }
                        }
                    }
                }
            }
        }
    }

}
