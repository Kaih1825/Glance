import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    width: Math.min(400, parent.width * 0.45)
    height: mainLayout.implicitHeight + topPadding + bottomPadding
    padding: 20
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

    property bool isPrivateSelected: false
    property string currentMode: rootContent.currentMode
    property var currentUsers: rootContent.currentUsers
    property var selectedOwners: []
    property var allRegisteredUsers: []

    function formatDate(date) {
        var y = date.getFullYear();
        var m = (date.getMonth() + 1).toString().padStart(2, '0');
        var d = date.getDate().toString().padStart(2, '0');
        return y + "-" + m + "-" + d;
    }

    function formatTime(date) {
        var h = date.getHours().toString().padStart(2, '0');
        var m = date.getMinutes().toString().padStart(2, '0');
        return h + ":" + m;
    }

    function isValidDate(dStr) {
        var reg = /^\d{4}-\d{2}-\d{2}$/;
        if (!reg.test(dStr)) return false;
        var parts = dStr.split('-');
        var y = parseInt(parts[0], 10);
        var m = parseInt(parts[1], 10) - 1;
        var d = parseInt(parts[2], 10);
        var dateObj = new Date(y, m, d);
        return dateObj.getFullYear() === y && dateObj.getMonth() === m && dateObj.getDate() === d;
    }

    function isValidTime(tStr) {
        var reg = /^([01]\d|2[0-3]):[0-5]\d$/;
        return reg.test(tStr);
    }

    function openDialog() {
        titleField.text = "";
        errorText.text = "";
        isPrivateSelected = false;

        allRegisteredUsers = backend.get_all_users();
        var owners = [];
        for (var i = 0; i < currentUsers.length; i++) {
            if (allRegisteredUsers.indexOf(currentUsers[i]) !== -1) {
                owners.push(currentUsers[i]);
            }
        }
        selectedOwners = owners;

        var now = new Date();
        var start = new Date(now);
        start.setHours(now.getHours() + 1);
        start.setMinutes(0);

        var end = new Date(now);
        end.setHours(now.getHours() + 2);
        end.setMinutes(0);

        startDateField.text = formatDate(start);
        startTimeField.text = formatTime(start);
        endDateField.text = formatDate(end);
        endTimeField.text = formatTime(end);

        root.open();
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "\ue878" // event icon
                font.family: "Material Icons"
                font.pixelSize: 20
                color: "white"
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                text: "新增行事曆事件"
                color: "white"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
            }
            Button {
                text: "✕"
                onClicked: root.close()
                background: null
                contentItem: Text {
                    text: parent.text
                    color: "#89FFFFFF"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#1EFFFFFF"
        }

        // Title Input
        TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: "活動名稱"
            color: "white"
            placeholderTextColor: "#60FFFFFF"
            background: Rectangle {
                color: "#1EFFFFFF"
                border.color: titleField.activeFocus ? "#4CFFFFFF" : "#1AFFFFFF"
                border.width: 1
                radius: 8
            }
            padding: 10
        }

        // Visibility Selector (Public / Private Segmented Control)
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            
            Text {
                text: "事件類型"
                color: "#89FFFFFF"
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: "#15FFFFFF"
                radius: 8
                border.color: "#1EFFFFFF"
                border.width: 1
                
                Row {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2
                    
                    // Public Option
                    Rectangle {
                        width: (currentMode === "guest") ? parent.width : (parent.width - 2) / 2
                        height: parent.height
                        radius: 6
                        color: isPrivateSelected ? "transparent" : "#33FFFFFF"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\ue80b" // public
                                font.family: "Material Icons"
                                font.pixelSize: 14
                                color: isPrivateSelected ? "#89FFFFFF" : "white"
                            }
                            Text {
                                text: "公共 (所有人可見)"
                                color: isPrivateSelected ? "#89FFFFFF" : "white"
                                font.pixelSize: 13
                                font.weight: isPrivateSelected ? Font.Normal : Font.Medium
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            enabled: currentMode !== "guest"
                            onClicked: {
                                isPrivateSelected = false;
                            }
                        }
                    }
                    
                    // Private Option
                    Rectangle {
                        width: (parent.width - 2) / 2
                        height: parent.height
                        radius: 6
                        color: isPrivateSelected ? "#33FFFFFF" : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        visible: currentMode !== "guest"
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\ue897" // lock
                                font.family: "Material Icons"
                                font.pixelSize: 14
                                color: isPrivateSelected ? "white" : "#89FFFFFF"
                            }
                            Text {
                                text: "私人 (僅限自己)"
                                color: isPrivateSelected ? "white" : "#89FFFFFF"
                                font.pixelSize: 13
                                font.weight: isPrivateSelected ? Font.Medium : Font.Normal
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                isPrivateSelected = true;
                            }
                        }
                    }
                }
            }
        }

        // Owner selection (Only visible if private and > 0 users registered)
        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true
            visible: isPrivateSelected && allRegisteredUsers.length > 0

            Text {
                text: "選擇私人事件成員 (複選)"
                color: "#89FFFFFF"
                font.pixelSize: 12
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                
                Repeater {
                    id: userRepeater
                    model: allRegisteredUsers
                    delegate: Button {
                        id: userBtn
                        property bool isChecked: selectedOwners.indexOf(modelData) !== -1
                        
                        background: Rectangle {
                            color: isChecked ? "#4C2196F3" : "#1AFFFFFF"
                            border.color: isChecked ? "#FF2196F3" : "#1AFFFFFF"
                            border.width: 1
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        
                        contentItem: RowLayout {
                            spacing: 6
                            Text {
                                text: userBtn.isChecked ? "\ue834" : "\ue835" // checked_box vs unchecked_box icon
                                font.family: "Material Icons"
                                font.pixelSize: 16
                                color: userBtn.isChecked ? "white" : "#89FFFFFF"
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                text: modelData
                                color: "white"
                                font.pixelSize: 13
                                font.weight: userBtn.isChecked ? Font.DemiBold : Font.Normal
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        
                        onClicked: {
                            var arr = selectedOwners.slice();
                            var idx = arr.indexOf(modelData);
                            if (idx !== -1) {
                                arr.splice(idx, 1);
                            } else {
                                arr.push(modelData);
                            }
                            selectedOwners = arr;
                        }
                    }
                }
            }
        }

        // Start Date/Time
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            
            Text {
                text: "開始時間"
                color: "#89FFFFFF"
                font.pixelSize: 12
            }
            
            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                
                TextField {
                    id: startDateField
                    placeholderText: "YYYY-MM-DD"
                    color: "white"
                    placeholderTextColor: "#60FFFFFF"
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: "#1EFFFFFF"
                        border.color: startDateField.activeFocus ? "#4CFFFFFF" : "#1AFFFFFF"
                        border.width: 1
                        radius: 8
                    }
                    padding: 8
                }
                
                TextField {
                    id: startTimeField
                    placeholderText: "HH:MM"
                    color: "white"
                    placeholderTextColor: "#60FFFFFF"
                    Layout.preferredWidth: 90
                    background: Rectangle {
                        color: "#1EFFFFFF"
                        border.color: startTimeField.activeFocus ? "#4CFFFFFF" : "#1AFFFFFF"
                        border.width: 1
                        radius: 8
                    }
                    padding: 8
                }
            }
        }

        // End Date/Time
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            
            Text {
                text: "結束時間"
                color: "#89FFFFFF"
                font.pixelSize: 12
            }
            
            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                
                TextField {
                    id: endDateField
                    placeholderText: "YYYY-MM-DD"
                    color: "white"
                    placeholderTextColor: "#60FFFFFF"
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: "#1EFFFFFF"
                        border.color: endDateField.activeFocus ? "#4CFFFFFF" : "#1AFFFFFF"
                        border.width: 1
                        radius: 8
                    }
                    padding: 8
                }
                
                TextField {
                    id: endTimeField
                    placeholderText: "HH:MM"
                    color: "white"
                    placeholderTextColor: "#60FFFFFF"
                    Layout.preferredWidth: 90
                    background: Rectangle {
                        color: "#1EFFFFFF"
                        border.color: endTimeField.activeFocus ? "#4CFFFFFF" : "#1AFFFFFF"
                        border.width: 1
                        radius: 8
                    }
                    padding: 8
                }
            }
        }

        // Error message
        Text {
            id: errorText
            color: "#FF5252"
            font.pixelSize: 12
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // Actions
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 12

            Button {
                text: "取消"
                background: null
                contentItem: Text {
                    text: parent.text
                    color: "#89FFFFFF"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }
                onClicked: root.close()
            }

            Button {
                text: "建立"
                background: Rectangle {
                    color: parent.pressed ? "#4CFFFFFF" : "#33FFFFFF"
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: 16
                    rightPadding: 16
                    topPadding: 8
                    bottomPadding: 8
                }
                onClicked: {
                    var title = titleField.text.trim();
                    if (title === "") {
                        errorText.text = "請輸入活動名稱";
                        return;
                    }

                    if (!isValidDate(startDateField.text) || !isValidTime(startTimeField.text)) {
                        errorText.text = "開始時間格式錯誤 (YYYY-MM-DD HH:MM)";
                        return;
                    }

                    if (!isValidDate(endDateField.text) || !isValidTime(endTimeField.text)) {
                        errorText.text = "結束時間格式錯誤 (YYYY-MM-DD HH:MM)";
                        return;
                    }

                    var startIso = startDateField.text + "T" + startTimeField.text + ":00";
                    var endIso = endDateField.text + "T" + endTimeField.text + ":00";
                    
                    var startDt = new Date(startIso);
                    var endDt = new Date(endIso);
                    
                    if (isNaN(startDt.getTime()) || isNaN(endDt.getTime())) {
                        errorText.text = "無效的時間數值";
                        return;
                    }

                    if (endDt <= startDt) {
                        errorText.text = "結束時間必須在開始時間之後";
                        return;
                    }

                    var visibility = isPrivateSelected ? "private" : "public";
                    var owner = "";
                    if (isPrivateSelected) {
                        if (selectedOwners.length > 0) {
                            owner = selectedOwners.join(",");
                        } else {
                            errorText.text = "請至少選擇一位私人事件成員";
                            return;
                        }
                    }

                    backend.add_event(title, startIso, endIso, visibility, owner);
                    root.close();
                }
            }
        }
    }
}
