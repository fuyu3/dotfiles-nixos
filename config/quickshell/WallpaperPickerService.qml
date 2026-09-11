pragma Singleton
import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Singleton {
    id: root

    property bool open: false
    property bool loadingWallpapers: false
    property var allWallpapers: []
    property var wallpaperController: null
    property string searchQuery: ""
    property int selectedIndex: -1

    readonly property string homeDir: String(
        Quickshell.env("HOME") ||
        StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string picturesDir: homeDir + "/Imagens"
    readonly property string activeWallpaperPath: wallpaperController && wallpaperController.wallpaperPath
                                                 ? String(wallpaperController.wallpaperPath)
                                                 : ""
    readonly property string normalizedSearchQuery: searchQuery.trim().toLowerCase()
    readonly property string resultsSummary: loadingWallpapers && allWallpapers.length === 0
                                           ? "Carregando wallpapers..."
                                           : filteredWallpapers.length + " resultado"
                                             + (filteredWallpapers.length === 1 ? "" : "s")

    property var filteredWallpapers: {
        var query = normalizedSearchQuery
        if (query === "")
            return allWallpapers
        return allWallpapers.filter(function(wallpaper) {
            return wallpaper.searchText.indexOf(query) !== -1
        })
    }

    function toggle() { open ? close() : show() }
    function show()   { open = true; clearSearch(); reloadWallpapers() }
    function close()  { open = false; selectedIndex = -1; clearSearch() }

    function clearSearch() { searchQuery = "" }

    function fileNameForPath(path) {
        return path.substring(path.lastIndexOf("/") + 1)
    }

    function relativePathFor(path) {
        if (path.indexOf(picturesDir + "/") === 0)
            return "~/" + path.substring(homeDir.length + 1)
        return path
    }

    function indexForWallpaperPath(path, wallpapers) {
        if (path === "") return -1
        var items = wallpapers || filteredWallpapers
        for (var i = 0; i < items.length; i++)
            if (items[i].path === path) return i
        return -1
    }

    function syncSelection() {
        if (filteredWallpapers.length === 0) {
            selectedIndex = -1
            return
        }
        if (selectedIndex < 0 || selectedIndex >= filteredWallpapers.length) {
            var activeIndex = indexForWallpaperPath(activeWallpaperPath, filteredWallpapers)
            selectedIndex = activeIndex >= 0 ? activeIndex : 0
        }
    }

    function selectIndex(index) {
        if (index < 0 || index >= filteredWallpapers.length) return
        selectedIndex = index
    }

    function moveSelection(step) {
        if (filteredWallpapers.length === 0) return
        var next = selectedIndex < 0 ? 0 : selectedIndex + step
        selectIndex(Math.max(0, Math.min(filteredWallpapers.length - 1, next)))
    }

    function applyCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filteredWallpapers.length)
            applyWallpaper(filteredWallpapers[selectedIndex])
    }

    function applyWallpaper(wallpaper) {
        if (!wallpaper || !wallpaper.path) return
        if (wallpaperController && wallpaperController.setWallpaper)
            wallpaperController.setWallpaper(wallpaper.path)
        close()
    }

    function handleWallpaperOutput(output) {
        var lines = output.split("\n")
        var wallpapers = []
        for (var i = 0; i < lines.length; i++) {
            var path = lines[i].trim()
            if (path === "") continue
            var name = fileNameForPath(path)
            var relativePath = relativePathFor(path)
            wallpapers.push({
                path: path,
                name: name,
                relativePath: relativePath,
                searchText: (name + "\n" + relativePath).toLowerCase()
            })
        }
        wallpapers.sort(function(a, b) { return a.name.localeCompare(b.name) })
        allWallpapers = wallpapers
        loadingWallpapers = false
        syncSelection()
    }

    function reloadWallpapers() {
        loadingWallpapers = true
        wallpaperScanner.command = [
            "find", picturesDir, "-type", "f",
            "(", "-iname", "*.jpg",
                 "-o", "-iname", "*.jpeg",
                 "-o", "-iname", "*.png",
                 "-o", "-iname", "*.webp",
                 "-o", "-iname", "*.bmp",
                 "-o", "-iname", "*.gif", ")"
        ]
        wallpaperScanner.running = true
    }

    onFilteredWallpapersChanged: syncSelection()
    onActiveWallpaperPathChanged: {
        var activeIndex = indexForWallpaperPath(activeWallpaperPath, filteredWallpapers)
        if (activeIndex >= 0)
            selectIndex(activeIndex)
    }

    Process {
        id: wallpaperScanner
        running: false
        command: []
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleWallpaperOutput(text)
        }
        onExited: { if (!running) root.loadingWallpapers = false }
    }
}