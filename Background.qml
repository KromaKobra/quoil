import QtQuick
import Quickshell
import Quickshell.Wayland

// Fullscreen wallpaper, one per monitor. Sits below every window and reserves no space.
PanelWindow {
    WlrLayershell.namespace: "quoil-background"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    color: "black"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Image {
        anchors.fill: parent
        source: Config.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
