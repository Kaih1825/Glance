import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    width: Math.min(520, Math.max(400, parent.width * 0.45))
    height: Math.min(560, Math.max(400, parent.height * 0.8))
    modal: true
    focus: true
    closePolicy: hasExistingLocation ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside) : Popup.NoAutoClose

    property bool hasExistingLocation: false
    property var searchResults: []

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 350
                easing.type: Easing.OutQuint
            }
            NumberAnimation {
                property: "scale"
                from: 0.9
                to: 1.0
                duration: 350
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
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    // 開啟時清空搜尋
    onOpened: {
        root.searchResults = [];
        searchField.text = "";
    }

    background: Rectangle {
        color: "#EE000000"
        radius: 24
        border.color: "#44FFFFFF"
        border.width: 1
    }

    Overlay.modal: Rectangle {
        color: "transparent"
    }

    Connections {
        target: backend

        function onHomeLocationSearchResults(res) {
            root.searchResults = [];
            root.searchResults = res;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 16

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "\ue0c8"
                font.family: "Material Icons"
                font.pixelSize: 26
                color: "#64B5F6"
            }
            Text {
                text: "設定我的位置"
                color: "white"
                font.pixelSize: 20
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            Button {
                visible: root.hasExistingLocation
                text: "✕"
                onClicked: root.close()
                background: null
                contentItem: Text {
                    text: parent.text
                    color: "#89FFFFFF"
                    font.pixelSize: 18
                }
                padding: 4
            }
        }

        Text {
            text: root.hasExistingLocation ? "更新您目前的位置，用於推薦附近 YouBike 站點" : "設定您的位置，讓系統推薦附近最佳 YouBike 站點"
            color: "#89FFFFFF"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#1EFFFFFF"
        }

        // ── 搜尋輸入 ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 10
                color: "#14FFFFFF"
                border.color: searchField.activeFocus ? "#64B5F6" : "#22FFFFFF"
                border.width: searchField.activeFocus ? 1.5 : 1
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: "\ue8b6"
                        font.family: "Material Icons"
                        font.pixelSize: 16
                        color: "#60FFFFFF"
                    }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "例：信義區、Xinyi District…"
                        color: "white"
                        font.pixelSize: 13
                        background: null
                        onAccepted: backend.search_home_location(text)
                    }
                }
            }

            Button {
                text: "搜尋"
                padding: 9
                onClicked: backend.search_home_location(searchField.text)
                background: Rectangle {
                    color: parent.pressed ? "#5C7FB8" : "#3D6BA8"
                    radius: 8
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 6
                    rightPadding: 6
                }
            }
        }

        // ── 搜尋結果 ──
        Rectangle {
            Layout.fillWidth: true
            height: Math.min(resultList.count * 70, 300)
            visible: root.searchResults.length > 0
            color: "#0AFFFFFF"
            radius: 10
            border.color: "#1EFFFFFF"
            clip: true
            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            ListView {
                id: resultList
                anchors.fill: parent
                anchors.margins: 4
                model: root.searchResults
                clip: true

                delegate: ItemDelegate {
                    width: ListView.view ? ListView.view.width : 0
                    height: 44

                    background: Rectangle {
                        color: parent.hovered ? "#18FFFFFF" : "transparent"
                        radius: 8
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 10
                        Text {
                            text: "\ue0c8"
                            font.family: "Material Icons"
                            font.pixelSize: 15
                            color: "#64B5F6"
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.name || ""
                                color: "white"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: "lat: " + (modelData.lat || 0).toFixed(4) + "  lng: " + (modelData.lon || 0).toFixed(4)
                                color: "#60FFFFFF"
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            text: "\ue5cc"
                            font.family: "Material Icons"
                            font.pixelSize: 16
                            color: "#40FFFFFF"
                        }
                    }

                    onClicked: {
                        // 點選搜尋結果直接儲存並關閉
                        backend.save_home_location(modelData.lat, modelData.lon, modelData.name);
                        root.close();
                    }
                }
            }
        }

        // 吸震元件：吸收剩下的垂直空間，讓上方元件能往上靠齊
        Item {
            Layout.fillHeight: true
        }
    }
}
