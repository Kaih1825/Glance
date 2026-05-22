import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    spacing: 8

    Repeater {
        id: weatherRepeater
        model: []

        delegate: Rectangle {
            property int margin: 20
            color: "#0AFFFFFF"        // 半透明背景 (毛玻璃質感)
            border.color: "#1EFFFFFF"  // 邊框
            border.width: 1
            width: childrenRect.width + margin
            height: childrenRect.height + margin
            radius: 12
            RowLayout {
                spacing: 14
                x: parent.margin / 2
                y: parent.margin / 2
                Text {
                    text: modelData.icon || "\ue8e3"
                    font.family: "Material Icons"
                    font.pixelSize: 36
                    color: modelData.iconColor || "white"
                    Layout.alignment: Qt.AlignVCenter
                }

                Column {
                    spacing: 2
                    Row {
                        spacing: 6
                        Text {
                            text: modelData.name || ""
                            color: "#89FFFFFF"
                            font.pixelSize: 13
                        }
                        Text {
                            text: modelData.condition || ""
                            color: "#89FFFFFF"
                            font.pixelSize: 13
                        }
                    }

                    Text {
                        text: (modelData.temp || "--") + "°C"
                        color: "white"
                        font.pixelSize: 28
                        font.weight: Font.Light
                    }

                    Text {
                        text: "體感 " + (modelData.feels_like || "--") + "°C　濕度 " + (modelData.humidity || "--") + "%　風速 " + (modelData.wind_speed || "--") + " km/h"
                        color: "#60FFFFFF"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    Connections {
        target: backend
        function onWeatherUpdated(data) {
            weatherRepeater.model = data;
        }
    }

    Timer {
        interval: 1800000 // 30 分鐘 (30 * 60 * 1000 毫秒)
        running: true
        repeat: true
        triggeredOnStart: false // 啟動時主程式已 fetch 過，不需重複觸發
        onTriggered: {
            backend.fetch_weather();
        }
    }
}
