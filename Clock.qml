import QtQuick
import Quickshell

// Hours and minutes. Stacks them on two lines when the bar runs down a side edge.
Text {
    property bool vertical: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, vertical ? "hh\nmm" : "hh:mm")
    color: Config.barTextColour
    font.pixelSize: Math.round(Config.barThickness * 0.45)
    font.weight: Font.DemiBold
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 0.9
}
