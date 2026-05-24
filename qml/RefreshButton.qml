import QtQuick

Item {
    id: control
    width: 24
    height: 24

    signal clicked()

    property bool spinning: false

    onSpinningChanged: {
        if (spinning) {
            bounceAnim.restart();
        } else {
            bounceAnim.stop();
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

        SequentialAnimation {
            id: bounceAnim
            loops: 1

            RotationAnimation {
                target: iconText
                from: 0
                to: 45
                duration: 180
                easing.type: Easing.OutQuad
            }
            RotationAnimation {
                target: iconText
                from: 45
                to: 0
                duration: 180
                easing.type: Easing.InQuad
            }
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
