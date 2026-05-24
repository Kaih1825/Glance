import QtQuick

Item {
    id: control
    width: 24
    height: 24

    signal clicked()

    property bool spinning: false

    onSpinningChanged: {
        if (spinning) {
            spinAnim.restart();
        } else {
            spinAnim.stop();
            iconText.rotation = 0;
        }
    }

    Text {
        id: iconText
        text: "\ue5d5" // refresh
        font.family: "Material Icons"
        font.pixelSize: 18
        color: mouseArea.containsMouse ? "white" : "#89FFFFFF"
        anchors.centerIn: parent
        transformOrigin: Item.Center

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        RotationAnimation {
            id: spinAnim
            target: iconText
            from: 0
            to: 360
            duration: 800
            loops: Animation.Infinite
            easing.type: Easing.Linear
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }
}
