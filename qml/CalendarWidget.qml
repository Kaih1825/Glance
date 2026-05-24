import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 0
    
    // ── 狀態與資料屬性 ──
    property int currentYear: new Date().getFullYear()
    property int currentMonth: new Date().getMonth() // 0-11
    property string selectedDateString: {
        var d = new Date();
        return d.getFullYear() + "-" + (d.getMonth() + 1).toString().padStart(2, '0') + "-" + d.getDate().toString().padStart(2, '0');
    }
    property var allEvents: []
    property var calendarModel: []
    
    // ── JavaScript 輔助函數 ──
    
    // 生成 42 天的月曆網格模型 (包含前後月份補位)
    function generateCalendar(year, month) {
        var firstDay = new Date(year, month, 1);
        var startingDayOfWeek = firstDay.getDay(); // 0 = 星期日, 1 = 星期一, ...
        var daysInMonth = new Date(year, month + 1, 0).getDate();
        var prevMonthDays = new Date(year, month, 0).getDate();
        
        var calendarDays = [];
        
        // 1. 填入上個月月底的補位日期
        for (var i = startingDayOfWeek - 1; i >= 0; i--) {
            var d = prevMonthDays - i;
            var m = month - 1;
            var y = year;
            if (m < 0) {
                m = 11;
                y--;
            }
            calendarDays.push({
                dayNumber: d,
                month: m,
                year: y,
                isCurrentMonth: false,
                isToday: false,
                dateString: y + "-" + (m + 1).toString().padStart(2, '0') + "-" + d.toString().padStart(2, '0')
            });
        }
        
        // 2. 填入當月的日期
        var today = new Date();
        var todayDateStr = today.getFullYear() + "-" + (today.getMonth() + 1).toString().padStart(2, '0') + "-" + today.getDate().toString().padStart(2, '0');
        for (var d = 1; d <= daysInMonth; d++) {
            var ds = year + "-" + (month + 1).toString().padStart(2, '0') + "-" + d.toString().padStart(2, '0');
            var isToday = (ds === todayDateStr);
            calendarDays.push({
                dayNumber: d,
                month: month,
                year: year,
                isCurrentMonth: true,
                isToday: isToday,
                dateString: ds
            });
        }
        
        // 3. 填入下個月初的補位日期，湊滿 6 週共 42 格
        var totalCells = 42;
        var remainingCells = totalCells - calendarDays.length;
        for (var d = 1; d <= remainingCells; d++) {
            var m = month + 1;
            var y = year;
            if (m > 11) {
                m = 0;
                y++;
            }
            calendarDays.push({
                dayNumber: d,
                month: m,
                year: y,
                isCurrentMonth: false,
                isToday: false,
                dateString: y + "-" + (m + 1).toString().padStart(2, '0') + "-" + d.toString().padStart(2, '0')
            });
        }
        
        return calendarDays;
    }
    
    // 檢查某個日期是否有重疊的事件
    function hasEventsOnDate(dateString) {
        if (!allEvents) return false;
        for (var i = 0; i < allEvents.length; i++) {
            var event = allEvents[i];
            var startDate = event.start_dt.substring(0, 10);
            var endDate = event.end_dt.substring(0, 10);
            if (dateString >= startDate && dateString <= endDate) {
                return true;
            }
        }
        return false;
    }
    
    // 篩選出特定日期的所有事件
    function getFilteredEvents(dateString) {
        if (!allEvents) return [];
        var filtered = [];
        for (var i = 0; i < allEvents.length; i++) {
            var event = allEvents[i];
            var startDate = event.start_dt.substring(0, 10);
            var endDate = event.end_dt.substring(0, 10);
            if (dateString >= startDate && dateString <= endDate) {
                filtered.push(event);
            }
        }
        return filtered;
    }
    
    // 更新月曆網格模型
    function updateCalendarModel() {
        calendarModel = generateCalendar(currentYear, currentMonth);
    }
    
    // 格式化選取日期的標題文字
    function formatSelectedDateTitle(dateString) {
        try {
            var parts = dateString.split("-");
            return parseInt(parts[1], 10) + "月" + parseInt(parts[2], 10) + "日的活動";
        } catch(e) {
            return dateString + " 的活動";
        }
    }
    
    // 監聽年月變更，自動重繪
    onCurrentYearChanged: updateCalendarModel()
    onCurrentMonthChanged: updateCalendarModel()
    Component.onCompleted: updateCalendarModel()
    
    // ── 主體滾動視圖 (包含月曆＋活動) ──
    ScrollView {
        id: calendarWidgetScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        
        Column {
            width: calendarWidgetScrollView.width
            spacing: 8
            
            // ── 1. 月份切換標頭與新增按鈕 ──
            RowLayout {
                width: parent.width
                spacing: 8
                
                RoundButton {
                    id: prevMonthBtn
                    width: 28
                    height: 28
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    padding: 0
                    
                    scale: pressed ? 0.9 : (hovered ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    
                    background: Rectangle {
                        radius: 14
                        color: parent.pressed ? "#33FFFFFF" : (parent.hovered ? "#1AFFFFFF" : "transparent")
                    }
                    contentItem: Text {
                        text: "\ue5cb" // chevron_left
                        font.family: "Material Icons"
                        font.pixelSize: 22
                        color: parent.hovered ? "white" : "#B2FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (currentMonth === 0) {
                            currentMonth = 11;
                            currentYear--;
                        } else {
                            currentMonth--;
                        }
                    }
                }
                
                Text {
                    id: monthYearText
                    Layout.fillWidth: true
                    text: currentYear + "年 " + (currentMonth + 1) + "月"
                    color: "white"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                RoundButton {
                    id: nextMonthBtn
                    width: 28
                    height: 28
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    padding: 0
                    
                    scale: pressed ? 0.9 : (hovered ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    
                    background: Rectangle {
                        radius: 14
                        color: parent.pressed ? "#33FFFFFF" : (parent.hovered ? "#1AFFFFFF" : "transparent")
                    }
                    contentItem: Text {
                        text: "\ue5cc" // chevron_right
                        font.family: "Material Icons"
                        font.pixelSize: 22
                        color: parent.hovered ? "white" : "#B2FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (currentMonth === 11) {
                            currentMonth = 0;
                            currentYear++;
                        } else {
                            currentMonth++;
                        }
                    }
                }
                
                RoundButton {
                    id: addEventButton
                    width: 28
                    height: 28
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    padding: 0
                    
                    scale: pressed ? 0.9 : (hovered ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    
                    background: Rectangle {
                        radius: 14
                        color: parent.pressed ? "#4CFFFFFF" : (parent.hovered ? "#33FFFFFF" : "#1AFFFFFF")
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    contentItem: Text {
                        text: "\ue145" // add icon
                        font.family: "Material Icons"
                        font.pixelSize: 16
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        openAddEventDialog();
                    }
                }
            }
            
            // ── 2. 星期標頭 ──
            Row {
                id: weekdaysRow
                width: parent.width
                spacing: 4
                
                Repeater {
                    model: ["日", "一", "二", "三", "四", "五", "六"]
                    delegate: Text {
                        width: (weekdaysRow.width - (weekdaysRow.spacing * 6)) / 7
                        text: modelData
                        color: index === 0 || index === 6 ? "#80E57373" : "#60FFFFFF" // 假日以紅色調高亮
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            
            // ── 3. 日期網格 (7x6) ──
            Grid {
                id: daysGrid
                columns: 7
                spacing: 4
                width: parent.width
                
                Repeater {
                    model: calendarModel
                    delegate: Rectangle {
                        width: (daysGrid.width - (daysGrid.spacing * 6)) / 7
                        height: 30 // 從 32 縮小至 26，使月曆更精簡
                        radius: 6
                        
                        // 背景高亮邏輯 (選取中帶深藍底，今日帶微白底)
                        color: {
                            if (selectedDateString === modelData.dateString) return "#222196F3"
                            if (modelData.isToday) return "#1AFFFFFF"
                            return "transparent"
                        }
                        
                        // 邊框邏輯
                        border.color: {
                            if (selectedDateString === modelData.dateString) return "#FF2196F3"
                            if (modelData.isToday) return "#33FFFFFF"
                            return "transparent"
                        }
                        border.width: selectedDateString === modelData.dateString ? 2 : 1
                        
                        scale: mouseArea.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            
                            Text {
                                text: modelData.dayNumber
                                color: {
                                    if (selectedDateString === modelData.dateString) return "white"
                                    if (modelData.isCurrentMonth) return "white"
                                    return "#3DFFFFFF" // 非當月日期呈淡灰色
                                }
                                font.pixelSize: 10
                                font.weight: modelData.isToday || selectedDateString === modelData.dateString ? Font.DemiBold : Font.Normal
                                Layout.alignment: Qt.AlignCenter
                            }
                            
                            // 事件標記桃紅圓點
                            Rectangle {
                                width: 3
                                height: 3
                                radius: 1.5
                                color: "#FF4081"
                                Layout.alignment: Qt.AlignCenter
                                visible: {
                                    // 藉由讀取 allEvents 以註冊 QML 的屬性依賴
                                    var dummy = allEvents;
                                    return hasEventsOnDate(modelData.dateString);
                                }
                            }
                        }
                        
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                selectedDateString = modelData.dateString;
                            }
                        }
                    }
                }
            }
            
            // ── 4. 分隔線 ──
            Rectangle {
                width: parent.width
                height: 1
                color: "#1EFFFFFF"
                transform: Translate { y: 2 }
            }
            
            // ── 5. 選取日期的事件標題 ──
            Text {
                id: filterTitle
                text: formatSelectedDateTitle(selectedDateString)
                color: "#89FFFFFF"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                padding: 4
            }
            
            // ── 6. 篩選後的事件列表 ──
            Column {
                width: parent.width
                spacing: 6
                
                Text {
                    visible: filteredRepeater.count === 0
                    text: "當天暫無事件"
                    color: "#3DFFFFFF"
                    font.pixelSize: 13
                    padding: 8
                }
                
                Repeater {
                    id: filteredRepeater
                    model: getFilteredEvents(selectedDateString)
                    
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
                                    if (vis === "private") return "\ue897" // lock 🔒
                                    if (vis === "shared") return "\ue7fb"  // people
                                    return "\ue80b"                      // public 🌐
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
    }
    
    // ── 7. 後端事件更新監聽 ──
    Connections {
        target: backend
        function onCalendarUpdated(data) {
            allEvents = data
        }
    }
}
