import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Widgets
import QtCore
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Scope {
    id: root

    Theme { id: theme }

    property color fundo: theme.fundo
    property color fundo2: theme.fundo2
    property color branco: theme.branco
    property color cinza: theme.neutralTextMuted
    property color pretoSuave: theme.pretoSuave
    property color destaque: theme.glassAccentStrong
    property color erro: theme.erro

    property bool lockOpen: false
    readonly property bool surfaceVisible: sessionLock.locked
    readonly property bool lockActive: openPending || sessionLock.locked || unlockTimer.running
    property bool authBusy: false
    property bool authError: false
    property bool holdAuthMessage: false
    property bool openPending: false
    property string authMessage: "Digite sua senha para desbloquear."
    property string passwordText: ""
    property string userName: String(Quickshell.env("USER") || "")
    property string displayName: userName !== ""
                                 ? userName.charAt(0).toUpperCase() + userName.slice(1)
                                 : "Usuario"
    property string avatarSource: ""
    property string backdropSource: ""
    property int avatarCandidateIndex: 0
    property int focusRequestSerial: 0
    property date currentDateTime: new Date()
    property string bannerSource: toFileUrl(homeDir + "/Imagens/evangelion_banner.jpg")

    readonly property string homeDir: String(Quickshell.env("HOME") || StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string avatarPreparedPath: "/tmp/quickshell-lock-avatar.png"
    readonly property string backdropRawPath: "/tmp/quickshell-lock-backdrop-raw.png"
    readonly property string backdropBlurredPath: "/tmp/quickshell-lock-backdrop.png"
    readonly property int revealDuration: 240
    readonly property string userInitial: displayName !== "" ? displayName.charAt(0).toUpperCase() : "U"
    readonly property string timeText: Qt.formatTime(currentDateTime, "HH:mm")
    readonly property string dateText: Qt.formatDate(currentDateTime, "dd/MM/yy")
    readonly property int desktopX: {
        if (Quickshell.screens.length === 0)
            return 0

        var minX = Quickshell.screens[0].x
        for (var i = 1; i < Quickshell.screens.length; i++)
            minX = Math.min(minX, Quickshell.screens[i].x)

        return minX
    }
    readonly property int desktopY: {
        if (Quickshell.screens.length === 0)
            return 0

        var minY = Quickshell.screens[0].y
        for (var i = 1; i < Quickshell.screens.length; i++)
            minY = Math.min(minY, Quickshell.screens[i].y)

        return minY
    }
    readonly property int desktopWidth: {
        if (Quickshell.screens.length === 0)
            return 1

        var maxX = Quickshell.screens[0].x + Quickshell.screens[0].width
        for (var i = 1; i < Quickshell.screens.length; i++)
            maxX = Math.max(maxX, Quickshell.screens[i].x + Quickshell.screens[i].width)

        return Math.max(1, maxX - desktopX)
    }
    readonly property int desktopHeight: {
        if (Quickshell.screens.length === 0)
            return 1

        var maxY = Quickshell.screens[0].y + Quickshell.screens[0].height
        for (var i = 1; i < Quickshell.screens.length; i++)
            maxY = Math.max(maxY, Quickshell.screens[i].y + Quickshell.screens[i].height)

        return Math.max(1, maxY - desktopY)
    }
    readonly property var avatarCandidatePaths: {
        var paths = []
        if (homeDir !== "") {
            paths.push(homeDir + "/.face")
            paths.push(homeDir + "/.face.icon")
        }

        if (userName !== "")
            paths.push("/var/lib/AccountsService/icons/" + userName)

        return paths
    }

    readonly property var actionsModel: [
        { title: "Desligar", icon: "󰐥", command: ["systemctl", "poweroff"] },
        { title: "Reiniciar", icon: "󰜉", command: ["systemctl", "reboot"] },
        { title: "Sair da sessao", icon: "󰍃", command: ["hyprctl", "dispatch", "exit"] },
        { title: "Suspender", icon: "󰤄", command: ["systemctl", "suspend"] }
    ]

    function toggle() {
        open()
    }

    function open() {
        if (sessionLock.locked || openPending || unlockTimer.running) {
            requestPasswordFocus()
            return
        }

        retryAuthTimer.stop()
        passwordText = ""
        authError = false
        authBusy = false
        holdAuthMessage = false
        authMessage = "Digite sua senha para desbloquear."
        backdropSource = ""
        openPending = true
        backdropCapture.command = [
            "sh",
            "-lc",
            "grim -t png \"$1\" && magick \"$1\" -colorspace Gray -filter Gaussian -resize 50% -blur 0x8 -resize 200% -brightness-contrast -16x-7 -modulate 86,58,100 -fill '#242a33' -colorize 16 \"$2\"",
            "_",
            backdropRawPath,
            backdropBlurredPath
        ]
        backdropCapture.running = true
    }

    function activateLock() {
        if (sessionLock.locked)
            return

        openPending = false
        lockOpen = true
        beginAuthentication()
        sessionLock.locked = true
        requestPasswordFocus()
    }

    function unlock() {
        if (!sessionLock.locked || unlockTimer.running)
            return

        lockOpen = false
        unlockTimer.start()
    }

    function finishClose() {
        retryAuthTimer.stop()
        if (pamContext.active)
            pamContext.abort()

        authBusy = false
        authError = false
        holdAuthMessage = false
        openPending = false
        lockOpen = false
        passwordText = ""
        authMessage = "Digite sua senha para desbloquear."
    }

    function requestPasswordFocus() {
        focusRequestSerial += 1
    }

    function toFileUrl(path) {
        return path !== "" ? "file://" + path : ""
    }

    function loadUserProfile() {
        resetAvatarSource()
        if (userName !== "") {
            profileLoader.command = ["getent", "passwd", userName]
            profileLoader.running = true
        }
    }

    function parseUserProfile(output) {
        var fields = output.trim().split(":")
        if (fields.length < 5)
            return

        var gecos = fields[4].split(",")[0].trim()
        if (gecos !== "")
            displayName = gecos
    }

    function resetAvatarSource() {
        avatarCandidateIndex = 0
        avatarSource = ""
        prepareAvatarSource()
    }

    function prepareAvatarSource() {
        if (avatarCandidateIndex >= avatarCandidatePaths.length) {
            avatarSource = ""
            return
        }

        avatarProbe.command = [
            "sh",
            "-lc",
            "candidate=\"$1\"; output=\"$2\"; [ -r \"$candidate\" ] && magick \"$candidate\" PNG:\"$output\"",
            "_",
            avatarCandidatePaths[avatarCandidateIndex],
            avatarPreparedPath
        ]
        avatarProbe.running = true
    }

    function advanceAvatarSource() {
        avatarCandidateIndex += 1
        prepareAvatarSource()
    }

    function beginAuthentication(preserveMessage) {
        if (pamContext.active)
            pamContext.abort()

        authBusy = false
        holdAuthMessage = preserveMessage === true
        if (!holdAuthMessage) {
            authError = false
            authMessage = "Digite sua senha para desbloquear."
        }

        if (!pamContext.start()) {
            authError = true
            holdAuthMessage = true
            authMessage = "Nao foi possivel iniciar a autenticacao."
        }
    }

    function submitPassword() {
        if (!pamContext.responseRequired || authBusy || passwordText === "")
            return

        var response = passwordText

        authBusy = true
        authError = false
        holdAuthMessage = false
        authMessage = "Verificando..."
        passwordText = ""
        pamContext.respond(response)
    }

    function syncPamState() {
        if (authBusy)
            return

        if (pamContext.responseRequired) {
            if (holdAuthMessage) {
                requestPasswordFocus()
                return
            }

            authError = pamContext.messageIsError
            authMessage = pamContext.messageIsError
                         ? (pamContext.message && pamContext.message !== ""
                            ? pamContext.message
                            : "Senha incorreta. Tente novamente.")
                         : "Digite sua senha para desbloquear."
            requestPasswordFocus()
            return
        }

        if (!holdAuthMessage && pamContext.message && pamContext.message !== "")
            authMessage = pamContext.message
    }

    function runAction(action) {
        if (!action || sessionAction.running)
            return

        sessionAction.command = action.command
        sessionAction.running = true
    }

    Component.onCompleted: loadUserProfile()

    PamContext {
        id: pamContext

        config: "login"
        user: root.userName

        onCompleted: function(result) {
            root.authBusy = false

            if (result === PamResult.Success) {
                root.authMessage = "Desbloqueando..."
                root.authError = false
                root.unlock()
                return
            }

            root.authError = true
            root.holdAuthMessage = true
            root.authMessage = result === PamResult.MaxTries
                               ? "Muitas tentativas. Tente novamente."
                               : "Senha incorreta. Tente novamente."
            retryAuthTimer.restart()
        }

        onError: function() {
            root.authBusy = false
            root.authError = true
            root.holdAuthMessage = true
            root.authMessage = "Falha ao autenticar."
            root.requestPasswordFocus()
        }

        onMessageChanged: root.syncPamState()
        onMessageIsErrorChanged: root.syncPamState()
        onResponseRequiredChanged: root.syncPamState()
    }

    Process {
        id: profileLoader

        running: false
        command: []
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseUserProfile(text)
        }
    }

    Process {
        id: avatarProbe

        running: false
        command: []

        onExited: function(exitCode) {
            if (running)
                return

            if (exitCode === 0) {
                root.avatarSource = root.toFileUrl(root.avatarPreparedPath) + "?t=" + Date.now()
                return
            }

            root.advanceAvatarSource()
        }
    }

    Process {
        id: sessionAction

        running: false
        command: []
    }

    Process {
        id: backdropCapture

        running: false
        command: []

        onExited: function(exitCode) {
            if (running)
                return

            root.backdropSource = exitCode === 0
                                  ? root.toFileUrl(root.backdropBlurredPath) + "?t=" + Date.now()
                                  : ""

            if (root.openPending)
                root.activateLock()
        }
    }

    Timer {
        id: clockTimer

        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentDateTime = new Date()
    }

    Timer {
        id: retryAuthTimer

        interval: 260
        repeat: false
        onTriggered: root.beginAuthentication(true)
    }

    Timer {
        id: unlockTimer

        interval: root.revealDuration
        repeat: false

        onTriggered: {
            if (sessionLock.locked)
                sessionLock.locked = false
            else
                root.finishClose()
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: false

        onLockStateChanged: {
            if (locked)
                return

            root.finishClose()
        }

        onSecureStateChanged: {
            if (secure && locked)
                root.requestPasswordFocus()
        }

        WlSessionLockSurface {
            id: lockSurface
            color: "#000000"
            property real revealProgress: 0
            readonly property real backdropProgress: (!root.lockOpen && unlockTimer.running) ? 1 : revealProgress

            Keys.priority: Keys.BeforeItem
            Keys.onEscapePressed: function(event) {
                event.accepted = true
            }

            Behavior on revealProgress {
                NumberAnimation {
                    duration: root.revealDuration
                    easing.type: Easing.OutCubic
                }
            }

            Timer {
                id: focusTimer
                property int attempts: 0

                interval: 35
                repeat: true

                onTriggered: {
                    if (!root.surfaceVisible || !root.lockOpen) {
                        stop()
                        attempts = 0
                        return
                    }

                    passwordInput.forceActiveFocus()
                    attempts += 1

                    if (passwordInput.activeFocus || attempts >= 6) {
                        stop()
                        attempts = 0
                    }
                }
            }

            Connections {
                target: root

                function onFocusRequestSerialChanged() {
                    if (root.surfaceVisible)
                        focusTimer.restart()
                }

                function onLockOpenChanged() {
                    lockSurface.revealProgress = root.lockOpen && lockSurface.visible ? 1 : 0

                    if (root.lockOpen && root.surfaceVisible)
                        focusTimer.restart()
                }
            }

            onVisibleChanged: {
                revealProgress = visible && root.lockOpen ? 1 : 0

                if (visible && root.lockOpen)
                    focusTimer.restart()
            }

            Rectangle {
                anchors.fill: parent
                color: "#b20d0f14"
                opacity: 0.9 * lockSurface.backdropProgress
            }

            Image {
                x: root.desktopX - lockSurface.screen.x
                y: root.desktopY - lockSurface.screen.y
                width: root.desktopWidth
                height: root.desktopHeight
                source: root.backdropSource
                visible: root.backdropSource !== ""
                asynchronous: true
                smooth: true
                mipmap: true
                fillMode: Image.Stretch
                opacity: 0.72 * lockSurface.backdropProgress
            }

            Rectangle {
                anchors.fill: parent
                color: "#66090b10"
                opacity: lockSurface.backdropProgress
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: passwordInput.forceActiveFocus()
            }

            Item {
                id: popup
                width: Math.min(620, lockSurface.width - 48)
                height: Math.min(740, lockSurface.height - 56)
                anchors.centerIn: parent
                transformOrigin: Item.Center
                opacity: lockSurface.revealProgress
                transform: Translate {
                    y: (1 - lockSurface.revealProgress) * 28
                }

                ClippingRectangle {
                    id: popupSurface
                    anchors.fill: parent
                    color: "transparent"
                    radius: theme.widgetRadius + 8
                    border.width: theme.widgetBorderWidth
                    border.color: theme.widgetBorderColor
                    antialiasing: true
                    contentUnderBorder: true

                    Image {
                        anchors.fill: parent
                        source: root.backdropSource
                        visible: root.backdropSource !== ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        opacity: 0.16
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.fundo }
                            GradientStop { position: 1.0; color: root.fundo2 }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#12ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: passwordInput.forceActiveFocus()
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 18

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 232

                            ClippingRectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 170
                                radius: 26
                                color: "#12000000"
                                antialiasing: true
                                contentUnderBorder: true

                                Image {
                                    anchors.fill: parent
                                    source: root.bannerSource
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#44000000"
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#22ffffff" }
                                        GradientStop { position: 1.0; color: "#06000000" }
                                    }
                                }

                                Rectangle {
                                    width: 156
                                    height: 80
                                    radius: 22
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 16
                                    anchors.rightMargin: 16
                                    color: "#16000000"
                                    border.width: 1
                                    border.color: "#24ffffff"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Item {
                                            width: lockClockText.implicitWidth
                                            height: lockClockText.implicitHeight + 2

                                            Text {
                                                id: lockClockText
                                                anchors.centerIn: parent
                                                text: root.timeText
                                                color: root.branco
                                                font.family: "Rubik"
                                                font.pixelSize: 30
                                                font.bold: true
                                                font.letterSpacing: 0.8
                                            }

                                            LinearGradient {
                                                anchors.fill: lockClockText
                                                source: lockClockText
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: "#ffffff" }
                                                    GradientStop { position: 1.0; color: "#a5a5a5" }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: root.dateText
                                            color: "#cfcfcf"
                                            font.family: "Rubik"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            ClippingRectangle {
                                width: 120
                                height: 120
                                radius: 60
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                color: "#18000000"
                                border.width: 2
                                border.color: "#24ffffff"
                                antialiasing: true
                                contentUnderBorder: true

                                Image {
                                    id: avatarImage
                                    anchors.fill: parent
                                    source: root.avatarSource
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false

                                    onStatusChanged: {
                                        if (status === Image.Error && root.avatarSource !== "")
                                            root.advanceAvatarSource()
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: avatarImage.status !== Image.Ready
                                    text: root.userInitial
                                    color: root.branco
                                    font.family: "Rubik"
                                    font.pixelSize: 40
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.displayName
                            color: root.branco
                            font.family: "Rubik"
                            font.pixelSize: 34
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "\"It all returns to nothing.\""
                            color: "#d6d6d6"
                            font.family: "Rubik"
                            font.pixelSize: 15
                            font.italic: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Item {
                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 380)
                                spacing: 12

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 56
                                    radius: 28
                                    color: root.pretoSuave
                                    antialiasing: true
                                    border.width: 1
                                    border.color: root.authError
                                                  ? "#48ff8585"
                                                  : passwordInput.activeFocus ? "#38ffffff" : "#18ffffff"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 18
                                        anchors.rightMargin: 18
                                        spacing: 12

                                        Text {
                                            text: "󰌾"
                                            color: root.branco
                                            font.family: "JetBrains Mono Nerd Font"
                                            font.pixelSize: 18
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: passwordInput.text.length === 0
                                                text: root.authBusy ? "Verificando..." : "Senha"
                                                color: "#8d8d8d"
                                                font.family: "Rubik"
                                                font.pixelSize: 14
                                            }

                                            TextInput {
                                                id: passwordInput
                                                anchors.fill: parent
                                                color: root.branco
                                                font.family: "Rubik"
                                                font.pixelSize: 14
                                                verticalAlignment: TextInput.AlignVCenter
                                                echoMode: TextInput.Password
                                                passwordMaskDelay: 0
                                                selectionColor: "#30ffffff"
                                                activeFocusOnPress: true
                                                enabled: pamContext.responseRequired && !root.authBusy

                                                Keys.priority: Keys.BeforeItem
                                                Keys.onEscapePressed: function(event) {
                                                    event.accepted = true
                                                }
                                                Keys.onReturnPressed: root.submitPassword()
                                                Keys.onEnterPressed: root.submitPassword()

                                                Component.onCompleted: text = root.passwordText

                                                Connections {
                                                    target: root

                                                    function onPasswordTextChanged() {
                                                        if (passwordInput.text !== root.passwordText)
                                                            passwordInput.text = root.passwordText
                                                    }
                                                }

                                                onTextEdited: {
                                                    if (root.passwordText !== text)
                                                        root.passwordText = text

                                                    if (root.authError || root.holdAuthMessage) {
                                                        root.authError = false
                                                        root.holdAuthMessage = false
                                                        root.authMessage = "Digite sua senha para desbloquear."
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.authMessage
                                    color: root.authError ? root.erro : root.cinza
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18

                            Repeater {
                                model: root.actionsModel

                                delegate: Rectangle {
                                    required property var modelData

                                    readonly property var action: modelData
                                    property bool hovered: actionArea.containsMouse

                                    width: 64
                                    height: 64
                                    radius: 32
                                    color: hovered ? root.destaque : "#0dffffff"
                                    antialiasing: true
                                    border.width: 1
                                    border.color: hovered ? "#34ffffff" : "#18ffffff"

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: action.icon
                                        color: root.branco
                                        font.family: "JetBrains Mono Nerd Font"
                                        font.pixelSize: 24
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runAction(action)
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
