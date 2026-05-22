import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: youbikeRoot

    property real availableWidth: 600
    property real targetAvailableWidth: availableWidth
    property bool isRightPanelOpened: false
    property real minCardWidth: 200
    property real maxHeight: 0

    Behavior on maxHeight {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    width: availableWidth
    height: Math.min(grid.implicitHeight, maxHeight)
    contentHeight: grid.implicitHeight
    clip: true

    ScrollBar.vertical: ScrollBar {
        policy: youbikeRoot.contentHeight > youbikeRoot.height
                ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        width: 4
    }

    Grid {
        id: grid
        width: youbikeRoot.availableWidth
        spacing: 6

        columns: {
            var maxCols = Math.max(1, Math.floor((youbikeRoot.targetAvailableWidth + spacing) / (youbikeRoot.minCardWidth + spacing)));
            var itemCount = bikeRepeater.model ? bikeRepeater.model.length : 0;
            return Math.max(1, Math.min(itemCount > 0 ? itemCount : 1, maxCols));
        }
        property real cardWidth: (youbikeRoot.targetAvailableWidth - (columns - 1) * spacing) / columns

        Repeater {
            id: bikeRepeater
            model: []

            delegate: Rectangle {
                color: "#0AFFFFFF"
                border.color: "#1EFFFFFF"
                border.width: 1
                width: grid.cardWidth
                height: 50
                radius: 12
                

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: "\ue52f" // directions_bike
                        font.family: "Material Icons"
                        font.pixelSize: 24
                        color: {
                            if (modelData.act !== "1")
                                return "#E57373";
                            var totalBikes = modelData.yb2 + modelData.eyb;
                            if (modelData.tot === 0)
                                return "#60FFFFFF";
                            var r = totalBikes / modelData.tot;
                            if (r >= 0.5)
                                return "#81C784";
                            if (r >= 0.2)
                                return "#FFB74D";
                            return "#E57373";
                        }
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
                                text: (modelData.sna || "").replace("YouBike2.0_", "")
                                color: "white"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: (modelData.yb2 + modelData.eyb) + " 輛"
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "一般 " + modelData.yb2
                                color: "#89FFFFFF"
                                font.pixelSize: 11
                            }
                            Text {
                                text: "·"
                                color: "#40FFFFFF"
                                font.pixelSize: 11
                            }
                            Text {
                                text: "電輔 " + modelData.eyb
                                color: "#89FFFFFF"
                                font.pixelSize: 11
                            }
                            Text {
                                text: "·"
                                color: "#40FFFFFF"
                                font.pixelSize: 11
                            }
                            Text {
                                text: "空 " + modelData.bemp
                                color: "#89FFFFFF"
                                font.pixelSize: 11
                                Layout.fillWidth: true
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
            bikeRepeater.model = data;
        }
    }

    Timer {
        interval: 60000 // 1 分鐘
        running: youbikeRoot.isRightPanelOpened
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            backend.fetch_youbike();
        }
    }
}
