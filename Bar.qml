import QtQuick
import Quickshell
import Quickshell.Wayland

// Status bar, one per monitor. Invisible along the whole edge except the middle, where it
// curves smoothly into the screen and back out again to hold the clock.
PanelWindow {
    id: bar

    readonly property string edge: Config.barEdges.includes(Config.barEdge) ? Config.barEdge : "top"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property real sizeScale: Math.max(0.1, Config.barScale)

    WlrLayershell.namespace: "quoil-bar"
    WlrLayershell.layer: WlrLayer.Top

    color: "transparent"

    // Anchoring to a single edge makes the compositor centre the window along it, so the
    // window is only as big as the dip and never swallows clicks anywhere else on the edge.
    anchors {
        top: bar.edge === "top"
        bottom: bar.edge === "bottom"
        left: bar.edge === "left"
        right: bar.edge === "right"
    }

    // Window sizes are whole pixels; round the span up so the tips of the dip aren't clipped.
    implicitWidth: Math.ceil((vertical ? dip.depth : dip.span) * sizeScale)
    implicitHeight: Math.ceil((vertical ? dip.span : dip.depth) * sizeScale)

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Math.ceil(dip.depth * sizeScale)

    // Drawn hanging from the top edge; rotated for the others.
    DockShape {
        id: dip

        anchors.centerIn: parent
        // Snapping the centre to a whole pixel would pull a rotated dip off the screen edge.
        anchors.alignWhenCentered: false
        length: Config.barLength
        depth: Config.barThickness
        scale: bar.sizeScale
        rotation: ({ top: 0, right: 90, bottom: 180, left: -90 })[bar.edge]
    }

    // Not a child of the Shape, so it stays upright whatever edge the bar is on.
    Clock {
        anchors.centerIn: parent
        vertical: bar.vertical
        scale: bar.sizeScale
    }

    Item {
        anchors.fill: parent

        WorkspaceWheelHandler {
            screen: bar.screen
        }
    }
}
