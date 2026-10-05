pragma Singleton

import QtQuick
import Quickshell

// The one file to edit. Everything else reads from here.
Singleton {
    property string wallpaper: "/home/kroma/Pictures/Wallpapers/octahedron-field.png"

    // Which screen edge the bar hangs from. A plain string so a future settings
    // dropdown can bind straight to it, using `barEdges` as its model.
    property string barEdge: "top"
    readonly property list<string> barEdges: ["top", "bottom", "left", "right"]

    // The bar is invisible along the edge except for one dip in the middle.
    property int barThickness: 32   // how far the dip reaches into the screen
    property int barLength: 120     // flat stretch of the dip that holds the clock

    // Shape of everything docked to the bar, the clock's dip included, so they all match.
    property real dockSlope: 0      // how far each side leans out per pixel of depth: 0 = vertical, 1 = 45°
    property int dockRadius: 16     // radius of the corners where each side leaves the edge and meets the floor

    property color barColour: Qt.rgba(0, 0, 0, 0.6)
    property color barTextColour: "white"
}
