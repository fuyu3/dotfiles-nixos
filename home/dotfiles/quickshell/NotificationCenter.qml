import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import QtQuick.Controls

PanelWindow {
    id: center
    visible: centerReady && !lockActive
    color: "transparent"
    focusable: true

    property bool centerReady: false
    property bool lockActive: false
    property int topOffset: 0

    Theme { id: theme }

    property color fundo: theme.fundo
    property color fundo2: theme.fundo2
    property color branco: theme.branco
    property color cinza: theme.cinzaEscuro

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: NotifServer.centerVisible && !lockActive
                                 ? WlrKeyboardFocus.Exclusive
                                 : WlrKeyboardFocus.None

    Connections {
        target: NotifServer
        function onCenterVisibleChanged() {
            if (NotifServer.centerVisible) {
                center.centerReady = true  // abre imediatamente
                focusTimer.start()
            }
            // fechar: espera a animação — o onRunningChanged cuida disso
        }
    }

    onLockActiveChanged: {
        if (lockActive) {
            NotifServer.centerVisible = false
            centerReady = false
        }
    }
    
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: NotifServer.centerVisible = false
    }

    margins {
        top: 0
        right: 0
        bottom: 0
    }

    implicitWidth: 360

    onVisibleChanged: {
        if (visible && NotifServer.centerVisible)
            focusTimer.start()
    }

    Timer {
        id: focusTimer
        property int attempts: 0

        interval: 35
        repeat: true

        onTriggered: {
            if (!center.visible || !NotifServer.centerVisible) {
                stop()
                attempts = 0
                return
            }

            keyCatcher.forceActiveFocus()
            attempts += 1

            if (keyCatcher.activeFocus || attempts >= 6) {
                stop()
                attempts = 0
            }
        }
    }

    Rectangle {
        id: rectangleNC
        radius: theme.widgetRadius - 2
        color: center.fundo
        border.color: theme.widgetBorderColor
        border.width: theme.widgetBorderWidth
        width: Math.min(500, parent.width - 24)
        height: Math.min(parent.height - 16, 400)
        
        opacity: NotifServer.centerVisible ? 1 : 0
        scale: NotifServer.centerVisible ? 1 : 0.95
        transformOrigin: Item.Top

        transform: Translate {
            y: NotifServer.centerVisible ? 0 : -30
            Behavior on y {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
        }
        gradient: Gradient {  
            GradientStop { position: 0.0; color: center.fundo }
            GradientStop { position: 1.0; color: center.fundo2 }
        }

        anchors {
            top: parent.top
            topMargin: 8 + center.topOffset
            horizontalCenter: parent.horizontalCenter
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // consome o evento sem fazer nada
        }

        FocusScope {
            id: keyCatcher
            anchors.fill: parent
            focus: NotifServer.centerVisible

            Keys.priority: Keys.BeforeItem
            Keys.onEscapePressed: function(event) {
                event.accepted = true
                NotifServer.centerVisible = false
            }
        }

        Behavior on opacity {
            NumberAnimation {
                id: opacityAnim
                duration: 200
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    // quando a animação de fechar terminar, esconde a window
                    if (!running && !NotifServer.centerVisible) {
                        center.centerReady = false
                    }
                }
            }
        }

        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        

        ColumnLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            // ── Header ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Notificações"
                    color: "#ffffff"
                    font.family: "Rubik"
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }

                // Clear-all button (only when there are notifications)
                Rectangle {
                    visible: NotifServer.notifications.length > 0
                    radius: 10
                    color: "#25ffffff"
                    implicitWidth: clearLabel.implicitWidth + 16
                    implicitHeight: 26

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Limpar tudo"
                        color: "#aaaaaa"
                        font.family: "Rubik"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifServer.clearAll()
                    }
                }

            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#20ffffff"
            }

            // ── Notification List ────────────────────────────────────
            Flickable {
                id: notificationFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: notifCol.implicitHeight
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    visible: NotifServer.notifications.length === 0
                    text: "󰂚\nNenhuma notificação"
                    color: "#444444"
                    font.family: "Ubuntu Nerd Font"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.6
                }

                Column {
                    id: notifCol
                    width: parent.width
                    spacing: 8

                    Repeater {
                        // Show newest first
                        model: {
                            let arr = [...NotifServer.notifications]
                            return arr.reverse()
                        }

                        delegate: Rectangle {
                            id: notifCard
                            required property Notification modelData
                            required property int index

                            property Notification notif: modelData
                            readonly property string mediaSource: NotifServer.notificationMediaSource(modelData)
                            readonly property bool hasMedia: mediaSource !== ""
                            property real swipeOffset: 0
                            property real swipeStartX: 0
                            property real swipeStartY: 0
                            property real swipeLastY: 0
                            property bool swipeDragging: false
                            property int dragMode: 0
                            property int swipeDirection: 1
                            readonly property real swipeDismissThreshold: Math.max(120, width * 0.35)

                            width: notifCol.width
                            implicitHeight: cardLayout.implicitHeight + 20
                            radius: 14
                            color: "#20ffffff"
                            border.color: "#15ffffff"
                            border.width: 1
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
                                    let pointer = cardDragArea.mapToItem(notificationFlickable, mouse.x, mouse.y)

                                    notifCard.swipeStartX = mouse.x
                                    notifCard.swipeStartY = pointer.y
                                    notifCard.swipeLastY = pointer.y
                                    notifCard.swipeDragging = false
                                    notifCard.dragMode = 0
                                    resetSwipeAnim.stop()
                                    dismissSwipeAnim.stop()
                                }

                                onPositionChanged: function(mouse) {
                                    let pointer = cardDragArea.mapToItem(notificationFlickable, mouse.x, mouse.y)
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
                                        let maxContentY = Math.max(0, notificationFlickable.contentHeight - notificationFlickable.height)
                                        notificationFlickable.contentY = Math.max(0, Math.min(maxContentY,
                                            notificationFlickable.contentY - (pointer.y - notifCard.swipeLastY)))
                                    }

                                    notifCard.swipeLastY = pointer.y
                                }

                                onReleased: notifCard.finishSwipe()
                                onCanceled: notifCard.finishSwipe()
                            }

                            // Urgency accent
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
                                id: cardLayout
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    leftMargin: 18
                                    rightMargin: 10
                                    topMargin: 10
                                }
                                spacing: 10

                                Image {
                                    visible: notifCard.hasMedia
                                    source: notifCard.mediaSource
                                    Layout.preferredWidth: notifCard.hasMedia ? 32 : 0
                                    Layout.preferredHeight: notifCard.hasMedia ? 32 : 0
                                    Layout.maximumWidth: notifCard.hasMedia ? 32 : 0
                                    Layout.maximumHeight: notifCard.hasMedia ? 32 : 0
                                    smooth: true
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectFit
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: modelData.appName
                                            color: "#666666"
                                            font.family: "Rubik"
                                            font.pixelSize: 10
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: modelData.summary
                                        color: "#ffffff"
                                        font.family: "Rubik"
                                        font.pixelSize: 13
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }

                                    Text {
                                        text: modelData.body
                                        color: "#bbbbbb"
                                        font.family: "Rubik"
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                        bottomPadding: 2
                                    }

                                    // Actions
                                    RowLayout {
                                        visible: modelData.actions.length > 0
                                        spacing: 6
                                        Layout.bottomMargin: 2

                                        Repeater {
                                            model: modelData.actions

                                            Rectangle {
                                                required property NotificationAction modelData
                                                radius: 8
                                                color: "#25ffffff"
                                                implicitWidth: actTxt.implicitWidth + 16
                                                implicitHeight: 22

                                                Text {
                                                    id: actTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.text
                                                    color: "#dddddd"
                                                    font.family: "Rubik"
                                                    font.pixelSize: 11
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        modelData.invoke()
                                                        NotifServer.dismiss(notifCard.notif)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
