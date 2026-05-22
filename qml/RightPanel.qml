import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#0AFFFFFF"
    border.color: "#1EFFFFFF"
    border.width: 1
    radius: 24
    
    property string welcomeMessage: "歡迎"
    property bool showWave: false
    
    function setupUser(mode, users) {
        if (users && users.length > 0) {
            welcomeMessage = "歡迎回來，" + users.join("、")
            showWave = true
        } else {
            welcomeMessage = "歡迎訪客"
            showWave = true
        }
    }
    
    property bool showRebuilding: false

    StackLayout {
        anchors.fill: parent
        anchors.margins: 32
        currentIndex: showRebuilding ? 1 : 0
        
        // Main Content
        ColumnLayout {
            spacing: 0
            
            RowLayout {
                Layout.topMargin: 4
                spacing: 8
                
                Text {
                    id: welcomeText
                    text: welcomeMessage
                    color: "white"
                    font.pixelSize: 22
                    font.weight: Font.Light
                }
                
                Text {
                    text: "\ue766" // waving_hand
                    font.family: "Material Icons"
                    font.pixelSize: 22
                    color: "#FFD54F" // gold/yellow
                    visible: showWave
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1EFFFFFF"
                Layout.topMargin: 12
                Layout.bottomMargin: 12
            }
            
            CalendarWidget {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(220, Math.max(120, parent.height * 0.35))
            }
            
            Item {
                Layout.fillHeight: true
            }
            
            // Action Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 10
                
                Button {
                    text: "重新辨識"
                    onClicked: backend.trigger_rescan()
                    background: Rectangle {
                        color: "transparent"
                        border.color: "#3DFFFFFF"
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#B2FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    padding: 8
                }
                
                Button {
                    id: registerNewUserButton
                    onClicked: openRegisterDialog()
                    background: Rectangle {
                        color: parent.pressed ? "#4CFFFFFF" : "#33FFFFFF"
                        radius: 8
                    }
                    contentItem: RowLayout {
                        spacing: 6
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "\ue7fe" // person_add
                            font.family: "Material Icons"
                            font.pixelSize: 16
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: "註冊新人員"
                            color: "white"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }
                    }
                    padding: 8
                }
            }
        }
        
        // Rebuilding overlay
        Rectangle {
            color: "#D80D0D1A"
            radius: 12
            
            Column {
                anchors.centerIn: parent
                spacing: 12
                BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter }
                Text {
                    text: "建構人臉特徵庫…"
                    color: "#89FFFFFF"
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
