import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

ApplicationWindow {
    visible: true
    width: 1200
    height: 700
    title: "玄關智慧中樞"
    color: '#0D1117'
    minimumWidth: 1000
    minimumHeight: 700

    FontLoader {
        id: materialFont
        source: "fonts/MaterialIcons-Regular.ttf"
    }

    Item {
        id: rootContent
        anchors.fill: parent

        property string currentMode: "idle"
        property var currentUsers: []
        property real popupOpacity: Math.max(settingsDialog.opacity,
                                    Math.max(registerDialog.opacity,
                                    Math.max(addEventDialog.opacity, locationSetupDialog.opacity)))

        layer.enabled: settingsDialog.visible || registerDialog.visible || addEventDialog.visible || locationSetupDialog.visible
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
                id: leftPanel
                Layout.fillWidth: true
                Layout.fillHeight: true
                isRightPanelOpened: rightPanel.isOpened
            }

            RightPanel {
                id: rightPanel
                Layout.preferredWidth: isOpened ? parent.width * 0.45 : 0
                Layout.fillHeight: true
                clip: true

                property bool isOpened: false

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 32
            spacing: 12
            readonly property int buttonSize: 40

            RoundButton {
                id: settingsButton
                width: parent.buttonSize
                height: parent.buttonSize
                scale: pressed ? 0.9 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
                contentItem: Text {
                    text: "\ue8b8"
                    font.family: "Material Icons"
                    font.pixelSize: 24
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? "#33FFFFFF" : (parent.hovered ? "#26FFFFFF" : "#1AFFFFFF")
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
                onClicked: settingsDialog.openSettings()
            }

            RoundButton {
                id: registerButton
                width: parent.buttonSize
                height: parent.buttonSize
                scale: pressed ? 0.9 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                contentItem: Text {
                    text: "\ue145"
                    font.family: "Material Icons"
                    font.pixelSize: 28
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: width / 2
                    color: parent.pressed ? "#66FFFFFF" : (parent.hovered ? "#4CFFFFFF" : "#33FFFFFF")
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
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

    AddEventDialog {
        id: addEventDialog
        anchors.centerIn: parent
    }

    LocationSetupDialog {
        id: locationSetupDialog
        anchors.centerIn: parent
        // 儲存位置後更新設定頁的顯示
        onClosed: {
            settingsDialog.homeLocationName = "";
            backend.load_home_location();
        }
    }

    Popup {
        id: modelDownloadPopup
        anchors.centerIn: parent
        width: 420
        height: 220
        padding: 32
        modal: true
        closePolicy: Popup.NoAutoClose
        
        background: Rectangle {
            color: "#E6000000"
            radius: 24
            border.color: "#33FFFFFF"
        }
        
        contentItem: ColumnLayout {
            spacing: 16
            
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: true
                palette.dark: "white"
            }
            
            Text {
                text: "正在下載 AI 模型..."
                color: "white"
                font.pixelSize: 20
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignHCenter
            }
            
            Text {
                text: "初次啟動需要數分鐘下載人臉辨識模型，請耐心等候，下載完成後會自動關閉。"
                color: "#89FFFFFF"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    Connections {
        target: backend
        function onModeChanged(mode, users) {
            rootContent.currentMode = mode;
            rootContent.currentUsers = users;
            if (mode === "idle") {
                openAnimation.stop();
                if (rightPanel.isOpened || leftPanel.isYoubikeOpened) {
                    closeAnimation.start();
                }
            } else {
                rightPanel.setupUser(mode, users);
                closeAnimation.stop();
                if (!rightPanel.isOpened || !leftPanel.isYoubikeOpened) {
                    openAnimation.start();
                }
            }
        }
        function onRebuildStarted() {
            rightPanel.showRebuilding = true;
        }
        function onRebuildDone() {
            rightPanel.showRebuilding = false;
            registerDialog.close();
        }
        // 程式啟動後若無位置資料，自動彈出位置設定 Dialog
        function onHomeLocationLoaded(loc) {
            settingsDialog.homeLocationName = (loc && loc.name) ? loc.name : "";
            if (!loc || !loc.name) {
                locationSetupDialog.hasExistingLocation = false;
                locationSetupDialog.open();
            }
        }
        function onModelDownloadStarted() {
            modelDownloadPopup.open();
        }
        function onModelDownloadDone() {
            modelDownloadPopup.close();
        }
    }

    function openRegisterDialog() {
        registerDialog.openDialog();
    }

    function openAddEventDialog() {
        addEventDialog.openDialog();
    }

    SequentialAnimation {
        id: openAnimation
        ScriptAction {
            script: {
                rightPanel.isOpened = true;
            }
        }
        PauseAnimation {
            duration: 600
        }
        ScriptAction {
            script: {
                leftPanel.isYoubikeOpened = true;
            }
        }
    }

    SequentialAnimation {
        id: closeAnimation
        ScriptAction {
            script: {
                leftPanel.isYoubikeOpened = false;
            }
        }
        PauseAnimation {
            duration: 400
        } // 等待 YouBike 的 400ms 收合動畫
        ScriptAction {
            script: {
                rightPanel.isOpened = false;
            }
        }
    }
}
