import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    width: Math.min(400, parent.width * 0.38)
    height: Math.min(280, parent.height * 0.45)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 400
                easing.type: Easing.OutQuint
            }
            NumberAnimation {
                property: "scale"
                from: 0.9
                to: 1.0
                duration: 400
                easing.type: Easing.OutQuint
            }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }

    background: Rectangle {
        color: "#E6000000"
        radius: 24
        border.color: "#33FFFFFF"
    }

    Overlay.modal: Rectangle {
        color: "transparent"
    }

    function openDialog() {
        idField.text = "";
        errorText.text = "";
        root.open();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        RowLayout {
            spacing: 6
            Text {
                text: "\ue7fe" // person_add
                font.family: "Material Icons"
                font.pixelSize: 20
                color: "white"
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                text: "註冊新人員"
                color: "white"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            text: "攝影機將擷取當前畫面作為人臉樣本。\n請確保面部清晰可見。"
            color: "#89FFFFFF"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        TextField {
            id: idField
            Layout.fillWidth: true
            placeholderText: "輸入使用者名稱"
            color: "white"
        }

        Text {
            id: errorText
            color: "#E57373"
            font.pixelSize: 12
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight

            Button {
                text: "取消"
                background: null
                contentItem: Text {
                    text: parent.text
                    color: "#89FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: root.close()
            }

            Button {
                text: "拍照並註冊"
                background: Rectangle {
                    color: parent.pressed ? "#4CFFFFFF" : "#33FFFFFF"
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    padding: 6
                }
                onClicked: {
                    var uid = idField.text.trim().toLowerCase();
                    if (uid === "") {
                        errorText.text = "名稱不可為空";
                        return;
                    }
                    backend.register_user(uid);
                    root.close();
                }
            }
        }
    }
}
