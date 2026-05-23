import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    width: Math.min(600, Math.max(480, parent.width * 0.55))
    height: Math.min(700, Math.max(500, parent.height * 0.9))
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

    property var weatherLocations: []
    property var youbikeStations: []
    property var weatherSearchResults: []
    property var youbikeSearchResults: []
    property int cameraIndex: 0
    property var cameraOptions: []

    function openSettings() {
        backend.load_settings();
        root.open();
        backend.test_camera(cameraIndex);
    }

    onClosed: {
        backend.stop_test_camera();
    }

    Connections {
        target: backend
        function onSettingsLoaded(w, y, cIdx, cams) {
            weatherLocations = w;
            youbikeStations = y;
            cameraIndex = cIdx;
            cameraOptions = cams;
            camComboBox.currentIndex = cIdx;
            weatherSearchResults = [];
            youbikeSearchResults = [];
        }

        function onPreviewFrame(b64) {
            camPreview.source = b64;
        }

        function onWeatherSearchResults(res) {
            console.log("QML onWeatherSearchResults received:", JSON.stringify(res));
            root.weatherSearchResults = [];
            root.weatherSearchResults = res;
        }

        function onYoubikeSearchResults(res) {
            console.log("QML onYoubikeSearchResults received:", JSON.stringify(res));
            root.youbikeSearchResults = [];
            root.youbikeSearchResults = res;
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
                contentItem: Text {
                    text: parent.text
                    color: "#89FFFFFF"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#1EFFFFFF"
        }

        ScrollView {
            id: settingsScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: settingsScrollView.width
                spacing: 16

                // Weather
                ColumnLayout {
                    spacing: 4
                    RowLayout {
                        spacing: 6
                        Text {
                            text: "\ue430" // wb_sunny
                            font.family: "Material Icons"
                            font.pixelSize: 18
                            color: "#B2FFFFFF"
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: "天氣位置"
                            color: "#B2FFFFFF"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Chips
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: weatherLocations
                            Button {
                                text: modelData.name + ", " + (modelData.country || "") + "  ✕"
                                onClicked: {
                                    var arr = weatherLocations.slice();
                                    arr.splice(index, 1);
                                    weatherLocations = arr;
                                }
                                background: Rectangle {
                                    color: "#662196F3"
                                    radius: 10
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    padding: 4
                                }
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
                            background: Rectangle {
                                color: parent.pressed ? "#4CFFFFFF" : "#33FFFFFF"
                                radius: 8
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 16
                                rightPadding: 16
                            }
                            padding: 8
                        }
                    }

                    Rectangle {
                        id: weatherSearchResultsContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(150, root.height * 0.2)
                        visible: root.weatherSearchResults.length > 0
                        color: "#0CFFFFFF"
                        radius: 8
                        clip: true

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 6
                            model: root.weatherSearchResults
                            delegate: ItemDelegate {
                                width: ListView.view ? ListView.view.width : 0
                                height: 30
                                contentItem: Text {
                                    text: modelData.name
                                    color: "white"
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: null
                                onClicked: {
                                    var exists = false;
                                    for (var i = 0; i < weatherLocations.length; i++) {
                                        if (weatherLocations[i].lat === modelData.lat && weatherLocations[i].lon === modelData.lon)
                                            exists = true;
                                    }
                                    if (!exists) {
                                        var arr = weatherLocations.slice();
                                        arr.push(modelData);
                                        weatherLocations = arr;
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1EFFFFFF"
                }

                // YouBike
                ColumnLayout {
                    spacing: 4
                    RowLayout {
                        spacing: 6
                        Text {
                            text: "\ue52f" // directions_bike
                            font.family: "Material Icons"
                            font.pixelSize: 18
                            color: "#B2FFFFFF"
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: "YouBike 站點"
                            color: "#B2FFFFFF"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: youbikeStations
                            Button {
                                text: modelData.sna + "  ✕"
                                onClicked: {
                                    var arr = youbikeStations.slice();
                                    arr.splice(index, 1);
                                    youbikeStations = arr;
                                }
                                background: Rectangle {
                                    color: "#664CAF50"
                                    radius: 10
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    padding: 4
                                }
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
                            background: Rectangle {
                                color: parent.pressed ? "#4CFFFFFF" : "#33FFFFFF"
                                radius: 8
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 16
                                rightPadding: 16
                            }
                            padding: 8
                        }
                    }

                    Rectangle {
                        id: youbikeSearchResultsContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(150, root.height * 0.2)
                        visible: root.youbikeSearchResults.length > 0
                        color: "#0CFFFFFF"
                        radius: 8
                        clip: true

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 6
                            model: root.youbikeSearchResults
                            delegate: ItemDelegate {
                                width: ListView.view ? ListView.view.width : 0
                                height: 30
                                contentItem: Text {
                                    text: modelData.sna + "  " + (modelData.sarea || "")
                                    color: "white"
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: null
                                onClicked: {
                                    var exists = false;
                                    for (var i = 0; i < youbikeStations.length; i++) {
                                        if (youbikeStations[i].sno === modelData.sno)
                                            exists = true;
                                    }
                                    if (!exists) {
                                        var arr = youbikeStations.slice();
                                        arr.push(modelData);
                                        youbikeStations = arr;
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1EFFFFFF"
                }

                // Camera
                ColumnLayout {
                    spacing: 4
                    RowLayout {
                        spacing: 6
                        Text {
                            text: "\ue412" // photo_camera
                            font.family: "Material Icons"
                            font.pixelSize: 18
                            color: "#B2FFFFFF"
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: "攝影機選擇"
                            color: "#B2FFFFFF"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    ComboBox {
                        id: camComboBox
                        Layout.fillWidth: true
                        model: cameraOptions
                        onActivated: index => {
                            cameraIndex = index;
                            backend.test_camera(index);
                        }
                    }
                    Image {
                        id: camPreview
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(220, root.height * 0.3)
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        source: ""
                    }
                }
            }
        }

        Button {
            id: saveSettingsButton
            property real buttonScale: 1.0
            Layout.fillWidth: true
            padding: 10
            scale: buttonScale
            Behavior on buttonScale {
                NumberAnimation {
                    easing.type: Easing.OutBack
                    duration: 500
                }
            }
            onHoveredChanged: {
                if (hovered)
                    buttonScale = 1.025;
                else
                    buttonScale = 1;
            }
            background: Rectangle {
                color: parent.pressed ? "#4CFFFFFF" : "#33FFFFFF"
                radius: 30
            }
            contentItem: RowLayout {
                spacing: 8
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: "\ue161" // save
                    font.family: "Material Icons"
                    font.pixelSize: 18
                    color: "white"
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    text: "儲存設定"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: "white"
                    verticalAlignment: Text.AlignVCenter
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            onClicked: {
                backend.save_settings(weatherLocations, youbikeStations, cameraIndex);
                root.close();
            }
        }
    }
}
