import QtQuick
import QtQuick.Controls

Column {
    spacing: 4
    
    property real parentHeight: 600
    
    Text {
        id: timeText
        font.family: "monospace"
        font.pixelSize: Math.round(Math.min(92, Math.max(50, parentHeight * 0.15)))
        font.weight: Font.Light
        color: "white"
        anchors.horizontalCenter: parent.horizontalCenter
    }
    
    Text {
        id: dateText
        font.pixelSize: Math.round(Math.min(20, Math.max(14, parentHeight * 0.035)))
        font.weight: Font.Light
        color: "#89FFFFFF"
        anchors.horizontalCenter: parent.horizontalCenter
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var date = new Date()
            var hh = date.getHours().toString().padStart(2, '0')
            var mm = date.getMinutes().toString().padStart(2, '0')
            var ss = date.getSeconds().toString().padStart(2, '0')
            timeText.text = hh + ":" + mm + ":" + ss
            
            var weekdays = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"]
            dateText.text = date.getFullYear() + " 年 " + (date.getMonth() + 1) + " 月 " + date.getDate() + " 日　" + weekdays[date.getDay()]
        }
    }
}
