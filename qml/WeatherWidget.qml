import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    spacing: 8
    
    Repeater {
        id: weatherRepeater
        model: []
        
        delegate: RowLayout {
            spacing: 14
            
            Text {
                text: modelData.emoji || "🌡️"
                font.pixelSize: 32
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
    
    Connections {
        target: backend
        function onWeatherUpdated(data) {
            weatherRepeater.model = data
        }
    }
}
