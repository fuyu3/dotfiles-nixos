import QtQuick
import Quickshell.Services.UPower

Item {
    id: root

    property bool vertical: false
    property bool autoDetect: true
    property bool showWhenManual: false
    property bool showPercentage: true
    property color foregroundColor: "#ffffff"
    property color mutedColor: "#a8a8a8"
    property string fontFamily: "Rubik"
    property int textPixelSize: vertical ? 7 : 8

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool detectedBatteryPresent: batteryDevice
        && batteryDevice.ready
        && batteryDevice.type === UPowerDeviceType.Battery
        && batteryDevice.isPresent
    readonly property real rawPercent: hasLiveData ? Number(batteryDevice.percentage) : 0
    readonly property real normalizedPercent: {
        if (!hasLiveData || !isFinite(rawPercent))
            return 50

        var scaled = rawPercent <= 1 ? rawPercent * 100 : rawPercent
        return Math.max(0, Math.min(100, scaled))
    }
    readonly property bool indicatorVisible: autoDetect ? detectedBatteryPresent : showWhenManual
    readonly property bool hasLiveData: detectedBatteryPresent
    readonly property int displayPercent: Math.round(normalizedPercent)
    readonly property bool charging: hasLiveData
        && (batteryDevice.state === UPowerDeviceState.Charging
            || batteryDevice.state === UPowerDeviceState.PendingCharge)
    readonly property color fillColor: !hasLiveData
        ? "#70ffffff"
        : charging
            ? "#7bd5ff"
            : displayPercent <= 15
                ? "#ff7b7b"
                : displayPercent <= 35
                    ? "#ffcb7d"
                    : "#b7f5d3"
    readonly property color badgeColor: !hasLiveData
        ? "#7a8a8a8a"
        : charging
            ? "#53aefc"
            : displayPercent <= 10
                ? "#ff4d4d"
                : displayPercent <= 25
                    ? "#ff8c42"
                    : displayPercent <= 50
                        ? "#ffb347"
                        : "#4fd18b"
    readonly property string badgeText: showPercentage
        ? (hasLiveData ? displayPercent + "%" : "?")
        : ""

    visible: indicatorVisible
    implicitWidth: Math.max(22, badgeBubble.visible ? badgeBubble.width + 6 : 22)
    implicitHeight: 22
    width: visible ? implicitWidth : 0
    height: visible ? implicitHeight : 0

    component BatteryGlyph: Item {
        width: 20
        height: 12

        Rectangle {
            id: batteryBody
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17
            height: 12
            radius: 3
            color: "transparent"
            border.color: root.foregroundColor
            border.width: 1
            antialiasing: true
        }

        Rectangle {
            anchors.left: batteryBody.left
            anchors.leftMargin: 2
            anchors.verticalCenter: batteryBody.verticalCenter
            width: Math.max(0, Math.round((batteryBody.width - 4) * root.displayPercent / 100))
            height: batteryBody.height - 4
            radius: 2
            color: root.fillColor
            antialiasing: true
        }

        Rectangle {
            anchors.left: batteryBody.right
            anchors.leftMargin: 1
            anchors.verticalCenter: batteryBody.verticalCenter
            width: 2
            height: 4
            radius: 1
            color: root.foregroundColor
            opacity: 0.8
            antialiasing: true
        }
    }

    BatteryGlyph {
        id: batteryIcon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
    }

    Rectangle {
        id: badgeBubble
        visible: root.badgeText !== ""
        anchors.top: parent.top
        anchors.right: parent.right
        width: Math.max(16, badgeLabel.implicitWidth + 8)
        height: 16
        radius: height / 2
        color: root.badgeColor
        border.color: "#22ffffff"
        border.width: 1
        antialiasing: true

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.badgeText
            color: "#ffffff"
            font.family: root.fontFamily
            font.pixelSize: root.textPixelSize
            font.bold: true
        }
    }
}
