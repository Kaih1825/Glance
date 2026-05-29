import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: recommendRoot
    property real availableWidth: 600
    property real targetAvailableWidth: availableWidth
    property bool isRightPanelOpened: false

    width: availableWidth
    clip: true

    // height 動畫收合，visible 不立即切換以保留動畫
    height: isRightPanelOpened ? contentCol.implicitHeight : 0

    Behavior on height {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    // 推薦資料
    property var stationData: null
    property bool loading: false
    property bool showNotFound: false

    // 當 Right Panel 開啟/收起時觸發
    onIsRightPanelOpenedChanged: {
        if (isRightPanelOpened) {
            clearTimer.stop();
            notFoundTimer.stop();
            showNotFound = false;
            stationData = null;
            loading = true;
            backend.fetch_recommendation();
        } else {
            loading = false;
            // 等動畫跑完再清資料，避免收合時卡片瞬間消失
            clearTimer.start();
        }
    }

    Timer {
        id: clearTimer
        interval: 420  // 比動畫稍長
        repeat: false
        onTriggered: recommendRoot.stationData = null
    }

    Timer {
        id: notFoundTimer
        interval: 5000
        repeat: false
        onTriggered: recommendRoot.showNotFound = false
    }

    Connections {
        target: backend
        function onRecommendationUpdated(data) {
            loading = false;
            recommendRoot.stationData = (data && data.sno) ? data : null;
            if (!recommendRoot.stationData) {
                recommendRoot.showNotFound = true;
                notFoundTimer.restart();
            } else {
                recommendRoot.showNotFound = false;
                notFoundTimer.stop();
            }
        }
    }

    Column {
        id: contentCol
        width: Math.min(recommendRoot.targetAvailableWidth, recommendRoot.availableWidth)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        // ── 載入中 ──
        Rectangle {
            width: parent.width
            height: recommendRoot.loading ? 56 : 0
            visible: height > 0
            color: "#0AFFFFFF"
            radius: 14
            border.color: "#1EFFFFFF"
            border.width: 1
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                BusyIndicator {
                    implicitWidth: 20
                    implicitHeight: 20
                }
                Text {
                    text: "正在尋找最佳 YouBike 站點…"
                    color: "#89FFFFFF"
                    font.pixelSize: 13
                }
            }
        }

        // ── 找不到站點 ──
        Rectangle {
            width: parent.width
            height: recommendRoot.showNotFound ? 56 : 0
            visible: height > 0
            color: "#0AFFFFFF"
            radius: 14
            border.color: "#1EFFFFFF"
            border.width: 1
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "\ue000" // error_outline
                    font.family: "Material Icons"
                    font.pixelSize: 18
                    color: "#89FFFFFF"
                }
                Text {
                    text: "找不到附近 2km 內的 YouBike 站點"
                    color: "#89FFFFFF"
                    font.pixelSize: 13
                }
            }
        }

        // ── 推薦卡片 ──
        Rectangle {
            id: card
            width: parent.width
            height: recommendRoot.stationData ? implicitHeight : 0
            implicitHeight: cardContent.implicitHeight + 24
            visible: height > 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }

            // 漸層背景
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "#1A1565"
                }
                GradientStop {
                    position: 1.0
                    color: "#0D3D2D"
                }
            }
            radius: 14
            border.color: "#33FFFFFF"
            border.width: 1

            // 光暈效果（左上角）
            Rectangle {
                width: 120
                height: 120
                x: -30
                y: -40
                radius: 60
                color: "#186464E0"
                z: 0
            }

            ColumnLayout {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                anchors.topMargin: 14
                spacing: 10
                z: 1

                // 站名行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\ue52f"   // directions_bike
                        font.family: "Material Icons"
                        font.pixelSize: 22
                        color: "#81C784"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: recommendRoot.stationData ? (recommendRoot.stationData.sna || "").replace("YouBike2.0_", "") : ""
                                color: "white"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // 天氣警示角標
                            Rectangle {
                                visible: recommendRoot.stationData ? recommendRoot.stationData.is_hot_rainy : false
                                width: warnRow.implicitWidth + 12
                                height: 18
                                radius: 4
                                color: "#20E53935"
                                border.color: "#60E53935"
                                border.width: 1

                                Row {
                                    id: warnRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        text: "\ue002"
                                        font.family: "Material Icons"
                                        font.pixelSize: 11
                                        color: "#EF5350"
                                    }
                                    Text {
                                        text: "天氣折扣"
                                        color: "#EF5350"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // 最佳推薦角標
                            Rectangle {
                                width: badgeRow.implicitWidth + 12
                                height: 18
                                radius: 4
                                color: "#20FFB74D"
                                border.color: "#60FFB74D"
                                border.width: 1

                                Row {
                                    id: badgeRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        text: "\ue838"
                                        font.family: "Material Icons"
                                        font.pixelSize: 11
                                        color: "#FFB74D"
                                    }
                                    Text {
                                        text: "最佳推薦"
                                        color: "#FFB74D"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }

                        Text {
                            text: recommendRoot.stationData ? (recommendRoot.stationData.sarea || "") : ""
                            color: "#89FFFFFF"
                            font.pixelSize: 11
                        }
                    }
                }

                // ── 數據行 ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // 可借車輛
                    Column {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: recommendRoot.stationData ? recommendRoot.stationData.bikes + " 輛" : "--"
                            color: "#81C784"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "可借車輛"
                            color: "#60FFFFFF"
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 36
                        color: "#20FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 步行距離
                    Column {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            property real dm: recommendRoot.stationData ? recommendRoot.stationData.distance_m : 0
                            text: dm >= 1000 ? (dm / 1000).toFixed(1) + " km" : Math.round(dm) + " m"
                            color: "#64B5F6"
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "預估步行距離"
                            color: "#60FFFFFF"
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 36
                        color: "#20FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 車輛細項
                    Column {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            Text {
                                text: recommendRoot.stationData ? ("一般 " + recommendRoot.stationData.yb2) : "--"
                                color: "#89FFFFFF"
                                font.pixelSize: 12
                            }
                            Text {
                                text: "/"
                                color: "#40FFFFFF"
                                font.pixelSize: 12
                            }
                            Text {
                                text: recommendRoot.stationData ? ("電輔 " + recommendRoot.stationData.eyb) : "--"
                                color: "#89FFFFFF"
                                font.pixelSize: 12
                            }
                        }
                        Text {
                            text: "車種明細"
                            color: "#60FFFFFF"
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }
}
