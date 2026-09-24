import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Wallust writes this file atomically whenever the wallpaper changes. Keep
    // the fallback palette so the shell remains usable before its first run.
    readonly property string wallustPalettePath: String(Quickshell.env("HOME")) + "/.cache/wallust-quickshell.json"
    readonly property var fallbackPalette: ({
        background: '#ee15ca',
        foreground: "#FDB8DC",
        surface: "#413A3F",
        accent: "#C3145A",
        accentStrong: "#F8359C",
        muted: "#AA668A"
    })
    readonly property var palette: parsePalette(wallustPalette.text())

    function parsePalette(text) {
        try {
            var parsed = JSON.parse(text)
            return parsed && typeof parsed === "object" ? parsed : fallbackPalette
        } catch (error) {
            return fallbackPalette
        }
    }

    function colorFromPalette(name) {
        var value = palette[name]
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)
            ? value : fallbackPalette[name]
    }

    function withAlpha(color, alpha) {
        return "#" + alpha + color.slice(1)
    }

    property QtObject wallustPalette: FileView {
        id: wallustPaletteFile
        path: root.wallustPalettePath
        printErrors: false
        watchChanges: true
        onFileChanged: wallustPaletteFile.reload()
    }

    property real widgetRadius: 20
    readonly property color neutralTextMuted: colorFromPalette("muted")
    readonly property color glassSubtle: withAlpha(colorFromPalette("foreground"), "12")
    readonly property color glassHover: withAlpha(colorFromPalette("foreground"), "18")
    readonly property color glassAccent: withAlpha(colorFromPalette("accent"), "20")
    readonly property color glassAccentStrong: withAlpha(colorFromPalette("accentStrong"), "36")
    readonly property color glassCard: withAlpha(colorFromPalette("foreground"), "1e")
    readonly property color glassDanger: "#24ff8585"
    readonly property color glassSuccess: "#269be3b0"
    readonly property color panelInset: "#14000000"
    readonly property color chipInset: "#16000000"
    readonly property color optionFill: "#0dffffff"

    property color widgetBorderColor: glassSubtle
    property int widgetBorderWidth: 0
    readonly property color fundo: colorFromPalette("background")
    readonly property color fundo2: withAlpha(colorFromPalette("background"), "80")
    readonly property color fundo3: colorFromPalette("accent")
    readonly property color branco: colorFromPalette("foreground")
    readonly property color branco2: withAlpha(colorFromPalette("foreground"), "80")
    readonly property color desativado: colorFromPalette("muted")
    readonly property color cinzaWorkspace: colorFromPalette("muted")
    readonly property color pretoSuave: "#b0000000"
    readonly property color erro: "#ff8585"
    readonly property color separator: colorFromPalette("accentStrong")

    readonly property color popupShadow: "#32000000"
    readonly property color popupFill: "#d9161616"
    readonly property color workspaceDrop: "#24ff8800"

    readonly property color sucesso: "#9be3b0"
    readonly property color alerta: "#ffd782"
}
