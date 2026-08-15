import QtQuick

Rectangle {
    id: root

    property string label: ""
    property color fillColor: "transparent"
    property color borderColor: "transparent"
    property color textColor: "#ffffff"
    property string fontFamily: "Rubik"
    property int fontPixelSize: 11
    readonly property bool hovered: area.containsMouse

    signal clicked()
    signal wheelStep(int step)

    implicitWidth: Math.max(20, profileLabel.implicitWidth + 8)
    implicitHeight: 20
    radius: 10
    color: fillColor
    border.color: borderColor
    border.width: 1
    antialiasing: true

    Text {
        id: profileLabel
        anchors.centerIn: parent
        text: root.label
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.bold: true
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: function(event) {
            var step = event.angleDelta.y > 0 ? 1 : -1
            root.wheelStep(step)
        }
    }
}
