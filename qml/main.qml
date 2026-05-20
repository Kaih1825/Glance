import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

ApplicationWindow {
    visible: true
    width: 1024
    height: 600
    title: "玄關智慧中樞"
    color: '#d5212121'
    minimumWidth: 1024
    minimumHeight: 600
    maximumWidth: 1024
    maximumHeight: 600

    Item {
        id: rootContent
        anchors.fill: parent

        property real popupOpacity: Math.max(settingsDialog.opacity, registerDialog.opacity)

        layer.enabled: settingsDialog.visible || registerDialog.visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: rootContent.popupOpacity
            colorization: rootContent.popupOpacity * 0.6
            colorizationColor: "#000000"
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 40
            spacing: 40

            LeftPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            RightPanel {
                id: rightPanel
                Layout.preferredWidth: panelWidth
                Layout.fillHeight: true
                clip: true

                property int panelWidth: 0

                Behavior on panelWidth {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 32
            spacing: 16

            RoundButton {
                text: "⚙️"
                width: 52
                height: 52
                font.pixelSize: 22
                scale: pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? "#33FFFFFF" : (parent.hovered ? "#26FFFFFF" : "#1AFFFFFF")
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                onClicked: settingsDialog.openSettings()
            }

            RoundButton {
                text: "🥸"
                width: 52
                height: 52
                font.pixelSize: 22
                scale: pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? "#66FFFFFF" : (parent.hovered ? "#4CFFFFFF" : "#33FFFFFF")
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                onClicked: backend.toggle_demo()
            }

            RoundButton {
                id: registerButton
                width: 52
                height: 52
                scale: pressed ? 0.9 : 1.0
                anchors.horizontalCenter: parent.horizontalCenter
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                
                contentItem: Item {
                    Text {
                        text: "+"
                        font.pixelSize: 28
                        color: "#FFFFFF"
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -3
                    }
                }

                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? "#66FFFFFF" : (parent.hovered ? "#4CFFFFFF" : "#33FFFFFF")
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                onClicked: openRegisterDialog()
            }
        }
    }


    SettingsDialog {
        id: settingsDialog
        anchors.centerIn: parent
    }

    RegisterDialog {
        id: registerDialog
        anchors.centerIn: parent
    }

    Connections {
        target: backend
        function onModeChanged(mode, users) {
            if (mode === "idle") {
                rightPanel.panelWidth = 0;
            } else {
                rightPanel.setupUser(mode, users);
                rightPanel.panelWidth = 460;
            }
        }
        function onRebuildStarted() {
            rightPanel.showRebuilding = true;
        }
        function onRebuildDone() {
            rightPanel.showRebuilding = false;
            registerDialog.close();
        }
    }

    function openRegisterDialog() {
        registerDialog.openDialog();
    }
}
