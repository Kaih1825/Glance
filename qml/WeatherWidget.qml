import QtQuick
import QtQuick.Layouts

Column {
    id: weatherRoot
    property real availableWidth: 600
    property real targetAvailableWidth: availableWidth
    property real minCardWidth: 180
    property bool isRightPanelOpened: false

    spacing: 6

    // ── 重整按鈕 ── 對齊 cards 右邊緣
    Item {
        width: weatherRoot.targetAvailableWidth
        height: refreshBtn.height
        anchors.horizontalCenter: parent.horizontalCenter

        RefreshButton {
            id: refreshBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                spinning = true;
                backend.fetch_weather();
                if (weatherRoot.isRightPanelOpened) {
                    backend.fetch_youbike();
                    backend.fetch_recommendation();
                }
            }
        }
    }

    // ── Cards ──
    Grid {
        id: grid
        anchors.horizontalCenter: parent.horizontalCenter
        width: weatherRoot.targetAvailableWidth
        spacing: 6

        columns: {
            var maxCols = Math.max(1, Math.floor((weatherRoot.targetAvailableWidth + spacing) / (weatherRoot.minCardWidth + spacing)));
            var itemCount = weatherRepeater.model ? weatherRepeater.model.length : 0;
            return Math.max(1, Math.min(itemCount > 0 ? itemCount : 1, maxCols));
        }
        property real cardWidth: (weatherRoot.targetAvailableWidth - (columns - 1) * spacing) / columns

        Repeater {
            id: weatherRepeater
            model: []

            delegate: Rectangle {
                color: "#0AFFFFFF"
                border.color: "#1EFFFFFF"
                border.width: 1
                width: grid.cardWidth
                height: 60
                radius: 12

                Behavior on width {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: modelData.icon || "\ue8e3"
                        font.family: "Material Icons"
                        font.pixelSize: 24
                        color: modelData.iconColor || "white"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: (modelData.name || "") + " (" + (modelData.condition || "") + ")"
                                color: "white"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                text: (modelData.temp || "--") + "°C"
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "體感 " + (modelData.feels_like || "--") + "°C · 濕度 " + (modelData.humidity || "--") + "%"
                                color: "#89FFFFFF"
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                fontSizeMode: width > 0 ? Text.HorizontalFit : Text.FixedSize
                                minimumPixelSize: 8
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                text: (modelData.wind_speed || "--") + " km/h"
                                color: "#60FFFFFF"
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: backend
        function onWeatherUpdated(data) {
            weatherRepeater.model = data;
            refreshBtn.spinning = false;
        }
    }

    Timer {
        interval: 1800000 // 30 分鐘
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: backend.fetch_weather()
    }
}
