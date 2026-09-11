pragma Singleton
import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

Scope {
    id: root

    property bool open: false
    property var allApps: []
    property var usageCounts: ({})
    property string searchQuery: ""
    property int selectedIndex: -1
    property string normalizedSearchQuery: searchQuery.trim().toLowerCase()
    readonly property bool loadingApps: allApps.length === 0
    readonly property string resultsSummary: loadingApps
        ? "Carregando aplicativos..."
        : filteredApps.length + " resultado" + (filteredApps.length === 1 ? "" : "s")

    property var filteredApps: {
        var query = normalizedSearchQuery
        if (query === "")
            return allApps
        return allApps.filter(function(app) {
            return app.searchText.indexOf(query) !== -1
        })
    }

    function toggle() { open ? close() : show() }

    function show() {
        if (loadingApps)
            rebuildApps()
        searchQuery = ""
        selectedIndex = allApps.length > 0 ? 0 : -1
        open = true
        syncSelection()
    }

    function close() {
        open = false
        searchQuery = ""
        selectedIndex = -1
    }

    function selectIndex(i) {
        if (i < 0 || i >= filteredApps.length) return
        selectedIndex = i
    }

    function moveSelection(step) {
        if (filteredApps.length === 0) return
        var next = selectedIndex < 0 ? 0 : selectedIndex + step
        next = Math.max(0, Math.min(filteredApps.length - 1, next))
        selectIndex(next)
    }

    function syncSelection() {
        if (filteredApps.length === 0) { selectedIndex = -1; return }
        if (selectedIndex < 0 || selectedIndex >= filteredApps.length)
            selectedIndex = 0
    }

    function launchCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length)
            launch(filteredApps[selectedIndex])
    }

    function launch(app) {
        if (!app) return
        rememberLaunch(app)
        var entry = app.id ? DesktopEntries.byId(app.id) : null
        if (entry) { entry.execute(); close(); return }
        if (!app.command || app.command.length === 0) return
        launcher.command = app.command
        launcher.running = true
        close()
    }

    function usageKey(app) { return app && (app.id || app.name) ? (app.id || app.name) : "" }

    function usageCount(app) {
        var key = usageKey(app)
        return key !== "" && usageCounts[key] ? usageCounts[key] : 0
    }

    function compareApps(a, b) {
        var diff = usageCount(b) - usageCount(a)
        return diff !== 0 ? diff : a.name.localeCompare(b.name)
    }

    function rememberLaunch(app) {
        var key = usageKey(app)
        if (key === "") return
        var next = {}
        for (var k in usageCounts) next[k] = usageCounts[k]
        next[key] = (next[key] || 0) + 1
        usageCounts = next
        usageStore.usageData = JSON.stringify(next)
        rebuildApps()
    }

    function loadUsage() {
        try {
            usageCounts = usageStore.usageData ? JSON.parse(usageStore.usageData) : {}
        } catch (e) {
            usageCounts = {}
            usageStore.usageData = "{}"
        }
    }

    function resolveIcon(name) {
        if (!name || name === "")
            return Quickshell.iconPath("application-x-executable")
        if (name.indexOf("/") === 0)
            return "file://" + name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    function rebuildApps() {
        var list = []
        var model = DesktopEntries.applications
        var entries = model && model.values ? model.values : []
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            if (!entry || !entry.name || entry.noDisplay) continue
            var name = entry.name || ""
            var genericName = entry.genericName || ""
            var comment = entry.comment || ""
            var cmd = []
            if (entry.command)
                for (var j = 0; j < entry.command.length; j++)
                    cmd.push(entry.command[j])
            list.push({
                id: entry.id || "",
                name: name,
                iconPath: resolveIcon(entry.icon || ""),
                genericName: genericName,
                comment: comment,
                searchText: [name, genericName, comment].join("\n").toLowerCase(),
                command: cmd
            })
        }
        list.sort(compareApps)
        allApps = list
        syncSelection()
    }

    onFilteredAppsChanged: syncSelection()
    onSearchQueryChanged: syncSelection()

    Component.onCompleted: {
        loadUsage()
        rebuildApps()
    }

    Settings {
        id: usageStore
        category: "appLauncher"
        location: "file://" + Quickshell.stateDir + "/app-launcher.ini"
        property string usageData: "{}"
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.rebuildApps() }
    }

    Connections {
        target: DesktopEntries.applications
        ignoreUnknownSignals: true
        function onValuesChanged() { root.rebuildApps() }
        function onObjectInsertedPost() { root.rebuildApps() }
        function onObjectRemovedPost() { root.rebuildApps() }
    }

    Process {
        id: launcher
        running: false
        command: []
    }
}