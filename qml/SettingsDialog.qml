import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    width: 520
    height: 640
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
            NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 250; easing.type: Easing.OutCubic }
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
    
    property var weatherLocations: []
    property var youbikeStations: []
    property int cameraIndex: 0
    property var cameraOptions: []
    
    function openSettings() {
        backend.load_settings()
        root.open()
        backend.test_camera(cameraIndex)
    }
    
    onClosed: {
        backend.stop_test_camera()
    }
    
    Connections {
        target: backend
        function onSettingsLoaded(w, y, cIdx, cams) {
            weatherLocations = w
            youbikeStations = y
            cameraIndex = cIdx
            cameraOptions = cams
            camComboBox.currentIndex = cIdx
            weatherSearchRepeater.model = []
            bikeSearchRepeater.model = []
        }
        
        function onPreviewFrame(b64) {
            camPreview.source = b64
        }
        
        function onWeatherSearchResults(res) {
            weatherSearchRepeater.model = res
        }
        
        function onYoubikeSearchResults(res) {
            bikeSearchRepeater.model = res
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "設定"
                color: "white"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            Button {
                text: "✕"
                onClicked: root.close()
                background: null
                contentItem: Text { text: parent.text; color: "#89FFFFFF" }
            }
        }
        
        Rectangle { Layout.fillWidth: true; height: 1; color: "#1EFFFFFF" }
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ColumnLayout {
                width: parent.width
                spacing: 16
                
                // Camera
                ColumnLayout {
                    spacing: 4
                    Text { text: "📷 攝影機選擇"; color: "#B2FFFFFF"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    ComboBox {
                        id: camComboBox
                        Layout.fillWidth: true
                        model: cameraOptions
                        onActivated: (index) => {
                            cameraIndex = index
                            backend.test_camera(index)
                        }
                    }
                    Image {
                        id: camPreview
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        source: ""
                    }
                }
                
                Rectangle { Layout.fillWidth: true; height: 1; color: "#1EFFFFFF" }
                
                // Weather
                ColumnLayout {
                    spacing: 4
                    Text { text: "🌤 天氣位置"; color: "#B2FFFFFF"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "最多 2 個位置"; color: "#60FFFFFF"; font.pixelSize: 12 }
                    
                    // Chips
                    Row {
                        spacing: 6
                        Repeater {
                            model: weatherLocations
                            Button {
                                text: modelData.name + ", " + (modelData.country || "") + "  ✕"
                                onClicked: {
                                    var arr = weatherLocations.slice()
                                    arr.splice(index, 1)
                                    weatherLocations = arr
                                }
                                background: Rectangle { color: "#662196F3"; radius: 10 }
                                contentItem: Text { text: parent.text; color: "white"; padding: 4 }
                            }
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            id: wSearchInput
                            Layout.fillWidth: true
                            placeholderText: "搜尋城市（例：Taipei）"
                            color: "white"
                            onAccepted: backend.search_weather(text)
                        }
                        Button {
                            text: "搜尋"
                            onClicked: backend.search_weather(wSearchInput.text)
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 110
                        color: "#0CFFFFFF"
                        radius: 8
                        clip: true
                        
                        ListView {
                            anchors.fill: parent
                            anchors.margins: 6
                            model: weatherSearchRepeater.model
                            delegate: ItemDelegate {
                                width: ListView.view.width
                                height: 30
                                text: modelData.name + ", " + (modelData.admin1 || "") + " " + (modelData.country || "")
                                contentItem: Text { text: parent.text; color: "white"; verticalAlignment: Text.AlignVCenter }
                                background: null
                                onClicked: {
                                    if (weatherLocations.length < 2) {
                                        var exists = false
                                        for(var i=0; i<weatherLocations.length; i++) {
                                            if (weatherLocations[i].lat === modelData.lat && weatherLocations[i].lon === modelData.lon) exists = true
                                        }
                                        if (!exists) {
                                            var arr = weatherLocations.slice()
                                            arr.push(modelData)
                                            weatherLocations = arr
                                        }
                                    }
                                }
                            }
                        }
                        
                        Repeater { id: weatherSearchRepeater; model: [] } // just to hold data
                    }
                }
                
                Rectangle { Layout.fillWidth: true; height: 1; color: "#1EFFFFFF" }
                
                // YouBike
                ColumnLayout {
                    spacing: 4
                    Text { text: "🚲 YouBike 站點"; color: "#B2FFFFFF"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "最多 2 個站點"; color: "#60FFFFFF"; font.pixelSize: 12 }
                    
                    Row {
                        spacing: 6
                        Repeater {
                            model: youbikeStations
                            Button {
                                text: modelData.sna + "  ✕"
                                onClicked: {
                                    var arr = youbikeStations.slice()
                                    arr.splice(index, 1)
                                    youbikeStations = arr
                                }
                                background: Rectangle { color: "#664CAF50"; radius: 10 }
                                contentItem: Text { text: parent.text; color: "white"; padding: 4 }
                            }
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            id: bSearchInput
                            Layout.fillWidth: true
                            placeholderText: "搜尋站點名稱（例：臺大）"
                            color: "white"
                            onAccepted: backend.search_youbike(text)
                        }
                        Button {
                            text: "搜尋"
                            onClicked: backend.search_youbike(bSearchInput.text)
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 110
                        color: "#0CFFFFFF"
                        radius: 8
                        clip: true
                        
                        ListView {
                            anchors.fill: parent
                            anchors.margins: 6
                            model: bikeSearchRepeater.model
                            delegate: ItemDelegate {
                                width: ListView.view.width
                                height: 30
                                text: modelData.sna + "  " + (modelData.sarea || "")
                                contentItem: Text { text: parent.text; color: "white"; verticalAlignment: Text.AlignVCenter }
                                background: null
                                onClicked: {
                                    if (youbikeStations.length < 2) {
                                        var exists = false
                                        for(var i=0; i<youbikeStations.length; i++) {
                                            if (youbikeStations[i].sno === modelData.sno) exists = true
                                        }
                                        if (!exists) {
                                            var arr = youbikeStations.slice()
                                            arr.push(modelData)
                                            youbikeStations = arr
                                        }
                                    }
                                }
                            }
                        }
                        
                        Repeater { id: bikeSearchRepeater; model: [] } // just to hold data
                    }
                }
            }
        }
        
        Button {
            text: "💾  儲存設定"
            Layout.fillWidth: true
            background: Rectangle { color: "#64B5F6"; radius: 8 }
            contentItem: Text { text: parent.text; color: "black"; horizontalAlignment: Text.AlignHCenter; padding: 10; font.pixelSize: 14 }
            onClicked: {
                backend.save_settings(weatherLocations, youbikeStations, cameraIndex)
                root.close()
            }
        }
    }
}
