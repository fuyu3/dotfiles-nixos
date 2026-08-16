import Quickshell
import Quickshell.Io
import QtCore
import QtQuick
import "." as ShellComponents

ShellRoot {
    id: shell
    property bool useHorizontalBar: true
    property bool renderBar: true
    property bool autoDetectBattery: true
    property bool showBatteryIcon: true
    property string pendingWallpaperSyncPath: ""
    readonly property string homeDir: String(Quickshell.env("HOME") || StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string wallpaperSyncScript: homeDir + "/.config/hypr/apply-wallpaper-theme.sh"
    readonly property int notificationTopOffset: useHorizontalBar ? 50 : 0
    readonly property string wallpaperPath: wallpaperStore.wallpaperPath

    function normalizeWallpaperPath(path) {
        var value = path === undefined || path === null ? "" : String(path).trim()
        if (value.indexOf("file://") === 0)
            return value.slice(7)

        return value
    }

    function requestWallpaperSync(path) {
        var normalized = normalizeWallpaperPath(path)
        if (normalized === "")
            return

        pendingWallpaperSyncPath = normalized
        if (!wallpaperSyncProcess.running)
            startWallpaperSync()
    }

    function startWallpaperSync() {
        if (pendingWallpaperSyncPath === "")
            return

        wallpaperSyncProcess.requestedWallpaperPath = pendingWallpaperSyncPath
        wallpaperSyncProcess.command = [wallpaperSyncScript, pendingWallpaperSyncPath]
        pendingWallpaperSyncPath = ""
        wallpaperSyncProcess.running = true
    }

    function setWallpaper(path) {
        var normalized = normalizeWallpaperPath(path)
        wallpaperStore.wallpaperPath = normalized
        requestWallpaperSync(normalized)
    }

    function clearWallpaper() {
        wallpaperStore.wallpaperPath = ""
    }

    Settings {
        id: wallpaperStore
        category: "wallpaper"
        location: "file://" + Quickshell.stateDir + "/wallpaper.ini"
        property string wallpaperPath: ""
    }

    Process {
        id: wallpaperSyncProcess
        property string requestedWallpaperPath: ""

        running: false
        command: []

        onExited: function() {
            if (running)
                return

            if (shell.pendingWallpaperSyncPath !== ""
                    && shell.pendingWallpaperSyncPath !== requestedWallpaperPath)
                shell.startWallpaperSync()
        }
    }

    LazyLoader {
        active: shell.renderBar && shell.useHorizontalBar

        BarHorizontal {
            autoDetectBattery: shell.autoDetectBattery
            showBatteryIcon: shell.showBatteryIcon
        }
    }

    LazyLoader {
        active: shell.renderBar && !shell.useHorizontalBar

        Bar {
            autoDetectBattery: shell.autoDetectBattery
            showBatteryIcon: shell.showBatteryIcon
        }
    }

    Workspaces {
        id: workspacesWidget
    }
    NotifToast {
        lockActive: lockScreen.lockActive
        topOffset: shell.notificationTopOffset
    }
    NotificationCenter {
        lockActive: lockScreen.lockActive
        topOffset: shell.notificationTopOffset
    }
    AppLauncher {
        id:appLauncher
    }
    WallpaperPicker {
        id: wallpaperPicker
        wallpaperController: shell
    }
    ClipboardViewer {
        id: clipboardViewer
    }
    LockScreen {
        id: lockScreen
    }

    IpcHandler {
        target: "appLauncher"
        function toggle(): void { appLauncher.toggle() }
    }

    IpcHandler {
        target: "workspacesWidget"
        function toggle(): void { workspacesWidget.toggle() }
        function open(): void { workspacesWidget.open() }
        function close(): void { workspacesWidget.close() }
    }

    IpcHandler {
        target: "wallpaperPicker"
        function toggle(): void { wallpaperPicker.toggle() }
        function open(): void { wallpaperPicker.open() }
        function close(): void { wallpaperPicker.close() }
    }

    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { shell.setWallpaper(path) }
        function clear(): void { shell.clearWallpaper() }
    }

    IpcHandler {
        target: "clipboardViewer"
        function toggle(): void { clipboardViewer.toggle() }
        function open(): void { clipboardViewer.open() }
        function close(): void { clipboardViewer.close() }
    }

    IpcHandler {
        target: "notificationCenter"
        function toggle(): void { ShellComponents.NotifServer.toggleCenter() }
        function open(): void {
            if (!ShellComponents.NotifServer.centerVisible)
                ShellComponents.NotifServer.toggleCenter()
        }
        function close(): void {
            if (ShellComponents.NotifServer.centerVisible)
                ShellComponents.NotifServer.toggleCenter()
        }
        function unreadCount(): int { return ShellComponents.NotifServer.unreadCount }
    }

    IpcHandler {
        target: "lockScreen"
        function open(): void { lockScreen.open() }
        function toggle(): void { lockScreen.open() }
    }

    Component.onCompleted: {
        if (wallpaperPath !== "")
            requestWallpaperSync(wallpaperPath)
    }
}
