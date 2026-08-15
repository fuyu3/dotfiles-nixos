import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property int powerSaverProfile: 0
    readonly property int balancedProfile: 1
    readonly property int performanceProfile: 2

    property bool tlpAvailable: false
    property bool tlpPowerProfilesAvailable: false
    property int tlpProfile: balancedProfile

    readonly property bool usingTlp: tlpAvailable
    readonly property int profile: usingTlp ? tlpProfile : fromPowerProfiles(PowerProfiles.profile)
    readonly property bool hasPerformanceProfile: !usingTlp && PowerProfiles.hasPerformanceProfile

    function labelFor(profile) {
        switch (profile) {
        case powerSaverProfile:
            return "Economia de energia"
        case performanceProfile:
            return "Performance"
        default:
            return "Equilibrado"
        }
    }

    function iconFor(profile) {
        switch (profile) {
        case powerSaverProfile:
            return ""
        case performanceProfile:
            return ""
        default:
            return ""
        }
    }

    function availableProfiles() {
        if (usingTlp) {
            var tlpProfiles = [powerSaverProfile, balancedProfile]
            if (tlpPowerProfilesAvailable)
                tlpProfiles.push(performanceProfile)
            return tlpProfiles
        }

        var profiles = [powerSaverProfile, balancedProfile]
        if (PowerProfiles.hasPerformanceProfile)
            profiles.push(performanceProfile)
        return profiles
    }

    function indexFor(profile) {
        var profiles = availableProfiles()
        for (var i = 0; i < profiles.length; i++) {
            if (profiles[i] === profile)
                return i
        }
        return -1
    }

    function cycle(step) {
        var profiles = availableProfiles()
        if (profiles.length === 0)
            return

        var currentIndex = indexFor(profile)
        if (currentIndex < 0)
            currentIndex = 0

        setProfile(profiles[(currentIndex + step + profiles.length) % profiles.length])
    }

    function setProfile(profile) {
        if (usingTlp) {
            tlpSetProc.requestedProfile = profile
            tlpSetProc.command = ["tlp", tlpCommandFor(profile)]
            tlpProfile = profile
            tlpSetProc.running = true
            return
        }

        PowerProfiles.profile = toPowerProfiles(profile)
    }

    function tlpCommandFor(profile) {
        if (!tlpPowerProfilesAvailable)
            return profile === powerSaverProfile ? "bat" : "ac"

        switch (profile) {
        case powerSaverProfile:
            return "power-saver"
        case performanceProfile:
            return "performance"
        default:
            return "balanced"
        }
    }

    function refresh() {
        if (usingTlp && !tlpStatusProc.running)
            tlpStatusProc.running = true
    }

    function fromPowerProfiles(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return powerSaverProfile
        case PowerProfile.Performance:
            return performanceProfile
        default:
            return balancedProfile
        }
    }

    function toPowerProfiles(profile) {
        switch (profile) {
        case powerSaverProfile:
            return PowerProfile.PowerSaver
        case performanceProfile:
            return PowerProfile.Performance
        default:
            return PowerProfile.Balanced
        }
    }

    function parseTlpStatus(text) {
        var status = String(text)
        var profileMatch = status.match(/Power\s+profile\s*=\s*([^/\n]+)(?:\/(AC|BAT))?/i)
        if (profileMatch) {
            var profileName = profileMatch[1].trim().toLowerCase()
            if (profileName === "performance") {
                tlpProfile = performanceProfile
                return
            }

            if (profileName === "power-saver" || profileName === "low-power") {
                tlpProfile = powerSaverProfile
                return
            }

            if (profileName === "balanced") {
                tlpProfile = balancedProfile
                return
            }

            if (profileMatch[2])
                tlpProfile = profileMatch[2].toUpperCase() === "BAT" ? powerSaverProfile : balancedProfile
            return
        }

        if (/Mode\s*=\s*BAT/i.test(status)) {
            tlpProfile = powerSaverProfile
            return
        }

        if (/Mode\s*=\s*AC/i.test(status))
            tlpProfile = balancedProfile
    }

    Component.onCompleted: tlpDetectProc.running = true

    Timer {
        interval: 10000
        running: root.usingTlp
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: tlpDetectProc
        command: ["sh", "-c", "if ! command -v tlp >/dev/null 2>&1; then echo no; elif tlp --help 2>&1 | grep -Eq 'power-saver|performance|balanced'; then echo profiles; else echo simple; fi"]
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var mode = String(text).trim()
                root.tlpAvailable = mode !== "no"
                root.tlpPowerProfilesAvailable = mode === "profiles"
                root.refresh()
            }
        }
    }

    Process {
        id: tlpStatusProc
        command: ["tlp-stat", "-s"]
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseTlpStatus(text)
        }
    }

    Process {
        id: tlpSetProc
        property int requestedProfile: root.balancedProfile

        command: []
        running: false
        onExited: root.refresh()
    }
}
