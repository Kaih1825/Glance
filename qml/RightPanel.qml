import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#0AFFFFFF"
    border.color: "#1EFFFFFF"
    border.width: 1
    radius: 24
    
    property bool showRebuilding: false
    
    function setupUser(mode, users) {
        if (users && users.length > 0) {
            welcomeText.text = "歡迎回來，" + users.join("、") + " 👋"
        } else {
            welcomeText.text = "歡迎訪客 👋"
        }
    }
    
    StackLayout {
        anchors.fill: parent
        anchors.margins: 32
        currentIndex: showRebuilding ? 1 : 0
        
        // Main Content
        ColumnLayout {
            spacing: 0
            
            Text {
                id: welcomeText
                text: "歡迎"
                color: "white"
                font.pixelSize: 22
                font.weight: Font.Light
                Layout.topMargin: 4
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
            }
            
            Item { Layout.preferredHeight: 12 }
            
            YouBikeWidget {
                Layout.fillWidth: true
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
                    text: "➕ 註冊新人員"
                    onClicked: openRegisterDialog()
                    background: Rectangle {
                        color: parent.pressed ? "#4CFFFFFF" : "#33FFFFFF"
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
