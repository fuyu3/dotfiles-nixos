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
import Caelestia.Blobs
import Quickshell.Services.Notifications
import Quickshell.Widgets

// Barra principal com moldura e popouts de calendário + notificações.
// Hover: cada ícone abre seu próprio popup; a MouseArea dentro de cada
// BlobRect mantém o popup aberto enquanto o mouse está em cima. A mask da
// janela aponta para os próprios BlobRects (altura 0 quando fechados), então
// nenhum espaço é reservado no desktop.
ShellRoot {
    id: root
    
    readonly property int notifPopoutHeight: 400
    readonly property int notifPopoutWidth: 600
    readonly property int barHeight: 40
    readonly property int edgeThickness: 4
    readonly property int popoutWidth: 286
    readonly property int popoutHeight: 280
    readonly property int launcherWidth: Math.min(780, bar.width - 40)
    readonly property int launcherHeight: 620

    property bool showBatteryIcon: true
    property bool autoDetectBattery: true

    PanelWindow {
        id: bar

        Theme { id: theme }

        // Estados de hover e popout.
        property bool clockPopupHover: false
        property bool clockPopupShown: false
        property bool statsButtonHover: false
        property bool statsDrawerHover: false
        property bool statsDrawerShown: false
        property bool powerDrawerShown: false
        property bool idleInhibited: false
        property int brightnessPercent: 0
        property bool brightnessAvailable: false
        property bool notifPopupHover: false
        property bool notifPopupShown: false

        property date currentDateTime: new Date()
        readonly property string monthTitle: Qt.locale("pt_BR").toString(currentDateTime, "MMMM yyyy")
        readonly property string longDate: Qt.locale("pt_BR").toString(currentDateTime, "dddd, d 'de' MMMM")
        readonly property var weekDayLabels: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"]
        readonly property int popupAnimDuration: 170
        readonly property int powerButtonWidth: 20

        focusable: AppLauncher.open || ClipboardService.open || WallpaperPickerService.open
WlrLayershell.keyboardFocus: (AppLauncher.open
                              || ClipboardService.open
                              || WallpaperPickerService.open)
    ? WlrKeyboardFocus.Exclusive
    : WlrKeyboardFocus.None

        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        IdleInhibitor {
            id: idleInhibitor
            window: bar
            enabled: bar.idleInhibited
        }

        PowerProfileController {
            id: powerProfile
        }

        PwObjectTracker {
            objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
        }

        // Atualiza o relógio a cada segundo.
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: bar.currentDateTime = new Date()
        }

        // Fechamento do calendário após perder o hover.
        Timer {
            id: clockPopupCloseTimer
            interval: bar.popupAnimDuration + 20
            repeat: false
            onTriggered: {
                bar.clockPopupHover = false
                bar.clockPopupShown = false
                clockPopupLayout.opacity = 0  
            }
        }

        Timer {
            id: clockPopupContentTimer
            interval: 250
            repeat: false
            onTriggered: clockPopupLayout.opacity = 1
        }

        Timer {
            id: notifPopupCloseTimer
            interval: bar.popupAnimDuration + 20
            repeat: false
            onTriggered: {
                bar.notifPopupHover = false
                bar.notifPopupShown = false
                notifPopupLayout.opacity = 0
            }
        }

        Timer {
            id: notifPopupContentTimer
            interval: 250
            repeat: false
            onTriggered: notifPopupLayout.opacity = 1
        }

        Timer {
            id: launcherContentTimer
            interval: 250
            repeat: false
            onTriggered: launcherLayout.opacity = 1
        }

        Timer {
            id: powerDrawerCloseTimer
            interval: bar.popupAnimDuration + 20
            repeat: false
            onTriggered: bar.powerDrawerShown = false
        }

        Timer {
            id: launcherFocusTimer
            interval: 30
            repeat: true
            property int attempts: 0

            onTriggered: {
                if (!AppLauncher.open) { stop(); attempts = 0; return }
                launcherSearchInput.forceActiveFocus()
                attempts += 1
                if (launcherSearchInput.activeFocus || attempts > 10) {
                    stop()
                    attempts = 0
                }
            }
        }

        Timer {
    id: wallpaperPickerContentTimer
    interval: 250
    repeat: false
    onTriggered: wallpaperPickerLayout.opacity = 1
}

Timer {
    id: wallpaperPickerFocusTimer
    interval: 30
    repeat: true
    property int attempts: 0

    onTriggered: {
        if (!WallpaperPickerService.open) { stop(); attempts = 0; return }
        wallpaperSearchInput.forceActiveFocus()
        attempts += 1
        if (wallpaperSearchInput.activeFocus || attempts > 10) {
            stop()
            attempts = 0
        }
    }
}

        Item {
            id: launcherKeyTrap
            width: 0; height: 0
            focus: AppLauncher.open
            Keys.priority: Keys.BeforeItem
            Keys.onEscapePressed: AppLauncher.close()
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

        Timer {
    id: clipboardContentTimer
    interval: 250
    repeat: false
    onTriggered: clipboardLayout.opacity = 1
}

Timer {
    id: clipboardFocusTimer
    interval: 30
    repeat: true
    property int attempts: 0

    onTriggered: {
        if (!ClipboardService.open) { stop(); attempts = 0; return }
        clipboardSearchInput.forceActiveFocus()
        attempts += 1
        if (clipboardSearchInput.activeFocus || attempts > 10) {
            stop()
            attempts = 0
        }
    }
}

        // Helpers de áudio e ícones.
        function volPct(node) {
            if (!node || !node.audio) return 0
            return Math.round(node.audio.volume * 100)
        }

        function speakerIcon(node) {
            if (!node || !node.audio) return "󰖁"
            if (node.audio.muted || node.audio.volume === 0) return "󰖁"
            if (node.audio.volume < 0.33) return "󰕿"
            if (node.audio.volume < 0.66) return "󰖀"
            return "󰕾"
        }

        function micIcon(node) {
            if (!node || !node.audio) return "󰍭"
            return node.audio.muted ? "󰍭" : "󰍬"
        }

        // Leitura e controles de brilho.
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

        // Estado de idle inhibitor e perfil de energia.
        function idleInhibitIcon() {
            return idleInhibited ? "" : ""
        }

        function toggleIdleInhibit() {
            idleInhibited = !idleInhibited
        }

        function switchWorkspace(workspaceId) {
            var id = String(workspaceId)
            if (Hyprland.usingLua)
                Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
            else
                Hyprland.dispatch("workspace " + id)

            Hyprland.refreshWorkspaces()
        }

        // Calendário mensal e cálculo de dias.
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

        // Fecha um popup instantaneamente (usado ao trocar de ícone).
        function forceCloseClockPopup() {
            clockPopupCloseTimer.stop()
            clockPopupContentTimer.stop()
            clockPopupHover = false
            clockPopupShown = false
            clockPopupLayout.opacity = 0
        }

        function forceCloseNotifPopup() {
            notifPopupCloseTimer.stop()
            notifPopupContentTimer.stop()
            notifPopupHover = false
            notifPopupShown = false
            notifPopupLayout.opacity = 0
        }

        // Estado de sincronização dos popups da barra.
        function syncClockPopup() {
            if (clockPopupHover) {
                clockPopupCloseTimer.stop()
                clockPopupShown = true
                clockPopupContentTimer.restart()
            } else if (clockPopupShown) {
                clockPopupContentTimer.stop()
                clockPopupCloseTimer.restart()
            }
        }

        function syncNotifPopup() {
            if (notifPopupHover) {
                notifPopupCloseTimer.stop()
                notifPopupShown = true
                notifPopupContentTimer.restart()
            } else if (notifPopupShown) {
                notifPopupContentTimer.stop()
                notifPopupCloseTimer.restart()
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

        // Primeiro cluster: espaços de trabalho e estatísticas.
        Rectangle {
            id: leftCluster
            z: 2
            anchors {
                left: parent.left
                leftMargin: 8
            }
            width: workspaceRow.implicitWidth + 22
            height: 30
            radius: theme.widgetRadius
            color: theme.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth
            y: (root.barHeight - height) / 2

            gradient: Gradient {
                GradientStop { position: 0.0; color: theme.fundo }
                GradientStop { position: 1.0; color: theme.fundo2 }
            }

            Row {
                id: workspaceRow
                anchors.centerIn: parent
                spacing: 6
                height: 24

                Item {
                    id: statsButtonItem
                    width: 20
                    height: workspaceRow.height

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: theme.branco
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
                    width: bar.statsDrawerShown ? statsWidgetHorizontal.implicitWidth + 2 : 0
                    height: workspaceRow.height
                    clip: true

                    Behavior on width {
                        NumberAnimation { duration: bar.popupAnimDuration; easing.type: Easing.OutCubic }
                    }

                    SystemStatsWidget {
                        id: statsWidgetHorizontal
                        anchors.left: parent.left
                        y: Math.round((statsDrawerItem.height - height) / 2)
                        vertical: false
                        active: bar.visible && bar.statsDrawerShown
                        opacity: bar.statsDrawerShown ? 1 : 0
                        foregroundColor: theme.branco
                        mutedColor: "#bcbcbc"

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
                    width: 2
                    height: 18
                    color: theme.separator
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: 5

                    Item {
                        id: workspaceButton
                        width: workspaceText.implicitWidth
                        height: workspaceRow.height
                        property bool isActive: Hyprland.focusedWorkspace
                            ? Hyprland.focusedWorkspace.id === (index + 1)
                            : false

                        Text {
                            id: workspaceText
                            anchors.centerIn: parent
                            text: ""
                            color: workspaceButton.isActive ? theme.branco : theme.desativado
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
                    }
                }
            }
        }

        // Segundo cluster: relógio e notificações centrais.
        Rectangle {
            id: centerCluster
            z: 2
            anchors {
                horizontalCenter: parent.horizontalCenter
            }
            width: centerRow.implicitWidth + 24
            height: 30
            radius: theme.widgetRadius
            color: theme.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth
            y: (root.barHeight - height) / 2

            gradient: Gradient {
                GradientStop { position: 0.0; color: theme.fundo }
                GradientStop { position: 1.0; color: theme.fundo2 }
            }

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 12

                Item {
                    id: clockBlock
                    width: clockText.implicitWidth
                    height: clockText.implicitHeight

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: Qt.formatTime(bar.currentDateTime, "HH:mm")
                        color: theme.branco
                        font.family: "Rubik"
                        font.pixelSize: 20
                        font.bold: true
                        font.letterSpacing: 0.4
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            // Fecha o rival na hora e abre o calendário.
                            bar.forceCloseNotifPopup()
                            bar.clockPopupHover = true
                            bar.syncClockPopup()
                        }
                        onExited: {
                            bar.clockPopupHover = false
                            bar.syncClockPopup()
                        }
                    }
                }

                Rectangle {
                    width: 2
                    height: 18
                    color: theme.separator
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: centerNotifItem
                    width: 24
                    height: 24

                    Text {
                        anchors.centerIn: parent
                        text: NotifServer.unreadCount > 0 ? "󰂚" : "󰂜"
                        color: NotifServer.unreadCount > 0 ? "#ffb25a" : theme.branco
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 15
                    }

                    Rectangle {
                        visible: NotifServer.unreadCount > 0
                        width: 14
                        height: 14
                        radius: 7
                        color: "#ff5252"
                        anchors {
                            top: parent.top
                            right: parent.right
                        }

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
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            // Fecha o rival na hora e abre o notif center.
                            bar.forceCloseClockPopup()
                            bar.notifPopupHover = true
                            bar.syncNotifPopup()
                        }
                        onExited: {
                            bar.notifPopupHover = false
                            bar.syncNotifPopup()
                        }
                    }
                }
            }
        }

        // Terceiro cluster: tray, volume, bateria e power menu.
        Rectangle {
            id: rightCluster
            z: 2
            anchors {
                right: parent.right
                rightMargin: 8
            }
            width: rightRow.implicitWidth + 22
            height: 30
            radius: theme.widgetRadius
            color: theme.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth
            y: (root.barHeight - height) / 2

            gradient: Gradient {
                GradientStop { position: 0.0; color: theme.fundo }
                GradientStop { position: 1.0; color: theme.fundo2 }
            }

            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: 10
                height: 24

                Row {
                    id: trayRow
                    y: Math.round((rightRow.height - height) / 2)
                    spacing: 2

                    Repeater {
                        model: SystemTray.items

                        Item {
                            width: 24
                            height: 24

                            Image {
                                width: 20
                                height: 20
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
                                            radius: 16
                                            color: parent.highlighted ? "#10ffffff" : "transparent"
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
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor

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
                }

                Item {
                    id: speakerItem
                    width: speakerRow.implicitWidth
                    height: 22
                    y: Math.round((rightRow.height - height) / 2)
                    property var sink: Pipewire.defaultAudioSink

                    Row {
                        id: speakerRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: bar.speakerIcon(speakerItem.sink)
                            color: speakerItem.sink && speakerItem.sink.audio && speakerItem.sink.audio.muted
                                ? "#ff7777"
                                : theme.branco
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        Text {
                            text: bar.volPct(speakerItem.sink) + "%"
                            color: "#bcbcbc"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

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

                Item {
                    id: microphoneItem
                    width: microphoneRow.implicitWidth
                    height: 22
                    y: Math.round((rightRow.height - height) / 2)
                    property var source: Pipewire.defaultAudioSource

                    Row {
                        id: microphoneRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: bar.micIcon(microphoneItem.source)
                            color: microphoneItem.source && microphoneItem.source.audio && microphoneItem.source.audio.muted
                                ? "#ff7777"
                                : theme.branco
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        Text {
                            text: bar.volPct(microphoneItem.source) + "%"
                            color: "#bcbcbc"
                            font.family: "Rubik"
                            font.pixelSize: 11
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

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

                BatteryIndicator {
                    id: batteryItem
                    vertical: false
                    y: Math.round((rightRow.height - height) / 2)
                    autoDetect: root.autoDetectBattery
                    showWhenManual: root.showBatteryIcon
                    foregroundColor: theme.branco
                    mutedColor: "#bcbcbc"
                }

                Rectangle {
                    width: 2
                    height: 18
                    y: Math.round((rightRow.height - height) / 2)
                    color: theme.separator
                }

                Item {
                    id: powerItem
                    width: bar.powerButtonWidth + (bar.powerDrawerShown ? powerDrawerRow.implicitWidth + 6 : 0)
                    height: 28
                    y: Math.round((rightRow.height - height) / 2)

                    Behavior on width {
                        NumberAnimation { duration: bar.popupAnimDuration; easing.type: Easing.OutCubic }
                    }

                    Process {
                        id: lockScreenProc
                        command: ["qs", "ipc", "call", "lockScreen", "open"]
                        running: false
                    }

                    Row {
                        id: powerDrawerRow
                        x: bar.powerDrawerShown ? 0 : parent.width - powerBubble.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        opacity: bar.powerDrawerShown ? 1 : 0
                        z: 3

                        Behavior on x {
                            NumberAnimation { duration: bar.popupAnimDuration; easing.type: Easing.OutCubic }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: bar.popupAnimDuration }
                        }

                        PowerProfileButton {
                            id: powerProfileButton
                            opacity: powerDrawerRow.opacity
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
                            opacity: powerDrawerRow.opacity
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

                            opacity: powerDrawerRow.opacity
                            enabled: opacity > 0.05 && bar.brightnessAvailable
                            width: brightnessRow.implicitWidth
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                id: brightnessRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: bar.brightnessIcon()
                                    color: bar.brightnessAvailable ? theme.branco : theme.desativado
                                    font.family: "JetBrains Mono Nerd Font"
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: bar.brightnessPercent + "%"
                                    color: bar.brightnessAvailable ? "#bcbcbc" : theme.desativado
                                    font.family: "Rubik"
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
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
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: bar.powerButtonWidth
                        height: 28
                        radius: 14
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: powerBubble
                        text: "󰐥"
                        color: theme.branco
                        font.family: "JetBrains Mono Nerd Font"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: powerBubble
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lockScreenProc.running = true
                        onContainsMouseChanged: bar.syncPowerDrawer()
                    }
                }
            }
        }

        // Máscara da janela: só clusters + os BlobRects dos popups. Como
        // popout/notifPopout têm height 0 quando fechados, a Region
        // correspondente fica vazia e nada é reservado no desktop.
        mask: Region {
    Region { item: leftCluster }
    Region { item: centerCluster }
    Region { item: rightCluster }
    Region { item: popout }
    Region { item: notifPopout }
    Region { item: launcherPopout }
    Region { item: clipboardPopout }  
    Region { item: wallpaperPickerPopout } 
    Region { item: clickOutsideCatcher }
    Region { item: toastBlob }
}

        BlobGroup {
            id: group
            color: theme.fundo3
            smoothing: 16
        }

        // =====================================================================
        // Popup do centro de notificações
        // =====================================================================
        BlobRect {
            id: notifPopout
            z: 1
            group: group

            x: (bar.width - root.notifPopoutWidth) / 2
            y: root.barHeight
            width: root.notifPopoutWidth
            height: bar.notifPopupShown ? root.notifPopoutHeight : 0

            topLeftRadius: 4
            topRightRadius: 4
            bottomLeftRadius: 18
            bottomRightRadius: 18

            Behavior on height {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            // MouseArea por baixo do conteúdo: mantém o popup aberto
            // enquanto o mouse estiver dentro da área do BlobRect.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    bar.notifPopupHover = true
                    bar.syncNotifPopup()
                }
                onExited: {
                    bar.notifPopupHover = false
                    bar.syncNotifPopup()
                }
            }

            ColumnLayout {
                id: notifPopupLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                opacity: 0

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Notificações"
                        color: theme.branco
                        font.family: "Rubik"
                        font.pixelSize: 15
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        // reserva espaço sempre → header não muda de tamanho
                        opacity: NotifServer.notifications.length > 0 ? 1 : 0
                        enabled: NotifServer.notifications.length > 0
                        radius: 10
                        color: '#25ffffff'
                        implicitWidth: clearLabel.implicitWidth + 16
                        implicitHeight: 26

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Limpar tudo"
                            color: theme.branco
                            font.bold: true
                            font.family: "Rubik"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifServer.clearAll()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.separator
                }

                Flickable {
                    id: notifFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: Math.max(notifCol.implicitHeight, height)
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Text {
                        anchors.centerIn: parent
                        visible: NotifServer.notifications.length === 0
                        text: "Nenhuma notificação"
                        color: theme.branco
                        font.family: "Rubik"
                        font.pixelSize: 12
                    }

                    Column {
                        id: notifCol
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: {
                                let arr = [...NotifServer.notifications]
                                return arr.reverse()
                            }

                            delegate: Rectangle {
                                id: notifCard
                                required property Notification modelData
                                property Notification notif: modelData

                                // ── Estado de swipe ─────────────────────────────────────────
                                property real swipeOffset: 0
                                property real swipeStartX: 0
                                property real swipeStartY: 0
                                property real swipeLastY: 0
                                property bool swipeDragging: false
                                property int dragMode: 0 // 0 = indefinido, 1 = swipe, 2 = scroll
                                property int swipeDirection: 1
                                readonly property real swipeDismissThreshold: Math.max(120, width * 0.35)

                                width: notifCol.width
                                implicitHeight: notifCardLayout.implicitHeight + 8
                                radius: 12
                                color: theme.fundo2
                                opacity: 1 - Math.min(0.6, Math.abs(swipeOffset) / Math.max(1, width) * 0.65)
                                transform: Translate { x: notifCard.swipeOffset }

    function finishSwipe() {
        if (!swipeDragging) {
            swipeOffset = 0
            return
        }

        swipeDragging = false

        if (Math.abs(swipeOffset) >= swipeDismissThreshold) {
            swipeDirection = swipeOffset < 0 ? -1 : 1
            dismissSwipeAnim.restart()
        } else {
            resetSwipeAnim.restart()
        }
    }

    NumberAnimation {
        id: resetSwipeAnim
        target: notifCard
        property: "swipeOffset"
        to: 0
        duration: 170
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: dismissSwipeAnim
        target: notifCard
        property: "swipeOffset"
        to: notifCard.swipeDirection * (notifCard.width + 48)
        duration: 140
        easing.type: Easing.InCubic
        onFinished: NotifServer.dismiss(notifCard.notif)
    }

    MouseArea {
        id: cardDragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        preventStealing: true

        onPressed: function(mouse) {
            let pointer = cardDragArea.mapToItem(notifFlickable, mouse.x, mouse.y)

            notifCard.swipeStartX = mouse.x
            notifCard.swipeStartY = pointer.y
            notifCard.swipeLastY = pointer.y
            notifCard.swipeDragging = false
            notifCard.dragMode = 0
            resetSwipeAnim.stop()
            dismissSwipeAnim.stop()
        }

        onPositionChanged: function(mouse) {
            let pointer = cardDragArea.mapToItem(notifFlickable, mouse.x, mouse.y)
            let deltaX = mouse.x - notifCard.swipeStartX
            let deltaY = pointer.y - notifCard.swipeStartY

            if (notifCard.dragMode === 0) {
                if (Math.abs(deltaX) > 6 && Math.abs(deltaX) > Math.abs(deltaY) * 0.65) {
                    notifCard.dragMode = 1
                } else if (Math.abs(deltaY) > 6 && Math.abs(deltaY) > Math.abs(deltaX)) {
                    notifCard.dragMode = 2
                }
            }

            if (notifCard.dragMode === 1) {
                notifCard.swipeDragging = true
                notifCard.swipeOffset = Math.max(-notifCard.width - 64,
                                                 Math.min(notifCard.width + 64, deltaX))
            } else if (notifCard.dragMode === 2) {
                let maxContentY = Math.max(0, notifFlickable.contentHeight - notifFlickable.height)
                notifFlickable.contentY = Math.max(0, Math.min(maxContentY,
                    notifFlickable.contentY - (pointer.y - notifCard.swipeLastY)))
            }

            notifCard.swipeLastY = pointer.y
        }

        onReleased: notifCard.finishSwipe()
        onCanceled: notifCard.finishSwipe()
    }

Rectangle {
    width: 4
    height: parent.height - 16
    radius: 2
    anchors {
        left: parent.left
        leftMargin: 6
        verticalCenter: parent.verticalCenter
    }
    color: {
        switch (modelData.urgency) {
            case NotificationUrgency.Critical: return "#ff9999"
            case NotificationUrgency.Normal:   return "#ffffff"
            default:                           return "#9dffbf"
        }
    }
}

    // ── Conteúdo do card (com ícone/mídia igual ao toast) ───────
readonly property string mediaSource: NotifServer.notificationMediaSource(modelData)
readonly property bool hasMedia: mediaSource !== ""

RowLayout {
    id: notifCardLayout
    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        leftMargin: 16
        rightMargin: 12
        topMargin: 8
        bottomMargin: 8
    }
    spacing: 10

    Image {
        visible: notifCard.hasMedia
        source: notifCard.mediaSource
        Layout.preferredWidth: notifCard.hasMedia ? 32 : 0
        Layout.preferredHeight: notifCard.hasMedia ? 32 : 0
        Layout.maximumWidth: notifCard.hasMedia ? 32 : 0
        Layout.maximumHeight: notifCard.hasMedia ? 32 : 0
        Layout.alignment: Qt.AlignTop
        smooth: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit

        // ícone arredondado, opcional
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: 32; height: 32; radius: 8
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            text: modelData.appName
            color: theme.branco2
            font.family: "Rubik"
            font.pixelSize: 9
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            text: modelData.summary
            color: theme.branco
            font.family: "Rubik"
            font.pixelSize: 12
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
            visible: text !== ""
        }

        Text {
            text: modelData.body
            color: theme.branco2
            font.family: "Rubik"
            font.pixelSize: 11
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: text !== ""
        }
    }
}
}
                        }
                    }
                }
            }
        }

        // =====================================================================
        // Fundo da barra
        // =====================================================================
        BlobInvertedRect {
            id: backgroundBlob
            z: 0

            anchors.fill: parent
            group: group
            radius: 14
            borderTop: root.barHeight
            borderLeft: root.edgeThickness
            borderRight: root.edgeThickness
            borderBottom: root.edgeThickness
        }

        // =====================================================================
// Catcher para fechar os menus ao clicar fora
// =====================================================================
Item {
    id: clickOutsideCatcher
    x: 0; y: 0
    width:  (AppLauncher.open || ClipboardService.open || WallpaperPickerService.open) ? bar.width  : 0
    height: (AppLauncher.open || ClipboardService.open || WallpaperPickerService.open) ? bar.height : 0
    z: 0.5

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: {
            AppLauncher.close()
            ClipboardService.close()
            WallpaperPickerService.close()
        }
    }
}

// =====================================================================
// Popout do App Launcher (blob colado embaixo da barra)
// =====================================================================
BlobRect {
    id: launcherPopout
    z: 2
    group: group

    x: (bar.width - root.launcherWidth) / 2
    width: root.launcherWidth
    height: AppLauncher.open ? root.launcherHeight : 0

    topLeftRadius: 18
    topRightRadius: 18
    bottomLeftRadius: 4
    bottomRightRadius: 4

    anchors.bottom: parent.bottom
    anchors.bottomMargin: -2

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    // MouseArea que impede o popup de "fechar" ao clicar dentro
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: launcherSearchInput.forceActiveFocus()
    }

    ColumnLayout {
        id: launcherLayout
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        // ---- Barra de busca ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 14
            color: theme.fundo2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: "󰍉"
                    color: theme.branco2
                    font.family: "Rubik"
                    font.pixelSize: 17
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: launcherSearchInput.text.length === 0
                        text: "Apps"
                        color: theme.branco2
                        font.family: "Rubik"
                        font.pixelSize: 15
                    }

                    TextInput {
                        id: launcherSearchInput
                        anchors.fill: parent
                        focus: AppLauncher.open
                        activeFocusOnPress: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.branco
                        font.family: "Rubik"
                        font.pixelSize: 15
                        selectionColor: "#40ffffff"
                        clip: true

                        text: AppLauncher.searchQuery
                        onTextChanged: AppLauncher.searchQuery = text

                        Keys.priority: Keys.BeforeItem
                        Keys.onEscapePressed: AppLauncher.close()
                        Keys.onReturnPressed: AppLauncher.launchCurrent()
                        Keys.onEnterPressed: AppLauncher.launchCurrent()
                        Keys.onDownPressed: AppLauncher.moveSelection(1)
                        Keys.onUpPressed: AppLauncher.moveSelection(-1)
                    }
                }
            }
        }

        // ---- Contagem de resultados ----
        Text {
            Layout.fillWidth: true
            visible: AppLauncher.normalizedSearchQuery !== "" || AppLauncher.loadingApps
            text: AppLauncher.resultsSummary
            color: theme.branco2
            font.family: "Rubik"
            font.pixelSize: 11
            leftPadding: 4
        }

        // ---- Lista ----
        ListView {
            id: launcherResultsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: AppLauncher.filteredApps
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            currentIndex: AppLauncher.selectedIndex

            Text {
                anchors.centerIn: parent
                visible: AppLauncher.filteredApps.length === 0
                text: AppLauncher.loadingApps
                      ? AppLauncher.resultsSummary
                      : "Nenhum aplicativo encontrado"
                color: theme.branco2
                font.family: "Rubik"
                font.pixelSize: 14
            }

            delegate: Rectangle {
                required property int index
                required property var modelData
                readonly property var app: modelData
                property bool hovered: delegateArea.containsMouse
                property bool selected: AppLauncher.selectedIndex === index

                width: launcherResultsView.width
                height: 56
                radius: 16
                color: selected ? theme.glassAccentStrong
                                : hovered ? theme.glassHover
                                          : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    Item {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            asynchronous: true
                            source: app.iconPath
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: app.name.charAt(0).toUpperCase()
                            color: theme.branco
                            font.family: "Rubik"
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: app.name
                        color: theme.branco
                        font.family: "Rubik"
                        font.pixelSize: selected ? 15 : 14
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    id: delegateArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: AppLauncher.selectIndex(index)
                    onClicked: AppLauncher.launch(app)
                }
            }
        }
    }
}

Connections {
    target: AppLauncher

    function onOpenChanged() {
        if (AppLauncher.open) {
            // conteúdo aparece depois da animação abrir (blob crescendo)
            launcherContentTimer.restart()
            launcherFocusTimer.restart()
        } else {
            // esconde imediatamente e cancela tudo
            launcherContentTimer.stop()
            launcherLayout.opacity = 0
            launcherFocusTimer.stop()
        }
    }
}

// =====================================================================
// Popout do Clipboard — mesmo visual e animação do App Launcher
// =====================================================================
BlobRect {
    id: clipboardPopout
    z: 2
    group: group

    x: (bar.width - root.launcherWidth) / 2
    width: root.launcherWidth
    height: ClipboardService.open ? root.launcherHeight : 0

    topLeftRadius: 18
    topRightRadius: 18
    bottomLeftRadius: 4
    bottomRightRadius: 4

    anchors.bottom: parent.bottom
    anchors.bottomMargin: -2

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: clipboardSearchInput.forceActiveFocus()
    }

    ColumnLayout {
        id: clipboardLayout
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        // ---- Barra de busca (idêntica à do launcher) ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 14
            color: theme.fundo2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: "󰍉"
                    color: theme.branco2
                    font.family: "Rubik"
                    font.pixelSize: 17
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: clipboardSearchInput.text.length === 0
                        text: "Histórico da área de transferência"
                        color: theme.branco2
                        font.family: "Rubik"
                        font.pixelSize: 15
                    }

                    TextInput {
                        id: clipboardSearchInput
                        anchors.fill: parent
                        focus: ClipboardService.open
                        activeFocusOnPress: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.branco
                        font.family: "Rubik"
                        font.pixelSize: 15
                        selectionColor: "#40ffffff"
                        clip: true

                        text: ClipboardService.searchQuery
                        onTextChanged: ClipboardService.searchQuery = text

                        Keys.priority: Keys.BeforeItem
                        Keys.onEscapePressed: ClipboardService.close()
                        Keys.onReturnPressed: ClipboardService.restoreCurrent()
                        Keys.onEnterPressed:  ClipboardService.restoreCurrent()
                        Keys.onDownPressed:   ClipboardService.moveSelection(1)
                        Keys.onUpPressed:     ClipboardService.moveSelection(-1)
                    }
                }
            }
        }

        // ---- Contagem de resultados ----
        Text {
            Layout.fillWidth: true
            visible: ClipboardService.normalizedSearchQuery !== "" || ClipboardService.loadingEntries
            text: ClipboardService.resultsSummary
            color: theme.branco2
            font.family: "Rubik"
            font.pixelSize: 11
            leftPadding: 4
        }

        // ---- Lista ----
        ListView {
            id: clipboardResultsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: ClipboardService.filteredEntries
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            currentIndex: ClipboardService.selectedIndex

            Text {
                anchors.centerIn: parent
                visible: ClipboardService.filteredEntries.length === 0
                text: ClipboardService.loadingEntries
                      ? ClipboardService.resultsSummary
                      : "Histórico vazio"
                color: theme.branco2
                font.family: "Rubik"
                font.pixelSize: 14
            }

            delegate: Rectangle {
                required property int index
                required property var modelData
                readonly property var entry: modelData
                property bool hovered: delegateArea.containsMouse
                property bool selected: ClipboardService.selectedIndex === index

                width: clipboardResultsView.width
                height: 68
                radius: 16
                color: selected ? theme.glassAccentStrong
                                : hovered ? theme.glassHover
                                          : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

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
                            text: ClipboardService.iconTextFor(entry)
                            color: theme.branco
                            font.family: "Rubik"
                            font.pixelSize: 15
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: ClipboardService.titleFor(entry)
                            color: theme.branco
                            font.family: "Rubik"
                            font.pixelSize: selected ? 14 : 13
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: ClipboardService.subtitleFor(entry)
                            color: theme.branco2
                            font.family: "Rubik"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: delegateArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: ClipboardService.selectIndex(index)
                    onClicked: ClipboardService.restoreEntry(entry)
                }
            }
        }
    }
}

Connections {
    target: ClipboardService

    function onOpenChanged() {
        if (ClipboardService.open) {
            clipboardContentTimer.restart()
            clipboardFocusTimer.restart()
        } else {
            clipboardContentTimer.stop()
            clipboardLayout.opacity = 0
            clipboardFocusTimer.stop()
        }
    }
}

// =====================================================================
// Popout do Wallpaper Picker — mesmo visual do App Launcher
// =====================================================================
BlobRect {
    id: wallpaperPickerPopout
    z: 2
    group: group

    x: (bar.width - root.launcherWidth) / 2
    width: root.launcherWidth
    height: WallpaperPickerService.open ? root.launcherHeight : 0

    topLeftRadius: 18
    topRightRadius: 18
    bottomLeftRadius: 4
    bottomRightRadius: 4

    anchors.bottom: parent.bottom
    anchors.bottomMargin: -2

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: wallpaperSearchInput.forceActiveFocus()
    }

    ColumnLayout {
        id: wallpaperPickerLayout
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 14
            color: theme.fundo2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: "󰍉"
                    color: theme.branco2
                    font.family: "Rubik"
                    font.pixelSize: 17
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: wallpaperSearchInput.text.length === 0
                        text: "Wallpapers em ~/Imagens"
                        color: theme.branco2
                        font.family: "Rubik"
                        font.pixelSize: 15
                    }

                    TextInput {
                        id: wallpaperSearchInput
                        anchors.fill: parent
                        focus: WallpaperPickerService.open
                        activeFocusOnPress: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.branco
                        font.family: "Rubik"
                        font.pixelSize: 15
                        selectionColor: "#40ffffff"
                        clip: true

                        text: WallpaperPickerService.searchQuery
                        onTextChanged: WallpaperPickerService.searchQuery = text

                        Keys.priority: Keys.BeforeItem
                        Keys.onEscapePressed: WallpaperPickerService.close()
                        Keys.onReturnPressed: WallpaperPickerService.applyCurrent()
                        Keys.onEnterPressed:  WallpaperPickerService.applyCurrent()
                        Keys.onDownPressed:   WallpaperPickerService.moveSelection(1)
                        Keys.onUpPressed:     WallpaperPickerService.moveSelection(-1)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: WallpaperPickerService.normalizedSearchQuery !== ""
                     || WallpaperPickerService.loadingWallpapers
            text: WallpaperPickerService.resultsSummary
            color: theme.branco2
            font.family: "Rubik"
            font.pixelSize: 11
            leftPadding: 4
        }

        ListView {
            id: wallpaperResultsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: WallpaperPickerService.filteredWallpapers
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            currentIndex: WallpaperPickerService.selectedIndex

            Text {
                anchors.centerIn: parent
                visible: WallpaperPickerService.filteredWallpapers.length === 0
                text: WallpaperPickerService.loadingWallpapers
                      ? WallpaperPickerService.resultsSummary
                      : "Nenhum wallpaper encontrado em ~/Imagens"
                color: theme.branco2
                font.family: "Rubik"
                font.pixelSize: 14
            }

            delegate: Rectangle {
                required property int index
                required property var modelData

                readonly property var wallpaper: modelData
                property bool hovered: delegateArea.containsMouse
                property bool selected: WallpaperPickerService.selectedIndex === index
                readonly property bool active: WallpaperPickerService.activeWallpaperPath === wallpaper.path

                width: wallpaperResultsView.width
                height: 72
                radius: 16
                color: selected ? theme.glassAccentStrong
                                : hovered ? theme.glassHover
                                          : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    ClippingRectangle {
    Layout.preferredWidth: 52
    Layout.preferredHeight: 52
    radius: 12
    color: theme.fundo2
    antialiasing: true

    Image {
        anchors.fill: parent
        source: wallpaper.path
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 52
        sourceSize.height: 52
        cache: true
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
                                color: theme.branco
                                font.family: "Rubik"
                                font.pixelSize: selected ? 15 : 14
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: active
                                radius: 999
                                color: theme.fundo2
                                border.color: theme.fundo2
                                border.width: 1
                                implicitWidth: activeLabel.implicitWidth + 14
                                implicitHeight: activeLabel.implicitHeight + 6

                                Text {
                                    id: activeLabel
                                    anchors.centerIn: parent
                                    text: "Atual"
                                    color: theme.branco
                                    font.family: "Rubik"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: wallpaper.relativePath
                            color: theme.branco2
                            font.family: "Rubik"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: delegateArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: WallpaperPickerService.selectIndex(index)
                    onClicked: WallpaperPickerService.applyWallpaper(wallpaper)
                }
            }
        }
    }
}

Connections {
    target: WallpaperPickerService

    function onOpenChanged() {
        if (WallpaperPickerService.open) {
            wallpaperPickerContentTimer.restart()
            wallpaperPickerFocusTimer.restart()
        } else {
            wallpaperPickerContentTimer.stop()
            wallpaperPickerLayout.opacity = 0
            wallpaperPickerFocusTimer.stop()
        }
    }
}

        // =====================================================================
        // Popout do calendário
        // =====================================================================
        BlobRect {
            id: popout
            z: 1
            group: group

            x: (bar.width - root.popoutWidth) / 2
            y: root.barHeight
            width: root.popoutWidth
            height: bar.clockPopupShown ? root.popoutHeight : 0

            topLeftRadius: 4
            topRightRadius: 4
            bottomLeftRadius: 18
            bottomRightRadius: 18

            Behavior on height {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            // MouseArea por baixo do conteúdo: mantém o calendário aberto
            // enquanto o mouse estiver dentro da área do BlobRect.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    bar.clockPopupHover = true
                    bar.syncClockPopup()
                }
                onExited: {
                    bar.clockPopupHover = false
                    bar.syncClockPopup()
                }
            }

            ColumnLayout {
                id: clockPopupLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                opacity: 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatTime(bar.currentDateTime, "HH:mm")
                    color: theme.branco
                    font.family: "Rubik"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: Qt.locale("pt_BR").toString(
                        bar.currentDateTime,
                        "dddd, d 'de' MMMM 'de' yyyy"
                    )
                    color: theme.branco
                    font.family: "Rubik"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.fundo2
                }

                Text {
                    Layout.fillWidth: true
                    text: bar.monthTitle
                    color: theme.branco
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
                            color: theme.neutralTextMuted
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
                    rowSpacing: 2

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
                                color: today ? theme.fundo2 : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: day > 0 ? String(day) : ""
                                color: today ? theme.branco : theme.brancoE
                                font.family: "Rubik"
                                font.pixelSize: 11
                                font.bold: today
                            }
                        }
                    }
                }
            }
        }
        // =====================================================================
// Toast de notificações — blob no canto superior direito,
// fundido com a barra, mesma animação dos popouts.
// =====================================================================
BlobRect {
    id: toastBlob
    z: 1
    group: group

    readonly property int toastWidth: 360
    readonly property var queue: NotifServer.toastQueue
    readonly property bool anyVisible: queue.length > 0 && !bar.notifPopupShown

    // Controla o fade do conteúdo (mesma ideia dos popouts)
    property real contentOpacity: 0

    x: bar.width - toastWidth - 8
    y: root.barHeight - 2                 // overlap leve para o merge com a barra
    width: toastWidth
    height: anyVisible ? toastColumn.implicitHeight + 6 : 0
    opacity: anyVisible ? 1 : 0
    visible: opacity > 0.01

    topLeftRadius: 4
    topRightRadius: 4
    bottomLeftRadius: 18
    bottomRightRadius: 18

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }
        Behavior on contentOpacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    onAnyVisibleChanged: {
        if (anyVisible) {
            contentTimer.restart()
        } else {
            contentTimer.stop()
            contentOpacity = 0     // volta ao estado inicial para o próximo toast
        }
    }

    Timer {
        id: contentTimer
        interval: 250               // mesmo delay dos popouts
        repeat: false
        onTriggered: toastBlob.contentOpacity = 1
    }

    Column {
        id: toastColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 3
        spacing: 6

        opacity: toastBlob.contentOpacity   // ← era opacity: 0 implícito

        Repeater {
            model: toastBlob.queue

            delegate: Item {
    id: toastItem
    required property Notification modelData
    width: toastColumn.width
    height: toastCard.implicitHeight

    property real swipeOffset: 0
    property real swipeStartX: 0
    property bool swipeDragging: false
    readonly property real dismissThreshold: Math.max(120, width * 0.35)

    readonly property string mediaSource: NotifServer.notificationMediaSource(modelData)
    readonly property bool hasMedia: mediaSource !== ""

    // ── Fade individual do card ──────────────────────────────────────────
    property bool cardReady: false
    opacity: cardReady ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    Component.onCompleted: {
        if (toastBlob.contentOpacity > 0.5) {
            // Blob já está aberto (é um toast novo numa pilha existente)
            // → faz fade-in individual, sincronizado com a animação de altura
            cardAppearTimer.start()
        } else {
            // Primeiro toast da pilha → o fade do container (contentOpacity)
            // já vai revelar este card, não precisa animar aqui.
            toastItem.cardReady = true
        }
    }

    Timer {
        id: cardAppearTimer
        interval: 250        // mesmo delay dos popouts (espera o blob crescer)
        repeat: false
        onTriggered: toastItem.cardReady = true
    }

    function finishSwipe() {
        if (!swipeDragging) { swipeOffset = 0; return }
        swipeDragging = false
        if (swipeOffset >= dismissThreshold)
            dismissAnim.restart()
        else
            resetAnim.restart()
    }


                NumberAnimation {
                    id: resetAnim
                    target: toastItem
                    property: "swipeOffset"
                    to: 0
                    duration: 170
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: dismissAnim
                    target: toastItem
                    property: "swipeOffset"
                    to: toastItem.width + 48
                    duration: 140
                    easing.type: Easing.InCubic
                    onFinished: NotifServer.dismissToast(toastItem.modelData)
                }

                // Auto-fecha (a menos que seja resident).
                Timer {
                    id: toastTimer
                    interval: (modelData.expireTimeout && modelData.expireTimeout > 0)
                              ? modelData.expireTimeout : 5000
                    running: !modelData.resident && toastBlob.anyVisible
                    repeat: false
                    onTriggered: NotifServer.dismissToast(toastItem.modelData)
                }

                // Card visual (fica atrás do MouseArea de swipe)
                Rectangle {
                    id: toastCard
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    implicitHeight: toastLayout.implicitHeight + 18
                    radius: 12
                    color: "transparent"        // o fundo vem do blob
                    clip: true
                    opacity: 1 - Math.min(0.55,
                        toastItem.swipeOffset / Math.max(1, width) * 0.55)
                    transform: Translate { x: toastItem.swipeOffset }

                    Rectangle {
                        width: 4
                        height: parent.height - 16
                        radius: 2
                        anchors {
                            left: parent.left
                            leftMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        color: {
                            switch (modelData.urgency) {
                                case NotificationUrgency.Critical: return "#ff9999"
                                case NotificationUrgency.Normal:   return "#ffffff"
                                default:                           return "#9dffbf"
                            }
                        }
                    }

                    RowLayout {
                        id: toastLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 18
                            rightMargin: 12
                            topMargin: 9
                        }
                        spacing: 10

                        Image {
                            visible: toastItem.hasMedia
                            source: toastItem.mediaSource
                            Layout.preferredWidth: toastItem.hasMedia ? 36 : 0
                            Layout.preferredHeight: toastItem.hasMedia ? 36 : 0
                            Layout.maximumWidth: toastItem.hasMedia ? 36 : 0
                            Layout.maximumHeight: toastItem.hasMedia ? 36 : 0
                            smooth: true
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.appName
                                color: theme.neutralTextMuted
                                font.family: "Rubik"
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            Text {
                                text: modelData.summary
                                color: theme.branco
                                font.family: "Rubik"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            Text {
                                text: modelData.body
                                color: theme.branco2
                                font.family: "Rubik"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: text !== ""
                                bottomPadding: 4
                            }

                            RowLayout {
                                visible: modelData.actions.length > 0
                                spacing: 6
                                Layout.bottomMargin: 2

                                Repeater {
                                    model: modelData.actions

                                    Rectangle {
                                        required property NotificationAction modelData
                                        radius: 8
                                        color: "#30ffffff"
                                        implicitWidth: actionLabel.implicitWidth + 16
                                        implicitHeight: 24

                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: theme.branco
                                            font.family: "Rubik"
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                modelData.invoke()
                                                NotifServer.dismissToast(toastItem.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── MouseArea de swipe — DEPOIS do card e com z alto ──
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    z: 10

                    onPressed: function(mouse) {
                        toastItem.swipeStartX = mouse.x
                        toastItem.swipeDragging = false
                        resetAnim.stop()
                        dismissAnim.stop()
                    }
                    onPositionChanged: function(mouse) {
                        let delta = Math.max(0, mouse.x - toastItem.swipeStartX)
                        if (delta > 8 || toastItem.swipeDragging)
                            toastItem.swipeDragging = true
                        toastItem.swipeOffset = Math.min(delta, toastItem.width + 64)
                    }
                    onReleased: toastItem.finishSwipe()
                    onCanceled: toastItem.finishSwipe()
                }
            }
        }
    }
}

// =====================================================================
// Exclusividade entre os três popouts centrais
// =====================================================================
Connections {
    target: AppLauncher
    function onOpenChanged() {
        if (!AppLauncher.open) return
        ClipboardService.close()
        WallpaperPickerService.close()
    }
}

Connections {
    target: ClipboardService
    function onOpenChanged() {
        if (!ClipboardService.open) return
        AppLauncher.close()
        WallpaperPickerService.close()
    }
}

Connections {
    target: WallpaperPickerService
    function onOpenChanged() {
        if (!WallpaperPickerService.open) return
        AppLauncher.close()
        ClipboardService.close()
    }
}
    }

    // Exclusion zones para o compositor respeitar a barra e as bordas da janela.
    ExclusionZone { anchors.top: true; exclusiveZone: root.barHeight }
    ExclusionZone { anchors.left: true; exclusiveZone: root.edgeThickness }
    ExclusionZone { anchors.right: true; exclusiveZone: root.edgeThickness }
    ExclusionZone { anchors.bottom: true; exclusiveZone: root.edgeThickness }

    component ExclusionZone: PanelWindow {
        WlrLayershell.namespace: "border-exclusion"
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
    }
}