pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool open: false
    property bool loadingEntries: false
    property var allEntries: []
    property string searchQuery: ""
    property int selectedIndex: -1

    readonly property string normalizedSearchQuery: searchQuery.trim().toLowerCase()
    readonly property string resultsSummary: loadingEntries && allEntries.length === 0
                                           ? "Carregando histórico..."
                                           : filteredEntries.length + " item" + (filteredEntries.length === 1 ? "" : "s")

    property var filteredEntries: {
        var query = normalizedSearchQuery
        if (query === "")
            return allEntries
        return allEntries.filter(function(entry) {
            return entry.searchText.indexOf(query) !== -1
        })
    }

    function toggle()      { open ? close() : openViewer() }
    function openViewer()  { open = true; clearSearch(); reloadEntries() }
    function close()       { open = false }
    function clearSearch() { searchQuery = "" }

    function syncSelection() {
        if (filteredEntries.length === 0) {
            selectedIndex = -1
            return
        }
        if (selectedIndex < 0 || selectedIndex >= filteredEntries.length)
            selectedIndex = 0
    }

    function selectIndex(index) {
        if (index < 0 || index >= filteredEntries.length) return
        selectedIndex = index
    }

    function moveSelection(step) {
        if (filteredEntries.length === 0) return
        var next = selectedIndex < 0 ? 0 : selectedIndex + step
        selectIndex(Math.max(0, Math.min(filteredEntries.length - 1, next)))
    }

    function restoreCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filteredEntries.length)
            restoreEntry(filteredEntries[selectedIndex])
    }

    function iconTextFor(entry)     { return !entry ? "⧉" : (entry.binary ? "◫" : "⧉") }
    function titleFor(entry)        { return !entry ? "" : entry.preview }
    function subtitleFor(entry)     { return !entry ? "" : (entry.binary ? "Conteúdo binário" : "#" + entry.id) }

    function restoreEntry(entry) {
        if (!entry) return
        clipboardSetter.command = ["bash", "-lc", "cliphist decode \"$1\" | wl-copy", "_", String(entry.id)]
        clipboardSetter.running = true
        close()
    }

    function handleEntriesOutput(output) {
        var lines = output.split("\n")
        var entries = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.trim() === "") continue
            var tabIndex = line.indexOf("\t")
            if (tabIndex === -1) continue
            var id = line.substring(0, tabIndex)
            var preview = line.substring(tabIndex + 1)
            entries.push({
                id: id,
                preview: preview,
                binary: preview.indexOf("[[ binary data") === 0,
                searchText: (id + "\n" + preview).toLowerCase()
            })
        }
        allEntries = entries
        loadingEntries = false
        syncSelection()
    }

    function reloadEntries() {
        loadingEntries = true
        clipboardScanner.command = ["cliphist", "list"]
        clipboardScanner.running = true
    }

    onFilteredEntriesChanged: syncSelection()

    Process {
        id: clipboardScanner
        running: false
        command: []
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleEntriesOutput(text)
        }
        onExited: { if (!running) root.loadingEntries = false }
    }

    Process {
        id: clipboardSetter
        running: false
        command: []
    }
}