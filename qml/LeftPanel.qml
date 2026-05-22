import QtQuick

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

    // Clock + Weather 保持垂直置中，YouBike 展開時不移動
    Column {
        id: topSection
        width: parent.width * 0.9
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: leftPanelRoot.panelSpacing

        ClockWidget {
            anchors.horizontalCenter: parent.horizontalCenter
            parentHeight: leftPanelRoot.height
        }

        WeatherWidget {
            id: weatherWidget
            anchors.horizontalCenter: parent.horizontalCenter
            availableWidth: parent.width
            targetAvailableWidth: leftPanelRoot.isRightPanelOpened
                ? leftPanelRoot.targetWidth * 0.9
                : Math.min(leftPanelRoot.targetWidth * 0.9, 340)
        }
    }

    // YouBike 固定在 topSection 下方，向下展開
    YouBikeWidget {
        id: youbikeWidget
        anchors.top: topSection.bottom
        anchors.topMargin: leftPanelRoot.panelSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        availableWidth: parent.width * 0.9
        targetAvailableWidth: leftPanelRoot.targetWidth * 0.9
        isRightPanelOpened: leftPanelRoot.isRightPanelOpened
        maxHeight: leftPanelRoot.isYoubikeOpened ? leftPanelRoot.height * 0.45 : 0
    }
}
