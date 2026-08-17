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

    IdleInhibitor {
    id: idleInhibitor
    window: bar
    enabled: bar.idleInhibited
    }

    PowerProfileController {
        id: powerProfile
    }

    readonly property string monthTitle: Qt.locale("pt_BR").toString(currentDateTime, "MMMM yyyy")
    readonly property string longDate: Qt.locale("pt_BR").toString(currentDateTime, "dddd, d 'de' MMMM")
    readonly property var weekDayLabels: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"]
    readonly property int popupAnimDuration: 170
    readonly property int popupSlideDistance: 10
    readonly property int powerButtonWidth: 20

    margins {
        top: 8
        left: 8
        right: 8
        bottom: 0
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: false
    }

    implicitHeight: 40
    color: "transparent"

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

    function popupXFor(item, popupWidth) {
        if (!item)
            return 8

        var rect = itemRect(item)
        var target = Math.round(rect.x + (rect.width - popupWidth) / 2)
        var maxX = Math.max(8, width - popupWidth - 8)
        return Math.max(8, Math.min(maxX, target))
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

    Item {
        id: barSurface
        anchors.fill: parent
        Rectangle {
            id: leftCluster
            anchors {
                left: parent.left
                leftMargin: 0
                top: parent.top
            }
            width: workspaceRow.implicitWidth + 22
            height: 40
            radius: theme.widgetRadius - 2
            color: bar.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth

            gradient: Gradient {
                GradientStop { position: 0.0; color: bar.fundo }
                GradientStop { position: 1.0; color: bar.fundo2 }
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
                        foregroundColor: bar.branco
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
                    color: "#60ffffff"
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
                            anchors.fill: workspaceText
                            source: workspaceText
                            cached: true
                            visible: false
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#00ffffff" }
                                GradientStop { position: 1.0; color: "#a5a5a5" }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: centerCluster
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            width: centerRow.implicitWidth + 24
            height: 40
            radius: theme.widgetRadius - 2
            color: bar.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth

            gradient: Gradient {
                GradientStop { position: 0.0; color: bar.fundo }
                GradientStop { position: 1.0; color: bar.fundo2 }
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
                        color: bar.branco
                        font.family: "Rubik"
                        font.pixelSize: 20
                        font.bold: true
                        font.letterSpacing: 0.4
                    }

                    LinearGradient {
                        anchors.fill: clockText
                        source: clockText
                        cached: true
                        visible: false
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ffffff" }
                            GradientStop { position: 1.0; color: "#a5a5a5" }
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
                    width: 2
                    height: 18
                    color: "#60ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: centerNotifItem
                    width: 24
                    height: 24

                    Text {
                        anchors.centerIn: parent
                        text: NotifServer.unreadCount > 0 ? "󰂚" : "󰂜"
                        color: NotifServer.unreadCount > 0 ? "#ffb25a" : bar.branco
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifServer.toggleCenter()
                    }
                }
            }
        }

        Rectangle {
            id: rightCluster
            anchors {
                right: parent.right
                rightMargin: 0
                top: parent.top
            }
            width: rightRow.implicitWidth + 22
            height: 40
            radius: theme.widgetRadius - 2
            color: bar.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth

            gradient: Gradient {
                GradientStop { position: 0.0; color: bar.fundo }
                GradientStop { position: 1.0; color: bar.fundo2 }
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
                                   : bar.branco
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
                                   : bar.branco
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
                    autoDetect: bar.autoDetectBattery
                    showWhenManual: bar.showBatteryIcon
                    foregroundColor: bar.branco
                    mutedColor: "#bcbcbc"
                }

                Rectangle {
                    width: 2
                    height: 18
                    y: Math.round((rightRow.height - height) / 2)
                    color: "#60ffffff"
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
                                    color: bar.brightnessAvailable ? bar.branco : "#777777"
                                    font.family: "JetBrains Mono Nerd Font"
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: bar.brightnessPercent + "%"
                                    color: bar.brightnessAvailable ? "#bcbcbc" : "#777777"
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
                        color: bar.branco
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
    }

    PopupWindow {
        id: clockPopup
        anchor.window: bar
        color: "transparent"
        visible: false
        anchor.rect.x: bar.popupXFor(clockBlock, implicitWidth)
        anchor.rect.y: bar.height + 8
        implicitWidth: 286
        implicitHeight: clockPopupCard.implicitHeight

        Item {
            id: clockPopupCard
            implicitWidth: 286
            implicitHeight: clockPopupLayout.implicitHeight + 24
            width: implicitWidth
            height: implicitHeight
            y: bar.clockPopupShown ? 0 : -bar.popupSlideDistance
            opacity: bar.clockPopupShown ? 1 : 0

            Behavior on y {
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
