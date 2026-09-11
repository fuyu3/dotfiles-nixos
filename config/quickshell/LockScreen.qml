import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Widgets
import QtCore
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Caelestia.Blobs
import M3Shapes

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

            // --- Arte de fundo: campo de blobs "lava lamp" espalhado pela
            // tela inteira + formas m3shapes variadas entre eles. Cada blob
            // deriva verticalmente (sobe/desce em ritmos diferentes) com um
            // pouco de wobble horizontal, e a física do BlobRect
            // (stiffness/damping/deformScale mais soltos que o padrão) faz
            // ele se espremer sozinho conforme se move — é isso que dá a
            // textura gelatinosa de lava lamp, não é só translação pura.
            Item {
                id: backgroundArt
                anchors.fill: parent
                opacity: 1 * lockSurface.backdropProgress
                visible: opacity > 0.01

                BlobGroup {
                    id: artGroup
                    color: root.destaque
                    smoothing: 18
                }

// Moldura da tela inteira, no mesmo grupo dos blobs para fundir com eles.
// O borderTop/Left/Right/Bottom define a espessura; o radius arredonda os
// cantos internos; quando um blob passa perto da borda interna, o smin do
// shader conecta os dois (é o mesmo mecanismo do toast colado na barra).
BlobInvertedRect {
    id: screenFrame

    anchors.fill: parent
    group: artGroup

    radius: 26                 // raio dos cantos
    borderTop: 6
    borderLeft: 6
    borderRight: 6
    borderBottom: 6

    // Se o seu BlobInvertedRect aceitar override de cor, use:
    // color: root.destaque
    // Senão, herda automaticamente do artGroup (que já é destaque).
}

                // Posições espalhadas de propósito por quadrantes diferentes
                // da tela (não cluster num canto só) — xPct/yPct em fração
                // da tela, amp = quanto o blob se desloca verticalmente,
                // dur = duração de um trecho da subida/descida.
                readonly property var lavaBlobs: [
                    { xPct: 0.08, yPct: 0.14, size: 210, dur: 13000, amp: 0.22 },
                    { xPct: 0.34, yPct: 0.78, size: 150, dur: 9500,  amp: 0.30 },
                    { xPct: 0.60, yPct: 0.22, size: 190, dur: 15000, amp: 0.18 },
                    { xPct: 0.82, yPct: 0.62, size: 130, dur: 8200,  amp: 0.34 },
                    { xPct: 0.16, yPct: 0.46, size: 100, dur: 11000, amp: 0.26 },
                    { xPct: 0.70, yPct: 0.90, size: 170, dur: 10200, amp: 0.20 },
                    { xPct: 0.92, yPct: 0.10, size: 120, dur: 9000,  amp: 0.28 },
                    { xPct: 0.46, yPct: 0.05, size: 150, dur: 12500, amp: 0.24 },
    { xPct: 0.55, yPct: 0.42, size: 140, dur: 11800, amp: 0.26 },   // centro-direita
    { xPct: 0.22, yPct: 0.92, size: 180, dur: 13500, amp: 0.22 },   // canto inferior-esquerdo
    { xPct: 0.80, yPct: 0.30, size: 110, dur: 8800,  amp: 0.30 },   // médio-direita
    { xPct: 0.42, yPct: 0.60, size: 160, dur: 14200, amp: 0.20 }    // centro

                ]

                Repeater {
                    model: backgroundArt.lavaBlobs

                    BlobRect {
                        id: lavaBlob
                        required property var modelData
                        required property int index

                        group: artGroup
                        width: modelData.size
                        height: modelData.size
                        topLeftRadius: width / 2
                        topRightRadius: width / 2
                        bottomLeftRadius: width / 2
                        bottomRightRadius: width / 2

                        // Física mais "gelatinosa" que o padrão do plugin —
                        // deixa o squish induzido pelo movimento bem visível.
                        stiffness: 70
                        damping: 12
                        deformScale: 0.0006

                        property real phaseX: 0
property real phaseY: 0

x: lockSurface.width * modelData.xPct + phaseX * lockSurface.width * 0.06
y: lockSurface.height * modelData.yPct + phaseY * lockSurface.height * modelData.amp

SequentialAnimation on phaseY {
    loops: Animation.Infinite
    PauseAnimation { duration: lavaBlob.index * 420 }
    NumberAnimation { to: 1;  duration: lavaBlob.modelData.dur;       easing.type: Easing.InOutSine }
    NumberAnimation { to: -0.6; duration: lavaBlob.modelData.dur * 1.15; easing.type: Easing.InOutSine }
}

SequentialAnimation on phaseX {
    loops: Animation.Infinite
    NumberAnimation { to: 1;  duration: lavaBlob.modelData.dur * 1.4; easing.type: Easing.InOutSine }
    NumberAnimation { to: -1; duration: lavaBlob.modelData.dur * 1.4; easing.type: Easing.InOutSine }
}
                    }
                }

                // Formas m3shapes espalhadas entre os blobs, com bem mais
                // variedade de contorno do que só Circle/Pill.
                readonly property var shapePool: [
                    MaterialShape.Circle, MaterialShape.Sunny, MaterialShape.Cookie9Sided,
                    MaterialShape.Clover4Leaf, MaterialShape.Flower, MaterialShape.Pill,
                    MaterialShape.Heart, MaterialShape.Gem, MaterialShape.Burst,
                    MaterialShape.PuffyDiamond, MaterialShape.Ghostish, MaterialShape.Oval
                ]

                readonly property var accentShapes: [
                    { xPct: 0.04, yPct: 0.32, size: 58 },
                    { xPct: 0.50, yPct: 0.86, size: 66 },
                    { xPct: 0.88, yPct: 0.36, size: 50 },
                    { xPct: 0.24, yPct: 0.06, size: 54 },
                    { xPct: 0.74, yPct: 0.80, size: 62 }
                ]

                Repeater {
                    model: backgroundArt.accentShapes

                    MaterialShape {
                        id: accentShape
                        required property var modelData
                        required property int index

                        property int shapeCursor: index

                        width: modelData.size
                        height: modelData.size
                        x: lockSurface.width * modelData.xPct
                        color: index % 2 === 0 ? root.fundo2 : root.destaque
                        opacity: 0.65
                        shape: backgroundArt.shapePool[shapeCursor % backgroundArt.shapePool.length]
                        animationDuration: 1200
                        animationEasing.type: Easing.InOutQuad                       

                        property real phaseY: 0
y: lockSurface.height * modelData.yPct + phaseY * lockSurface.height * 0.10
 
Timer {
                            interval: 2200 + accentShape.index * 350
                            running: true
                            repeat: true
                            onTriggered: accentShape.shapeCursor += 1
                        }

SequentialAnimation on phaseY {
    loops: Animation.Infinite
    NumberAnimation { to: 1;  duration: 9000 + accentShape.index * 700; easing.type: Easing.InOutSine }
    NumberAnimation { to: -1; duration: 9000 + accentShape.index * 700; easing.type: Easing.InOutSine }
}
                    }
                }
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
                opacity: 0.55 * lockSurface.backdropProgress
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

            RectangularGlow {
                anchors.fill: popup
                glowRadius: 28
                spread: 0.12
                color: "#40000000"
                cornerRadius: popupSurface.radius + 28
                opacity: lockSurface.revealProgress
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
                    radius: theme.widgetRadius + 16
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

                                delegate: MaterialShape {
    id: actionShape
    required property var modelData

    readonly property var action: modelData
    property bool hovered: actionArea.containsMouse
    property int shapeCursor: 0
    property real spinAngle: 0

    width: 64
    height: 64
    color: hovered ? root.destaque : "#0dffffff"
    shape: hovered ? backgroundArt.shapePool[shapeCursor % backgroundArt.shapePool.length]
                   : MaterialShape.Circle
    animationDuration: 260
    rotation: spinAngle

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    // Gira enquanto hovered: +3° a cada 16ms ≈ 187°/s
    Timer {
        interval: 16
        running: actionShape.hovered
        repeat: true
        onTriggered: actionShape.spinAngle += 3
    }

    // Volta ao estado "normal" ao sair do hover
    NumberAnimation {
        id: returnSpinAnim
        target: actionShape
        property: "spinAngle"
        to: 0
        duration: 420
        easing.type: Easing.OutCubic
    }

    // Troca de forma continuamente enquanto hovered
    Timer {
        interval: 700
        running: actionShape.hovered
        repeat: true
        onTriggered: actionShape.shapeCursor += 1
    }

    onHoveredChanged: {
        if (hovered) {
            returnSpinAnim.stop()
            // começa de uma forma aleatória para os 4 botões não ficarem sincronizados
            shapeCursor = Math.floor(Math.random() * backgroundArt.shapePool.length)
        } else {
            returnSpinAnim.restart()
        }
    }

    Text {
        anchors.centerIn: parent
        text: actionShape.action.icon
        color: root.branco
        font.family: "JetBrains Mono Nerd Font"
        font.pixelSize: 24
        // contra-rotação: o ícone fica em pé enquanto o botão gira
        rotation: -actionShape.spinAngle
    }

    MouseArea {
        id: actionArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.runAction(actionShape.action)
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
