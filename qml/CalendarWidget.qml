import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 8
    
    Text {
        text: "行事曆"
        color: "#60FFFFFF"
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    
    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 180
        clip: true
        
        Column {
            width: parent.width
            spacing: 6
            
            Text {
                visible: calendarRepeater.count === 0
                text: "暫無行事曆"
                color: "#3DFFFFFF"
                font.pixelSize: 13
            }
            
            Repeater {
                id: calendarRepeater
                model: []
                
                delegate: Rectangle {
                    width: parent.width
                    height: 56
                    color: "#0FFFFFFF"
                    radius: 12
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 8
                        
                        Text {
                            text: {
                                var vis = modelData.visibility || "public"
                                if (vis === "private") return "🔒"
                                if (vis === "shared") return "👥"
                                return "🌐"
                            }
                            font.pixelSize: 16
                            Layout.preferredWidth: 28
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Text {
                                text: modelData.title || ""
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                            Text {
                                text: {
                                    var f = function(iso) {
                                        try {
                                            var d = new Date(iso)
                                            if(isNaN(d.getTime())) return iso
                                            return (d.getMonth()+1) + "/" + d.getDate() + " " + d.getHours().toString().padStart(2, '0') + ":" + d.getMinutes().toString().padStart(2, '0')
                                        } catch(e) { return iso }
                                    }
                                    return f(modelData.start_dt) + " - " + f(modelData.end_dt)
                                }
                                color: "#89FFFFFF"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
    
    Connections {
        target: backend
        function onCalendarUpdated(data) {
            calendarRepeater.model = data
        }
    }
}
