import QtQuick
import QtQuick.Controls

Item {
    id: leftPanelRoot
    property bool isRightPanelOpened: false
    property bool isYoubikeOpened: false
    property real targetWidth: {
        if (!parent)
            return 944.0;
        var rowWidth = parent.width;
        return isRightPanelOpened ? (rowWidth - 40 - rowWidth * 0.45) : rowWidth;
    }

    readonly property real panelSpacing: Math.min(10, leftPanelRoot.height * 0.018)

    // ClockWidget 保持在上方，固定不滾動
    ClockWidget {
        id: clockWidget
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: leftPanelRoot.height * 0.3
        anchors.horizontalCenter: parent.horizontalCenter
        parentHeight: leftPanelRoot.height
    }

    // ScrollView 包裹 WeatherWidget 和 YouBikeWidget，使其可一起滾動
    ScrollView {
        id: contentScrollView
        anchors.top: clockWidget.bottom
        anchors.topMargin: leftPanelRoot.panelSpacing
        anchors.bottom: parent.bottom
        anchors.bottomMargin: leftPanelRoot.panelSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        clip: true

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: contentScrollView.width
            spacing: leftPanelRoot.panelSpacing

            WeatherWidget {
                id: weatherWidget
                anchors.horizontalCenter: parent.horizontalCenter
                availableWidth: parent.width * 0.95
                targetAvailableWidth: Math.min(leftPanelRoot.targetWidth * 0.95, 500)
                isRightPanelOpened: leftPanelRoot.isRightPanelOpened
            }

            RecommendWidget {
                id: recommendWidget
                anchors.horizontalCenter: parent.horizontalCenter
                availableWidth: parent.width * 0.95
                targetAvailableWidth: leftPanelRoot.targetWidth * 0.95
                isRightPanelOpened: leftPanelRoot.isRightPanelOpened
            }

            YouBikeWidget {
                id: youbikeWidget
                anchors.horizontalCenter: parent.horizontalCenter
                availableWidth: parent.width * 0.95
                targetAvailableWidth: leftPanelRoot.targetWidth * 0.95
                isRightPanelOpened: leftPanelRoot.isRightPanelOpened
                maxHeight: leftPanelRoot.isYoubikeOpened ? leftPanelRoot.height * 0.45 : 0
            }
        }
    }
}
