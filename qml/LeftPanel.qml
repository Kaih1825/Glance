import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24
        
        ClockWidget {
            Layout.alignment: Qt.AlignHCenter
        }
        WeatherWidget {
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
