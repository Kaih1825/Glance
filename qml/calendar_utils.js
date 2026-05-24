// qml/calendar_utils.js
.pragma library

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
function hasEventsOnDate(dateString, allEvents) {
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
function getFilteredEvents(dateString, allEvents) {
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

// 格式化選取日期的標題文字
function formatSelectedDateTitle(dateString) {
    try {
        var parts = dateString.split("-");
        return parseInt(parts[1], 10) + "月" + parseInt(parts[2], 10) + "日的活動";
    } catch(e) {
        return dateString + " 的活動";
    }
}
