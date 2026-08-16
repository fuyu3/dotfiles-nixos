import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Variants {
    id: root
    property bool lockActive: false
    property int topOffset: 0
    model: NotifServer.toastQueue

    PanelWindow {
        Theme { id: theme }

        property color fundo: theme.fundo
        property color fundo2: theme.fundo2
        property color branco: theme.branco
        property color cinza: theme.cinzaEscuro
        property real swipeOffset: 0
        property real swipeStartX: 0
        property bool swipeDragging: false
        readonly property real swipeDismissThreshold: Math.max(120, implicitWidth * 0.35)
        
        id: toastWin
        required property Notification modelData
        readonly property string mediaSource: NotifServer.notificationMediaSource(modelData)
        readonly property bool hasMedia: mediaSource !== ""
        visible: !root.lockActive

        function finishSwipe() {
            if (!swipeDragging) {
                swipeOffset = 0
                return
            }

            swipeDragging = false

            if (swipeOffset >= swipeDismissThreshold) {
                swipeDismissAnim.restart()
            } else {
                swipeResetAnim.restart()
            }
        }

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: -1                   

        anchors {
            top: true
            right: true
        }
        margins {
            top: root.topOffset + 12 + NotifServer.toastQueue.indexOf(modelData) * 88
            right: 12
        }

        implicitWidth: 360
        implicitHeight: toastRect.implicitHeight
        color: "transparent"

        Timer {
            id: autoClose
            interval: modelData.expireTimeout > 0 ? modelData.expireTimeout : 5000
            running: !modelData.resident
            repeat: false
            onTriggered: NotifServer.dismissToast(modelData)
        }

        NumberAnimation {
            id: swipeResetAnim
            target: toastWin
            property: "swipeOffset"
            to: 0
            duration: 170
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: swipeDismissAnim
            target: toastWin
            property: "swipeOffset"
            to: toastWin.implicitWidth + 48
            duration: 140
            easing.type: Easing.InCubic
            onFinished: NotifServer.dismiss(toastWin.modelData)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            preventStealing: true

            onPressed: function(mouse) {
                toastWin.swipeStartX = mouse.x
                toastWin.swipeDragging = false
            }

            onPositionChanged: function(mouse) {
                let delta = Math.max(0, mouse.x - toastWin.swipeStartX)
                if (delta > 8 || toastWin.swipeDragging)
                    toastWin.swipeDragging = true

                toastWin.swipeOffset = Math.min(delta, toastWin.width + 64)
            }

            onReleased: toastWin.finishSwipe()
            onCanceled: toastWin.finishSwipe()
        }

        Rectangle {
            id: toastRect
            anchors.fill: parent
            implicitHeight: toastLayout.implicitHeight + 24
            radius: theme.widgetRadius - 6
            color: toastWin.fundo
            border.color: theme.widgetBorderColor
            border.width: theme.widgetBorderWidth
            clip: true
            opacity: 1 - Math.min(0.55, toastWin.swipeOffset / Math.max(1, width) * 0.55)
            transform: Translate { x: toastWin.swipeOffset }

            gradient: Gradient { 
                GradientStop { position: 0.0; color: toastWin.fundo }
                GradientStop { position: 1.0; color: toastWin.fundo2 }
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
                        case NotificationUrgency.Critical: return '#ff9999'
                        case NotificationUrgency.Normal:   return '#ffffff'
                        default:                            return '#9dffbf'
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
                    topMargin: 12
                }
                spacing: 10

                Image {
                    visible: toastWin.hasMedia
                    source: toastWin.mediaSource
                    Layout.preferredWidth: toastWin.hasMedia ? 36 : 0
                    Layout.preferredHeight: toastWin.hasMedia ? 36 : 0
                    Layout.maximumWidth: toastWin.hasMedia ? 36 : 0
                    Layout.maximumHeight: toastWin.hasMedia ? 36 : 0
                    smooth: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: modelData.appName
                            color: "#888888"
                            font.family: "Rubik"
                            font.pixelSize: 11
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
                        color: "#cccccc"
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
                        Layout.bottomMargin: 4

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
                                    color: "#ffffff"
                                    font.family: "Rubik"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.invoke()
                                        NotifServer.dismiss(toastWin.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: progressBar
                z: 10
                visible: autoClose.running
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 7
                    leftMargin: 1
                }
                height: 2
                radius: 2
                color: '#4d4d4d'
                width: toastRect.width - 10
                

                SequentialAnimation {
                    id: progressAnim
                    running: autoClose.running
                    NumberAnimation {
                        target: progressBar
                        property: "width"
                        from: toastRect.width - 10
                        to: 0
                        duration: autoClose.interval
                        easing.type: Easing.Linear
                    }
                }

                onWidthChanged: {
                    if (!progressAnim.running && autoClose.running)
                        progressAnim.start()
                }
            }
        }
    }
}
