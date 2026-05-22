import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 8

    FontLoader {
        id: materialFont
        source: "fonts/MaterialIcons-Regular.ttf"
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "YouBike 動態"
            color: "#60FFFFFF"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Item {
            Layout.fillWidth: true
        }

        Button {
            id: refreshButton
            width: 28
            height: 28
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            padding: 0

            scale: pressed ? 0.9 : (hovered ? 1.08 : 1.0)
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            background: Rectangle {
                radius: width / 2
                color: refreshButton.pressed ? "#33FFFFFF" : (refreshButton.hovered ? "#1AFFFFFF" : "transparent")
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            contentItem: Text {
                id: refreshIcon
                width: refreshButton.width
                height: refreshButton.height
                text: "\ue5d5"
                font.family: materialFont.name
                font.pixelSize: 18
                color: refreshButton.hovered ? "white" : "#60FFFFFF"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                transformOrigin: Item.Center
            }

            SequentialAnimation {
                id: rotateAnim

                NumberAnimation {
                    target: refreshIcon
                    property: "rotation"
                    to: 360
                    duration: 500
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: refreshIcon
                    property: "rotation"
                    to: 0
                    duration: 300
                    easing.type: Easing.InOutCubic
                }
            }

            onClicked: {
                backend.fetch_youbike();
                rotateAnim.start();
            }
        }
    }

    Row {
        id: spinnerRow
        spacing: 10
        visible: false
        BusyIndicator {
            width: 18
            height: 18
        }
        Text {
            text: "載入中…"
            color: "#60FFFFFF"
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    ScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Column {
            width: scrollView.width
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
                                Text {
                                    text: "\ue52f" // directions_bike
                                    font.family: "Material Icons"
                                    font.pixelSize: 18
                                    color: "#89FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.yb2
                                    font.pixelSize: 20
                                    font.weight: Font.Light
                                    color: {
                                        if (modelData.tot === 0)
                                            return "#60FFFFFF";
                                        var r = modelData.yb2 / modelData.tot;
                                        if (r >= 0.5)
                                            return "#81C784";
                                        if (r >= 0.2)
                                            return "#FFB74D";
                                        return "#E57373";
                                    }
                                }
                                Text {
                                    text: " / "
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: (modelData.act === "1") ? "white" : "#60FFFFFF"
                                }
                                Text {
                                    text: "\ue3e7" // flash_on
                                    font.family: "Material Icons"
                                    font.pixelSize: 16
                                    color: "#FFD54F" // yellow
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.eyb
                                    font.pixelSize: 20
                                    font.weight: Font.Light
                                    color: {
                                        if (modelData.tot === 0)
                                            return "#60FFFFFF";
                                        var r = modelData.eyb / modelData.tot;
                                        if (r >= 0.5)
                                            return "#81C784";
                                        if (r >= 0.2)
                                            return "#FFB74D";
                                        return "#E57373";
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
            spinnerRow.visible = false;
            scrollView.visible = true;
            bikeRepeater.model = data;
            console.log("Update");
        }
    }

    function setLoading(isLoading) {
        spinnerRow.visible = isLoading;
        scrollView.visible = !isLoading;
    }
}
