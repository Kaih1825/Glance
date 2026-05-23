import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 8
    
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        
        Text {
            text: "行事曆"
            color: "#60FFFFFF"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
        }
        
        Item {
            Layout.fillWidth: true
        }
        
        RoundButton {
            id: addEventButton
            width: 22
            height: 22
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            padding: 0
            
            scale: pressed ? 0.9 : (hovered ? 1.1 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            
            background: Rectangle {
                radius: 11
                color: parent.pressed ? "#4CFFFFFF" : (parent.hovered ? "#26FFFFFF" : "transparent")
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            
            contentItem: Text {
                text: "\ue145" // add icon
                font.family: "Material Icons"
                font.pixelSize: 14
                color: parent.hovered ? "white" : "#60FFFFFF"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            
            onClicked: {
                openAddEventDialog();
            }
        }
    }
    
    ScrollView {
        id: calendarScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        
        Column {
            width: calendarScrollView.width
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
                                if (vis === "private") return "\ue897" // lock
                                if (vis === "shared") return "\ue7fb"  // people
                                return "\ue80b"                      // public
                            }
                            font.family: "Material Icons"
                            font.pixelSize: 20
                            color: "#89FFFFFF"
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
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
