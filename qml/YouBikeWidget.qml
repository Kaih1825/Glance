import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 8
    
    Text {
        text: "YouBike 動態"
        color: "#60FFFFFF"
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    
    Row {
        id: spinnerRow
        spacing: 10
        visible: false
        BusyIndicator { width: 18; height: 18 }
        Text { text: "載入中…"; color: "#60FFFFFF"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
    }
    
    ScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        
        Column {
            width: parent.width
            spacing: 6
            
            Text {
                visible: bikeRepeater.count === 0 && !spinnerRow.visible
                text: "無站點資料"
                color: "#3DFFFFFF"
                font.pixelSize: 13
            }
            
            Repeater {
                id: bikeRepeater
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
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Text {
                                text: modelData.sna || ""
                                color: (modelData.act === "1") ? "white" : "#60FFFFFF"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                            Text {
                                text: modelData.sarea || ""
                                color: "#60FFFFFF"
                                font.pixelSize: 11
                            }
                        }
                        
                        Column {
                            Layout.alignment: Qt.AlignRight
                            spacing: 2
                            
                            Row {
                                anchors.right: parent.right
                                spacing: 4
                                Text { text: "🚲"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: modelData.sbi
                                    font.pixelSize: 20
                                    font.weight: Font.Light
                                    color: {
                                        if (modelData.tot === 0) return "#60FFFFFF"
                                        var r = modelData.sbi / modelData.tot
                                        if (r >= 0.5) return "#81C784"
                                        if (r >= 0.2) return "#FFB74D"
                                        return "#E57373"
                                    }
                                }
                            }
                            Text {
                                text: "空位 " + modelData.bemp
                                color: "#60FFFFFF"
                                font.pixelSize: 11
                                anchors.right: parent.right
                            }
                        }
                    }
                }
            }
        }
    }
    
    Connections {
        target: backend
        function onYoubikeUpdated(data) {
            spinnerRow.visible = false
            scrollView.visible = true
            bikeRepeater.model = data
        }
    }
    
    function setLoading(isLoading) {
        spinnerRow.visible = isLoading
        scrollView.visible = !isLoading
    }
}
